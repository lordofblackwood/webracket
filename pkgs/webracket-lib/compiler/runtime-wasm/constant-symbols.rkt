#lang racket

(provide symbol-data-name
         symbol-global-name
         runtime-constant-registry-declare-symbols!
         runtime-constant-registry-initialize-symbols!)

(require "../private/wasm-utils.rkt"
         (only-in "constant-registry.rkt"
                  runtime-constant-registry-symbols
                  set-runtime-constant-registry-symbols!))

;; symbol-data-name : symbol? -> symbol?
;;   Return the WAT data segment name for a symbol constant.
(define (symbol-data-name name)
  (string->symbol (~a "$symbol-data:" name)))

;; symbol-global-name : symbol? -> symbol?
;;   Return the WAT global name for a symbol constant.
(define (symbol-global-name name)
  (string->symbol (~a "$symbol:" name)))

;; constant-entry<? : list? list? -> boolean?
;;   Order constant registry entries by generated WAT name.
(define (constant-entry<? a b)
  (symbol<? (first a) (first b)))

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
   (sort
    (remove-duplicates/string (runtime-constant-registry-symbols registry)
                              (lambda (ns)
                                (symbol->string (first ns))))
    constant-entry<?)))

;; runtime-constant-registry-declare-symbols! : runtime-constant-registry? -> list?
;;   Emit WAT data/global declarations for registered symbol constants.
(define (runtime-constant-registry-declare-symbols! registry)
  (runtime-constant-registry-normalize-symbols! registry)
  (append*
   (for/list ([ns (in-list (runtime-constant-registry-symbols registry))])
     (define name (first ns))
     (define symbol (second ns))
     (define string (symbol->string symbol))
     (define $symbol-data:name (symbol-data-name name))
     (define $symbol:name (symbol-global-name name))
     (list `(data ,$symbol-data:name ,string)
           `(global ,$symbol:name (mut (ref eq)) ,(Imm #f))))))

;; runtime-constant-registry-initialize-symbols! :
;;   runtime-constant-registry? [#:string-converter symbol?] [#:symbol-converter symbol?] -> list?
;;   Emit WAT initialization forms for registered symbol constants.
(define (runtime-constant-registry-initialize-symbols! registry
                                                       #:string-converter
                                                       [string-converter '$i8array->string]
                                                       #:symbol-converter
                                                       [symbol-converter '$string->symbol])
  (runtime-constant-registry-normalize-symbols! registry)
  (for/list ([ns (in-list (runtime-constant-registry-symbols registry))])
    (define name (first ns))
    (define symbol (second ns))
    (define string (symbol->string symbol))
    (define $symbol-data:name (symbol-data-name name))
    (define $symbol:name (symbol-global-name name))
    (define n (bytes-length (string->bytes/utf-8 string)))
    `(global.set ,$symbol:name
                 (call ,symbol-converter
                       (call ,string-converter
                             (array.new_data $I8Array ,$symbol-data:name
                                             (i32.const 0) (i32.const ,n)))))))
