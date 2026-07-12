#lang racket

(provide (struct-out helper-dependency-problem)
         shared-type-name-set
         core-runtime-helper-dependency-problems)

(require "shared-types.rkt")

;; A helper dependency problem explains why a core helper is not standalone
;; with respect to the shared type declarations.
(struct helper-dependency-problem (kind detail) #:transparent)

;; wasm-dollar-symbol? : any/c -> boolean?
;;   Check whether v is a Wasm identifier symbol such as `$Pair`.
(define (wasm-dollar-symbol? v)
  (and (symbol? v)
       (regexp-match? #rx"^\\$" (symbol->string v))))

;; collect-shared-type-names : datum? -> (listof symbol?)
;;   Collect named type declarations from the shared type tree.
(define (collect-shared-type-names form)
  (match form
    [`(type ,(? wasm-dollar-symbol? type-name) . ,body)
     (cons type-name (append-map collect-shared-type-names body))]
    [(? list?)
     (append-map collect-shared-type-names form)]
    [_ '()]))

;; shared-type-name-set : [(listof datum?)] -> hasheq?
;;   Return the set of named types available to standalone core helpers.
(define (shared-type-name-set [shared-types (generate-shared-types)])
  (for*/hasheq ([form (in-list shared-types)]
                [name (in-list (collect-shared-type-names form))])
    (values name #t)))

;; direct-type-reference-heads : (listof symbol?)
;;   Operators whose first operand is a named type reference.
(define direct-type-reference-heads
  '(array.get
    array.get_s
    array.get_u
    array.new
    array.new_default
    array.new_fixed
    array.set
    struct.get
    struct.new
    struct.new_default
    struct.set))

;; named-type-reference-names : datum? -> (listof symbol?)
;;   Collect references to named types from a WAT form.
(define (named-type-reference-names form)
  (match form
    [`(type ,(? wasm-dollar-symbol? type-name))
     (list type-name)]
    [`(ref ,(? wasm-dollar-symbol? type-name))
     (list type-name)]
    [`(ref null ,(? wasm-dollar-symbol? type-name))
     (list type-name)]
    [`(,(? (lambda (head) (memq head direct-type-reference-heads)))
       ,(? wasm-dollar-symbol? type-name)
       ,body ...)
     (cons type-name (append-map named-type-reference-names body))]
    [(? list?)
     (append-map named-type-reference-names form)]
    [_ '()]))

;; disallowed-core-helper-heads : (listof symbol?)
;;   Forms that mean a helper depends on monolithic runtime definitions.
(define disallowed-core-helper-heads
  '(call_indirect
    call_ref
    data
    elem
    global.set
    import
    memory
    return_call_indirect
    return_call_ref
    table))

;; runtime-dependency-problems :
;;   datum? hasheq? [hasheq?] -> (listof helper-dependency-problem?)
;;   Report runtime dependencies that standalone helpers must not have.
(define (runtime-dependency-problems form
                                     core-helper-names
                                     [core-global-names (hasheq)])
  (match form
    [`(,(? (lambda (head) (memq head '(call return_call))) _)
       ,(? symbol? target)
       ,body ...)
     (append
      (if (hash-has-key? core-helper-names target)
          '()
          (list (helper-dependency-problem 'runtime-call target)))
      (append-map (lambda (body-form)
                    (runtime-dependency-problems body-form
                                                 core-helper-names
                                                 core-global-names))
                  body))]
    [`(global.get ,(? symbol? target))
     (if (hash-has-key? core-global-names target)
         '()
         (list (helper-dependency-problem 'runtime-global target)))]
    [`(ref.func ,(? symbol? target))
     (if (hash-has-key? core-helper-names target)
         '()
         (list (helper-dependency-problem 'runtime-func-ref target)))]
    [`(,(? (lambda (head) (memq head disallowed-core-helper-heads)) head)
       ,body ...)
     (cons (helper-dependency-problem 'runtime-dependency head)
           (append-map (lambda (body-form)
                         (runtime-dependency-problems body-form
                                                      core-helper-names
                                                      core-global-names))
                       body))]
    [(? list?)
     (append-map (lambda (body-form)
                   (runtime-dependency-problems body-form
                                                core-helper-names
                                                core-global-names))
                 form)]
    [_ '()]))

;; type-dependency-problems : datum? hasheq? -> (listof helper-dependency-problem?)
;;   Report references to named types not supplied by generate-shared-types.
(define (type-dependency-problems form shared-types)
  (for/list ([type-name (in-list (remove-duplicates
                                  (named-type-reference-names form)
                                  eq?))]
             #:unless (hash-has-key? shared-types type-name))
    (helper-dependency-problem 'unshared-type type-name)))

;; core-runtime-helper-dependency-problems :
;;   datum? hasheq? [hasheq?] [hasheq?] -> (listof helper-dependency-problem?)
;;   Report dependencies that prevent a helper from living in core runtime.
(define (core-runtime-helper-dependency-problems
         form
         core-helper-names
         [shared-types (shared-type-name-set)]
         [core-global-names (hasheq)])
  (append (runtime-dependency-problems form core-helper-names core-global-names)
          (type-dependency-problems form shared-types)))

(module+ test
  (require rackunit)

  (define helper-names
    (hasheq '$known #t))

  (check-equal?
   (core-runtime-helper-dependency-problems
    '(func $uses-known
           (drop (ref.func $known)))
    helper-names
    (hasheq))
   '())

  (check-equal?
   (core-runtime-helper-dependency-problems
    '(func $uses-missing
           (drop (ref.func $missing)))
    helper-names
    (hasheq))
   (list (helper-dependency-problem 'runtime-func-ref '$missing))))
