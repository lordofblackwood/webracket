#lang webracket/base

(require racket/include
         racket/list
         racket/match
         racket/path
         racket/string
         webracket/define-key
         ;; The DOM-like backend is a host-Racket test/probe entry point, so
         ;; its element constructors need native Racket keyword metadata.
         (only-in racket/base
                  make-keyword-procedure
                  keyword-apply
                  procedure-reduce-keyword-arity)
         (only-in webracket/primitives
                  js-log)
         (for-syntax racket/base))

;; Internal DOM-like entry point for tests and non-browser renderer probes.
;;
;; Public module programs should normally require `web-easy`, which uses the
;; browser backend.

(provide (all-defined-out))

(begin-for-syntax
  (define (read-syntax/skip-first-line
           [source-name (object-name (current-input-port))]
           [in          (current-input-port)])
    (read-line in)
    (read-syntax source-name in)))

(include/reader "../observable.rkt"        read-syntax/skip-first-line)
(include/reader "../define-element.rkt"    read-syntax/skip-first-line)
(include/reader "../operator.rkt"          read-syntax/skip-first-line)
(include/reader "../view.rkt"              read-syntax/skip-first-line)
(include/reader "../theme-token.rkt"       read-syntax/skip-first-line)
(include/reader "../backend-dom-like.rkt"  read-syntax/skip-first-line)
(include/reader "../renderer.rkt"          read-syntax/skip-first-line)
