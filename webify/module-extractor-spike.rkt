#lang racket/base

(provide webify-module-extractor-spike
         webify-module-extractor-spike?
         webify-module-extractor-spike-name
         webify-module-extractor-spike-directory-keys
         webify-module-extractor-spike-bundle-keys
         webify-module-extractor-spike-phase0-imports
         webify-module-extractor-spike-phase0-exports
         webify-module-extractor-spike-manifest-ready?
         webify-module-extractor-spike-notes
         webify-compile-module-extractor-spike)

(require racket/linklet
         racket/match)

(struct webify-module-extractor-spike
  (name directory-keys bundle-keys phase0-imports phase0-exports manifest-ready? notes)
  #:transparent)

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

;; webify-compile-module-extractor-spike : any/c -> webify-module-extractor-spike?
;;   Probe Racket's compiled-module linklet shape without claiming extraction support.
(define (webify-compile-module-extractor-spike module-datum)
  (define who 'webify-compile-module-extractor-spike)
  (define name (validate-source-module! who module-datum))
  (define compiled
    (parameterize ([current-namespace (make-base-namespace)])
      (compile (datum->syntax #f module-datum))))
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
  (webify-module-extractor-spike
   name
   (sort (hash-keys directory-hash) key<?)
   (sort (hash-keys bundle-hash) key<?)
   (linklet-import-variables phase0-linklet)
   (linklet-export-variables phase0-linklet)
   #f
   '("compiled source modules expose linklet objects and metadata"
     "webify still needs a linklet datum or object-to-datum adapter"
     "compiled module import metadata includes kernel/runtime plumbing")))
