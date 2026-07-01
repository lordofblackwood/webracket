#lang racket

(provide location-runtime-only-helpers)

(require "../core-helper.rkt")

;; location-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate source-location helpers used by the monolithic runtime.
(define location-runtime-only-helpers
  (function-forms->runtime-helpers
   'location-runtime-only-helpers
   '(
     (func $make-initial-location (result (ref eq))
           ;; (location 1 0 1)
           (struct.new $Location
                       (i32.const 0)            ;; hash (placeholder)
                       (global.get $one)        ;; line
                       (global.get $zero)       ;; col
                       (global.get $one))))))   ;; pos
