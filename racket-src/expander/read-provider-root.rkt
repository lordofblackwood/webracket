#lang racket/base

;; Provider root for staging `expander/read` inside WebRacket.
;;
;; The upstream reader exports names like `read` and `string->number` that are
;; already public Racket/WebRacket bindings. Rebind them here under Webify-owned
;; names so the flattened provider has ordinary instance variables to export;
;; public aliases can be introduced deliberately by the driver later.

(require (prefix-in raw: "read/main.rkt"))

(define webify-expander-read raw:read)
(define webify-expander-read-language raw:read-language)
(define webify-expander-current-readtable raw:current-readtable)
(define webify-expander-make-readtable raw:make-readtable)
(define webify-expander-readtable? raw:readtable?)
(define webify-expander-readtable-mapping raw:readtable-mapping)
(define webify-expander-string->number raw:string->number)
(define webify-expander-current-reader-guard raw:current-reader-guard)
(define webify-expander-read-square-bracket-as-paren raw:read-square-bracket-as-paren)
(define webify-expander-read-curly-brace-as-paren raw:read-curly-brace-as-paren)
(define webify-expander-read-square-bracket-with-tag raw:read-square-bracket-with-tag)
(define webify-expander-read-curly-brace-with-tag raw:read-curly-brace-with-tag)
(define webify-expander-read-cdot raw:read-cdot)
(define webify-expander-read-accept-graph raw:read-accept-graph)
(define webify-expander-read-syntax-accept-graph raw:read-syntax-accept-graph)
(define webify-expander-read-accept-compiled raw:read-accept-compiled)
(define webify-expander-read-accept-box raw:read-accept-box)
(define webify-expander-read-single-flonum raw:read-single-flonum)
(define webify-expander-read-decimal-as-inexact raw:read-decimal-as-inexact)
(define webify-expander-read-accept-dot raw:read-accept-dot)
(define webify-expander-read-accept-infix-dot raw:read-accept-infix-dot)
(define webify-expander-read-accept-quasiquote raw:read-accept-quasiquote)
(define webify-expander-read-accept-reader raw:read-accept-reader)
(define webify-expander-read-accept-lang raw:read-accept-lang)
(define webify-expander-special-comment? raw:special-comment?)
(define webify-expander-make-special-comment raw:make-special-comment)
(define webify-expander-special-comment-value raw:special-comment-value)

(provide webify-expander-read
         webify-expander-read-language
         webify-expander-current-readtable
         webify-expander-make-readtable
         webify-expander-readtable?
         webify-expander-readtable-mapping
         webify-expander-string->number
         webify-expander-current-reader-guard
         webify-expander-read-square-bracket-as-paren
         webify-expander-read-curly-brace-as-paren
         webify-expander-read-square-bracket-with-tag
         webify-expander-read-curly-brace-with-tag
         webify-expander-read-cdot
         webify-expander-read-accept-graph
         webify-expander-read-syntax-accept-graph
         webify-expander-read-accept-compiled
         webify-expander-read-accept-box
         webify-expander-read-single-flonum
         webify-expander-read-decimal-as-inexact
         webify-expander-read-accept-dot
         webify-expander-read-accept-infix-dot
         webify-expander-read-accept-quasiquote
         webify-expander-read-accept-reader
         webify-expander-read-accept-lang
         webify-expander-special-comment?
         webify-expander-make-special-comment
         webify-expander-special-comment-value)
