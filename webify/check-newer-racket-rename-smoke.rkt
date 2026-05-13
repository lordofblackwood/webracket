#lang racket/base

(require rackunit
         racket/file
         racket/list
         racket/runtime-path)

;; This smoke is intended for the newer ../racket checkout, where
;; current-compile-target-machine #f exposes a decompilable phase-0 linklet.
;; Keep its compilation cache out of the normal 8.12 `webify/compiled` tree.

(define compiled-root
  (build-path (find-system-path 'temp-dir)
              (format "webracket-newer-racket-compiled-~a" (version))))
(make-directory* compiled-root)

(current-compiled-file-roots (list compiled-root))

(define-runtime-path here ".")
(define module-extractor-module
  (build-path here "module-extractor-spike.rkt"))
(define module-input-module
  (build-path here "module-input.rkt"))

(define module-extractor-spike
  (dynamic-require module-extractor-module #f))
(define module-input
  (dynamic-require module-input-module #f))

(define webify-compile-module-extractor-spike
  (dynamic-require module-extractor-module
                   'webify-compile-module-extractor-spike))
(define webify-module-extractor-spike-manifest-ready?
  (dynamic-require module-extractor-module
                   'webify-module-extractor-spike-manifest-ready?))
(define webify-module-extractor-spike-notes
  (dynamic-require module-extractor-module
                   'webify-module-extractor-spike-notes))
(define webify-source-module->resolved-linklet-input
  (dynamic-require module-extractor-module
                   'webify-source-module->resolved-linklet-input))
(define webify-module-path->extractor-spike
  (dynamic-require module-extractor-module
                   'webify-module-path->extractor-spike))
(define webify-module-path->module-export-metadata
  (dynamic-require module-extractor-module
                   'webify-module-path->module-export-metadata))
(define webify-module-extractor-spikes->required-provider-closure
  (dynamic-require module-extractor-module
                   'webify-module-extractor-spikes->required-provider-closure))
(define webify-module-extractor-spike-name
  (dynamic-require module-extractor-module
                   'webify-module-extractor-spike-name))
(define webify-module-extractor-spike->resolved-linklet-input/providers
  (dynamic-require module-extractor-module
                   'webify-module-extractor-spike->resolved-linklet-input/providers))
(define webify-module-extractor-spikes->resolved-linklet-inputs
  (dynamic-require module-extractor-module
                   'webify-module-extractor-spikes->resolved-linklet-inputs))
(define webify-module-linklet-input-imports
  (dynamic-require module-input-module
                   'webify-module-linklet-input-imports))

(define module-datum
  '(module a racket/base
     (require (rename-in racket/list [first head]))
     (provide y)
     (define y (head (list 10)))))

(define report (webify-compile-module-extractor-spike module-datum))

(unless (webify-module-extractor-spike-manifest-ready? report)
  (error 'check-newer-racket-rename-smoke
         "source module did not produce a decompilable phase-0 linklet datum; notes: ~s"
         (webify-module-extractor-spike-notes report)))

(define input
  (webify-source-module->resolved-linklet-input
   module-datum
   #:dependency-exports '((racket/list (first)))
   #:module-protocol-dependency 'module-protocol))

(check-equal? (drop (webify-module-linklet-input-imports input) 2)
              '((first racket/list first)))

(define private-list-report
  (webify-module-path->extractor-spike 'racket/private/list))
(define private-list-metadata
  (webify-module-path->module-export-metadata 'racket/private/list))
(define reverse-row
  (for*/first ([row (in-list (cadr private-list-metadata))]
               #:when (equal? (car row) 0)
               [entry (in-list (cdr row))]
               #:when (and (pair? entry) (eq? (car entry) 'reverse)))
    entry))
(check-match reverse-row
             `(reverse ((,_mpi 0 alt-reverse 0)) reverse))

(define private-list-closure
  (webify-module-extractor-spikes->required-provider-closure
   (list private-list-report)))
(define private-list-closure-names
  (map webify-module-extractor-spike-name private-list-closure))
(check-not-false (member 'racket/private/pico private-list-closure-names))

(define private-list-input
  (webify-module-extractor-spike->resolved-linklet-input/providers
   private-list-report
   (filter (lambda (provider-report)
             (not (eq? (webify-module-extractor-spike-name provider-report)
                       'racket/private/list)))
           private-list-closure)
   #:module-protocol-dependency 'module-protocol))
(check-not-false
 (member '(1/reverse racket/private/pico reverse)
         (webify-module-linklet-input-imports private-list-input)))

(define string-report
  (webify-compile-module-extractor-spike
   '(module string-smoke racket/base
      (require racket/string)
      (provide y)
      (define y (string-join (list "a" "b") ",")))))
(define string-closure
  (webify-module-extractor-spikes->required-provider-closure
   (list string-report)))
(define string-frontier
  (with-handlers ([exn:fail? exn-message])
    (webify-module-extractor-spikes->resolved-linklet-inputs
     string-closure
     #:module-protocol-dependency 'module-protocol)
    'resolved))
(check-true (string? string-frontier))
(check-not-false (regexp-match? #rx"string->number" string-frontier))
(check-false (regexp-match? #rx"string-join" string-frontier))

(displayln "newer-racket-rename-smoke: ok")
