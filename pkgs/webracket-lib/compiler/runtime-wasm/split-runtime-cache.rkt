#lang racket/base

(provide split-runtime-core-cache-directory
         split-runtime-boundary-cache-directory
         split-runtime-boundary-cache-version
         split-runtime-core-fingerprint
         split-runtime-core-cache-key-fingerprint
         split-runtime-core-cache-wasm-path
         split-runtime-core-cache-wat-path
         split-runtime-boundary-cache-path
         split-runtime-boundary-cache-current?
         split-runtime-request-cache-fingerprint
         make-split-runtime-core-cache-key
         make-split-runtime-core-only-cache-key)

(require (only-in "../private/structs.rkt"
                  foreign-racket-name)
         (only-in "module-forms.rkt"
                  module-write-sha1)
         (only-in file/sha1
                  bytes->hex-string
                  sha1-bytes)
         racket/match
         racket/port
         racket/fasl)

;; split-runtime-core-cache-directory : string?
;;   Stable cache directory for assembled/rendered split runtime modules.
(define split-runtime-core-cache-directory
  "split-runtime-core-v3")

;; split-runtime-boundary-cache-directory : string?
;;   Stable cache directory for split-boundary metadata.
(define split-runtime-boundary-cache-directory
  "split-runtime-boundary-v1")

;; split-runtime-boundary-cache-version : exact-integer?
;;   Bump when the serialized split-boundary metadata layout changes.
(define split-runtime-boundary-cache-version
  1)

;; split-runtime-core-fingerprint : list? -> string?
;;   Fingerprint the generated core runtime module tree for Wasm cache reuse.
(define (split-runtime-core-fingerprint core-module)
  (module-write-sha1 core-module))

;; split-runtime-core-cache-key-fingerprint : any/c -> string?
;;   Fingerprint a compiler-provided stable split runtime cache key.
(define (split-runtime-core-cache-key-fingerprint cache-key)
  (bytes->hex-string
   (sha1-bytes
    (s-exp->fasl cache-key))))

;; split-runtime-core-cache-wasm-path : path-string? string? -> path?
;;   Return the stable cache path for an assembled split core runtime module.
(define (split-runtime-core-cache-wasm-path cache-root fingerprint)
  (build-path cache-root
              split-runtime-core-cache-directory
              (format "~a.wasm" fingerprint)))

;; split-runtime-core-cache-wat-path : path-string? string? boolean? -> path?
;;   Return the stable cache path for a rendered split core runtime WAT module.
(define (split-runtime-core-cache-wat-path cache-root fingerprint pretty-wat?)
  (build-path cache-root
              split-runtime-core-cache-directory
              (format "~a.~a.wat"
                      fingerprint
                      (if pretty-wat? "pretty" "compact"))))

;; split-runtime-boundary-cache-path : path-string? any/c -> path?
;;   Return the cache path for split-runtime boundary metadata.
(define (split-runtime-boundary-cache-path cache-root core-cache-key)
  (build-path cache-root
              split-runtime-boundary-cache-directory
              (format "~a.fasl"
                      (split-runtime-core-cache-key-fingerprint
                       core-cache-key))))

;; split-runtime-boundary-cache-current? : path-string? any/c -> boolean?
;;   Check whether cached split-boundary metadata exists for this core key.
(define (split-runtime-boundary-cache-current? cache-root core-cache-key)
  (define cache-path
    (split-runtime-boundary-cache-path cache-root core-cache-key))
  (and (file-exists? cache-path)
       (with-handlers ([exn:fail? (lambda (_exn) #f)])
         (match (call-with-input-file cache-path
                  (lambda (in)
                    (fasl->s-exp (port->bytes in))))
           [(list 'split-runtime-boundary-cache
                  version
                  cached-core-cache-key
                  _payload)
            (and (= version split-runtime-boundary-cache-version)
                 (equal? cached-core-cache-key core-cache-key))]
           [_ #f]))))

;; split-runtime-request-cache-fingerprint :
;;   #:browser? boolean? #:runtime-source-fingerprint any/c
;;   #:active-ffi-foreigns list? #:active-ffi-imports-wat list?
;;   #:active-ffi-funcs-wat list? -> list?
;;   Fingerprint the stable split-runtime build request without a generated module.
(define (split-runtime-request-cache-fingerprint
         #:browser? browser?
         #:runtime-source-fingerprint runtime-source-fingerprint
         #:active-ffi-foreigns active-ffi-foreigns
         #:active-ffi-imports-wat active-ffi-imports-wat
         #:active-ffi-funcs-wat active-ffi-funcs-wat)
  `(split-runtime-request-cache
    1
    ,(if browser? 'browser 'node)
    ,runtime-source-fingerprint
    ,(sort (map foreign-racket-name active-ffi-foreigns) symbol<?)
    ,(equal-hash-code active-ffi-imports-wat)
    ,(equal-hash-code active-ffi-funcs-wat)))

;; make-split-runtime-core-cache-key : boolean? any/c -> list?
;;   Build the stable cache key for the classified split-runtime core.
(define (make-split-runtime-core-cache-key tree-shake? request-fingerprint)
  `(split-runtime-core-cache
    2
    ,(if tree-shake? 'tree-shake 'no-tree-shake)
    ,request-fingerprint))

;; make-split-runtime-core-only-cache-key : any/c -> list?
;;   Build the stable cache key for the core-helper-only split-runtime module.
(define (make-split-runtime-core-only-cache-key runtime-source-fingerprint)
  `(split-runtime-core-only-cache
    1
    ,runtime-source-fingerprint))

(module+ test
  (require rackunit)

  (define sample-runtime-source-fingerprint
    '(runtime-source 3 ("runtime-wasm.rkt" 1 2)))
  (define sample-request
    (split-runtime-request-cache-fingerprint
     #:browser? #f
     #:runtime-source-fingerprint sample-runtime-source-fingerprint
     #:active-ffi-foreigns '()
     #:active-ffi-imports-wat '()
     #:active-ffi-funcs-wat '()))
  (define sample-core-cache-key
    (make-split-runtime-core-cache-key #t sample-request))

  (check-match sample-request
    `(split-runtime-request-cache 1 node ,_ () ,_ ,_))
  (check-equal? sample-core-cache-key
                `(split-runtime-core-cache 2 tree-shake ,sample-request))
  (check-equal?
   (make-split-runtime-core-only-cache-key sample-runtime-source-fingerprint)
   `(split-runtime-core-only-cache 1 ,sample-runtime-source-fingerprint))
  (check-equal?
   (split-runtime-core-cache-wasm-path "/tmp/cache" "abc")
   (build-path "/tmp/cache" split-runtime-core-cache-directory "abc.wasm"))
  (check-equal?
   (split-runtime-core-cache-wat-path "/tmp/cache" "abc" #f)
   (build-path "/tmp/cache" split-runtime-core-cache-directory "abc.compact.wat"))
  (check-equal?
   (split-runtime-core-cache-wat-path "/tmp/cache" "abc" #t)
   (build-path "/tmp/cache" split-runtime-core-cache-directory "abc.pretty.wat"))
  (check-equal?
   (split-runtime-boundary-cache-path "/tmp/cache" sample-core-cache-key)
   (build-path "/tmp/cache"
               split-runtime-boundary-cache-directory
               (format "~a.fasl"
                       (split-runtime-core-cache-key-fingerprint
                        sample-core-cache-key))))
  (check-false
   (split-runtime-boundary-cache-current? "/tmp/cache" sample-core-cache-key)))
