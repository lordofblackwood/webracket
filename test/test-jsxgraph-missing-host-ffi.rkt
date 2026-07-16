#lang webracket/base

;; Browser smoke for missing JSXGraph host-library errors.

(require jsxgraph
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

(define board-message
  (catch-message
   (lambda ()
     (jsx-create-board "missing-jsxgraph-host"))))

(define point-message
  (catch-message
   (lambda ()
     (jsx-point?/raw (js-eval "({})")))))

(check-true (and board-message
                 (string-contains/simple? board-message
                                          "JSXGraph JXG.JSXGraph not available"))
            "missing JSXGraph board message")
(check-true (and point-message
                 (string-contains/simple? point-message
                                          "JSXGraph JXG.isPoint not available"))
            "missing JSXGraph point message")

(js-log "jsxgraph-missing-host-ffi-ok")
#t
