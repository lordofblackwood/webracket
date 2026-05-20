#lang racket/base

;; `webracket/js` is the first explicit WebRacket FFI provider. Keep this
;; surface intentionally tiny while the JS/browser binding story settles.
(provide js-log)

;; js-log : any/c -> void?
;;   Host-side stand-in; compiled WebRacket programs lower `js-log` to a runtime primitive.
(define (js-log v)
  (displayln v))
