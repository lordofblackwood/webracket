#lang racket

(provide bytes-data-name
         bytes-global-name
         runtime-constant-registry-declare-bytes
         runtime-constant-registry-initialize-bytes)

(require "../private/wasm-data.rkt"
         "../private/wasm-utils.rkt"
         (only-in "constant-registry.rkt"
                  runtime-constant-registry-bytes))

;; bytes-data-name : symbol? -> symbol?
;;   Return the WAT data segment name for a byte string constant.
(define (bytes-data-name name)
  (string->symbol (~a "$bytes-data:" name)))

;; bytes-global-name : symbol? -> symbol?
;;   Return the WAT global name for a byte string constant.
(define (bytes-global-name name)
  (string->symbol (~a "$bytes:" name)))

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
