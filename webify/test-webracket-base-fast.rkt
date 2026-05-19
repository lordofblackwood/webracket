#lang racket/base

(require racket/file
         racket/path
         racket/runtime-path
         racket/string
         rackunit
         "test-module-support.rkt")

(define-runtime-path repo-root* "..")
(define repo-root (simplify-path repo-root*))

(define repo-parent
  (let-values ([(base _name _must-be-dir?) (split-path repo-root)])
    base))

(define path-list-separator
  (if (eq? (system-type 'os) 'windows) ";" ":"))

;; collection-env-value : -> string?
;;   Make child Racket processes resolve this checkout as collection `webracket`.
(define (collection-env-value)
  (format "~a~a~a"
          (string-join (list (path->string repo-parent)
                             (path->string repo-root))
                       path-list-separator)
          path-list-separator
          (or (getenv "PLTCOLLECTS") "")))

;; run-fast-module-smoke : string? regexp? -> void?
;;   Compile and run one tiny module-language smoke with bounded resources.
(define (run-fast-module-smoke source expected)
  (define source-dir (make-temporary-file "webracket-fast-module-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-fast-module-dest-~a" 'directory))
  (define source-path (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out) (display source out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (parameterize ([current-environment-variables
                        (environment-variables-copy
                         (current-environment-variables))])
          (environment-variables-set!
           (current-environment-variables)
           #"PLTCOLLECTS"
           (string->bytes/utf-8 (collection-env-value)))
          (run-webracket
           (list "-r" "--no-stdlib" "--no-io-format-provider"
                 "--dest" (path->string dest-dir)
                 (path->string source-path))
           source-dir
           #:timeout-seconds 120
           #:memory-mb 1024)))
      (check-equal? status 0 output)
      (check-regexp-match expected output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "fast #lang webracket/base expression smoke"
  (run-fast-module-smoke
   "#lang webracket/base\n(js-log (+ 40 2))\n"
   #rx"(?m:^42$)"))

(test-case "fast #lang webracket/full list-provider smoke"
  (run-fast-module-smoke
   (string-append
    "#lang webracket/full\n"
    "(define xs '(1 2 3 4))\n"
    "(define ys (filter-map (lambda (x) (and (even? x) (+ x 10))) xs))\n"
    "(define zs (append-map (lambda (x) (list x x)) '(5 6)))\n"
    "(js-log (+ (first ys) (length zs) (first (rest ys)) 12))\n")
   #rx"(?m:^42$)"))

(test-case "fast #lang webracket/full staged-set smoke"
  (run-fast-module-smoke
   (string-append
    "#lang webracket/full\n"
    "(define s (set 'a 'b 'c))\n"
    "(js-log (+ (length (set->list s)) (set-count (set-rest s))))\n")
   #rx"(?m:^5$)"))

(module+ main
  (void))
