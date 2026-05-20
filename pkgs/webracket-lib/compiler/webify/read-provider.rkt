#lang racket/base

;;; Cached demod support for the staged original-Racket expander/read provider.

(provide webify-read-source-root
         webify-read-provider-source
         webify-read-export-symbols
         webify-read-default-cache-root
         webify-read-cache-paths
         webify-read-source-fingerprint
         webify-read-demod-command
         webify-read-demod!
         webify-read-linklet
         webify-read-lowered-provider-cache-path
         webify-read-private-cell-symbol
         webify-read-public-alias-pairs
         webify-read-public-alias-symbols
         webify-read-public-alias-forms)

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

(define webify-read-source-root
  (build-path repo-root "racket-src/expander"))

(define webify-read-provider-source
  (build-path webify-read-source-root "read-provider-root.rkt"))

(define webify-read-export-symbols
  '(webify-expander-current-reader-guard
    webify-expander-current-readtable
    webify-expander-make-readtable
    webify-expander-make-special-comment
    webify-expander-read
    webify-expander-read-accept-box
    webify-expander-read-accept-compiled
    webify-expander-read-accept-dot
    webify-expander-read-accept-graph
    webify-expander-read-accept-infix-dot
    webify-expander-read-accept-lang
    webify-expander-read-accept-quasiquote
    webify-expander-read-accept-reader
    webify-expander-read-cdot
    webify-expander-read-curly-brace-as-paren
    webify-expander-read-curly-brace-with-tag
    webify-expander-read-decimal-as-inexact
    webify-expander-read-language
    webify-expander-read-single-flonum
    webify-expander-read-square-bracket-as-paren
    webify-expander-read-square-bracket-with-tag
    webify-expander-read-syntax-accept-graph
    webify-expander-readtable-mapping
    webify-expander-readtable?
    webify-expander-special-comment-value
    webify-expander-special-comment?
    webify-expander-string->number))

(define webify-read-public-alias-pairs
  '((current-reader-guard . webify-expander-current-reader-guard)
    (current-readtable . webify-expander-current-readtable)
    (make-readtable . webify-expander-make-readtable)
    (make-special-comment . webify-expander-make-special-comment)
    (read . webify-expander-read)
    (read-accept-box . webify-expander-read-accept-box)
    (read-accept-compiled . webify-expander-read-accept-compiled)
    (read-accept-dot . webify-expander-read-accept-dot)
    (read-accept-graph . webify-expander-read-accept-graph)
    (read-accept-infix-dot . webify-expander-read-accept-infix-dot)
    (read-accept-lang . webify-expander-read-accept-lang)
    (read-accept-quasiquote . webify-expander-read-accept-quasiquote)
    (read-accept-reader . webify-expander-read-accept-reader)
    (read-cdot . webify-expander-read-cdot)
    (read-curly-brace-as-paren . webify-expander-read-curly-brace-as-paren)
    (read-curly-brace-with-tag . webify-expander-read-curly-brace-with-tag)
    (read-decimal-as-inexact . webify-expander-read-decimal-as-inexact)
    (read-language . webify-expander-read-language)
    (read-single-flonum . webify-expander-read-single-flonum)
    (read-square-bracket-as-paren . webify-expander-read-square-bracket-as-paren)
    (read-square-bracket-with-tag . webify-expander-read-square-bracket-with-tag)
    (read-syntax-accept-graph . webify-expander-read-syntax-accept-graph)
    (readtable-mapping . webify-expander-readtable-mapping)
    (readtable? . webify-expander-readtable?)
    (special-comment-value . webify-expander-special-comment-value)
    (special-comment? . webify-expander-special-comment?)
    (string->number . webify-expander-string->number)))

(define webify-read-public-alias-symbols
  (map car webify-read-public-alias-pairs))

(define webify-read-default-cache-root
  (build-path (find-system-path 'temp-dir) "webracket-read-provider-cache"))

(define read-cache-format-version 1)

;; webify-read-lowered-provider-cache-path : [path-string?] -> path?
;;   Return the cache file for lowered provider forms.
(define (webify-read-lowered-provider-cache-path
         [cache-root webify-read-default-cache-root])
  (define root (if (path? cache-root) cache-root (string->path cache-root)))
  (build-path root "expander-read-provider.rktd"))

;; webify-read-cache-paths : [path-string?] -> (values path? path? path?)
;;   Return the flattened linklet, dependency file, and bootstrap cache paths.
(define (webify-read-cache-paths [cache-root webify-read-default-cache-root])
  (define root (if (path? cache-root) cache-root (string->path cache-root)))
  (values (build-path root "expander-read.rktl")
          (build-path root "expander-read-dep.rktd")
          (build-path root "bootstrap-cache")))

;; webify-read-source-paths : -> (listof path?)
;;   Return source files that invalidate the expander/read provider cache.
(define (webify-read-source-paths)
  (sort
   (map simplify-path
        (append
         (list webify-read-provider-source)
         (find-files file-exists? (build-path webify-read-source-root "read"))
         (find-files file-exists? (build-path webify-read-source-root "common"))
         (find-files file-exists? (build-path webify-read-source-root "host"))))
   string<?
   #:key path->string))

;; webify-read-source-fingerprint : -> any/c
;;   Fingerprint the staged expander/read source tree using path, size, and mtime.
(define (webify-read-source-fingerprint)
  `(expander-read-cache-format
    ,read-cache-format-version
    ,@(for/list ([path (in-list (webify-read-source-paths))])
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

;; webify-read-demod-command : [path-string?] -> (listof string?)
;;   Build the Racket CS demodularizer command for the staged expander/read root.
(define (webify-read-demod-command [cache-root webify-read-default-cache-root])
  (define-values (out-rktl dep-rktd bootstrap-cache)
    (webify-read-cache-paths cache-root))
  (list (path->string racket-bin)
        (path->string bootstrap-run-rkt)
        "-t" (path->string webify-read-provider-source)
        "-c" (path->string bootstrap-cache)
        "-k" (path->string racket-root)
        "-s" "-x"
        "--depends" (path->string dep-rktd)
        "--no-global"
        "-o" (path->string out-rktl)))

;; webify-read-demod! : [#:cache-root path-string?] [#:force? boolean?]
;;                   -> (values exact-integer? string? path?)
;;   Generate or reuse the flattened expander/read linklet.
(define (webify-read-demod! #:cache-root [cache-root webify-read-default-cache-root]
                            #:force? [force? #f]
                            #:verbose? [verbose? #f])
  (define-values (out-rktl _dep-rktd _bootstrap-cache)
    (webify-read-cache-paths cache-root))
  (define fingerprint-path
    (path-add-extension out-rktl #".fingerprint.rktd"))
  (define fingerprint (webify-read-source-fingerprint))
  (make-directory* cache-root)
  (cond
    [(and (not force?)
          (file-exists? out-rktl)
          (cached-fingerprint-valid? fingerprint-path fingerprint))
     (when verbose?
       (fprintf (current-error-port)
                "provider-cache: expander/read demod hit: ~a\n"
                out-rktl))
     (values 0 "using cached expander/read demod linklet\n" out-rktl)]
    [else
     (when verbose?
       (fprintf (current-error-port)
                "provider-cache: expander/read demod miss; regenerating: ~a\n"
                out-rktl))
     (define stdout (open-output-string))
     (define stderr (open-output-string))
     (define command (webify-read-demod-command cache-root))
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

;; webify-read-linklet : [#:cache-root path-string?] [#:force? boolean?] -> any/c
;;   Return the cached flattened expander/read linklet, generating it if needed.
(define (webify-read-linklet #:cache-root [cache-root webify-read-default-cache-root]
                             #:force? [force? #f]
                             #:verbose? [verbose? #f])
  (define-values (status output out-rktl)
    (webify-read-demod! #:cache-root cache-root
                        #:force? force?
                        #:verbose? verbose?))
  (unless (zero? status)
    (error 'webify-read-linklet
           "expander/read demod failed with status ~a\n~a"
           status
           output))
  (call-with-input-file out-rktl read))

;; webify-read-private-cell-symbol : symbol? -> symbol?
;;   Private top-level cell used to publish provider exports safely.
(define (webify-read-private-cell-symbol export)
  (unless (memq export webify-read-export-symbols)
    (raise-argument-error 'webify-read-private-cell-symbol
                          "expander/read export symbol"
                          export))
  (string->symbol (format "webify-expander-read-export-cell$~a" export)))

;; webify-read-public-alias-forms : (hash/c symbol? symbol?) -> (listof datum?)
;;   Bind public names to generated expander/read provider cells.
(define (webify-read-public-alias-forms export-cells)
  (define webify-owned-forms
    (for/list ([export (in-list webify-read-export-symbols)])
      (define cell (hash-ref export-cells export))
      `(begin
         (define ,(webify-read-private-cell-symbol export)
           ,cell)
         (define ,export
           (module-variable-ref ,(webify-read-private-cell-symbol export))))))
  (append
   webify-owned-forms
   ;; Public aliases are intentionally separate aliases over staged provider
   ;; cells. The compiler is parameterized to let these bindings shadow the
   ;; temporary primitive/runtime stubs, otherwise alpha-renaming rejects the
   ;; primitive redefinitions.
   (for/list ([alias (in-list webify-read-public-alias-pairs)])
     (define public-name (car alias))
     (define export-name (cdr alias))
     `(define ,public-name
        (module-variable-ref
         ,(webify-read-private-cell-symbol export-name))))))
