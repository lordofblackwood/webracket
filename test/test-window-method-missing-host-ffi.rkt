#lang webracket/base

;; Browser smoke for direct window function host-boundary errors.

(require (only-in webracket/unsafe/standard
                  js-eval)
         (only-in webracket/unsafe/window
                  js-window-alert
                  js-window-atob
                  js-window-btoa
                  js-window-blur
                  js-window-cancel-animation-frame
                  js-window-clear-interval
                  js-window-clear-timeout
                  js-window-close
                  js-window-confirm
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
                  js-window-resize-by
                  js-window-resize-to
                  js-window-scroll
                  js-window-scroll-by
                  js-window-scroll-to
                  js-window-set-interval
                  js-window-set-timeout
                  js-window-set-timeout/delay
                  js-window-stop))

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

(define callback (js-eval "() => {}"))
(define element (js-eval "document.createElement('div')"))

(js-eval
 "globalThis.__wrWindowMethodBoundaryNames = [
    'alert',
    'atob',
    'btoa',
    'blur',
    'cancelAnimationFrame',
    'clearInterval',
    'clearTimeout',
    'close',
    'confirm',
    'focus',
    'getComputedStyle',
    'getSelection',
    'matchMedia',
    'moveBy',
    'moveTo',
    'open',
    'postMessage',
    'print',
    'prompt',
    'requestAnimationFrame',
    'resizeBy',
    'resizeTo',
    'scroll',
    'scrollBy',
    'scrollTo',
    'setInterval',
    'setTimeout',
    'stop'
  ];
  globalThis.__wrWindowMethodBoundary = {};
  for (const name of globalThis.__wrWindowMethodBoundaryNames) {
    globalThis.__wrWindowMethodBoundary[name] = window[name];
    window[name] = undefined;
  }")

(define alert-message
  (catch-message
   (lambda ()
     (js-window-alert "message"))))

(define atob-message
  (catch-message
   (lambda ()
     (js-window-atob "QQ=="))))

(define btoa-message
  (catch-message
   (lambda ()
     (js-window-btoa "A"))))

(define blur-message
  (catch-message
   (lambda ()
     (js-window-blur))))

(define cancel-animation-frame-message
  (catch-message
   (lambda ()
     (js-window-cancel-animation-frame 1))))

(define clear-interval-message
  (catch-message
   (lambda ()
     (js-window-clear-interval 1))))

(define clear-timeout-message
  (catch-message
   (lambda ()
     (js-window-clear-timeout 1))))

(define close-message
  (catch-message
   (lambda ()
     (js-window-close))))

(define confirm-message
  (catch-message
   (lambda ()
     (js-window-confirm "message"))))

(define focus-message
  (catch-message
   (lambda ()
     (js-window-focus))))

(define get-computed-style-message
  (catch-message
   (lambda ()
     (js-window-get-computed-style element (void)))))

(define get-selection-message
  (catch-message
   (lambda ()
     (js-window-get-selection))))

(define match-media-message
  (catch-message
   (lambda ()
     (js-window-match-media "(min-width: 1px)"))))

(define move-by-message
  (catch-message
   (lambda ()
     (js-window-move-by 0.0 0.0))))

(define move-to-message
  (catch-message
   (lambda ()
     (js-window-move-to 0.0 0.0))))

(define open-message
  (catch-message
   (lambda ()
     (js-window-open "about:blank" (void) (void) (void)))))

(define post-message-message
  (catch-message
   (lambda ()
     (js-window-post-message "message" "*" (void)))))

(define print-message
  (catch-message
   (lambda ()
     (js-window-print))))

(define prompt-message
  (catch-message
   (lambda ()
     (js-window-prompt "message" (void)))))

(define request-animation-frame-message
  (catch-message
   (lambda ()
     (js-window-request-animation-frame callback))))

(define resize-by-message
  (catch-message
   (lambda ()
     (js-window-resize-by 0.0 0.0))))

(define resize-to-message
  (catch-message
   (lambda ()
     (js-window-resize-to 1.0 1.0))))

(define scroll-message
  (catch-message
   (lambda ()
     (js-window-scroll 0.0 0.0 (void)))))

(define scroll-by-message
  (catch-message
   (lambda ()
     (js-window-scroll-by 0.0 0.0 (void)))))

(define scroll-to-message
  (catch-message
   (lambda ()
     (js-window-scroll-to 0.0 0.0 (void)))))

(define set-interval-message
  (catch-message
   (lambda ()
     (js-window-set-interval callback 1.0))))

(define set-timeout-message
  (catch-message
   (lambda ()
     (js-window-set-timeout callback))))

(define set-timeout/delay-message
  (catch-message
   (lambda ()
     (js-window-set-timeout/delay callback 1.0))))

(define stop-message
  (catch-message
   (lambda ()
     (js-window-stop))))

(js-eval
 "for (const name of globalThis.__wrWindowMethodBoundaryNames) {
    window[name] = globalThis.__wrWindowMethodBoundary[name];
  }
  delete globalThis.__wrWindowMethodBoundary;
  delete globalThis.__wrWindowMethodBoundaryNames;")

(check-message alert-message
               "window.alert not available in this environment"
               "missing alert message")
(check-message atob-message
               "window.atob not available in this environment"
               "missing atob message")
(check-message btoa-message
               "window.btoa not available in this environment"
               "missing btoa message")
(check-message blur-message
               "window.blur not available in this environment"
               "missing blur message")
(check-message cancel-animation-frame-message
               "window.cancelAnimationFrame not available in this environment"
               "missing cancelAnimationFrame message")
(check-message clear-interval-message
               "window.clearInterval not available in this environment"
               "missing clearInterval message")
(check-message clear-timeout-message
               "window.clearTimeout not available in this environment"
               "missing clearTimeout message")
(check-message close-message
               "window.close not available in this environment"
               "missing close message")
(check-message confirm-message
               "window.confirm not available in this environment"
               "missing confirm message")
(check-message focus-message
               "window.focus not available in this environment"
               "missing focus message")
(check-message get-computed-style-message
               "window.getComputedStyle not available in this environment"
               "missing getComputedStyle message")
(check-message get-selection-message
               "window.getSelection not available in this environment"
               "missing getSelection message")
(check-message match-media-message
               "window.matchMedia not available in this environment"
               "missing matchMedia message")
(check-message move-by-message
               "window.moveBy not available in this environment"
               "missing moveBy message")
(check-message move-to-message
               "window.moveTo not available in this environment"
               "missing moveTo message")
(check-message open-message
               "window.open not available in this environment"
               "missing open message")
(check-message post-message-message
               "window.postMessage not available in this environment"
               "missing postMessage message")
(check-message print-message
               "window.print not available in this environment"
               "missing print message")
(check-message prompt-message
               "window.prompt not available in this environment"
               "missing prompt message")
(check-message request-animation-frame-message
               "window.requestAnimationFrame not available in this environment"
               "missing requestAnimationFrame message")
(check-message resize-by-message
               "window.resizeBy not available in this environment"
               "missing resizeBy message")
(check-message resize-to-message
               "window.resizeTo not available in this environment"
               "missing resizeTo message")
(check-message scroll-message
               "window.scroll not available in this environment"
               "missing scroll message")
(check-message scroll-by-message
               "window.scrollBy not available in this environment"
               "missing scrollBy message")
(check-message scroll-to-message
               "window.scrollTo not available in this environment"
               "missing scrollTo message")
(check-message set-interval-message
               "window.setInterval not available in this environment"
               "missing setInterval message")
(check-message set-timeout-message
               "window.setTimeout not available in this environment"
               "missing setTimeout message")
(check-message set-timeout/delay-message
               "window.setTimeout not available in this environment"
               "missing setTimeout/delay message")
(check-message stop-message
               "window.stop not available in this environment"
               "missing stop message")

(js-log "window-method-missing-host-ffi-ok")
#t
