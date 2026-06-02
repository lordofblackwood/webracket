#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-array-from
 js-array-from-async
 js-array-is-array
 js-array->vector
 js-array->bytes
 js-array-of
 js-array-length
 js-set-array-length!
 js-array-ref
 js-array-at
 js-array-concat
 js-array-copy-within
 js-array-entries
 js-array-every
 js-array-fill
 js-array-filter
 js-array-find
 js-array-find-index
 js-array-find-last
 js-array-find-last-index
 js-array-flat
 js-array-flat-map
 js-array-for-each
 js-array-includes
 js-array-index-of
 js-array-join
 js-array-keys
 js-array-last-index-of
 js-array-map
 js-array-pop
 js-array-push
 js-array-reduce
 js-array-reduce-right
 js-array-reverse
 js-array-shift
 js-array-slice
 js-array-some
 js-array-sort
 js-array-splice
 js-array-to-locale-string
 js-array-to-string
 js-array-unshift
 js-array-values
 js-array-to-reversed
 js-array-to-sorted
 js-array-to-spliced
 js-array-with)

;; js-array-from : ffi (value extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-from (unsafe-ffi-primitive 'js-array-from))

;; js-array-from-async : ffi (value extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-from-async (unsafe-ffi-primitive 'js-array-from-async))

;; js-array-is-array : ffi (value) -> (i32)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-is-array (unsafe-ffi-primitive 'js-array-is-array))

;; js-array->vector : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array->vector (unsafe-ffi-primitive 'js-array->vector))

;; js-array->bytes : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array->bytes (unsafe-ffi-primitive 'js-array->bytes))

;; js-array-of : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-of (unsafe-ffi-primitive 'js-array-of))

;; js-array-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-length (unsafe-ffi-primitive 'js-array-length))

;; js-set-array-length! : ffi (extern u32) -> ()
;;   Raw binding generated for webracket/unsafe/js.
(define js-set-array-length! (unsafe-ffi-primitive 'js-set-array-length!))

;; js-array-ref : ffi (extern i32) -> (value)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-ref (unsafe-ffi-primitive 'js-array-ref))

;; js-array-at : ffi (extern i32) -> (value)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-at (unsafe-ffi-primitive 'js-array-at))

;; js-array-concat : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-concat (unsafe-ffi-primitive 'js-array-concat))

;; js-array-copy-within : ffi (extern i32 i32 value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-copy-within (unsafe-ffi-primitive 'js-array-copy-within))

;; js-array-entries : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-entries (unsafe-ffi-primitive 'js-array-entries))

;; js-array-every : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-every (unsafe-ffi-primitive 'js-array-every))

;; js-array-fill : ffi (extern value value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-fill (unsafe-ffi-primitive 'js-array-fill))

;; js-array-filter : ffi (extern extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-filter (unsafe-ffi-primitive 'js-array-filter))

;; js-array-find : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-find (unsafe-ffi-primitive 'js-array-find))

;; js-array-find-index : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-find-index (unsafe-ffi-primitive 'js-array-find-index))

;; js-array-find-last : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-find-last (unsafe-ffi-primitive 'js-array-find-last))

;; js-array-find-last-index : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-find-last-index (unsafe-ffi-primitive 'js-array-find-last-index))

;; js-array-flat : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-flat (unsafe-ffi-primitive 'js-array-flat))

;; js-array-flat-map : ffi (extern extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-flat-map (unsafe-ffi-primitive 'js-array-flat-map))

;; js-array-for-each : ffi (extern extern value) -> ()
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-for-each (unsafe-ffi-primitive 'js-array-for-each))

;; js-array-includes : ffi (extern value value) -> (i32)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-includes (unsafe-ffi-primitive 'js-array-includes))

;; js-array-index-of : ffi (extern value value) -> (i32)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-index-of (unsafe-ffi-primitive 'js-array-index-of))

;; js-array-join : ffi (extern value) -> (string)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-join (unsafe-ffi-primitive 'js-array-join))

;; js-array-keys : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-keys (unsafe-ffi-primitive 'js-array-keys))

;; js-array-last-index-of : ffi (extern value value) -> (i32)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-last-index-of (unsafe-ffi-primitive 'js-array-last-index-of))

;; js-array-map : ffi (extern extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-map (unsafe-ffi-primitive 'js-array-map))

;; js-array-pop : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-pop (unsafe-ffi-primitive 'js-array-pop))

;; js-array-push : ffi (extern value) -> (u32)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-push (unsafe-ffi-primitive 'js-array-push))

;; js-array-reduce : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-reduce (unsafe-ffi-primitive 'js-array-reduce))

;; js-array-reduce-right : ffi (extern extern value) -> (value)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-reduce-right (unsafe-ffi-primitive 'js-array-reduce-right))

;; js-array-reverse : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-reverse (unsafe-ffi-primitive 'js-array-reverse))

;; js-array-shift : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-shift (unsafe-ffi-primitive 'js-array-shift))

;; js-array-slice : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-slice (unsafe-ffi-primitive 'js-array-slice))

;; js-array-some : ffi (extern extern value) -> (i32)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-some (unsafe-ffi-primitive 'js-array-some))

;; js-array-sort : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-sort (unsafe-ffi-primitive 'js-array-sort))

;; js-array-splice : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-splice (unsafe-ffi-primitive 'js-array-splice))

;; js-array-to-locale-string : ffi (extern value) -> (string)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-to-locale-string (unsafe-ffi-primitive 'js-array-to-locale-string))

;; js-array-to-string : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-to-string (unsafe-ffi-primitive 'js-array-to-string))

;; js-array-unshift : ffi (extern value) -> (u32)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-unshift (unsafe-ffi-primitive 'js-array-unshift))

;; js-array-values : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-values (unsafe-ffi-primitive 'js-array-values))

;; js-array-to-reversed : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-to-reversed (unsafe-ffi-primitive 'js-array-to-reversed))

;; js-array-to-sorted : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-to-sorted (unsafe-ffi-primitive 'js-array-to-sorted))

;; js-array-to-spliced : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-to-spliced (unsafe-ffi-primitive 'js-array-to-spliced))

;; js-array-with : ffi (extern i32 value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/js.
(define js-array-with (unsafe-ffi-primitive 'js-array-with))
