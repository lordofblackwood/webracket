#lang racket/base

(require "../pkgs/webracket/define-key.rkt"
         "../pkgs/webracket/sxml.rkt")

;; check-equal? : any/c any/c symbol? -> void?
;;   Lightweight check to avoid depending on RackUnit in this checkout.
(define (check-equal? actual expected who)
  (unless (equal? actual expected)
    (error who
           "check failed\n  actual: ~s\n  expected: ~s"
           actual
           expected)))

(define/key (greet who #:punct [punct "!"])
  (string-append "Hello, " who punct))

(check-equal? (greet "WebRacket")
              "Hello, WebRacket!"
              'define-key-default)

(check-equal? (greet "WebRacket" #:punct ".")
              "Hello, WebRacket."
              'define-key-keyword)

(check-equal? (sxml->html '(p (|@| (class "note")) "Hi & welcome"))
              "<p class=\"note\">Hi &amp; welcome</p>"
              'sxml-module-wrapper)
