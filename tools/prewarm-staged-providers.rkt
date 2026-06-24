#lang racket/base

;;; Prewarm Staged Providers
;;;

;; This tool builds staged provider artifacts into a WebRacket provider cache
;; before an example compile needs them. It is mainly used for expensive staged
;; providers such as regexp support and `expander/read`, where prewarming moves
;; the cold demodularization cost out of the normal compile path.
;;
;; Invoke it with the Racket toolchain and cache directory you plan to use for
;; the later compile:
;;
;;   racket tools/prewarm-staged-providers.rkt \
;;     --provider-cache-dir path/to/provider-cache \
;;     --mode read
;;
;; It prints the prewarmed mode and cache path. The selected provider artifacts
;; are written into the cache, and repeated runs reuse the existing artifacts
;; unless `--force` is supplied.


;;; Imports

;; The tool reuses the compiler driver's staged-provider entry points so the
;; prewarmed artifacts exactly match what normal WebRacket compilation expects.

(require racket/cmdline
         racket/file
         racket/format
         racket/match
         racket/path
         "../pkgs/webracket-lib/compiler/driver.rkt")


;;; Provider Prewarming

;; This section drives the staged provider builders under the requested cache
;; settings. The modes mirror the practical compile needs: regexp alone, read
;; plus its regexp dependency, or all currently known staged providers.

;; prewarm-staged-providers! : path-string? symbol? boolean? boolean? -> void?
;;   Build staged provider artifacts into provider-cache-dir.
(define (prewarm-staged-providers! provider-cache-dir mode force? verbose?)
  (define cache-dir
    (let ([p (if (path? provider-cache-dir)
                 provider-cache-dir
                 (string->path provider-cache-dir))])
      (path->complete-path p)))
  (make-directory* cache-dir)
  (parameterize ([current-provider-cache-dir cache-dir]
                 [current-provider-cache-force? force?]
                 [current-provider-cache-verbose? verbose?])
    (match mode
      ['regexp
       (regexp-provider-forms #:public-aliases? #t
                              #:owner 'prewarm)]
      ['read
       ;; The staged reader needs the staged regexp provider as part of its
       ;; dependency closure, so prewarm both artifacts together.
       (regexp-provider-forms #:public-aliases? #t
                              #:owner 'prewarm-expander-read)
       (read-provider-forms #:public-aliases? #t
                            #:owner 'prewarm-expander-read)]
      ['all
       (regexp-provider-forms #:public-aliases? #t
                              #:owner 'prewarm-expander-read)
       (read-provider-forms #:public-aliases? #t
                            #:owner 'prewarm-expander-read)]
      [_
       (error 'prewarm-staged-providers!
              "unsupported mode: ~a"
              mode)]))
  (printf "prewarmed staged providers: mode=~a cache=~a\n"
          mode
          cache-dir))


;;; Command-Line Validation

;; Command-line validation keeps mode errors friendly before the tool starts
;; building staged providers.

;; parse-mode : string? -> symbol?
;;   Parse a command-line prewarm mode.
(define (parse-mode s)
  (define mode
    (string->symbol s))
  (unless (memq mode '(regexp read all))
    (raise-user-error
     'prewarm-staged-providers
     (format "expected mode regexp, read, or all; got ~a" s)))
  mode)


;;; Command-Line Entry Point

;; The main body collects cache and mode options, then runs the selected
;; prewarm operation with optional cache refresh and verbose cache logging.

(module+ main
  (define provider-cache-dir
    (build-path (find-system-path 'temp-dir) "webracket-provider-cache"))
  (define mode 'all)
  (define force? #f)
  (define verbose? #f)
  (command-line
   #:program "prewarm-staged-providers.rkt"
   #:once-each
   [("--provider-cache-dir") dir
    "Write staged provider artifacts to <dir>."
    (set! provider-cache-dir dir)]
   [("--mode") which
    "Prewarm one of: regexp, read, all."
    (set! mode (parse-mode which))]
   [("--force")
    "Force staged provider cache refresh."
    (set! force? #t)]
   [("--verbose")
    "Print provider-cache hit/miss messages."
    (set! verbose? #t)])
  (prewarm-staged-providers! provider-cache-dir mode force? verbose?))
