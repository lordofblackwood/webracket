#lang racket

(provide module-func-name
         module-global-name
         module-data-name
         module-func-names
         module-write-bytes
         module-write-sha1
         module-form-count
         module-func-count
         module-global-count
         module-export-count
         module-byte-size
         symbol-prefix-count
         forms->module)

(require file/sha1)

;; module-name-symbol : any/c -> (or/c symbol? #f)
;;   Normalize a WAT identifier, accepting pre-strip syntax identifiers.
(define (module-name-symbol x)
  (cond
    [(symbol? x) x]
    [(and (identifier? x)
          (symbol? (syntax-e x)))
     (syntax-e x)]
    [else #f]))

;; module-func-name : any/c -> (or/c symbol? #f)
;;   Return the name of a WAT function form, if the form has one.
(define (module-func-name form)
  (and (pair? form)
       (eq? (car form) 'func)
       (pair? (cdr form))
       (module-name-symbol (cadr form))))

;; module-global-name : any/c -> (or/c symbol? #f)
;;   Return the name of a WAT global form, if the form has one.
(define (module-global-name form)
  (and (pair? form)
       (eq? (car form) 'global)
       (pair? (cdr form))
       (module-name-symbol (cadr form))))

;; module-data-name : any/c -> (or/c symbol? #f)
;;   Return the name of a WAT data form, if the form has one.
(define (module-data-name form)
  (and (pair? form)
       (eq? (car form) 'data)
       (pair? (cdr form))
       (module-name-symbol (cadr form))))

;; module-write-bytes : list? -> bytes?
;;   Serialize a WAT module with `write`.
(define (module-write-bytes module)
  (call-with-output-bytes
   (lambda (out)
     (write module out))))

;; module-write-sha1 : list? -> string?
;;   Hash the serialized WAT module without materializing the bytes.
(define (module-write-sha1 module)
  (define-values (in out) (make-pipe))
  (define writer-result (make-channel))
  (thread
   (lambda ()
     (with-handlers ([exn:fail?
                      (lambda (e)
                        (with-handlers ([exn:fail? void])
                          (close-output-port out))
                        (channel-put writer-result e))])
       (write module out)
       (close-output-port out)
       (channel-put writer-result #t))))
  (define digest (sha1 in))
  (close-input-port in)
  (define result (channel-get writer-result))
  (when (exn:fail? result)
    (raise result))
  digest)

;; module-write-size : list? -> exact-nonnegative-integer?
;;   Count the serialized byte length without materializing the bytes.
(define (module-write-size module)
  (define size 0)
  (define out
    (make-output-port
     'module-write-size
     always-evt
     (lambda (_bs start end _non-block? _breakable?)
       (define n (- end start))
       (set! size (+ size n))
       n)
     void))
  (write module out)
  (close-output-port out)
  size)

;; module-func-names : (listof any/c) -> (listof symbol?)
;;   Return all named function forms in a sequence of module body forms.
(define (module-func-names forms)
  (for/list ([form (in-list forms)]
             #:do [(define name (module-func-name form))]
             #:when name)
    name))

;; module-form-count : list? procedure? -> exact-nonnegative-integer?
;;   Count module body forms accepted by predicate.
(define (module-form-count module predicate)
  (for/sum ([form (in-list (cdr module))]
            #:when (predicate form))
    1))

;; module-func-count : list? -> exact-nonnegative-integer?
;;   Count named function forms in module.
(define (module-func-count module)
  (module-form-count module module-func-name))

;; module-global-count : list? -> exact-nonnegative-integer?
;;   Count named global forms in module.
(define (module-global-count module)
  (module-form-count module module-global-name))

;; module-export-count : list? -> exact-nonnegative-integer?
;;   Count export forms in module.
(define (module-export-count module)
  (module-form-count
   module
   (lambda (form)
     (and (pair? form)
          (eq? (car form) 'export)))))

;; module-byte-size : list? -> exact-nonnegative-integer?
;;   Return the byte size of the module's serialized s-expression.
(define (module-byte-size module)
  (module-write-size module))

;; symbol-prefix-count : (listof symbol?) string? -> exact-nonnegative-integer?
;;   Count symbols whose printed names start with prefix.
(define (symbol-prefix-count syms prefix)
  (for/sum ([sym (in-list syms)]
            #:when (string-prefix? (symbol->string sym) prefix))
    1))

;; forms->module : (listof any/c) -> list?
;;   Wrap WAT module body forms in a module form.
(define (forms->module forms)
  `(module ,@forms))

(module+ test
  (require rackunit)

  (define sample-module
    '(module
      (type $T (func))
      (func $f (result i32) (i32.const 0))
      (func (export "anon"))
      (global $g (mut i32) (i32.const 0))
      (data $d "abc")
      (export "f" (func $f))))

  (check-equal? (module-func-name '(func $f)) '$f)
  (check-equal? (module-func-name (list 'func #'$f)) '$f)
  (check-false (module-func-name '(func (export "anon"))))
  (check-equal? (module-global-name '(global $g i32 (i32.const 0))) '$g)
  (check-equal? (module-global-name (list 'global #'$g 'i32 '(i32.const 0))) '$g)
  (check-equal? (module-data-name '(data $d "abc")) '$d)
  (check-equal? (module-data-name (list 'data #'$d "abc")) '$d)
  (check-equal? (module-func-names (cdr sample-module)) '($f))
  (check-equal? (module-func-count sample-module) 1)
  (check-equal? (module-global-count sample-module) 1)
  (check-equal? (module-export-count sample-module) 1)
  (check-equal? (symbol-prefix-count '($string:a $bytes:a $string:b) "$string:") 2)
  (check-equal? (forms->module '((func $f))) '(module (func $f)))
  (check-equal? (module-byte-size sample-module)
                (bytes-length (module-write-bytes sample-module)))
  (check-equal? (module-write-sha1 sample-module)
                (sha1 (open-input-bytes (module-write-bytes sample-module)))))
