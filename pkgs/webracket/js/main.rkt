#lang racket/base

(require (only-in "../core.rkt" js-log))

;; `webracket/js` is the first explicit WebRacket FFI provider. Keep this
;; surface intentionally tiny while the JS/browser binding story settles.
(provide js-log)
