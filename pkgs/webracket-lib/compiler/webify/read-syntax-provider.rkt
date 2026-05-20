#lang racket/base

;;; Probe support for the separate staged original-Racket `read-syntax` track.

(provide webify-read-syntax-provider-source
         webify-read-syntax-export-symbols
         webify-read-syntax-default-cache-root
         webify-read-syntax-cache-paths
         webify-read-syntax-source-fingerprint
         webify-read-syntax-demod-command
         webify-read-syntax-demod!
         webify-read-syntax-linklet
         webify-read-syntax-lowered-provider-cache-path
         webify-read-syntax-private-cell-symbol
         webify-read-syntax-alias-forms)

(require racket/file
         racket/list
         racket/path
         racket/runtime-path
         racket/system)

(define-runtime-path repo-root "../../../..")
(define simplified-repo-root (simplify-path repo-root))

(define racket-root
  (simplify-path (build-path repo-root "../racket/racket")))

(define racket-bin
  (build-path racket-root "bin/racket"))

(define bootstrap-run-rkt
  (build-path racket-root "src/expander/bootstrap-run.rkt"))

(define webify-read-syntax-provider-source
  (build-path repo-root "racket-src/expander/read-syntax-provider-root.rkt"))

(define webify-read-syntax-export-symbols
  '(webify-expander-read-syntax
    webify-expander-read-syntax/recursive
    webify-expander-syntax->datum
    webify-expander-syntax-source
    webify-expander-syntax-line
    webify-expander-syntax-column
    webify-expander-syntax-position))

(define webify-read-syntax-default-cache-root
  (build-path (find-system-path 'temp-dir) "webracket-read-syntax-provider-cache"))

(define read-syntax-cache-format-version 2)

;; webify-read-syntax-cache-paths : [path-string?] -> (values path? path? path?)
;;   Return the flattened linklet, dependency file, and bootstrap cache paths.
(define (webify-read-syntax-cache-paths
         [cache-root webify-read-syntax-default-cache-root])
  (define root (if (path? cache-root) cache-root (string->path cache-root)))
  (values (build-path root "read-syntax.rktl")
          (build-path root "read-syntax-dep.rktd")
          (build-path root "read-syntax-bootstrap-cache")))

;; webify-read-syntax-lowered-provider-cache-path : [path-string?] -> path?
;;   Return the cache file for lowered read-syntax provider forms.
(define (webify-read-syntax-lowered-provider-cache-path
         [cache-root webify-read-syntax-default-cache-root])
  (define root (if (path? cache-root) cache-root (string->path cache-root)))
  (build-path root "expander-read-syntax-provider.rktd"))

;; webify-read-syntax-source-paths : -> (listof path?)
;;   Return source files that invalidate the private read-syntax provider cache.
(define (webify-read-syntax-source-paths)
  (sort
   (map simplify-path
        (append
         (list webify-read-syntax-provider-source)
         (find-files file-exists? (build-path repo-root "racket-src/expander/read"))
         (find-files file-exists? (build-path repo-root "racket-src/expander/syntax"))
         (find-files file-exists? (build-path repo-root "racket-src/expander/common"))
         (find-files file-exists? (build-path repo-root "racket-src/expander/compile"))
         (find-files file-exists? (build-path repo-root "racket-src/expander/eval"))
         (find-files file-exists? (build-path repo-root "racket-src/expander/namespace"))
         (find-files file-exists? (build-path repo-root "racket-src/expander/host"))))
   string<?
   #:key path->string))

;; webify-read-syntax-source-fingerprint : -> any/c
;;   Fingerprint the staged read-syntax source tree using path, size, and mtime.
(define (webify-read-syntax-source-fingerprint)
  `(expander-read-syntax-cache-format
    ,read-syntax-cache-format-version
    ,@(for/list ([path (in-list (webify-read-syntax-source-paths))])
        (list (path->string (find-relative-path simplified-repo-root path))
              (file-size path)
              (file-or-directory-modify-seconds path)))))

;; cached-fingerprint-valid? : path? any/c -> boolean?
;;   Check whether a cache fingerprint file matches the current source.
(define (cached-fingerprint-valid? path fingerprint)
  (and (file-exists? path)
       (with-handlers ([exn:fail? (lambda (_exn) #f)])
         (equal? (call-with-input-file path read) fingerprint))))

;; write-cache-fingerprint! : path? any/c -> void?
;;   Write the source fingerprint next to a generated artifact.
(define (write-cache-fingerprint! path fingerprint)
  (call-with-output-file path
    (lambda (out) (write fingerprint out) (newline out))
    #:exists 'truncate/replace))

;; webify-read-syntax-demod-command : path-string? -> (listof string?)
;;   Build the demodularizer command for the isolated read-syntax probe.
(define (webify-read-syntax-demod-command
         [cache-root webify-read-syntax-default-cache-root])
  (define-values (out-rktl dep-rktd bootstrap-cache)
    (webify-read-syntax-cache-paths cache-root))
  (list (path->string racket-bin)
        (path->string bootstrap-run-rkt)
        "-t" (path->string webify-read-syntax-provider-source)
        "-c" (path->string bootstrap-cache)
        "-k" (path->string racket-root)
        "-s" "-x"
        "--depends" (path->string dep-rktd)
        "--no-global"
        ;; The upstream reader caches the default input-port handler in this
        ;; global. Keep the allowance private to the provider extraction.
        "++global-ok" "default-read-handler"
        "-o" (path->string out-rktl)))

;; webify-read-syntax-demod! : [#:cache-root path-string?] [#:force? boolean?] [#:verbose? boolean?]
;;                         -> (values exact-integer? string? path?)
;;   Generate or reuse the flattened read-syntax linklet.
(define (webify-read-syntax-demod! #:cache-root [cache-root webify-read-syntax-default-cache-root]
                                   #:force? [force? #f]
                                   #:verbose? [verbose? #f])
  (define-values (out-rktl _dep-rktd _bootstrap-cache)
    (webify-read-syntax-cache-paths cache-root))
  (define fingerprint-path
    (path-add-extension out-rktl #".fingerprint.rktd"))
  (define fingerprint (webify-read-syntax-source-fingerprint))
  (make-directory* cache-root)
  (cond
    [(and (not force?)
          (file-exists? out-rktl)
          (cached-fingerprint-valid? fingerprint-path fingerprint))
     (when verbose?
       (fprintf (current-error-port)
                "provider-cache: expander/read-syntax demod hit: ~a\n"
                out-rktl))
     (values 0 "using cached expander/read-syntax demod linklet\n" out-rktl)]
    [else
     (when verbose?
       (fprintf (current-error-port)
                "provider-cache: expander/read-syntax demod miss; regenerating: ~a\n"
                out-rktl))
     (define stdout (open-output-string))
     (define stderr (open-output-string))
     (define command (webify-read-syntax-demod-command cache-root))
     (define status
       (parameterize ([current-output-port stdout]
                      [current-error-port stderr])
         (apply system*/exit-code command)))
     (when (zero? status)
       (write-cache-fingerprint! fingerprint-path fingerprint))
     (values status
             (string-append (get-output-string stdout)
                            (get-output-string stderr))
             out-rktl)]))

;; webify-read-syntax-linklet : [#:cache-root path-string?] [#:force? boolean?] [#:verbose? boolean?] -> any/c
;;   Return the cached flattened read-syntax linklet, generating it if needed.
(define (webify-read-syntax-linklet #:cache-root [cache-root webify-read-syntax-default-cache-root]
                                    #:force? [force? #f]
                                    #:verbose? [verbose? #f])
  (define-values (status output out-rktl)
    (webify-read-syntax-demod! #:cache-root cache-root
                               #:force? force?
                               #:verbose? verbose?))
  (unless (zero? status)
    (error 'webify-read-syntax-linklet
           "expander/read-syntax demod failed with status ~a\n~a"
           status
           output))
  (call-with-input-file out-rktl read))

;; webify-read-syntax-private-cell-symbol : symbol? -> symbol?
;;   Private top-level cell used to publish read-syntax provider exports safely.
(define (webify-read-syntax-private-cell-symbol export)
  (unless (memq export webify-read-syntax-export-symbols)
    (raise-argument-error 'webify-read-syntax-private-cell-symbol
                          "expander/read-syntax export symbol"
                          export))
  (string->symbol (format "webify-expander-read-syntax-export-cell$~a" export)))

;; webify-read-syntax-alias-forms : (hash/c symbol? symbol?) -> (listof datum?)
;;   Bind private Webify-owned read-syntax names to generated provider cells.
(define (webify-read-syntax-alias-forms export-cells)
  (for/list ([export (in-list webify-read-syntax-export-symbols)])
    (define cell (hash-ref export-cells export))
    `(begin
       (define ,(webify-read-syntax-private-cell-symbol export)
         ,cell)
       (define ,export
         (module-variable-ref
          ,(webify-read-syntax-private-cell-symbol export))))))
