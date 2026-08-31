#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-file-system-open-picker-supported?
 js-file-system-save-picker-supported?
 js-file-system-directory-picker-supported?
 js-file-system-origin-private-supported?
 js-file-system-file-handle?
 js-file-system-directory-handle?
 js-file-system-writable-file-stream?
 js-file-system-file?
 js-file-system-show-open-file-picker
 js-file-system-show-save-file-picker
 js-file-system-show-directory-picker
 js-file-system-origin-private-directory
 js-file-system-handle-name
 js-file-system-file-handle-get-file
 js-file-system-file-handle-create-writable
 js-file-system-directory-handle-get-file-handle
 js-file-system-directory-handle-get-directory-handle
 js-file-system-directory-handle-remove-entry!
 js-file-system-file-name
 js-file-system-file-size
 js-file-system-file-type
 js-file-system-file-last-modified
 js-file-system-file-text
 js-file-system-writable-file-stream-write
 js-file-system-writable-file-stream-seek
 js-file-system-writable-file-stream-truncate
 js-file-system-writable-file-stream-close)

;; js-file-system-open-picker-supported? : ffi () -> (boolean)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-open-picker-supported? (unsafe-ffi-primitive 'js-file-system-open-picker-supported?))

;; js-file-system-save-picker-supported? : ffi () -> (boolean)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-save-picker-supported? (unsafe-ffi-primitive 'js-file-system-save-picker-supported?))

;; js-file-system-directory-picker-supported? : ffi () -> (boolean)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-directory-picker-supported? (unsafe-ffi-primitive 'js-file-system-directory-picker-supported?))

;; js-file-system-origin-private-supported? : ffi () -> (boolean)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-origin-private-supported? (unsafe-ffi-primitive 'js-file-system-origin-private-supported?))

;; js-file-system-file-handle? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-file-handle? (unsafe-ffi-primitive 'js-file-system-file-handle?))

;; js-file-system-directory-handle? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-directory-handle? (unsafe-ffi-primitive 'js-file-system-directory-handle?))

;; js-file-system-writable-file-stream? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-writable-file-stream? (unsafe-ffi-primitive 'js-file-system-writable-file-stream?))

;; js-file-system-file? : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-file? (unsafe-ffi-primitive 'js-file-system-file?))

;; js-file-system-show-open-file-picker : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-show-open-file-picker (unsafe-ffi-primitive 'js-file-system-show-open-file-picker))

;; js-file-system-show-save-file-picker : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-show-save-file-picker (unsafe-ffi-primitive 'js-file-system-show-save-file-picker))

;; js-file-system-show-directory-picker : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-show-directory-picker (unsafe-ffi-primitive 'js-file-system-show-directory-picker))

;; js-file-system-origin-private-directory : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-origin-private-directory (unsafe-ffi-primitive 'js-file-system-origin-private-directory))

;; js-file-system-handle-name : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-handle-name (unsafe-ffi-primitive 'js-file-system-handle-name))

;; js-file-system-file-handle-get-file : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-file-handle-get-file (unsafe-ffi-primitive 'js-file-system-file-handle-get-file))

;; js-file-system-file-handle-create-writable : ffi (extern boolean) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-file-handle-create-writable (unsafe-ffi-primitive 'js-file-system-file-handle-create-writable))

;; js-file-system-directory-handle-get-file-handle : ffi (extern string boolean) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-directory-handle-get-file-handle (unsafe-ffi-primitive 'js-file-system-directory-handle-get-file-handle))

;; js-file-system-directory-handle-get-directory-handle : ffi (extern string boolean) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-directory-handle-get-directory-handle (unsafe-ffi-primitive 'js-file-system-directory-handle-get-directory-handle))

;; js-file-system-directory-handle-remove-entry! : ffi (extern string boolean) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-directory-handle-remove-entry! (unsafe-ffi-primitive 'js-file-system-directory-handle-remove-entry!))

;; js-file-system-file-name : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-file-name (unsafe-ffi-primitive 'js-file-system-file-name))

;; js-file-system-file-size : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-file-size (unsafe-ffi-primitive 'js-file-system-file-size))

;; js-file-system-file-type : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-file-type (unsafe-ffi-primitive 'js-file-system-file-type))

;; js-file-system-file-last-modified : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-file-last-modified (unsafe-ffi-primitive 'js-file-system-file-last-modified))

;; js-file-system-file-text : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-file-text (unsafe-ffi-primitive 'js-file-system-file-text))

;; js-file-system-writable-file-stream-write : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-writable-file-stream-write (unsafe-ffi-primitive 'js-file-system-writable-file-stream-write))

;; js-file-system-writable-file-stream-seek : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-writable-file-stream-seek (unsafe-ffi-primitive 'js-file-system-writable-file-stream-seek))

;; js-file-system-writable-file-stream-truncate : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-writable-file-stream-truncate (unsafe-ffi-primitive 'js-file-system-writable-file-stream-truncate))

;; js-file-system-writable-file-stream-close : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/file-system.
(define js-file-system-writable-file-stream-close (unsafe-ffi-primitive 'js-file-system-writable-file-stream-close))
