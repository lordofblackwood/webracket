#lang racket/base

(require webracket/unsafe/image)

(provide image-new
         image-alt
         image-set-alt!
         image-src
         image-set-src!
         image-width
         image-set-width!
         image-height
         image-set-height!
         image-current-src
         image-decoding
         image-set-decoding!
         image-loading
         image-set-loading!
         image-complete?
         image-cross-origin
         image-set-cross-origin!)

;; This is the canonical module version of the old `include-lib image`
;; safe wrapper. Raw bindings remain in `webracket/unsafe/image`.

;;;
;;; Image wrappers
;;;

;; image-i32->boolean : integer? -> boolean?
;;   Convert a browser i32 flag to a boolean.
(define (image-i32->boolean v)
  (not (zero? v)))

;; image-stringish->string : symbol? any/c -> string?
;;   Normalize a browser string argument.
(define (image-stringish->string who value)
  (cond
    [(string? value) value]
    [(symbol? value) (symbol->string value)]
    [else (raise-argument-error who "(or/c string? symbol?)" value)]))

;; image-resolve-optional : any/c -> any/c
;;   Treat #f as omitted for optional browser arguments.
(define (image-resolve-optional value)
  (if (eq? value #f)
      (void)
      value))

;; image-check-constructor-result : external/raw -> external/raw
;;   Validate that Image construction returned a usable HTMLImageElement value.
(define (image-check-constructor-result raw)
  (with-handlers ([exn:fail?
                   (lambda (_exn)
                     (raise-arguments-error 'image-new
                                            "Image constructor result must be HTMLImageElement-like"))])
    (js-image-alt raw)
    (js-image-src raw)
    (js-image-width raw)
    (js-image-height raw)
    (js-image-complete raw)
    (js-image-current-src raw)
    raw))

;; image-new : [any/c #f] [any/c #f] -> external/raw
;;   Create a new image element.
(define (image-new [width #f] [height #f])
  (image-check-constructor-result
   (js-image-new (image-resolve-optional width)
                 (image-resolve-optional height))))

;; image-alt : external? -> string?
;;   Read the alt text.
(define (image-alt img)
  (js-image-alt img))

;; image-set-alt! : external? (or/c string? symbol?) -> void?
;;   Set the alt text.
(define (image-set-alt! img alt)
  (js-set-image-alt! img (image-stringish->string 'image-set-alt! alt))
  (void))

;; image-src : external? -> string?
;;   Read the image source.
(define (image-src img)
  (js-image-src img))

;; image-set-src! : external? (or/c string? symbol?) -> void?
;;   Set the image source.
(define (image-set-src! img src)
  (js-set-image-src! img (image-stringish->string 'image-set-src! src))
  (void))

;; image-width : external? -> exact-nonnegative-integer?
;;   Read the rendered width.
(define (image-width img)
  (js-image-width img))

;; image-set-width! : external? exact-nonnegative-integer? -> void?
;;   Set the rendered width.
(define (image-set-width! img width)
  (js-set-image-width! img width)
  (void))

;; image-height : external? -> exact-nonnegative-integer?
;;   Read the rendered height.
(define (image-height img)
  (js-image-height img))

;; image-set-height! : external? exact-nonnegative-integer? -> void?
;;   Set the rendered height.
(define (image-set-height! img height)
  (js-set-image-height! img height)
  (void))

;; image-current-src : external? -> string?
;;   Read the selected source URL.
(define (image-current-src img)
  (js-image-current-src img))

;; image-decoding : external? -> string?
;;   Read the decoding hint.
(define (image-decoding img)
  (js-image-decoding img))

;; image-set-decoding! : external? (or/c string? symbol?) -> void?
;;   Set the decoding hint.
(define (image-set-decoding! img decoding)
  (js-set-image-decoding! img
                          (image-stringish->string 'image-set-decoding! decoding))
  (void))

;; image-loading : external? -> string?
;;   Read the loading strategy.
(define (image-loading img)
  (js-image-loading img))

;; image-set-loading! : external? (or/c string? symbol?) -> void?
;;   Set the loading strategy.
(define (image-set-loading! img loading)
  (js-set-image-loading! img (image-stringish->string 'image-set-loading! loading))
  (void))

;; image-complete? : external? -> boolean?
;;   Report whether loading completed.
(define (image-complete? img)
  (image-i32->boolean (js-image-complete img)))

;; image-cross-origin : external? -> any/c
;;   Read the CORS mode.
(define (image-cross-origin img)
  (js-image-cross-origin img))

;; image-set-cross-origin! : external? (or/c string? symbol?) -> void?
;;   Set the CORS mode.
(define (image-set-cross-origin! img mode)
  (js-set-image-cross-origin! img (image-stringish->string 'image-set-cross-origin! mode))
  (void))
