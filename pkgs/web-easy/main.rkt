#lang webracket/base

(require browser/dom
         racket/include
         racket/list
         racket/match
         racket/path
         racket/string
         webracket/define-key
         (only-in webracket/primitives
                  external?
                  js-log
                  procedure->external)
         (for-syntax racket/base))

;; Public browser entry point for the `web-easy` collection.
;;
;; The legacy library is assembled textually by `lib/web-easy/main-browser.rkt`.
;; This module keeps the same source order, but exposes the resulting bindings
;; through a normal module provider for module-bridge programs.

(provide (all-defined-out))

(begin-for-syntax
  (define (read-syntax/skip-first-line
           [source-name (object-name (current-input-port))]
           [in          (current-input-port)])
    (read-line in)
    (read-syntax source-name in)))

(include/reader "observable.rkt"          read-syntax/skip-first-line)
(include/reader "define-element.rkt"      read-syntax/skip-first-line)
(include/reader "operator.rkt"            read-syntax/skip-first-line)
(include/reader "view.rkt"                read-syntax/skip-first-line)
(include/reader "theme-token.rkt"         read-syntax/skip-first-line)
(include/reader "backend-browser.rkt"     read-syntax/skip-first-line)
(include/reader "theme-token-browser.rkt" read-syntax/skip-first-line)
(include/reader "renderer.rkt"            read-syntax/skip-first-line)
(include/reader "browser-host.rkt"        read-syntax/skip-first-line)
(include/reader "event-browser.rkt"       read-syntax/skip-first-line)
(include/reader "theme-browser.rkt"       read-syntax/skip-first-line)
