#lang racket/base

;;; Provider metadata for the staged original Racket `io/print` direction.
;;;
;;; This module is an ownership/plan guard, not a completed provider bridge.
;;; High-level public printing should move here from the legacy stdlib after
;;; the staged print closure is adapted enough for WebRacket's port substrate.

(provide io-print-provider-symbols
         io-print-runtime-substrate-symbols
         io-print-staged-source-files
         io-print-provider-module
         io-print-provider-status
         io-print-provider-ready?
         io-print-bootstrap-blockers)

(require racket/runtime-path)

(define io-print-provider-symbols
  '(display
    displayln
    newline
    print
    println
    write
    writeln))

(define io-print-runtime-substrate-symbols
  '(current-output-port
    open-output-string
    get-output-string
    output-port?
    port-display-handler
    port-print-handler
    port-write-handler
    write-string))

(define io-print-staged-source-files
  '("print/main.rkt"
    "print/mode.rkt"
    "print/parameter.rkt"
    "print/regexp.rkt"))

(define-runtime-path io-print-provider-module
  "../racket-src/io/print/main.rkt")

(define io-print-bootstrap-blockers
  '((missing-staged-closure
     "print/main.rkt still requires unstaged print helpers such as custom-write, list, vector, hash, and graph")
    (port-substrate-adapter
     "WebRacket needs an adapter for the staged print layer's core-output-port protocol")
    (custom-write-properties
     "prop:custom-write and prop:custom-print-quotable must line up with WebRacket structs")
    (graph-and-sharing
     "default printing needs graph/cycle detection semantics before replacing stdlib/writing.rkt")))

;; io-print-provider-ready? : -> boolean?
;;   Report whether the high-level print provider is ready for public aliases.
(define (io-print-provider-ready?)
  (null? io-print-bootstrap-blockers))

;; io-print-provider-status : -> (listof (list/c symbol? symbol?))
;;   Report current ownership status for public high-level printing names.
(define (io-print-provider-status)
  (for/list ([name (in-list io-print-provider-symbols)])
    (list name
          (if (io-print-provider-ready?)
              'staged-original-ready
              'staged-original-planned))))
