#lang racket

(provide (struct-out runtime-constant-registry)
         make-runtime-constant-registry
         runtime-constant-registry-add-string!
         runtime-constant-registry-add-bytes!
         runtime-constant-registry-add-symbol!
         runtime-constant-registry-add-string-constants!
         runtime-constant-registry-add-bytes-constants!
         runtime-constant-registry-add-symbols!)

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

;; runtime-constant-registry-add-string-constants! : runtime-constant-registry? list? -> void?
;;   Add a sequence of named string constants to the registry.
(define (runtime-constant-registry-add-string-constants! registry constants)
  (for ([constant (in-list constants)])
    (runtime-constant-registry-add-string! registry
                                           (first constant)
                                           (second constant))))

;; runtime-constant-registry-add-bytes-constants! : runtime-constant-registry? list? -> void?
;;   Add a sequence of named byte-string constants to the registry.
(define (runtime-constant-registry-add-bytes-constants! registry constants)
  (for ([constant (in-list constants)])
    (runtime-constant-registry-add-bytes! registry
                                          (first constant)
                                          (second constant))))

;; runtime-constant-registry-add-symbols! : runtime-constant-registry? (listof symbol?) -> void?
;;   Add a sequence of interned-symbol constants to the registry.
(define (runtime-constant-registry-add-symbols! registry symbols)
  (for ([symbol (in-list symbols)])
    (runtime-constant-registry-add-symbol! registry symbol)))
