#lang racket/base

;;; Expansion-time route for `racket/format` in WebRacket module programs.
;;;
;;; The implementation lives under `racket-src/` because it is a staged adapter
;;; for original-Racket formatting work, not part of the legacy textual stdlib.

(require "../../../racket-src/racket/format-web.rkt"
         (only-in "../../../racket-src/io/format/main-web.rkt"
                  fprintf
                  printf
                  eprintf))

(provide (all-from-out "../../../racket-src/racket/format-web.rkt")
         fprintf
         printf
         eprintf)
