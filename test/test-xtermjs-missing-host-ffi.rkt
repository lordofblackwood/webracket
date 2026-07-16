#lang webracket/base

;; Browser smoke for missing xterm.js host-library errors.

(require xterm)

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

(define terminal-message
  (catch-message
   (lambda ()
     (xterm-terminal-new (void)))))

(define fit-addon-message
  (catch-message
   (lambda ()
     (xterm-fit-addon-new))))

(check-true (and terminal-message
                 (string-contains/simple? terminal-message
                                          "xterm.js Terminal not available"))
            "missing Terminal message")
(check-true (and fit-addon-message
                 (string-contains/simple? fit-addon-message
                                          "xterm.js FitAddon not available"))
            "missing FitAddon message")

(js-log "xtermjs-missing-host-ffi-ok")
#t
