#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-image-new
 js-image-alt
 js-set-image-alt!
 js-image-src
 js-set-image-src!
 js-image-srcset
 js-set-image-srcset!
 js-image-sizes
 js-set-image-sizes!
 js-image-cross-origin
 js-set-image-cross-origin!
 js-image-use-map
 js-set-image-use-map!
 js-image-is-map
 js-set-image-is-map!
 js-image-width
 js-set-image-width!
 js-image-height
 js-set-image-height!
 js-image-natural-width
 js-image-natural-height
 js-image-complete
 js-image-current-src
 js-image-decoding
 js-set-image-decoding!
 js-image-fetch-priority
 js-set-image-fetch-priority!
 js-image-loading
 js-set-image-loading!
 js-image-referrer-policy
 js-set-image-referrer-policy!
 js-image-name
 js-set-image-name!
 js-image-x
 js-image-y
 js-image-decode)

;; js-image-new : ffi (value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-new (unsafe-ffi-primitive 'js-image-new))

;; js-image-alt : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-alt (unsafe-ffi-primitive 'js-image-alt))

;; js-set-image-alt! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-alt! (unsafe-ffi-primitive 'js-set-image-alt!))

;; js-image-src : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-src (unsafe-ffi-primitive 'js-image-src))

;; js-set-image-src! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-src! (unsafe-ffi-primitive 'js-set-image-src!))

;; js-image-srcset : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-srcset (unsafe-ffi-primitive 'js-image-srcset))

;; js-set-image-srcset! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-srcset! (unsafe-ffi-primitive 'js-set-image-srcset!))

;; js-image-sizes : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-sizes (unsafe-ffi-primitive 'js-image-sizes))

;; js-set-image-sizes! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-sizes! (unsafe-ffi-primitive 'js-set-image-sizes!))

;; js-image-cross-origin : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-cross-origin (unsafe-ffi-primitive 'js-image-cross-origin))

;; js-set-image-cross-origin! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-cross-origin! (unsafe-ffi-primitive 'js-set-image-cross-origin!))

;; js-image-use-map : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-use-map (unsafe-ffi-primitive 'js-image-use-map))

;; js-set-image-use-map! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-use-map! (unsafe-ffi-primitive 'js-set-image-use-map!))

;; js-image-is-map : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-is-map (unsafe-ffi-primitive 'js-image-is-map))

;; js-set-image-is-map! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-is-map! (unsafe-ffi-primitive 'js-set-image-is-map!))

;; js-image-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-width (unsafe-ffi-primitive 'js-image-width))

;; js-set-image-width! : ffi (extern u32) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-width! (unsafe-ffi-primitive 'js-set-image-width!))

;; js-image-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-height (unsafe-ffi-primitive 'js-image-height))

;; js-set-image-height! : ffi (extern u32) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-height! (unsafe-ffi-primitive 'js-set-image-height!))

;; js-image-natural-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-natural-width (unsafe-ffi-primitive 'js-image-natural-width))

;; js-image-natural-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-natural-height (unsafe-ffi-primitive 'js-image-natural-height))

;; js-image-complete : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-complete (unsafe-ffi-primitive 'js-image-complete))

;; js-image-current-src : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-current-src (unsafe-ffi-primitive 'js-image-current-src))

;; js-image-decoding : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-decoding (unsafe-ffi-primitive 'js-image-decoding))

;; js-set-image-decoding! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-decoding! (unsafe-ffi-primitive 'js-set-image-decoding!))

;; js-image-fetch-priority : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-fetch-priority (unsafe-ffi-primitive 'js-image-fetch-priority))

;; js-set-image-fetch-priority! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-fetch-priority! (unsafe-ffi-primitive 'js-set-image-fetch-priority!))

;; js-image-loading : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-loading (unsafe-ffi-primitive 'js-image-loading))

;; js-set-image-loading! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-loading! (unsafe-ffi-primitive 'js-set-image-loading!))

;; js-image-referrer-policy : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-referrer-policy (unsafe-ffi-primitive 'js-image-referrer-policy))

;; js-set-image-referrer-policy! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-referrer-policy! (unsafe-ffi-primitive 'js-set-image-referrer-policy!))

;; js-image-name : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-name (unsafe-ffi-primitive 'js-image-name))

;; js-set-image-name! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/image.
(define js-set-image-name! (unsafe-ffi-primitive 'js-set-image-name!))

;; js-image-x : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-x (unsafe-ffi-primitive 'js-image-x))

;; js-image-y : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-y (unsafe-ffi-primitive 'js-image-y))

;; js-image-decode : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/image.
(define js-image-decode (unsafe-ffi-primitive 'js-image-decode))
