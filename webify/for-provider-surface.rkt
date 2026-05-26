#lang racket/base

(provide for-provider-surface-row
         for-provider-surface-row?
         for-provider-surface-row-name
         for-provider-surface-row-status
         for-provider-surface-row-provider
         staged-for-provider-exports
         original-for-provider-exports
         compare-for-provider-surface
         print-for-provider-surface)

(require racket/set
         "../pkgs/webracket-lib/compiler/webify/module-extractor.rkt")

(struct for-provider-surface-row (name status provider) #:transparent)

(define intentionally-postponed-for-exports
  '(in-directory
    in-files
    in-glob
    check-in-ephemeron-hash
    check-in-ephemeron-hash-keys
    check-in-ephemeron-hash-values
    check-in-ephemeron-hash-pairs
    check-in-weak-hash
    check-in-weak-hash-keys
    check-in-weak-hash-values
    check-in-weak-hash-pairs
    default-in-ephemeron-hash
    default-in-ephemeron-hash-keys
    default-in-ephemeron-hash-values
    default-in-ephemeron-hash-pairs
    default-in-weak-hash
    default-in-weak-hash-keys
    default-in-weak-hash-values
    default-in-weak-hash-pairs
    empty-stream
    in-stream
    make-do-stream
    make-list-stream
    prop:stream
    sequence->stream
    stream-empty?
    stream-first
    stream-ref
    stream-rest
    stream-via-prop?
    stream?
    unsafe-stream-first
    unsafe-stream-not-empty?
    unsafe-stream-rest))

;; phase0-value-export-names : (listof any/c) -> (listof symbol?)
;;   Extract phase-0 value export names from `module->exports` data.
(define (phase0-value-export-names vars)
  (for/list ([binding (in-list (cdr (assoc 0 vars)))])
    (car binding)))

;; staged-for-provider-exports : -> (listof symbol?)
;;   Read the staged provider's public phase-0 value exports.
(define (staged-for-provider-exports)
  (namespace-require 'webracket/private/for)
  (define-values (vars _stxs) (module->exports 'webracket/private/for))
  (sort (phase0-value-export-names vars) symbol<?))

;; original-for-provider-exports : -> (listof symbol?)
;;   Read the original compiled provider's public phase-0 exports.
(define (original-for-provider-exports)
  (sort (webify-module-report-phase0-exports
         (webify-module-path->report 'racket/private/for))
        symbol<?))

;; classify-for-export : symbol? set? set? -> for-provider-surface-row?
;;   Classify one original provider export against the staged surface.
(define (classify-for-export name staged-set postponed-set)
  (cond
    [(set-member? staged-set name)
     (for-provider-surface-row name 'supported 'webracket/private/for)]
    [(set-member? postponed-set name)
     (for-provider-surface-row name 'postponed 'racket/private/for)]
    [else
     (for-provider-surface-row name 'missing 'racket/private/for)]))

;; compare-for-provider-surface : -> (listof for-provider-surface-row?)
;;   Compare original `racket/private/for` exports to the staged provider.
(define (compare-for-provider-surface)
  (define original (original-for-provider-exports))
  (define staged-set (list->seteq (staged-for-provider-exports)))
  (define postponed-set (list->seteq intentionally-postponed-for-exports))
  (for/list ([name (in-list original)])
    (classify-for-export name staged-set postponed-set)))

;; print-for-provider-surface : [output-port?] -> void?
;;   Print a compact TSV surface report.
(define (print-for-provider-surface [out (current-output-port)])
  (fprintf out "name\tstatus\tprovider\n")
  (for ([row (in-list (compare-for-provider-surface))])
    (fprintf out "~a\t~a\t~a\n"
             (for-provider-surface-row-name row)
             (for-provider-surface-row-status row)
             (for-provider-surface-row-provider row))))

(module+ main
  (print-for-provider-surface))
