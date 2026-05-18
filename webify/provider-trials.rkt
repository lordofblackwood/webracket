#lang racket/base

(provide webify-provider-trial
         webify-provider-trial?
         webify-provider-trial-module
         webify-provider-trial-exports
         webify-provider-trial-source
         webify-provider-trials
         webify-provider-trial-ref)

(require racket/list)

(struct webify-provider-trial (module exports source) #:transparent)

;; webify-provider-trials : (listof webify-provider-trial?)
;;   Small external-provider discovery-only cases that are not runtime defaults.
(define webify-provider-trials
  (list
   (webify-provider-trial
    'racket/list
    '(first)
    '(module use-list racket/base
       (require (only-in racket/list first))
       (provide answer)
       (define answer first)))
   (webify-provider-trial
    'racket/string
    '(string-prefix?)
    '(module use-string racket/base
       (require (only-in racket/string string-prefix?))
       (provide answer)
       (define answer string-prefix?)))
   (webify-provider-trial
    'racket/bool
    '(boolean=?)
    '(module use-bool racket/base
       (require (only-in racket/bool boolean=?))
       (provide answer)
       (define answer boolean=?)))))

;; webify-provider-trial-ref : symbol? -> webify-provider-trial?
;;   Look up a provider trial by module name.
(define (webify-provider-trial-ref module)
  (define trial
    (findf (lambda (trial)
             (eq? module (webify-provider-trial-module trial)))
           webify-provider-trials))
  (unless trial
    (raise-arguments-error 'webify-provider-trial-ref
                           "unknown provider trial module"
                           "module" module))
  trial)
