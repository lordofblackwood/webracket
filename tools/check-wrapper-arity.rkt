#lang racket/base

;;; Check Wrapper Arity
;;;

;; This tool is a backward-compatibility launcher for the renamed constructor
;; arity scanner. Keep it around for older scripts, but use
;; `tools/check-constructor-arity.rkt` for new call sites.
;;
;; Invoke it exactly like the replacement:
;;
;;   racket tools/check-wrapper-arity.rkt path ...
;;
;; It forwards command-line arguments to `check-constructor-arity.rkt` and
;; produces the same diagnostics and exit status.


;;; Imports

;; Only `racket/runtime-path` is needed so the launcher can find the sibling
;; scanner reliably from any current directory.

(require racket/runtime-path)


;;; Delegation

;; This section preserves the original command-line arguments and loads the
;; replacement tool as the actual entry point.

(define-runtime-path tool-path "check-constructor-arity.rkt")

(parameterize ([current-command-line-arguments (current-command-line-arguments)])
  (dynamic-require tool-path #f))
