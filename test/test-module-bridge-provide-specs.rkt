#lang racket/base

(require racket/file
         racket/list
         racket/path
         racket/string
         racket/system
         "../pkgs/webracket-lib/compiler/driver.rkt")

;; fresh-temp-directory : string? -> path?
;;   Create a temporary directory under /tmp for generated module sources.
(define (fresh-temp-directory name)
  (define path
    (build-path "/tmp"
                (format "~a-~a-~a"
                        name
                        (current-process-milliseconds)
                        (random 1000000))))
  (make-directory* path)
  path)

;; write-file! : path? string? -> void?
;;   Write one temporary source file.
(define (write-file! path content)
  (make-directory* (or (path-only path) (current-directory)))
  (call-with-output-file path
    (lambda (out)
      (display content out))
    #:exists 'truncate/replace))

;; find-repo-root : path? -> path?
;;   Find the checkout root that contains `webracket.rkt`.
(define (find-repo-root start)
  (let loop ([dir (simplify-path start)])
    (cond
      [(file-exists? (build-path dir "webracket.rkt"))
       dir]
      [else
       (define parent (path-only dir))
       (unless parent
         (error 'test-module-bridge-provide-specs
                "could not find repository root containing webracket.rkt"))
       (loop (path->complete-path parent))])))

;; repo-racket-executable : path? -> path?
;;   Prefer the adjacent Racket checkout with the bridge's expected toolchain.
(define (repo-racket-executable repo-root)
  (define candidate
    (build-path repo-root ".." "racket" "racket" "bin" "racket"))
  (cond
    [(file-exists? candidate) candidate]
    [else
     (or (find-executable-path "racket")
         (error 'test-module-bridge-provide-specs
                "could not find a racket executable"))]))

;; missing-required-paths : (listof path?) (listof path?) -> (listof path?)
;;   Return expected paths that were not discovered by the local require scanner.
(define (missing-required-paths expected actual)
  (define actual* (map simplify-path actual))
  (filter-not (lambda (path)
                (member (simplify-path path) actual*))
              expected))

;; provider-symbols-for-path : path? path? -> (listof symbol?)
;;   Return the provider symbols that diagnostics may use for a local source path.
(define (provider-symbols-for-path source-dir path)
  (define relative
    (path->string (find-relative-path source-dir path)))
  (define without-extension
    (if (string-suffix? relative ".rkt")
        (substring relative 0 (- (string-length relative) 4))
        relative))
  (remove-duplicates
   (list (string->symbol without-extension)
         (string->symbol relative))
   eq?))

;; assert-local-provide-spec-case : symbol? path-string? path? (listof path?) -> void?
;;   Build the local module graph and check that local provider modules stay local.
(define (assert-local-provide-spec-case label source-path source-dir expected-paths)
  (printf "case-start ~a\n" label)
  (flush-output)
  (define-values (root reports local-source-paths)
    (webracket/base-file->local-module-reports source-path))
  (define missing
    (missing-required-paths expected-paths local-source-paths))
  (unless (null? missing)
    (raise-arguments-error label
                           "local require scanner missed expected source paths"
                           "missing paths" missing
                           "local source paths" local-source-paths))
  (define external (webracket/base-external-provider-names reports))
  (define forbidden-providers
    (append* (map (lambda (path)
                    (provider-symbols-for-path source-dir path))
                  expected-paths)))
  (define leaked
    (filter (lambda (name) (member name external)) forbidden-providers))
  (unless (null? leaked)
    (raise-arguments-error label
                           "local module escaped into external providers"
                           "leaked providers" leaked
                           "external providers" external))
  (void
   (webracket/base-reports->module-graph
    root
    reports
    #:local-source-paths local-source-paths))
  (printf "case-ok ~a\n" label)
  (flush-output))

;; assert-compiled-run : path? path? path? path? string? -> void?
;;   Compile and run one module-bridge program through the public CLI.
(define (assert-compiled-run repo-root racket-exe source-path dest-dir provider-cache-dir expected-marker)
  (printf "compile-run-start ~a\n" (file-name-from-path source-path))
  (flush-output)
  (make-directory* dest-dir)
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define status
    (parameterize ([current-directory repo-root]
                   [current-output-port stdout]
                   [current-error-port stderr])
      (system*/exit-code
       racket-exe
       "-y"
       (path->string (build-path repo-root "webracket.rkt"))
       "--node"
       "--run"
       "--webracket-module-bridge"
       "--no-stdlib"
       "--dest" (path->string dest-dir)
       "--provider-cache-dir" (path->string provider-cache-dir)
       (path->string source-path))))
  (define output
    (string-append (get-output-string stdout)
                   (get-output-string stderr)))
  (unless (zero? status)
    (raise-arguments-error 'test-module-bridge-provide-specs
                           "provide-spec compile/run failed"
                           "source" source-path
                           "status" status
                           "output" output))
  (unless (string-contains? output expected-marker)
    (raise-arguments-error 'test-module-bridge-provide-specs
                           "provide-spec compile/run missed expected marker"
                           "source" source-path
                           "expected marker" expected-marker
                           "output" output))
  (printf "compile-run-ok ~a\n" (file-name-from-path source-path))
  (flush-output))

;; run-provide-spec-smoke : -> void?
;;   Cover Racket's base provide-spec forms in local module-bridge providers.
(define (run-provide-spec-smoke)
  (define repo-root
    (find-repo-root (or (current-load-relative-directory)
                        (current-directory))))
  (define racket-exe (repo-racket-executable repo-root))
  (define base (fresh-temp-directory "webracket-module-bridge-provide-specs"))
  (define src-dir (build-path base "src"))
  (define cache-dir (build-path base "provider-cache"))
  (define out-dir (build-path base "out"))
  (define id-path (build-path src-dir "provide-id.rkt"))
  (define all-defined-path (build-path src-dir "provide-all-defined.rkt"))
  (define all-from-source-path (build-path src-dir "provide-all-from-source.rkt"))
  (define all-from-path (build-path src-dir "provide-all-from.rkt"))
  (define rename-path (build-path src-dir "provide-rename.rkt"))
  (define except-path (build-path src-dir "provide-except.rkt"))
  (define prefix-path (build-path src-dir "provide-prefix.rkt"))
  (define struct-path (build-path src-dir "provide-struct.rkt"))
  (define combine-path (build-path src-dir "provide-combine.rkt"))
  (define protect-path (build-path src-dir "provide-protect.rkt"))
  (define meta0-path (build-path src-dir "provide-meta0.rkt"))
  (define space-path (build-path src-dir "provide-space-default.rkt"))
  (define custom-space-path (build-path src-dir "provide-space-custom.rkt"))
  (define template-source-path (build-path src-dir "provide-template-source.rkt"))
  (define label-source-path (build-path src-dir "provide-label-source.rkt"))
  (define phase-wrapper-path (build-path src-dir "provide-phase-wrappers.rkt"))
  (define main-path (build-path src-dir "main-provide-specs.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-file! id-path
                   "#lang webracket/base\n(provide id-value)\n(define id-value 11)\n")
      (write-file! all-defined-path
                   "#lang webracket/base\n(provide (all-defined-out))\n(define all-defined-value 21)\n(define all-defined-extra 22)\n")
      (write-file! all-from-source-path
                   "#lang webracket/base\n(provide (rename-out [from-source all-from-export]) all-from-extra)\n(define from-source 31)\n(define all-from-extra 32)\n")
      (write-file! all-from-path
                   "#lang webracket/base\n(require (rename-in \"provide-all-from-source.rkt\"\n                            [all-from-export all-from-local]\n                            [all-from-extra all-from-extra-local]))\n(provide (all-from-out \"provide-all-from-source.rkt\"))\n")
      (write-file! rename-path
                   "#lang webracket/base\n(provide (rename-out [rename-internal renamed-value]))\n(define rename-internal 41)\n")
      (write-file! except-path
                   "#lang webracket/base\n(provide (except-out (all-defined-out) except-hidden))\n(define except-keep 51)\n(define except-hidden 999)\n")
      (write-file! prefix-path
                   "#lang webracket/base\n(provide (prefix-out pref: (combine-out prefix-a (rename-out [prefix-b prefix-renamed]))))\n(define prefix-a 61)\n(define prefix-b 62)\n")
      (write-file! struct-path
                   "#lang webracket/base\n(provide (struct-out posn))\n(struct posn (x y))\n")
      (write-file! combine-path
                   "#lang webracket/base\n(provide (combine-out combine-a (rename-out [combine-b combine-renamed])))\n(define combine-a 81)\n(define combine-b 82)\n")
      (write-file! protect-path
                   "#lang webracket/base\n(provide (protect-out protected-value))\n(define protected-value 91)\n")
      (write-file! meta0-path
                   "#lang webracket/base\n(provide (for-meta 0 meta0-value))\n(define meta0-value 101)\n")
      (write-file! space-path
                   "#lang webracket/base\n(provide (for-space #f space-default-value))\n(define space-default-value 102)\n")
      (write-file! custom-space-path
                   "#lang webracket/base\n(require (for-syntax racket/base))\n(begin-for-syntax\n  (define custom-space-introduce\n    (make-interned-syntax-introducer 'custom)))\n(define-syntax (define-custom-space stx)\n  (syntax-case stx ()\n    [(_ id rhs)\n     (with-syntax ([id* (custom-space-introduce #'id 'add)])\n       #'(define id* rhs))]))\n(define custom-space-runtime-value 105)\n(define-custom-space custom-space-value 106)\n(provide custom-space-runtime-value\n         (for-space custom custom-space-value))\n")
      (write-file! template-source-path
                   "#lang webracket/base\n(provide template-value)\n(define template-value 201)\n")
      (write-file! label-source-path
                   "#lang webracket/base\n(provide label-value)\n(define label-value 202)\n")
      (write-file! phase-wrapper-path
                   "#lang webracket/base\n(require (for-template \"provide-template-source.rkt\")\n         (for-label \"provide-label-source.rkt\"))\n(begin-for-syntax\n  (define syntax-number 103)\n  (define meta-one-number 107))\n(define phase-wrapper-runtime-value 104)\n(provide phase-wrapper-runtime-value\n         (for-syntax syntax-number)\n         (for-meta 1 meta-one-number)\n         (for-template template-value)\n         (for-label label-value))\n")
      (write-file! main-path
                   "#lang webracket/base\n(require \"provide-id.rkt\"\n         \"provide-all-defined.rkt\"\n         \"provide-all-from.rkt\"\n         \"provide-rename.rkt\"\n         \"provide-except.rkt\"\n         \"provide-prefix.rkt\"\n         \"provide-struct.rkt\"\n         \"provide-combine.rkt\"\n         \"provide-protect.rkt\"\n         \"provide-meta0.rkt\"\n         \"provide-space-default.rkt\"\n         \"provide-space-custom.rkt\"\n         \"provide-phase-wrappers.rkt\"\n         (for-syntax \"provide-phase-wrappers.rkt\")\n         (for-template \"provide-phase-wrappers.rkt\")\n         (for-label \"provide-phase-wrappers.rkt\"))\n(define-syntax (syntax-number-value stx)\n  (datum->syntax stx syntax-number))\n(define-syntax (meta-one-number-value stx)\n  (datum->syntax stx meta-one-number))\n(define p (posn 71 72))\n(define syntax-runtime-value (syntax-number-value))\n(define meta-one-runtime-value (meta-one-number-value))\n(define aggregate-result\n  (+ id-value\n     all-defined-value\n     all-defined-extra\n     all-from-local\n     all-from-extra-local\n     renamed-value\n     except-keep\n     pref:prefix-a\n     pref:prefix-renamed\n     (if (posn? p) (posn-x p) 0)\n     (posn-y p)\n     combine-a\n     combine-renamed\n     protected-value\n     meta0-value\n     space-default-value\n     custom-space-runtime-value\n     syntax-runtime-value\n     meta-one-runtime-value))\n(define binding-values-ok?\n  (and (= id-value 11)\n       (= all-defined-value 21)\n       (= all-defined-extra 22)\n       (= all-from-local 31)\n       (= all-from-extra-local 32)\n       (= renamed-value 41)\n       (= except-keep 51)\n       (= pref:prefix-a 61)\n       (= pref:prefix-renamed 62)\n       (posn? p)\n       (= (posn-x p) 71)\n       (= (posn-y p) 72)\n       (= combine-a 81)\n       (= combine-renamed 82)\n       (= protected-value 91)\n       (= meta0-value 101)\n       (= space-default-value 102)\n       (= custom-space-runtime-value 105)\n       (= syntax-runtime-value 103)\n       (= meta-one-runtime-value 107)\n       (= phase-wrapper-runtime-value 104)\n       (= aggregate-result 1247)))\n(if binding-values-ok?\n    (js-log \"provide-spec-bindings-ok\")\n    (js-log \"provide-spec-bindings-bad\"))\naggregate-result\n")
      (parameterize ([current-provider-cache-dir cache-dir]
                     [current-provider-cache-force? #f]
                     [current-provider-cache-verbose? #f])
        (assert-local-provide-spec-case
         'aggregate-provide-spec-bridge
         main-path
         src-dir
         (list id-path
               all-defined-path
               all-from-source-path
               all-from-path
               rename-path
               except-path
               prefix-path
               struct-path
               combine-path
               protect-path
               meta0-path
               space-path
               custom-space-path
               phase-wrapper-path))
        (assert-compiled-run repo-root
                             racket-exe
                             main-path
                             out-dir
                             cache-dir
                             "provide-spec-bindings-ok")))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files base)))))

(module+ main
  (run-provide-spec-smoke))
