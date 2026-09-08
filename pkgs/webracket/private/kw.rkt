#lang racket/base

(require (only-in '#%kernel
                  checked-procedure-check-and-extract
                  [make-struct-field-accessor kernel:make-struct-field-accessor]
                  [make-struct-type-property kernel:make-struct-type-property]
                  [procedure->method kernel:procedure->method]
                  [procedure-rename kernel:procedure-rename]
                  [procedure-realm kernel:procedure-realm]
                  [procedure-reduce-arity kernel:procedure-reduce-arity]
                  [procedure-reduce-arity-mask kernel:procedure-reduce-arity-mask]
                  [prop:procedure kernel:prop:procedure]))

(provide make-keyword-procedure
         keyword-apply
         new-keyword-apply
         new:procedure-reduce-arity
         new:procedure-reduce-arity-mask
         new-prop:procedure
         new:procedure->method
         new:procedure-rename
         new:procedure-realm
         subsets?
         make-optional-keyword-procedure
         make-optional-keyword-method
         make-required-keyword-method/arity-error
         keyword-procedure-extract
         procedure-keywords
         procedure-reduce-keyword-arity
         procedure-reduce-keyword-arity-mask
         missing-kw
         prop:named-keyword-procedure
         struct:keyword-procedure
         struct:keyword-procedure/arity-error
         struct:keyword-method
         struct:keyword-method/arity-error)

;; A small WebRacket-owned subset of `racket/private/kw`.
;;
;; Racket's expander lowers keyword lambdas to calls into this runtime
;; protocol. This module intentionally supports the non-impersonator path first:
;; enough for module-based programs that define and call ordinary keyword
;; procedures.

;; Racket 9.3 imports these names directly from `racket/private/kw`. The
;; source names below are aliases for the underlying WebRacket primitives; the
;; module bridge recognizes the compiler's renamed `new:*` imports and routes
;; them to those primitives instead of back to this shim.
(define-values (keyword-procedure-accessor-property
                keyword-procedure-accessor?
                keyword-procedure-accessor-ref)
  (kernel:make-struct-type-property
   'procedure
   (lambda (value info)
     (if (exact-integer? value)
         (kernel:make-struct-field-accessor (list-ref info 3) value)
         #f))))

(define-values (new-prop:procedure
                new-procedure?
                new-procedure-ref)
  (kernel:make-struct-type-property
   'procedure
   #f
   (list (cons kernel:prop:procedure values)
         (cons keyword-procedure-accessor-property values))
   #t))

;; new:procedure-reduce-arity : procedure? procedure-arity? [symbol?] [symbol?] -> procedure?
;;   Reduce a procedure's arity with Racket's default `racket` realm.
(define new:procedure-reduce-arity
  (case-lambda
    [(proc arity) (kernel:procedure-reduce-arity proc arity #f 'racket)]
    [(proc arity name) (kernel:procedure-reduce-arity proc arity name 'racket)]
    [(proc arity name realm) (kernel:procedure-reduce-arity proc arity name realm)]))

;; new:procedure-reduce-arity-mask : procedure? exact-nonnegative-integer? [symbol?] [symbol?] -> procedure?
;;   Reduce a procedure's arity mask with Racket's default `racket` realm.
(define new:procedure-reduce-arity-mask
  (case-lambda
    [(proc mask) (kernel:procedure-reduce-arity-mask proc mask #f 'racket)]
    [(proc mask name) (kernel:procedure-reduce-arity-mask proc mask name 'racket)]
    [(proc mask name realm) (kernel:procedure-reduce-arity-mask proc mask name realm)]))

(define new:procedure->method kernel:procedure->method)

;; new:procedure-rename : procedure? symbol? [symbol?] -> procedure?
;;   Rename a procedure with Racket's default `racket` realm.
(define new:procedure-rename
  (case-lambda
    [(proc name) (kernel:procedure-rename proc name 'racket)]
    [(proc name realm) (kernel:procedure-rename proc name realm)]))

(define new:procedure-realm kernel:procedure-realm)

(define-values (struct:keyword-procedure
                make-raw-keyword-procedure
                keyword-procedure?
                keyword-procedure-ref
                keyword-procedure-set!)
  (make-struct-type 'keyword-procedure
                    #f
                    4
                    0
                    #f
                    (list (cons prop:checked-procedure #t))
                    (current-inspector)
                    #f
                    '(0 1 2 3)))

(define keyword-procedure-checker
  (make-struct-field-accessor keyword-procedure-ref 0))

(define keyword-procedure-proc
  (make-struct-field-accessor keyword-procedure-ref 1))

(define keyword-procedure-required
  (make-struct-field-accessor keyword-procedure-ref 2))

(define keyword-procedure-allowed
  (make-struct-field-accessor keyword-procedure-ref 3))

(define-values (struct:optional-keyword-procedure
                make-raw-optional-keyword-procedure
                optional-keyword-procedure?
                optional-keyword-procedure-ref
                optional-keyword-procedure-set!)
  (make-struct-type 'procedure
                    struct:keyword-procedure
                    1
                    0
                    #f
                    null
                    (current-inspector)
                    0
                    '(0)))

(define optional-keyword-procedure-plain
  (make-struct-field-accessor optional-keyword-procedure-ref 0))

(define-values (struct:keyword-method
                make-raw-keyword-method
                keyword-method?
                keyword-method-ref
                keyword-method-set!)
  (make-struct-type 'procedure
                    struct:keyword-procedure
                    0
                    0
                    #f
                    null
                    (current-inspector)
                    #f
                    null))

(define-values (struct:optional-keyword-method
                make-raw-optional-keyword-method
                optional-keyword-method?
                optional-keyword-method-ref
                optional-keyword-method-set!)
  (make-struct-type 'procedure
                    struct:optional-keyword-procedure
                    0
                    0
                    #f
                    null
                    (current-inspector)
                    #f
                    null))

(define-values (prop:named-keyword-procedure
                named-keyword-procedure?
                keyword-procedure-name+fail)
  (make-struct-type-property 'named-keyword-procedure))

(define-values (struct:keyword-procedure/arity-error
                make-keyword-procedure/arity-error
                keyword-procedure/arity-error?
                keyword-procedure/arity-error-ref
                keyword-procedure/arity-error-set!)
  (make-struct-type 'procedure
                    struct:keyword-procedure
                    0
                    0
                    #f
                    null
                    (current-inspector)
                    #f
                    null))

(define-values (struct:keyword-method/arity-error
                make-keyword-method/arity-error
                keyword-method/arity-error?
                keyword-method/arity-error-ref
                keyword-method/arity-error-set!)
  (make-struct-type 'procedure
                    struct:keyword-method
                    0
                    0
                    #f
                    null
                    (current-inspector)
                    #f
                    null))

(define-values (struct:required-keyword-method/arity-error
                make-required-keyword-method/arity-error
                required-keyword-method/arity-error?
                required-keyword-method/arity-error-ref
                required-keyword-method/arity-error-set!)
  (make-struct-type 'procedure
                    struct:keyword-method/arity-error
                    3
                    0
                    #f
                    (list (cons prop:procedure 0)
                          (cons prop:object-name 1)
                          (cons prop:named-keyword-procedure
                                (lambda (r)
                                  (vector
                                   (required-keyword-method/arity-error-ref r 1)
                                   (required-keyword-method/arity-error-ref r 2)
                                   (required-keyword-method/arity-error-ref r 0)))))
                    (current-inspector)
                    #f
                    '(0 1 2)))

;; sorted-keywords? : any/c -> boolean?
;;   Check for a sorted, duplicate-free keyword list.
(define (sorted-keywords? kws)
  (let loop ([kws kws])
    (cond
      [(null? kws) #t]
      [(not (pair? kws)) #f]
      [(not (keyword? (car kws))) #f]
      [(null? (cdr kws)) #t]
      [(not (and (pair? (cdr kws))
                 (keyword? (cadr kws))
                 (keyword<? (car kws) (cadr kws))))
       #f]
      [else (loop (cdr kws))])))

;; sorted-keyword-subset? : (listof keyword?) (listof keyword?) -> boolean?
;;   Check whether required sorted keywords are included in supplied sorted keywords.
(define (sorted-keyword-subset? required supplied)
  (cond
    [(null? required) #t]
    [(null? supplied) #f]
    [(eq? (car required) (car supplied))
     (sorted-keyword-subset? (cdr required) (cdr supplied))]
    [else (sorted-keyword-subset? required (cdr supplied))]))

;; keyword-list-valid? : (listof keyword?) (or/c (listof keyword?) #f) -> boolean?
;;   Check the required/allowed keyword invariant from the Reference.
(define (keyword-list-valid? required allowed)
  (and (sorted-keywords? required)
       (or (not allowed)
           (and (sorted-keywords? allowed)
                (sorted-keyword-subset? required allowed)))))

;; keyword-args-accepted? : (listof keyword?) (listof keyword?) (or/c (listof keyword?) #f) -> boolean?
;;   Check supplied keywords against required and allowed keyword sets.
(define (keyword-args-accepted? kws required allowed)
  (and (sorted-keyword-subset? required kws)
       (or (not allowed)
           (sorted-keyword-subset? kws allowed))))

;; subsets? : (listof any/c) (listof any/c) (listof any/c) -> boolean?
;;   Check whether l1 and l2 are subsets of l3, assuming sorted inputs and l1 subset of l3.
(define (subsets? l1 l2 l3)
  (cond
    [(null? l1) (sorted-keyword-subset? l2 l3)]
    [(null? l2) #f]
    [(null? l3) #f]
    [else
     (define v2 (car l2))
     (cond
       [(eq? (car l1) v2)
        (subsets? (cdr l1) (cdr l2) (cdr l3))]
       [(eq? v2 (car l3))
        (subsets? l1 (cdr l2) (cdr l3))]
       [else
        (subsets? l1 l2 (cdr l3))])]))

;; make-keyword-checker : (listof keyword?) (or/c (listof keyword?) #f) exact-integer? -> procedure?
;;   Build a checker for reduced keyword procedure metadata.
(define (make-keyword-checker required allowed arity-mask)
  (lambda (kws argc)
    (and (keyword-args-accepted? kws required allowed)
         (bitwise-bit-set? arity-mask argc))))

;; check-keyword-list : symbol? any/c exact-nonnegative-integer? -> void?
;;   Validate a sorted keyword list argument.
(define (check-keyword-list who kws pos)
  (unless (sorted-keywords? kws)
    (raise-argument-error who
                          "(and/c (listof keyword?) sorted? distinct?)"
                          pos
                          kws)))

;; raw-keyword-procedure-extract : any/c (listof keyword?) exact-nonnegative-integer? -> procedure?
;;   Extract the keyword dispatcher for an ordinary keyword-procedure struct.
(define (raw-keyword-procedure-extract proc kws argc)
  (check-keyword-list 'keyword-procedure-extract kws 1)
  (cond
    [(and (keyword-procedure? proc)
          ((keyword-procedure-checker proc) kws argc))
     (keyword-procedure-proc proc)]
    [(and (or (keyword-method? proc)
              (optional-keyword-method? proc))
          ((keyword-procedure-checker proc) kws (add1 argc)))
     ;; Keyword methods account for the implicit receiver in their arity mask.
     (keyword-procedure-proc proc)]
    [else
     (raise-arguments-error 'keyword-procedure-extract
                            "procedure does not accept the supplied keywords"
                            "procedure" proc
                            "keywords" kws
                            "argument count" argc)]))

;; keyword-procedure-extract : any/c (listof keyword?) exact-nonnegative-integer? -> procedure?
;;   Extract the keyword dispatcher for an expanded keyword application.
(define (keyword-procedure-extract proc kws argc)
  (checked-procedure-check-and-extract struct:keyword-procedure
                                       proc
                                       raw-keyword-procedure-extract
                                       kws
                                       argc))

;; procedure-keywords : procedure? -> (values (listof keyword?) (or/c (listof keyword?) #f))
;;   Report keyword requirements for WebRacket keyword procedures.
(define (procedure-keywords proc)
  (cond
    [(keyword-procedure? proc)
     (values (keyword-procedure-required proc)
             (keyword-procedure-allowed proc))]
    [(procedure? proc) (values null null)]
    [else
     (raise-argument-error 'procedure-keywords "procedure?" proc)]))

;; make-plain-keyword-fallback : procedure? -> procedure?
;;   Build the no-keyword entry point for make-keyword-procedure.
(define (make-plain-keyword-fallback proc)
  (lambda args
    (apply proc null null args)))

;; missing-kw : procedure? any/c ... -> any
;;   Failure entry point imported by Racket's keyword-lambda expansion.
(define (missing-kw proc . args)
  (raise-arguments-error 'missing-kw
                         "procedure is missing a required keyword"
                         "procedure" proc
                         "arguments" args))

;; make-optional-keyword-procedure : procedure? [procedure?] -> procedure?
;; make-optional-keyword-procedure : procedure? procedure? list? (or/c list? #f) procedure? -> procedure?
;;   Construct the applicable struct shape generated by keyword lambdas.
(define make-optional-keyword-procedure
  (case-lambda
    [(kw-proc)
     (make-optional-keyword-procedure kw-proc
                                      (make-plain-keyword-fallback kw-proc))]
    [(kw-proc plain-proc)
     (make-optional-keyword-procedure (lambda (_kws _argc) #t)
                                      kw-proc
                                      null
                                      #f
                                      plain-proc)]
    [(checker kw-proc required allowed plain-proc)
     (unless (procedure? checker)
       (raise-argument-error 'make-optional-keyword-procedure "procedure?" checker))
     (unless (procedure? kw-proc)
       (raise-argument-error 'make-optional-keyword-procedure "procedure?" kw-proc))
     (unless (list? required)
       (raise-argument-error 'make-optional-keyword-procedure "list?" required))
     (unless (or (list? allowed) (not allowed))
       (raise-argument-error 'make-optional-keyword-procedure "(or/c list? #f)" allowed))
     (unless (procedure? plain-proc)
       (raise-argument-error 'make-optional-keyword-procedure "procedure?" plain-proc))
     (make-raw-optional-keyword-procedure checker
                                          kw-proc
                                          required
                                          allowed
                                          plain-proc)]))

;; make-optional-keyword-method : procedure? procedure? list? (or/c list? #f) procedure? -> procedure?
;;   Construct the method variant of an optional keyword procedure.
(define (make-optional-keyword-method checker kw-proc required allowed plain-proc)
  (unless (procedure? checker)
    (raise-argument-error 'make-optional-keyword-method "procedure?" checker))
  (unless (procedure? kw-proc)
    (raise-argument-error 'make-optional-keyword-method "procedure?" kw-proc))
  (unless (list? required)
    (raise-argument-error 'make-optional-keyword-method "list?" required))
  (unless (or (list? allowed) (not allowed))
    (raise-argument-error 'make-optional-keyword-method "(or/c list? #f)" allowed))
  (unless (procedure? plain-proc)
    (raise-argument-error 'make-optional-keyword-method "procedure?" plain-proc))
  (make-raw-optional-keyword-method checker
                                    kw-proc
                                    required
                                    allowed
                                    plain-proc))

;; make-keyword-procedure : procedure? [procedure?] -> procedure?
;;   Public constructor for procedures that accept arbitrary keywords.
(define make-keyword-procedure
  (case-lambda
    [(kw-proc)
     (make-optional-keyword-procedure kw-proc)]
    [(kw-proc plain-proc)
     (make-optional-keyword-procedure kw-proc plain-proc)]))

;; collect-normal-args : symbol? list? -> list?
;;   Merge keyword-apply's positional arguments with the final rest list.
(define (collect-normal-args who normal-argss)
  (let loop ([normal-argss normal-argss] [pos 3])
    (cond
      [(null? normal-argss)
       (raise-arguments-error who
                              "expected at least one final positional list")]
      [(null? (cdr normal-argss))
       (define tail (car normal-argss))
       (unless (list? tail)
         (raise-argument-error who "list?" pos tail))
       tail]
      [else
       (cons (car normal-argss)
             (loop (cdr normal-argss) (add1 pos)))])))

;; merge-keyword-arguments : symbol? list? list? list? list? -> (values list? list?)
;;   Merge sorted keyword/value lists, rejecting duplicates.
(define (merge-keyword-arguments who kws kw-args orig-kws orig-kw-args)
  (let loop ([kws kws]
             [kw-args kw-args]
             [orig-kws orig-kws]
             [orig-kw-args orig-kw-args])
    (cond
      [(null? kws) (values orig-kws orig-kw-args)]
      [(null? orig-kws) (values kws kw-args)]
      [(eq? (car kws) (car orig-kws))
       (raise-mismatch-error who
                             "keyword duplicated in list and direct keyword arguments: "
                             (car kws))]
      [(keyword<? (car kws) (car orig-kws))
       (define-values (rest-kws rest-args)
         (loop (cdr kws) (cdr kw-args) orig-kws orig-kw-args))
       (values (cons (car kws) rest-kws)
               (cons (car kw-args) rest-args))]
      [else
       (define-values (rest-kws rest-args)
         (loop kws kw-args (cdr orig-kws) (cdr orig-kw-args)))
       (values (cons (car orig-kws) rest-kws)
               (cons (car orig-kw-args) rest-args))])))

;; do-keyword-apply : symbol? procedure? list? list? list? -> any/c
;;   Apply proc with already-validated keyword and positional arguments.
(define (do-keyword-apply who proc kws kw-args normal-args)
  (cond
    [(null? kws) (apply proc normal-args)]
    [else
     (apply (keyword-procedure-extract proc kws (+ 2 (length normal-args)))
            (cons kws (cons kw-args normal-args)))]))

;; arity->mask : any/c -> exact-integer?
;;   Convert a procedure arity value to a procedure-arity-mask-style integer.
(define (arity->mask arity)
  (cond
    [(and (exact-integer? arity) (not (negative? arity)))
     (arithmetic-shift 1 arity)]
    [(arity-at-least? arity)
     (arithmetic-shift -1 (arity-at-least-value arity))]
    [(list? arity)
     (let loop ([arities arity] [mask 0])
       (cond
         [(null? arities) mask]
         [else (loop (cdr arities)
                     (bitwise-ior mask (arity->mask (car arities))))]))]
    [else
     (raise-argument-error 'procedure-reduce-keyword-arity
                           "procedure-arity?"
                           arity)]))

;; keyword-apply : procedure? list? list? any/c ... list? #:kw any/c ... -> any/c
;;   Apply a procedure with dynamic keyword arguments.
(define keyword-apply
  (make-keyword-procedure
   (lambda (direct-kws direct-kw-args proc kws kw-args . normal-argss)
     (unless (procedure? proc)
       (raise-argument-error 'keyword-apply "procedure?" 0 proc))
     (check-keyword-list 'keyword-apply kws 1)
     (unless (list? kw-args)
       (raise-argument-error 'keyword-apply "list?" 2 kw-args))
     (unless (= (length kws) (length kw-args))
       (raise-arguments-error 'keyword-apply
                              "keyword list length does not match value list length"
                              "keyword list length" (length kws)
                              "value list length" (length kw-args)
                              "keyword list" kws
                              "value list" kw-args))
     (define normal-args (collect-normal-args 'keyword-apply normal-argss))
     (define-values (merged-kws merged-kw-args)
       (merge-keyword-arguments 'keyword-apply
                                direct-kws
                                direct-kw-args
                                kws
                                kw-args))
     (do-keyword-apply 'keyword-apply proc merged-kws merged-kw-args normal-args))
   (lambda (proc kws kw-args . normal-argss)
     (unless (procedure? proc)
       (raise-argument-error 'keyword-apply "procedure?" 0 proc))
     (check-keyword-list 'keyword-apply kws 1)
     (unless (list? kw-args)
       (raise-argument-error 'keyword-apply "list?" 2 kw-args))
     (unless (= (length kws) (length kw-args))
       (raise-arguments-error 'keyword-apply
                              "keyword list length does not match value list length"
                              "keyword list length" (length kws)
                              "value list length" (length kw-args)
                              "keyword list" kws
                              "value list" kw-args))
     (do-keyword-apply 'keyword-apply
                       proc
                       kws
                       kw-args
                       (collect-normal-args 'keyword-apply normal-argss)))))

;; new-keyword-apply : procedure? list? list? list? any/c ... -> any/c
;;   WebRacket version of racket/private/pre-base's keyword-apply wrapper.
(define new-keyword-apply
  (make-keyword-procedure
   (lambda (direct-kws direct-kw-args proc orig-kws orig-kw-args args . rest)
     (define-values (merged-kws merged-kw-args)
       (merge-keyword-arguments 'keyword-apply
                                direct-kws
                                direct-kw-args
                                orig-kws
                                orig-kw-args))
     (do-keyword-apply 'keyword-apply
                       proc
                       merged-kws
                       merged-kw-args
                       (apply list* args rest)))
   (lambda (proc orig-kws orig-kw-args args . rest)
     (do-keyword-apply 'keyword-apply
                       proc
                       orig-kws
                       orig-kw-args
                       (apply list* args rest)))))

;; procedure-reduce-keyword-arity : procedure? arity? list? (or/c list? #f) [symbol? #f] [symbol?] -> procedure?
;;   Reduce positional and keyword arity for a keyword-capable procedure.
(define procedure-reduce-keyword-arity
  (case-lambda
    [(proc arity required allowed)
     (procedure-reduce-keyword-arity proc arity required allowed #f 'racket)]
    [(proc arity required allowed name)
     (procedure-reduce-keyword-arity proc arity required allowed name 'racket)]
    [(proc arity required allowed name realm)
     (unless (procedure? proc)
       (raise-argument-error 'procedure-reduce-keyword-arity "procedure?" proc))
     (unless (keyword-list-valid? required allowed)
       (raise-arguments-error 'procedure-reduce-keyword-arity
                              "expected sorted distinct required keywords and compatible allowed keywords"
                              "required keywords" required
                              "allowed keywords" allowed))
     (procedure-reduce-keyword-arity-mask proc
                                          (arity->mask arity)
                                          required
                                          allowed
                                          name
                                          realm)]))

;; procedure-reduce-keyword-arity-mask : procedure? exact-integer? list? (or/c list? #f) [symbol? #f] [symbol?] -> procedure?
;;   Reduce keyword arity using an arity mask.
(define procedure-reduce-keyword-arity-mask
  (case-lambda
    [(proc mask required allowed)
     (procedure-reduce-keyword-arity-mask proc mask required allowed #f 'racket)]
    [(proc mask required allowed name)
     (procedure-reduce-keyword-arity-mask proc mask required allowed name 'racket)]
    [(proc mask required allowed name realm)
     (unless (procedure? proc)
       (raise-argument-error 'procedure-reduce-keyword-arity-mask "procedure?" proc))
     (unless (exact-integer? mask)
       (raise-argument-error 'procedure-reduce-keyword-arity-mask "exact-integer?" mask))
     (unless (keyword-list-valid? required allowed)
       (raise-arguments-error 'procedure-reduce-keyword-arity-mask
                              "expected sorted distinct required keywords and compatible allowed keywords"
                              "required keywords" required
                              "allowed keywords" allowed))
     ;; Racket's expanded keyword-call protocol passes an argument count that
     ;; includes the hidden `kws` and `kw-args` dispatcher arguments.
     (define keyword-mask (arithmetic-shift mask 2))
     (define plain-base-proc
       (if (optional-keyword-procedure? proc)
           (optional-keyword-procedure-plain proc)
           (lambda normal-args
             (do-keyword-apply 'procedure-reduce-keyword-arity-mask
                               proc
                               null
                               null
                               normal-args))))
     (define plain-proc
       (and (null? required)
            (procedure-reduce-arity-mask plain-base-proc mask name realm)))
     (define kw-base-proc
       (if (keyword-procedure? proc)
           (keyword-procedure-proc proc)
           (lambda (kws kw-args . normal-args)
             (do-keyword-apply 'procedure-reduce-keyword-arity-mask
                               proc
                               kws
                               kw-args
                               normal-args))))
     (define kw-proc
       (procedure-reduce-arity-mask kw-base-proc keyword-mask name realm))
     (make-optional-keyword-procedure
      (make-keyword-checker required allowed keyword-mask)
      kw-proc
      required
      allowed
      (or plain-proc
          (lambda args
            (missing-kw proc args))))]))
