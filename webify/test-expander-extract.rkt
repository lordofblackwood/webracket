#lang racket/base

(require racket/file
         racket/list
         racket/path
         racket/runtime-path
         racket/system
         rackunit
         "../pkgs/webracket-lib/compiler/webify/lower.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-diagnostics.rkt"
         "test-module-support.rkt")

(define-runtime-path repo-root "..")

(define racket-root (simplify-path (build-path repo-root "../racket/racket")))
(define racket-bin  (build-path racket-root "bin/racket"))
(define bootstrap-run-rkt
  (build-path racket-root "src/expander/bootstrap-run.rkt"))
(define expander-main-rkt
  (build-path racket-root "src/expander/main.rkt"))

;; expander-extraction-args : path? -> (listof string?)
;;   Build the standalone expander extraction command from src/expander/main.zuo.
(define (expander-extraction-args out-dir)
  (define out-rktl (build-path out-dir "expander.rktl"))
  (define dep-rktd (build-path out-dir "expander-dep.rktd"))
  (define cache-dir (build-path out-dir "cache-src"))
  (list
   (path->string bootstrap-run-rkt)
   "-t" (path->string expander-main-rkt)
   "-c" (path->string cache-dir)
   "--depends" (path->string dep-rktd)
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/api.rkt"))
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/primitive-parameter.rkt"))
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/readtable-parameter.rkt"))
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/readtable.rkt"))
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/number.rkt"))
   "++direct" "linklet"
   "++direct" "kernel"
   "++disallow" "make-optional-keyword-procedure"
   "--no-global"
   "++global-ok" "core-forms"
   "++global-ok" "core-primitives"
   "++global-ok" "built-in-symbols"
   "++global-ok" "default-read-handler"
   "++global-ok" "current-previously-unbound"
   "++global-ok" "keep-source-locations?"
   "++global-ok" "rx:path-list"
   "++global-ok" "load-configure-expand"
   "-k" (path->string racket-root)
   "-s" "-x"
   "-o" (path->string out-rktl)))

;; extract-expander! : path? -> (values exact-integer? string?)
;;   Generate the flattened expander linklet with Racket's standalone recipe.
(define (extract-expander! out-dir)
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define status
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr])
      (apply system*/exit-code
             (path->string racket-bin)
             (expander-extraction-args out-dir))))
  (values status
          (string-append (get-output-string stdout)
                         (get-output-string stderr))))

;; linklet-export-external-names : any/c -> (listof symbol?)
;;   Extract external export names from a linklet datum.
(define (linklet-export-external-names datum)
  (check-match datum `(linklet ,_ ,_ . ,_))
  (for/list ([export (in-list (caddr datum))])
    (cond
      [(symbol? export) export]
      [(and (list? export) (= (length export) 2) (symbol? (cadr export)))
       (cadr export)]
      [else
       (fail-check (format "unexpected expander export shape: ~s" export))])))

(when (and (file-exists? racket-bin)
           (file-exists? bootstrap-run-rkt)
           (file-exists? expander-main-rkt))
  (test-case "Racket CS expander extracts to one closed linklet"
    (define out-dir (make-temporary-file "webracket-expander-extract-~a" 'directory))
    (dynamic-wind
      void
      (lambda ()
        (define-values (status output) (extract-expander! out-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"Traversed 311 modules" output)
        (check-regexp-match #rx"Need 245 of those linklets" output)
        (define out-rktl (build-path out-dir "expander.rktl"))
        (define dep-rktd (build-path out-dir "expander-dep.rktd"))
        (check-true (file-exists? out-rktl))
        (check-true (file-exists? dep-rktd))
        (define datum (call-with-input-file out-rktl read))
        (check-equal? (car datum) 'linklet)
        (check-equal? (cadr datum) '())
        (check-equal? (length (linklet-export-external-names datum)) 71)
        (define export-names (linklet-export-external-names datum))
        (for ([name (in-list '(boot
                               compile
                               current-eval
                               current-namespace
                               datum->syntax
                               dynamic-require
                               eval
                               expand
                               identifier?
                               make-namespace
                               read
                               read-syntax
                               syntax->datum
                               syntax-e
                               syntax?))])
          (check-true (and (memq name export-names) #t)
                      (format "~a is exported" name)))
        (define deps (call-with-input-file dep-rktd read))
        (check-equal? (sub1 (length deps)) 310)
        (define-values (webified exports exports-info)
          (run-first-slice-top-level datum #:define-export-aliases? #f))
        (check-equal? (length exports) 71)
        (check-true (first-slice-unsupported-free? webified))
        (check-true (module-prompt-free? webified))
        (define literal-wat
          (wat-string
           (comp (datum->syntax
                  #f
                  `(begin
                     (define rx ',#rx"^[\\][\\][?][\\]")
                     (object-name rx)
                     (void))))))
        (check-true (positive? (string-length literal-wat)))
        (check-regexp-match #rx"\\$Regexp" literal-wat))
      (lambda ()
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files out-dir))))))

(module+ main
  (void))
