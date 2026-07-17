#lang webracket/base

;; Browser smoke for missing xterm.js host-library and method errors.

(require xterm
         (only-in webracket/unsafe/standard
                  js-eval))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(define (string-contains/simple? haystack needle)
  (define haystack-length (string-length haystack))
  (define needle-length (string-length needle))
  (let loop ([index 0])
    (cond
      [(> (+ index needle-length) haystack-length) #f]
      [(string=? (substring haystack index (+ index needle-length)) needle) #t]
      [else (loop (add1 index))])))

(define (check-message message needle label)
  (check-true (and message
                   (string-contains/simple? message needle))
              label))

(define terminal-message
  (catch-message
   (lambda ()
     (xterm-terminal-new (void)))))

(define fit-addon-message
  (catch-message
   (lambda ()
     (xterm-fit-addon-new))))

(define missing-terminal (js-eval "({})"))
(define missing-addon (js-eval "({})"))
(define handler (js-eval "(() => {})"))
(define parent (js-eval "document.createElement('div')"))

(define attach-key-message
  (catch-message
   (lambda ()
     (xterm-terminal-attach-custom-key-event-handler missing-terminal handler))))

(define attach-wheel-message
  (catch-message
   (lambda ()
     (xterm-terminal-attach-custom-wheel-event-handler missing-terminal handler))))

(define blur-message
  (catch-message
   (lambda ()
     (xterm-terminal-blur missing-terminal))))

(define focus-message
  (catch-message
   (lambda ()
     (xterm-terminal-focus missing-terminal))))

(define dispose-message
  (catch-message
   (lambda ()
     (xterm-terminal-dispose missing-terminal))))

(define clear-message
  (catch-message
   (lambda ()
     (xterm-terminal-clear missing-terminal))))

(define clear-selection-message
  (catch-message
   (lambda ()
     (xterm-terminal-clear-selection missing-terminal))))

(define clear-texture-atlas-message
  (catch-message
   (lambda ()
     (xterm-terminal-clear-texture-atlas missing-terminal))))

(define deregister-character-joiner-message
  (catch-message
   (lambda ()
     (xterm-terminal-deregister-character-joiner missing-terminal 0))))

(define get-selection-message
  (catch-message
   (lambda ()
     (xterm-terminal-get-selection missing-terminal))))

(define get-selection-position-message
  (catch-message
   (lambda ()
     (xterm-terminal-get-selection-position missing-terminal))))

(define has-selection-message
  (catch-message
   (lambda ()
     (xterm-terminal-has-selection missing-terminal))))

(define input-message
  (catch-message
   (lambda ()
     (xterm-terminal-input missing-terminal "x" (void)))))

(define load-addon-message
  (catch-message
   (lambda ()
     (xterm-terminal-load-addon missing-terminal missing-addon))))

(define open-message
  (catch-message
   (lambda ()
     (xterm-terminal-open missing-terminal parent))))

(define paste-message
  (catch-message
   (lambda ()
     (xterm-terminal-paste missing-terminal "x"))))

(define refresh-message
  (catch-message
   (lambda ()
     (xterm-terminal-refresh missing-terminal 0 0))))

(define register-character-joiner-message
  (catch-message
   (lambda ()
     (xterm-terminal-register-character-joiner missing-terminal handler))))

(define register-decoration-message
  (catch-message
   (lambda ()
     (xterm-terminal-register-decoration missing-terminal missing-addon))))

(define register-link-provider-message
  (catch-message
   (lambda ()
     (xterm-terminal-register-link-provider missing-terminal missing-addon))))

(define register-marker-message
  (catch-message
   (lambda ()
     (xterm-terminal-register-marker missing-terminal (void)))))

(define reset-message
  (catch-message
   (lambda ()
     (xterm-terminal-reset missing-terminal))))

(define resize-message
  (catch-message
   (lambda ()
     (xterm-terminal-resize missing-terminal 80 24))))

(define scroll-lines-message
  (catch-message
   (lambda ()
     (xterm-terminal-scroll-lines missing-terminal 1))))

(define scroll-pages-message
  (catch-message
   (lambda ()
     (xterm-terminal-scroll-pages missing-terminal 1))))

(define scroll-to-bottom-message
  (catch-message
   (lambda ()
     (xterm-terminal-scroll-to-bottom missing-terminal))))

(define scroll-to-line-message
  (catch-message
   (lambda ()
     (xterm-terminal-scroll-to-line missing-terminal 0))))

(define scroll-to-top-message
  (catch-message
   (lambda ()
     (xterm-terminal-scroll-to-top missing-terminal))))

(define select-message
  (catch-message
   (lambda ()
     (xterm-terminal-select missing-terminal 0 0 1))))

(define select-all-message
  (catch-message
   (lambda ()
     (xterm-terminal-select-all missing-terminal))))

(define select-lines-message
  (catch-message
   (lambda ()
     (xterm-terminal-select-lines missing-terminal 0 1))))

(define write-message
  (catch-message
   (lambda ()
     (xterm-terminal-write missing-terminal "x" (void)))))

(define writeln-message
  (catch-message
   (lambda ()
     (xterm-terminal-writeln missing-terminal "x" (void)))))

(define fit-activate-message
  (catch-message
   (lambda ()
     (xterm-fit-addon-activate missing-addon missing-terminal))))

(define fit-dispose-message
  (catch-message
   (lambda ()
     (xterm-fit-addon-dispose missing-addon))))

(define fit-message
  (catch-message
   (lambda ()
     (xterm-fit-addon-fit missing-addon))))

(define propose-dimensions-message
  (catch-message
   (lambda ()
     (xterm-fit-addon-propose-dimensions missing-addon))))

(check-message terminal-message
               "xterm.js Terminal not available"
               "missing Terminal message")
(check-message fit-addon-message
               "xterm.js FitAddon not available"
               "missing FitAddon message")
(check-message attach-key-message
               "xterm.js Terminal.attachCustomKeyEventHandler not available in this environment"
               "missing attachCustomKeyEventHandler message")
(check-message attach-wheel-message
               "xterm.js Terminal.attachCustomWheelEventHandler not available in this environment"
               "missing attachCustomWheelEventHandler message")
(check-message blur-message
               "xterm.js Terminal.blur not available in this environment"
               "missing blur message")
(check-message focus-message
               "xterm.js Terminal.focus not available in this environment"
               "missing focus message")
(check-message dispose-message
               "xterm.js Terminal.dispose not available in this environment"
               "missing dispose message")
(check-message clear-message
               "xterm.js Terminal.clear not available in this environment"
               "missing clear message")
(check-message clear-selection-message
               "xterm.js Terminal.clearSelection not available in this environment"
               "missing clearSelection message")
(check-message clear-texture-atlas-message
               "xterm.js Terminal.clearTextureAtlas not available in this environment"
               "missing clearTextureAtlas message")
(check-message deregister-character-joiner-message
               "xterm.js Terminal.deregisterCharacterJoiner not available in this environment"
               "missing deregisterCharacterJoiner message")
(check-message get-selection-message
               "xterm.js Terminal.getSelection not available in this environment"
               "missing getSelection message")
(check-message get-selection-position-message
               "xterm.js Terminal.getSelectionPosition not available in this environment"
               "missing getSelectionPosition message")
(check-message has-selection-message
               "xterm.js Terminal.hasSelection not available in this environment"
               "missing hasSelection message")
(check-message input-message
               "xterm.js Terminal.input not available in this environment"
               "missing input message")
(check-message load-addon-message
               "xterm.js Terminal.loadAddon not available in this environment"
               "missing loadAddon message")
(check-message open-message
               "xterm.js Terminal.open not available in this environment"
               "missing open message")
(check-message paste-message
               "xterm.js Terminal.paste not available in this environment"
               "missing paste message")
(check-message refresh-message
               "xterm.js Terminal.refresh not available in this environment"
               "missing refresh message")
(check-message register-character-joiner-message
               "xterm.js Terminal.registerCharacterJoiner not available in this environment"
               "missing registerCharacterJoiner message")
(check-message register-decoration-message
               "xterm.js Terminal.registerDecoration not available in this environment"
               "missing registerDecoration message")
(check-message register-link-provider-message
               "xterm.js Terminal.registerLinkProvider not available in this environment"
               "missing registerLinkProvider message")
(check-message register-marker-message
               "xterm.js Terminal.registerMarker not available in this environment"
               "missing registerMarker message")
(check-message reset-message
               "xterm.js Terminal.reset not available in this environment"
               "missing reset message")
(check-message resize-message
               "xterm.js Terminal.resize not available in this environment"
               "missing resize message")
(check-message scroll-lines-message
               "xterm.js Terminal.scrollLines not available in this environment"
               "missing scrollLines message")
(check-message scroll-pages-message
               "xterm.js Terminal.scrollPages not available in this environment"
               "missing scrollPages message")
(check-message scroll-to-bottom-message
               "xterm.js Terminal.scrollToBottom not available in this environment"
               "missing scrollToBottom message")
(check-message scroll-to-line-message
               "xterm.js Terminal.scrollToLine not available in this environment"
               "missing scrollToLine message")
(check-message scroll-to-top-message
               "xterm.js Terminal.scrollToTop not available in this environment"
               "missing scrollToTop message")
(check-message select-message
               "xterm.js Terminal.select not available in this environment"
               "missing select message")
(check-message select-all-message
               "xterm.js Terminal.selectAll not available in this environment"
               "missing selectAll message")
(check-message select-lines-message
               "xterm.js Terminal.selectLines not available in this environment"
               "missing selectLines message")
(check-message write-message
               "xterm.js Terminal.write not available in this environment"
               "missing write message")
(check-message writeln-message
               "xterm.js Terminal.writeln not available in this environment"
               "missing writeln message")
(check-message fit-activate-message
               "xterm.js FitAddon.activate not available in this environment"
               "missing FitAddon.activate message")
(check-message fit-dispose-message
               "xterm.js FitAddon.dispose not available in this environment"
               "missing FitAddon.dispose message")
(check-message fit-message
               "xterm.js FitAddon.fit not available in this environment"
               "missing FitAddon.fit message")
(check-message propose-dimensions-message
               "xterm.js FitAddon.proposeDimensions not available in this environment"
               "missing FitAddon.proposeDimensions message")

(js-log "xtermjs-missing-host-ffi-ok")
#t
