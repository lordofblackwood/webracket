#lang racket/base

;;; Standard-library export discovery for the driver.
;;;
;;; The stdlib files are still source files for now, but the driver rewrites
;;; public definitions to private top-level names and exposes selected exports
;;; through module-variable cells. Keep export discovery close to the include
;;; roots so the Node and browser stdlib variants do not drift.

(require racket/list
         racket/match
         racket/runtime-path)

(provide stdlib-module-export-symbols
         stdlib-module-alias-symbols
         stdlib-module-private-forms+bindings
         stdlib-module-private-files-forms+bindings
         stdlib-definition-form-symbols
         stdlib-node-files
         stdlib-browser-files
         stdlib-primitive-owned-export-symbols
         stdlib-transitional-export-symbols)

(define-runtime-path stdlib-dir ".")

(define stdlib-node-files
  '("shared-library-structs.rkt"
    "qq-and-or.rkt"
    "ellipses.rkt"
    "parameters.rkt"
    "ports.rkt"
    "exceptions.rkt"
    "writing.rkt"
    "reading.rkt"
    "evaluation.rkt"
    "hash-code.rkt"
    "intmap.rkt"
    "formatting-numbers.rkt"))

(define stdlib-browser-files
  '("browser.rkt"))

(define stdlib-transitional-export-symbols
  '(unsafe-intmap-iterate-key+value
    unsafe-intmap-iterate-value
    unsafe-intmap-iterate-key
    unsafe-intmap-iterate-pair
    unsafe-intmap-iterate-next
    unsafe-intmap-iterate-first
    intmap-iterate-key+value
    intmap-iterate-value
    intmap-iterate-key
    intmap-iterate-pair
    intmap-iterate-next
    intmap-iterate-first
    intmap-keys-subset?
    intmap-hash-code
    intmap-map
    intmap-for-each
    intmap-fold
    intmap-remove
    intmap-set
    intmap-has-key?
    intmap-ref-key
    intmap-ref
    intmap-empty?
    intmap-count
    intmap-eq?
    intmap-eqv?
    intmap-equal?
    intmap?))

;; Public stdlib exports that intentionally remain compiler/runtime primitives
;; at the top level for now. The module wrapper still evaluates the stdlib
;; definitions internally, but does not generate top-level aliases for these
;; names until ownership is moved fully to the stdlib module.
(define stdlib-primitive-owned-export-symbols
  '(empty-hash empty-hasheq empty-hasheqv
    hash-code-combine hash-code-combine*
    hash-code-combine-unordered hash-code-combine-unordered*
    current-print
    error-print-width
    error-value->string-handler
    print-as-expression
    print-boolean-long-form
    print-box
    print-graph
    print-hash-table
    print-mpair-curly-braces
    print-pair-curly-braces
    print-reader-abbreviations
    print-struct
    print-syntax-width
    print-unreadable
    print-value-columns
    print-vector-length
    raise-argument-error
    raise-argument-error*
    raise-arguments-error
    read
    read-syntax))

;; definition-form->symbols : any/c -> (listof symbol?)
;;   Extract top-level names defined by the small definition shapes used in
;;   stdlib/*.rkt.
(define (definition-form->symbols form)
  (match form
    [`(define (,name . ,_) . ,_) (if (symbol? name) (list name) '())]
    [`(define ,name . ,_)       (if (symbol? name) (list name) '())]
    [`(define-values ,names . ,_)
     (filter symbol? names)]
    [_ '()]))

(define stdlib-definition-form-symbols definition-form->symbols)

;; stdlib-file-export-symbols : path-string? -> (listof symbol?)
;;   Read a #lang webracket stdlib source after its language line and collect
;;   top-level definition names.
(define (stdlib-file-export-symbols filename)
  (define path (build-path stdlib-dir filename))
  (call-with-input-file path
    (lambda (in)
      (read-line in 'any)
      (let loop ([acc '()])
        (define form (read in))
        (if (eof-object? form)
            (reverse acc)
            (loop (append (definition-form->symbols form) acc)))))))

;; stdlib-module-export-symbols : boolean? -> (listof symbol?)
;;   Return the public names produced by the selected stdlib root.
(define (stdlib-module-export-symbols browser?)
  (remove-duplicates
   (append-map stdlib-file-export-symbols
               (append stdlib-node-files
                       (if browser? stdlib-browser-files '())))
   eq?))

;; stdlib-module-alias-symbols : boolean? -> (listof symbol?)
;;   Return names that should be re-exported as top-level script bindings.
(define (stdlib-module-alias-symbols browser?)
  (remove* stdlib-primitive-owned-export-symbols
           (stdlib-module-export-symbols browser?)
           eq?))

;; stdlib-private-symbol : exact-nonnegative-integer? -> symbol?
;;   Produce a stable private top-level name for a stdlib definition.
(define (stdlib-private-symbol i)
  (string->symbol (format "webify-stdlib-private$~a" i)))

;; stdlib-file-forms : path-string? -> (listof any/c)
;;   Read a #lang webracket stdlib source after its language line.
(define (stdlib-file-forms filename)
  (define path (build-path stdlib-dir filename))
  (call-with-input-file path
    (lambda (in)
      (read-line in 'any)
      (let loop ([acc '()])
        (define form (read in))
        (if (eof-object? form)
            (reverse acc)
            (loop (cons form acc)))))))

;; stdlib-root-forms : boolean? -> (listof any/c)
;;   Return the flattened source forms for the selected stdlib root.
(define (stdlib-root-forms browser?)
  (append-map stdlib-file-forms
              (append stdlib-node-files
                      (if browser? stdlib-browser-files '()))))

;; rename-reference : hash? any/c -> any/c
;;   Rename references to stdlib-defined top-level names, preserving quoted
;;   data and syntax templates.
(define (rename-reference renames v)
  (cond
    [(symbol? v)
     (hash-ref renames v v)]
    [(pair? v)
     (match v
       [`(quote . ,_) v]
       [`(quote-syntax . ,_) v]
       [`(syntax . ,_) v]
       [`(quasiquote . ,_) v]
       [else
        (cons (rename-reference renames (car v))
              (rename-reference renames (cdr v)))])]
    [(vector? v)
     (list->vector
      (for/list ([elem (in-vector v)])
        (rename-reference renames elem)))]
    [else v]))

;; rename-definition-name : hash? symbol? -> symbol?
;;   Rename a top-level definition name if it belongs to the stdlib boundary.
(define (rename-definition-name renames name)
  (hash-ref renames name name))

;; rename-top-level-form : hash? any/c -> any/c
;;   Rename a stdlib top-level form into the private namespace.
(define (rename-top-level-form renames form)
  (match form
    [`(require . ,_) form]
    [`(define-syntax . ,_) form]
    [`(define-syntaxes . ,_) form]
    [`(define-syntax-rule . ,_) form]
    [`(define (,name . ,formals) . ,body)
     `(define (,(rename-definition-name renames name) . ,formals)
        ,@body)]
    [`(define ,name . ,rhs)
     `(define ,(rename-definition-name renames name)
        ,@rhs)]
    [`(define-values ,names . ,rhs)
     `(define-values ,(map (λ (name) (rename-definition-name renames name)) names)
        ,@rhs)]
    [else (rename-reference renames form)]))

;; stdlib-module-private-forms+bindings : boolean?
;;                                      -> (values (listof any/c)
;;                                                 (listof (cons symbol? symbol?)))
;;   Return renamed stdlib forms and public->private export bindings.
(define (stdlib-module-private-forms+bindings browser?)
  (define exports (stdlib-module-export-symbols browser?))
  (define bindings
    (for/list ([export (in-list exports)]
               [i (in-naturals)])
      (cons export (stdlib-private-symbol i))))
  (define renames
    (for/hash ([binding (in-list bindings)])
      (values (car binding) (cdr binding))))
  (values (map (λ (form) (rename-top-level-form renames form))
               (stdlib-root-forms browser?))
          bindings))

;; stdlib-module-private-files-forms+bindings : (listof path-string?)
;;                                           -> (values (listof any/c)
;;                                                      (listof (cons symbol? symbol?)))
;;   Return renamed stdlib forms and public->private bindings for a file slice.
(define (stdlib-module-private-files-forms+bindings filenames)
  (define exports
    (remove-duplicates
     (append-map stdlib-file-export-symbols filenames)
     eq?))
  (define bindings
    (for/list ([export (in-list exports)]
               [i (in-naturals)])
      (cons export (stdlib-private-symbol i))))
  (define renames
    (for/hash ([binding (in-list bindings)])
      (values (car binding) (cdr binding))))
  (values (map (λ (form) (rename-top-level-form renames form))
               (append-map stdlib-file-forms filenames))
          bindings))
