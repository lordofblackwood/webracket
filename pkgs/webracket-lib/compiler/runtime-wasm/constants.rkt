#lang racket

(provide make-runtime-constant-registry
         runtime-constant-registry-add-string!
         runtime-constant-registry-add-bytes!
         runtime-constant-registry-add-symbol!
         runtime-constant-registry-declare-strings
         runtime-constant-registry-declare-bytes
         runtime-constant-registry-declare-symbols!
         runtime-constant-registry-initialize-strings
         runtime-constant-registry-initialize-bytes
         runtime-constant-registry-initialize-symbols!)

(require "../private/wasm-data.rkt"
         "../private/wasm-utils.rkt")

;; A runtime constant registry tracks program constants plus constants needed
;; by runtime support. Symbols are normalized lazily because runtime-wasm.rkt
;; keeps adding symbols while it builds the runtime tree.
(struct runtime-constant-registry (strings bytes symbols seen-symbols)
  #:mutable
  #:transparent)

;; make-runtime-constant-registry : list? list? list? -> runtime-constant-registry?
;;   Create a mutable registry seeded with program string, byte, and symbol constants.
(define (make-runtime-constant-registry string-constants
                                        bytes-constants
                                        symbol-constants)
  (runtime-constant-registry string-constants
                             bytes-constants
                             symbol-constants
                             (make-hasheq)))

;; runtime-constant-registry-add-string! : runtime-constant-registry? symbol? string? -> void?
;;   Add a string constant to the registry.
(define (runtime-constant-registry-add-string! registry name string)
  (set-runtime-constant-registry-strings!
   registry
   (cons (list name string)
         (runtime-constant-registry-strings registry))))

;; runtime-constant-registry-add-bytes! : runtime-constant-registry? symbol? bytes? -> void?
;;   Add a byte string constant to the registry.
(define (runtime-constant-registry-add-bytes! registry name bytes)
  (set-runtime-constant-registry-bytes!
   registry
   (cons (list name bytes)
         (runtime-constant-registry-bytes registry))))

;; runtime-constant-registry-add-symbol! : runtime-constant-registry? symbol? -> void?
;;   Add an interned-symbol constant to the registry, avoiding duplicate additions.
(define (runtime-constant-registry-add-symbol! registry symbol)
  (define seen (runtime-constant-registry-seen-symbols registry))
  (unless (hash-ref seen symbol #f)
    (hash-set! seen symbol #t)
    (set-runtime-constant-registry-symbols!
     registry
     (cons (list symbol symbol)
           (runtime-constant-registry-symbols registry)))))

;; string-data-name : symbol? -> symbol?
;;   Return the WAT data segment name for a string constant.
(define (string-data-name name)
  (string->symbol (~a "$string-data:" name)))

;; string-global-name : symbol? -> symbol?
;;   Return the WAT global name for a string constant.
(define (string-global-name name)
  (string->symbol (~a "$string:" name)))

;; bytes-data-name : symbol? -> symbol?
;;   Return the WAT data segment name for a byte string constant.
(define (bytes-data-name name)
  (string->symbol (~a "$bytes-data:" name)))

;; bytes-global-name : symbol? -> symbol?
;;   Return the WAT global name for a byte string constant.
(define (bytes-global-name name)
  (string->symbol (~a "$bytes:" name)))

;; symbol-data-name : symbol? -> symbol?
;;   Return the WAT data segment name for a symbol constant.
(define (symbol-data-name name)
  (string->symbol (~a "$symbol-data:" name)))

;; symbol-global-name : symbol? -> symbol?
;;   Return the WAT global name for a symbol constant.
(define (symbol-global-name name)
  (string->symbol (~a "$symbol:" name)))

;; remove-duplicates/string : list? procedure? -> list?
;;   Remove duplicates using a string key in linear time.
(define (remove-duplicates/string xs key)
  ;; `remove-duplicates` with string=? is quadratic on large inputs because
  ;; racket/list only switches to a hash-table implementation for a few
  ;; built-in equality predicates.
  (define seen (make-hash))
  (let loop ([rest xs] [acc '()])
    (cond
      [(null? rest) (reverse acc)]
      [else
       (define v (car rest))
       (define k (key v))
       (cond
         [(hash-ref seen k #f)
          (loop (cdr rest) acc)]
         [else
          (hash-set! seen k #t)
          (loop (cdr rest) (cons v acc))])])))

;; runtime-constant-registry-normalize-symbols! : runtime-constant-registry? -> void?
;;   Remove duplicate symbol constants by generated global name.
(define (runtime-constant-registry-normalize-symbols! registry)
  (set-runtime-constant-registry-symbols!
   registry
   (remove-duplicates/string (runtime-constant-registry-symbols registry)
                             (lambda (ns)
                               (symbol->string (first ns))))))

;; runtime-constant-registry-declare-strings : runtime-constant-registry? -> list?
;;   Emit WAT data/global declarations for registered string constants.
(define (runtime-constant-registry-declare-strings registry)
  (append*
   (for/list ([ns (reverse (runtime-constant-registry-strings registry))])
     (define name (first ns))
     (define string (second ns))
     (define $string-data:name (string-data-name name))
     (define $string:name (string-global-name name))
     (list `(data ,$string-data:name ,(wasm-data (string->bytes/utf-8 string)))
           `(global ,$string:name (mut (ref eq)) ,(Imm #f))))))

;; runtime-constant-registry-initialize-strings : runtime-constant-registry? -> list?
;;   Emit WAT initialization forms for registered string constants.
(define (runtime-constant-registry-initialize-strings registry)
  (for/list ([ns (reverse (runtime-constant-registry-strings registry))])
    (define name (first ns))
    (define string (second ns))
    (define $string-data:name (string-data-name name))
    (define $string:name (string-global-name name))
    (define n (bytes-length (string->bytes/utf-8 string)))
    `(global.set ,$string:name
                 (call $i8array->string
                       (array.new_data $I8Array ,$string-data:name
                                       (i32.const 0) (i32.const ,n))))))

;; runtime-constant-registry-declare-bytes : runtime-constant-registry? -> list?
;;   Emit WAT data/global declarations for registered byte string constants.
(define (runtime-constant-registry-declare-bytes registry)
  (append*
   (for/list ([ns (reverse (runtime-constant-registry-bytes registry))])
     (define name (first ns))
     (define bytes (second ns))
     (define $bytes-data:name (bytes-data-name name))
     (define $bytes:name (bytes-global-name name))
     (list `(data ,$bytes-data:name ,(wasm-data bytes))
           `(global ,$bytes:name (mut (ref eq)) ,(Imm #f))))))

;; runtime-constant-registry-initialize-bytes : runtime-constant-registry? -> list?
;;   Emit WAT initialization forms for registered byte string constants.
(define (runtime-constant-registry-initialize-bytes registry)
  (for/list ([ns (reverse (runtime-constant-registry-bytes registry))])
    (define name (first ns))
    (define bytes (second ns))
    (define $bytes-data:name (bytes-data-name name))
    (define $bytes:name (bytes-global-name name))
    (define n (bytes-length bytes))
    `(global.set ,$bytes:name
                 (call $i8array->immutable-bytes
                       (array.new_data $I8Array ,$bytes-data:name
                                       (i32.const 0) (i32.const ,n))))))

;; runtime-constant-registry-declare-symbols! : runtime-constant-registry? -> list?
;;   Emit WAT data/global declarations for registered symbol constants.
(define (runtime-constant-registry-declare-symbols! registry)
  (runtime-constant-registry-normalize-symbols! registry)
  (append*
   (for/list ([ns (reverse (runtime-constant-registry-symbols registry))])
     (define name (first ns))
     (define symbol (second ns))
     (define string (symbol->string symbol))
     (define $symbol-data:name (symbol-data-name name))
     (define $symbol:name (symbol-global-name name))
     (list `(data ,$symbol-data:name ,string)
           `(global ,$symbol:name (mut (ref eq)) ,(Imm #f))))))

;; runtime-constant-registry-initialize-symbols! : runtime-constant-registry? -> list?
;;   Emit WAT initialization forms for registered symbol constants.
(define (runtime-constant-registry-initialize-symbols! registry)
  (runtime-constant-registry-normalize-symbols! registry)
  (for/list ([ns (reverse (runtime-constant-registry-symbols registry))])
    (define name (first ns))
    (define symbol (second ns))
    (define string (symbol->string symbol))
    (define $symbol-data:name (symbol-data-name name))
    (define $symbol:name (symbol-global-name name))
    (define n (bytes-length (string->bytes/utf-8 string)))
    `(global.set ,$symbol:name
                 (call $string->symbol
                       (call $i8array->string
                             (array.new_data $I8Array ,$symbol-data:name
                                             (i32.const 0) (i32.const ,n)))))))

(module+ test
  (require rackunit)

  ;; form-names : (listof datum?) -> (listof symbol?)
  ;;   Extract data/global names from declaration forms.
  (define (form-names forms)
    (for/list ([form (in-list forms)])
      (second form)))

  (let ([registry (make-runtime-constant-registry
                   '((program-string "program"))
                   '((program-bytes #"program"))
                   '())])
    (runtime-constant-registry-add-string! registry 'runtime-string "runtime")
    (runtime-constant-registry-add-bytes! registry 'runtime-bytes #"runtime")
    (check-equal?
     (form-names (runtime-constant-registry-declare-strings registry))
     '($string-data:program-string
       $string:program-string
       $string-data:runtime-string
       $string:runtime-string))
    (check-equal?
     (form-names (runtime-constant-registry-declare-bytes registry))
     '($bytes-data:program-bytes
       $bytes:program-bytes
       $bytes-data:runtime-bytes
       $bytes:runtime-bytes)))

  (let ([registry (make-runtime-constant-registry
                   '()
                   '()
                   '((foo foo)))])
    (runtime-constant-registry-add-symbol! registry 'foo)
    (runtime-constant-registry-add-symbol! registry 'bar)
    (runtime-constant-registry-add-symbol! registry 'bar)
    (check-equal?
     (form-names (runtime-constant-registry-declare-symbols! registry))
     '($symbol-data:foo
       $symbol:foo
       $symbol-data:bar
       $symbol:bar))))
