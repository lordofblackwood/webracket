#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-window-window
 js-window-self
 js-window-document
 js-window-name
 js-set-window-name!
 js-window-location
 js-set-window-location!
 js-window-custom-elements
 js-window-history
 js-window-locationbar
 js-window-menubar
 js-window-personalbar
 js-window-scrollbars
 js-window-statusbar
 js-window-toolbar
 js-window-closed
 js-window-frames
 js-window-length
 js-window-opener
 js-set-window-opener!
 js-window-parent
 js-window-top
 js-window-visual-viewport
 js-window-navigator
 js-window-origin
 js-window-crypto
 js-window-device-pixel-ratio
 js-window-frame-element
 js-window-inner-height
 js-window-inner-width
 js-window-outer-height
 js-window-outer-width
 js-window-screen-x
 js-window-screen-y
 js-window-screen-left
 js-window-screen-top
 js-window-page-x-offset
 js-window-page-y-offset
 js-window-scroll-x
 js-window-scroll-y
 js-window-screen
 js-window-local-storage
 js-window-session-storage
 js-window-performance
 js-window-indexed-db
 js-window-is-secure-context
 js-window-cross-origin-isolated
 js-window-caches
 js-window-speech-synthesis
 js-window-style-media
 js-window-alert
 js-window-atob
 js-window-btoa
 js-window-blur
 js-window-cancel-animation-frame
 js-window-cancel-idle-callback
 js-window-clear-interval
 js-window-clear-timeout
 js-window-close
 js-window-confirm
 js-window-create-image-bitmap
 js-window-fetch
 js-window-focus
 js-window-get-computed-style
 js-window-get-selection
 js-window-match-media
 js-window-move-by
 js-window-move-to
 js-window-open
 js-window-post-message
 js-window-print
 js-window-prompt
 js-window-request-animation-frame
 js-window-request-idle-callback
 js-window-resize-by
 js-window-resize-to
 js-window-scroll
 js-window-scroll-by
 js-window-scroll-to
 js-window-set-interval
 js-window-set-timeout
 js-window-set-timeout/delay
 js-window-stop
 js-window-structured-clone
 js-window-queue-microtask
 js-window-report-error)

;; js-window-window : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-window (unsafe-ffi-primitive 'js-window-window))

;; js-window-self : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-self (unsafe-ffi-primitive 'js-window-self))

;; js-window-document : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-document (unsafe-ffi-primitive 'js-window-document))

;; js-window-name : ffi () -> (string)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-name (unsafe-ffi-primitive 'js-window-name))

;; js-set-window-name! : ffi (string) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-set-window-name! (unsafe-ffi-primitive 'js-set-window-name!))

;; js-window-location : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-location (unsafe-ffi-primitive 'js-window-location))

;; js-set-window-location! : ffi (value) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-set-window-location! (unsafe-ffi-primitive 'js-set-window-location!))

;; js-window-custom-elements : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-custom-elements (unsafe-ffi-primitive 'js-window-custom-elements))

;; js-window-history : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-history (unsafe-ffi-primitive 'js-window-history))

;; js-window-locationbar : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-locationbar (unsafe-ffi-primitive 'js-window-locationbar))

;; js-window-menubar : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-menubar (unsafe-ffi-primitive 'js-window-menubar))

;; js-window-personalbar : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-personalbar (unsafe-ffi-primitive 'js-window-personalbar))

;; js-window-scrollbars : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-scrollbars (unsafe-ffi-primitive 'js-window-scrollbars))

;; js-window-statusbar : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-statusbar (unsafe-ffi-primitive 'js-window-statusbar))

;; js-window-toolbar : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-toolbar (unsafe-ffi-primitive 'js-window-toolbar))

;; js-window-closed : ffi () -> (i32)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-closed (unsafe-ffi-primitive 'js-window-closed))

;; js-window-frames : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-frames (unsafe-ffi-primitive 'js-window-frames))

;; js-window-length : ffi () -> (u32)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-length (unsafe-ffi-primitive 'js-window-length))

;; js-window-opener : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-opener (unsafe-ffi-primitive 'js-window-opener))

;; js-set-window-opener! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-set-window-opener! (unsafe-ffi-primitive 'js-set-window-opener!))

;; js-window-parent : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-parent (unsafe-ffi-primitive 'js-window-parent))

;; js-window-top : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-top (unsafe-ffi-primitive 'js-window-top))

;; js-window-visual-viewport : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-visual-viewport (unsafe-ffi-primitive 'js-window-visual-viewport))

;; js-window-navigator : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-navigator (unsafe-ffi-primitive 'js-window-navigator))

;; js-window-origin : ffi () -> (string)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-origin (unsafe-ffi-primitive 'js-window-origin))

;; js-window-crypto : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-crypto (unsafe-ffi-primitive 'js-window-crypto))

;; js-window-device-pixel-ratio : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-device-pixel-ratio (unsafe-ffi-primitive 'js-window-device-pixel-ratio))

;; js-window-frame-element : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-frame-element (unsafe-ffi-primitive 'js-window-frame-element))

;; js-window-inner-height : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-inner-height (unsafe-ffi-primitive 'js-window-inner-height))

;; js-window-inner-width : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-inner-width (unsafe-ffi-primitive 'js-window-inner-width))

;; js-window-outer-height : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-outer-height (unsafe-ffi-primitive 'js-window-outer-height))

;; js-window-outer-width : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-outer-width (unsafe-ffi-primitive 'js-window-outer-width))

;; js-window-screen-x : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-screen-x (unsafe-ffi-primitive 'js-window-screen-x))

;; js-window-screen-y : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-screen-y (unsafe-ffi-primitive 'js-window-screen-y))

;; js-window-screen-left : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-screen-left (unsafe-ffi-primitive 'js-window-screen-left))

;; js-window-screen-top : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-screen-top (unsafe-ffi-primitive 'js-window-screen-top))

;; js-window-page-x-offset : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-page-x-offset (unsafe-ffi-primitive 'js-window-page-x-offset))

;; js-window-page-y-offset : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-page-y-offset (unsafe-ffi-primitive 'js-window-page-y-offset))

;; js-window-scroll-x : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-scroll-x (unsafe-ffi-primitive 'js-window-scroll-x))

;; js-window-scroll-y : ffi () -> (f64)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-scroll-y (unsafe-ffi-primitive 'js-window-scroll-y))

;; js-window-screen : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-screen (unsafe-ffi-primitive 'js-window-screen))

;; js-window-local-storage : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-local-storage (unsafe-ffi-primitive 'js-window-local-storage))

;; js-window-session-storage : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-session-storage (unsafe-ffi-primitive 'js-window-session-storage))

;; js-window-performance : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-performance (unsafe-ffi-primitive 'js-window-performance))

;; js-window-indexed-db : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-indexed-db (unsafe-ffi-primitive 'js-window-indexed-db))

;; js-window-is-secure-context : ffi () -> (i32)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-is-secure-context (unsafe-ffi-primitive 'js-window-is-secure-context))

;; js-window-cross-origin-isolated : ffi () -> (i32)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-cross-origin-isolated (unsafe-ffi-primitive 'js-window-cross-origin-isolated))

;; js-window-caches : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-caches (unsafe-ffi-primitive 'js-window-caches))

;; js-window-speech-synthesis : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-speech-synthesis (unsafe-ffi-primitive 'js-window-speech-synthesis))

;; js-window-style-media : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-style-media (unsafe-ffi-primitive 'js-window-style-media))

;; js-window-alert : ffi (string) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-alert (unsafe-ffi-primitive 'js-window-alert))

;; js-window-atob : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-atob (unsafe-ffi-primitive 'js-window-atob))

;; js-window-btoa : ffi (string) -> (string)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-btoa (unsafe-ffi-primitive 'js-window-btoa))

;; js-window-blur : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-blur (unsafe-ffi-primitive 'js-window-blur))

;; js-window-cancel-animation-frame : ffi (u32) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-cancel-animation-frame (unsafe-ffi-primitive 'js-window-cancel-animation-frame))

;; js-window-cancel-idle-callback : ffi (u32) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-cancel-idle-callback (unsafe-ffi-primitive 'js-window-cancel-idle-callback))

;; js-window-clear-interval : ffi (u32) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-clear-interval (unsafe-ffi-primitive 'js-window-clear-interval))

;; js-window-clear-timeout : ffi (u32) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-clear-timeout (unsafe-ffi-primitive 'js-window-clear-timeout))

;; js-window-close : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-close (unsafe-ffi-primitive 'js-window-close))

;; js-window-confirm : ffi (string) -> (i32)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-confirm (unsafe-ffi-primitive 'js-window-confirm))

;; js-window-create-image-bitmap : ffi (extern value value value value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-create-image-bitmap (unsafe-ffi-primitive 'js-window-create-image-bitmap))

;; js-window-fetch : ffi (value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-fetch (unsafe-ffi-primitive 'js-window-fetch))

;; js-window-focus : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-focus (unsafe-ffi-primitive 'js-window-focus))

;; js-window-get-computed-style : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-get-computed-style (unsafe-ffi-primitive 'js-window-get-computed-style))

;; js-window-get-selection : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-get-selection (unsafe-ffi-primitive 'js-window-get-selection))

;; js-window-match-media : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-match-media (unsafe-ffi-primitive 'js-window-match-media))

;; js-window-move-by : ffi (f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-move-by (unsafe-ffi-primitive 'js-window-move-by))

;; js-window-move-to : ffi (f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-move-to (unsafe-ffi-primitive 'js-window-move-to))

;; js-window-open : ffi (string value value value) -> (extern)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-open (unsafe-ffi-primitive 'js-window-open))

;; js-window-post-message : ffi (value string value) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-post-message (unsafe-ffi-primitive 'js-window-post-message))

;; js-window-print : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-print (unsafe-ffi-primitive 'js-window-print))

;; js-window-prompt : ffi (string value) -> (value)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-prompt (unsafe-ffi-primitive 'js-window-prompt))

;; js-window-request-animation-frame : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-request-animation-frame (unsafe-ffi-primitive 'js-window-request-animation-frame))

;; js-window-request-idle-callback : ffi (extern value) -> (u32)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-request-idle-callback (unsafe-ffi-primitive 'js-window-request-idle-callback))

;; js-window-resize-by : ffi (f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-resize-by (unsafe-ffi-primitive 'js-window-resize-by))

;; js-window-resize-to : ffi (f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-resize-to (unsafe-ffi-primitive 'js-window-resize-to))

;; js-window-scroll : ffi (f64 f64 value) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-scroll (unsafe-ffi-primitive 'js-window-scroll))

;; js-window-scroll-by : ffi (f64 f64 value) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-scroll-by (unsafe-ffi-primitive 'js-window-scroll-by))

;; js-window-scroll-to : ffi (f64 f64 value) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-scroll-to (unsafe-ffi-primitive 'js-window-scroll-to))

;; js-window-set-interval : ffi (extern f64) -> (u32)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-set-interval (unsafe-ffi-primitive 'js-window-set-interval))

;; js-window-set-timeout : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-set-timeout (unsafe-ffi-primitive 'js-window-set-timeout))

;; js-window-set-timeout/delay : ffi (extern f64) -> (u32)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-set-timeout/delay (unsafe-ffi-primitive 'js-window-set-timeout/delay))

;; js-window-stop : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-stop (unsafe-ffi-primitive 'js-window-stop))

;; js-window-structured-clone : ffi (value value) -> (value)
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-structured-clone (unsafe-ffi-primitive 'js-window-structured-clone))

;; js-window-queue-microtask : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-queue-microtask (unsafe-ffi-primitive 'js-window-queue-microtask))

;; js-window-report-error : ffi (value) -> ()
;;   Raw binding generated for webracket/unsafe/window.
(define js-window-report-error (unsafe-ffi-primitive 'js-window-report-error))
