#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 xterm-terminal-new
 xterm-terminal-buffer
 xterm-terminal-cols
 xterm-terminal-rows
 xterm-terminal-element
 xterm-terminal-textarea
 xterm-terminal-markers
 xterm-terminal-modes
 xterm-terminal-options
 xterm-set-terminal-options!
 xterm-terminal-parser
 xterm-terminal-unicode
 xterm-terminal-on-bell
 xterm-terminal-on-binary
 xterm-terminal-on-cursor-move
 xterm-terminal-on-data
 xterm-terminal-on-key
 xterm-terminal-on-line-feed
 xterm-terminal-on-render
 xterm-terminal-on-resize
 xterm-terminal-on-scroll
 xterm-terminal-on-selection-change
 xterm-terminal-on-title-change
 xterm-terminal-on-write-parsed
 xterm-terminal-attach-custom-key-event-handler
 xterm-terminal-attach-custom-wheel-event-handler
 xterm-terminal-blur
 xterm-terminal-focus
 xterm-terminal-dispose
 xterm-terminal-clear
 xterm-terminal-clear-selection
 xterm-terminal-clear-texture-atlas
 xterm-terminal-deregister-character-joiner
 xterm-terminal-get-selection
 xterm-terminal-get-selection-position
 xterm-terminal-has-selection
 xterm-terminal-input
 xterm-terminal-load-addon
 xterm-terminal-open
 xterm-terminal-paste
 xterm-terminal-refresh
 xterm-terminal-register-character-joiner
 xterm-terminal-register-decoration
 xterm-terminal-register-link-provider
 xterm-terminal-register-marker
 xterm-terminal-reset
 xterm-terminal-resize
 xterm-terminal-scroll-lines
 xterm-terminal-scroll-pages
 xterm-terminal-scroll-to-bottom
 xterm-terminal-scroll-to-line
 xterm-terminal-scroll-to-top
 xterm-terminal-select
 xterm-terminal-select-all
 xterm-terminal-select-lines
 xterm-terminal-write
 xterm-terminal-writeln
 xterm-fit-addon-new
 xterm-fit-addon-activate
 xterm-fit-addon-dispose
 xterm-fit-addon-fit
 xterm-fit-addon-propose-dimensions)

;; xterm-terminal-new : ffi (value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-new (unsafe-ffi-primitive 'xterm-terminal-new))

;; xterm-terminal-buffer : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-buffer (unsafe-ffi-primitive 'xterm-terminal-buffer))

;; xterm-terminal-cols : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-cols (unsafe-ffi-primitive 'xterm-terminal-cols))

;; xterm-terminal-rows : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-rows (unsafe-ffi-primitive 'xterm-terminal-rows))

;; xterm-terminal-element : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-element (unsafe-ffi-primitive 'xterm-terminal-element))

;; xterm-terminal-textarea : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-textarea (unsafe-ffi-primitive 'xterm-terminal-textarea))

;; xterm-terminal-markers : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-markers (unsafe-ffi-primitive 'xterm-terminal-markers))

;; xterm-terminal-modes : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-modes (unsafe-ffi-primitive 'xterm-terminal-modes))

;; xterm-terminal-options : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-options (unsafe-ffi-primitive 'xterm-terminal-options))

;; xterm-set-terminal-options! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-set-terminal-options! (unsafe-ffi-primitive 'xterm-set-terminal-options!))

;; xterm-terminal-parser : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-parser (unsafe-ffi-primitive 'xterm-terminal-parser))

;; xterm-terminal-unicode : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-unicode (unsafe-ffi-primitive 'xterm-terminal-unicode))

;; xterm-terminal-on-bell : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-on-bell (unsafe-ffi-primitive 'xterm-terminal-on-bell))

;; xterm-terminal-on-binary : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-on-binary (unsafe-ffi-primitive 'xterm-terminal-on-binary))

;; xterm-terminal-on-cursor-move : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-on-cursor-move (unsafe-ffi-primitive 'xterm-terminal-on-cursor-move))

;; xterm-terminal-on-data : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-on-data (unsafe-ffi-primitive 'xterm-terminal-on-data))

;; xterm-terminal-on-key : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-on-key (unsafe-ffi-primitive 'xterm-terminal-on-key))

;; xterm-terminal-on-line-feed : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-on-line-feed (unsafe-ffi-primitive 'xterm-terminal-on-line-feed))

;; xterm-terminal-on-render : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-on-render (unsafe-ffi-primitive 'xterm-terminal-on-render))

;; xterm-terminal-on-resize : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-on-resize (unsafe-ffi-primitive 'xterm-terminal-on-resize))

;; xterm-terminal-on-scroll : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-on-scroll (unsafe-ffi-primitive 'xterm-terminal-on-scroll))

;; xterm-terminal-on-selection-change : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-on-selection-change (unsafe-ffi-primitive 'xterm-terminal-on-selection-change))

;; xterm-terminal-on-title-change : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-on-title-change (unsafe-ffi-primitive 'xterm-terminal-on-title-change))

;; xterm-terminal-on-write-parsed : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-on-write-parsed (unsafe-ffi-primitive 'xterm-terminal-on-write-parsed))

;; xterm-terminal-attach-custom-key-event-handler : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-attach-custom-key-event-handler (unsafe-ffi-primitive 'xterm-terminal-attach-custom-key-event-handler))

;; xterm-terminal-attach-custom-wheel-event-handler : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-attach-custom-wheel-event-handler (unsafe-ffi-primitive 'xterm-terminal-attach-custom-wheel-event-handler))

;; xterm-terminal-blur : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-blur (unsafe-ffi-primitive 'xterm-terminal-blur))

;; xterm-terminal-focus : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-focus (unsafe-ffi-primitive 'xterm-terminal-focus))

;; xterm-terminal-dispose : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-dispose (unsafe-ffi-primitive 'xterm-terminal-dispose))

;; xterm-terminal-clear : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-clear (unsafe-ffi-primitive 'xterm-terminal-clear))

;; xterm-terminal-clear-selection : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-clear-selection (unsafe-ffi-primitive 'xterm-terminal-clear-selection))

;; xterm-terminal-clear-texture-atlas : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-clear-texture-atlas (unsafe-ffi-primitive 'xterm-terminal-clear-texture-atlas))

;; xterm-terminal-deregister-character-joiner : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-deregister-character-joiner (unsafe-ffi-primitive 'xterm-terminal-deregister-character-joiner))

;; xterm-terminal-get-selection : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-get-selection (unsafe-ffi-primitive 'xterm-terminal-get-selection))

;; xterm-terminal-get-selection-position : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-get-selection-position (unsafe-ffi-primitive 'xterm-terminal-get-selection-position))

;; xterm-terminal-has-selection : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-has-selection (unsafe-ffi-primitive 'xterm-terminal-has-selection))

;; xterm-terminal-input : ffi (extern string value) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-input (unsafe-ffi-primitive 'xterm-terminal-input))

;; xterm-terminal-load-addon : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-load-addon (unsafe-ffi-primitive 'xterm-terminal-load-addon))

;; xterm-terminal-open : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-open (unsafe-ffi-primitive 'xterm-terminal-open))

;; xterm-terminal-paste : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-paste (unsafe-ffi-primitive 'xterm-terminal-paste))

;; xterm-terminal-refresh : ffi (extern i32 i32) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-refresh (unsafe-ffi-primitive 'xterm-terminal-refresh))

;; xterm-terminal-register-character-joiner : ffi (extern extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-register-character-joiner (unsafe-ffi-primitive 'xterm-terminal-register-character-joiner))

;; xterm-terminal-register-decoration : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-register-decoration (unsafe-ffi-primitive 'xterm-terminal-register-decoration))

;; xterm-terminal-register-link-provider : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-register-link-provider (unsafe-ffi-primitive 'xterm-terminal-register-link-provider))

;; xterm-terminal-register-marker : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-register-marker (unsafe-ffi-primitive 'xterm-terminal-register-marker))

;; xterm-terminal-reset : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-reset (unsafe-ffi-primitive 'xterm-terminal-reset))

;; xterm-terminal-resize : ffi (extern i32 i32) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-resize (unsafe-ffi-primitive 'xterm-terminal-resize))

;; xterm-terminal-scroll-lines : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-scroll-lines (unsafe-ffi-primitive 'xterm-terminal-scroll-lines))

;; xterm-terminal-scroll-pages : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-scroll-pages (unsafe-ffi-primitive 'xterm-terminal-scroll-pages))

;; xterm-terminal-scroll-to-bottom : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-scroll-to-bottom (unsafe-ffi-primitive 'xterm-terminal-scroll-to-bottom))

;; xterm-terminal-scroll-to-line : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-scroll-to-line (unsafe-ffi-primitive 'xterm-terminal-scroll-to-line))

;; xterm-terminal-scroll-to-top : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-scroll-to-top (unsafe-ffi-primitive 'xterm-terminal-scroll-to-top))

;; xterm-terminal-select : ffi (extern i32 i32 i32) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-select (unsafe-ffi-primitive 'xterm-terminal-select))

;; xterm-terminal-select-all : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-select-all (unsafe-ffi-primitive 'xterm-terminal-select-all))

;; xterm-terminal-select-lines : ffi (extern i32 i32) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-select-lines (unsafe-ffi-primitive 'xterm-terminal-select-lines))

;; xterm-terminal-write : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-write (unsafe-ffi-primitive 'xterm-terminal-write))

;; xterm-terminal-writeln : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-terminal-writeln (unsafe-ffi-primitive 'xterm-terminal-writeln))

;; xterm-fit-addon-new : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-fit-addon-new (unsafe-ffi-primitive 'xterm-fit-addon-new))

;; xterm-fit-addon-activate : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-fit-addon-activate (unsafe-ffi-primitive 'xterm-fit-addon-activate))

;; xterm-fit-addon-dispose : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-fit-addon-dispose (unsafe-ffi-primitive 'xterm-fit-addon-dispose))

;; xterm-fit-addon-fit : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-fit-addon-fit (unsafe-ffi-primitive 'xterm-fit-addon-fit))

;; xterm-fit-addon-propose-dimensions : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/xtermjs.
(define xterm-fit-addon-propose-dimensions (unsafe-ffi-primitive 'xterm-fit-addon-propose-dimensions))
