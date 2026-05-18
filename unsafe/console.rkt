#lang racket/base

(require "../js.rkt")

(provide js-console-log
         js-console-info
         js-console-warn
         js-console-error
         js-console-debug
         js-console-assert
         js-console-clear
         js-console-dir
         js-console-dirxml
         js-console-table
         js-console-group
         js-console-group-collapsed
         js-console-group-end
         js-console-count
         js-console-count-reset
         js-console-time
         js-console-time-end
         js-console-time-log
         js-console-time-stamp
         js-console-trace
         js-console-profile
         js-console-profile-end
         js-console-exception)

;; This module is the unsafe/raw console binding surface corresponding to
;; `ffi/console.ffi`. For now it is a primitive-backed shim so module programs
;; can require the raw names; the generator should replace these definitions
;; with direct `.ffi` import-backed exports.

;; js-console-log : any/c -> void?
;;   Raw console log binding.
(define (js-console-log args)
  (js-log args)
  (void))

;; js-console-info : any/c -> void?
;;   Raw console info binding.
(define (js-console-info args)
  (js-log args)
  (void))

;; js-console-warn : any/c -> void?
;;   Raw console warning binding.
(define (js-console-warn args)
  (js-log args)
  (void))

;; js-console-error : any/c -> void?
;;   Raw console error binding.
(define (js-console-error args)
  (js-log args)
  (void))

;; js-console-debug : any/c -> void?
;;   Raw console debug binding.
(define (js-console-debug args)
  (js-log args)
  (void))

;; js-console-assert : any/c -> void?
;;   Raw console assert binding.
(define (js-console-assert args)
  (js-log args)
  (void))

;; js-console-clear : -> void?
;;   Raw console clear binding.
(define (js-console-clear)
  (void))

;; js-console-dir : any/c -> void?
;;   Raw console dir binding.
(define (js-console-dir args)
  (js-log args)
  (void))

;; js-console-dirxml : any/c -> void?
;;   Raw console dirxml binding.
(define (js-console-dirxml args)
  (js-log args)
  (void))

;; js-console-table : any/c -> void?
;;   Raw console table binding.
(define (js-console-table args)
  (js-log args)
  (void))

;; js-console-group : any/c -> void?
;;   Raw console group binding.
(define (js-console-group args)
  (js-log args)
  (void))

;; js-console-group-collapsed : any/c -> void?
;;   Raw console collapsed group binding.
(define (js-console-group-collapsed args)
  (js-log args)
  (void))

;; js-console-group-end : -> void?
;;   Raw console group-end binding.
(define (js-console-group-end)
  (void))

;; js-console-count : any/c -> void?
;;   Raw console count binding.
(define (js-console-count args)
  (js-log args)
  (void))

;; js-console-count-reset : any/c -> void?
;;   Raw console count-reset binding.
(define (js-console-count-reset args)
  (js-log args)
  (void))

;; js-console-time : any/c -> void?
;;   Raw console time binding.
(define (js-console-time args)
  (js-log args)
  (void))

;; js-console-time-end : any/c -> void?
;;   Raw console time-end binding.
(define (js-console-time-end args)
  (js-log args)
  (void))

;; js-console-time-log : any/c -> void?
;;   Raw console time-log binding.
(define (js-console-time-log args)
  (js-log args)
  (void))

;; js-console-time-stamp : any/c -> void?
;;   Raw console time-stamp binding.
(define (js-console-time-stamp args)
  (js-log args)
  (void))

;; js-console-trace : any/c -> void?
;;   Raw console trace binding.
(define (js-console-trace args)
  (js-log args)
  (void))

;; js-console-profile : any/c -> void?
;;   Raw console profile binding.
(define (js-console-profile args)
  (js-log args)
  (void))

;; js-console-profile-end : any/c -> void?
;;   Raw console profile-end binding.
(define (js-console-profile-end args)
  (js-log args)
  (void))

;; js-console-exception : any/c -> void?
;;   Raw console exception binding.
(define (js-console-exception args)
  (js-console-error args))
