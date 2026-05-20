#lang racket/base

(provide webify-module-phase-policy
         webify-module-phase-policy?
         webify-module-phase-policy-supported-phases
         webify-module-phase-policy-transformer-policy
         webify-module-phase-policy-set-transformer-policy
         webify-module-phase-policy-get-syntax-literal-policy
         webify-default-module-phase-policy)

(struct webify-module-phase-policy
  (supported-phases
   transformer-policy
   set-transformer-policy
   get-syntax-literal-policy)
  #:transparent)

;; webify-default-module-phase-policy : webify-module-phase-policy?
;;   Current bridge policy: execute phase 0 only and approximate syntax literals.
(define webify-default-module-phase-policy
  (webify-module-phase-policy
   '(0)
   'metadata-visible-not-executed
   'runtime-no-op
   'runtime-placeholder-syntax-and-source-location-data))
