#lang racket/base

(provide webify-module-extractor-spike
         webify-module-extractor-spike?
         webify-module-extractor-spike-name
         webify-module-extractor-spike-directory-keys
         webify-module-extractor-spike-bundle-keys
         webify-module-extractor-spike-phase0-imports
         webify-module-extractor-spike-phase0-exports
         webify-module-extractor-spike-phase0-linklet-datum
         webify-module-extractor-spike-manifest-ready?
         webify-module-extractor-spike-notes
         webify-source-module->linklet-input
         webify-compile-module-extractor-spike)

(require racket/linklet
         racket/match
         "module-input.rkt")

(struct webify-module-extractor-spike
  (name
   directory-keys
   bundle-keys
   phase0-imports
   phase0-exports
   phase0-linklet-datum
   manifest-ready?
   notes)
  #:transparent)

;; maybe-decompile-linklet : (or/c procedure? #f)
;;   Use the newer decompiler API when the host Racket provides it.
(define maybe-decompile-linklet
  (dynamic-require 'racket/linklet 'decompile-linklet (lambda () #f)))

;; key<? : any/c any/c -> boolean?
;;   Sort mixed linklet-directory keys deterministically for spike reports.
(define (key<? a b)
  (string<? (format "~s" a) (format "~s" b)))

;; validate-source-module! : symbol? any/c -> symbol?
;;   Check the tiny source-module shape accepted by this extractor spike.
(define (validate-source-module! who module-datum)
  (match module-datum
    [`(module ,(? symbol? name) ,_language . ,_body)
     name]
    [_
     (raise-arguments-error who
                            "expected a source module datum"
                            "module" module-datum)]))

;; strip-correlated* : any/c -> any/c
;;   Recursively convert correlated objects to plain datum values.
(define (strip-correlated* v)
  (cond
    [(correlated? v) (strip-correlated* (correlated-e v))]
    [(pair? v)       (cons (strip-correlated* (car v))
                           (strip-correlated* (cdr v)))]
    [(vector? v)     (list->vector (map strip-correlated* (vector->list v)))]
    [else            v]))

;; linklet-datum? : any/c -> boolean?
;;   Check whether v has the linklet datum shape consumed by webify manifests.
(define (linklet-datum? v)
  (match v
    [`(linklet ,importss ,exports . ,body)
     (and (list? importss)
          (list? exports)
          (list? body))]
    [_ #f]))

;; webify-compile-module-extractor-spike : any/c -> webify-module-extractor-spike?
;;   Probe Racket's compiled-module linklet shape without claiming extraction support.
(define (webify-compile-module-extractor-spike module-datum)
  (define who 'webify-compile-module-extractor-spike)
  (define name (validate-source-module! who module-datum))
  (define compiled
    (parameterize ([current-namespace (make-base-namespace)])
      (parameterize ([current-compile-target-machine #f])
        (compile (datum->syntax #f module-datum)))))
  (unless (linklet-directory? compiled)
    (raise-arguments-error who
                           "compiled module did not produce a linklet directory"
                           "compiled" compiled))
  (define directory-hash (linklet-directory->hash compiled))
  (define main-bundle
    (hash-ref directory-hash
              #f
              (lambda ()
                (raise-arguments-error who
                                       "compiled module has no main linklet bundle"
                                       "directory keys" (hash-keys directory-hash)))))
  (unless (linklet-bundle? main-bundle)
    (raise-arguments-error who
                           "main directory entry is not a linklet bundle"
                           "entry" main-bundle))
  (define bundle-hash (linklet-bundle->hash main-bundle))
  (define phase0-linklet
    (hash-ref bundle-hash
              0
              (lambda ()
                (raise-arguments-error who
                                       "main bundle has no phase-0 linklet"
                                       "bundle keys" (hash-keys bundle-hash)))))
  (unless (linklet? phase0-linklet)
    (raise-arguments-error who
                           "phase-0 bundle entry is not a linklet"
                           "entry" phase0-linklet))
  (define phase0-linklet-datum
    (and maybe-decompile-linklet
         (strip-correlated* (maybe-decompile-linklet phase0-linklet))))
  (define manifest-ready? (linklet-datum? phase0-linklet-datum))
  (webify-module-extractor-spike
   name
   (sort (hash-keys directory-hash) key<?)
   (sort (hash-keys bundle-hash) key<?)
   (linklet-import-variables phase0-linklet)
   (linklet-export-variables phase0-linklet)
   phase0-linklet-datum
   manifest-ready?
   (cond
     [manifest-ready?
      '("machine-independent compilation exposes a decompilable phase-0 linklet datum"
        "compiled module import metadata still includes kernel/runtime plumbing")]
     [maybe-decompile-linklet
      '("compiled source modules expose linklet objects and metadata"
        "decompile-linklet did not produce a linklet datum for the phase-0 linklet")]
     [else
      '("compiled source modules expose linklet objects and metadata"
        "host Racket does not provide decompile-linklet"
        "use the newer ../racket checkout for the machine-independent decompile spike")])))

;; webify-source-module->linklet-input : module-datum [#:imports imports] -> webify-module-linklet-input?
;;   Extract the phase-0 linklet datum from a source module into the manifest input shape.
(define (webify-source-module->linklet-input module-datum #:imports [imports #f])
  (define who 'webify-source-module->linklet-input)
  (define report (webify-compile-module-extractor-spike module-datum))
  (unless (webify-module-extractor-spike-manifest-ready? report)
    (raise-arguments-error who
                           "source module did not produce a decompilable phase-0 linklet datum"
                           "notes" (webify-module-extractor-spike-notes report)))
  (webify-module-linklet-input
   (webify-module-extractor-spike-name report)
   (webify-module-extractor-spike-phase0-linklet-datum report)
   imports))
