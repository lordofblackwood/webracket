#lang racket

(provide string-data-name
         string-global-name
         runtime-constant-registry-declare-strings
         runtime-constant-registry-initialize-strings)

(require "../private/wasm-data.rkt"
         "../private/wasm-utils.rkt"
         (only-in "constant-registry.rkt"
                  runtime-constant-registry-strings))

;; string-data-name : symbol? -> symbol?
;;   Return the WAT data segment name for a string constant.
(define (string-data-name name)
  (string->symbol (~a "$string-data:" name)))

;; string-global-name : symbol? -> symbol?
;;   Return the WAT global name for a string constant.
(define (string-global-name name)
  (string->symbol (~a "$string:" name)))

;; constant-entry<? : list? list? -> boolean?
;;   Order constant registry entries by generated WAT name.
(define (constant-entry<? a b)
  (symbol<? (first a) (first b)))

;; runtime-constant-registry-sorted-strings : runtime-constant-registry? -> list?
;;   Return string constants in canonical emission order.
(define (runtime-constant-registry-sorted-strings registry)
  (sort (runtime-constant-registry-strings registry)
        constant-entry<?))

;; runtime-constant-registry-declare-strings : runtime-constant-registry? -> list?
;;   Emit WAT data/global declarations for registered string constants.
(define (runtime-constant-registry-declare-strings registry)
  (append*
   (for/list ([ns (in-list (runtime-constant-registry-sorted-strings registry))])
     (define name (first ns))
     (define string (second ns))
     (define $string-data:name (string-data-name name))
     (define $string:name (string-global-name name))
     (list `(data ,$string-data:name ,(wasm-data (string->bytes/utf-8 string)))
           `(global ,$string:name (mut (ref eq)) ,(Imm #f))))))

;; runtime-constant-registry-initialize-strings : runtime-constant-registry? [#:converter symbol?] -> list?
;;   Emit WAT initialization forms for registered string constants.
(define (runtime-constant-registry-initialize-strings registry
                                                       #:converter [converter '$i8array->string])
  (for/list ([ns (in-list (runtime-constant-registry-sorted-strings registry))])
    (define name (first ns))
    (define string (second ns))
    (define $string-data:name (string-data-name name))
    (define $string:name (string-global-name name))
    (define n (bytes-length (string->bytes/utf-8 string)))
    `(global.set ,$string:name
                 (call ,converter
                       (array.new_data $I8Array ,$string-data:name
                                       (i32.const 0) (i32.const ,n))))))
