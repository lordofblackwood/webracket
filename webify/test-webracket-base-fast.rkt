#lang racket/base

(require racket/file
         racket/path
         racket/runtime-path
         racket/string
         rackunit
         "test-module-support.rkt")

(define module-linklet-decompile-available?
  (and (dynamic-require 'racket/linklet 'decompile-linklet (lambda () #f)) #t))

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
           (string->bytes/utf-8 (webracket-collection-env-value)))
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

(test-case "fast #lang webracket/base optional keyword smoke"
  (cond
    [module-linklet-decompile-available?
     (run-fast-module-smoke
      (string-append
       "#lang webracket/base\n"
       "(define (scale x #:by [by 1]) (* x by))\n"
       "(js-log (scale 21 #:by 2))\n")
      #rx"(?m:^42$)")]
    [else
     (check-true #t "keyword module smoke requires host linklet decompilation")]))

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

(test-case "fast #lang webracket/full generic sequence smoke"
  (run-fast-module-smoke
   (string-append
    "#lang webracket/full\n"
    "(define xs (for/list ([x (list 1 2 3)]) (+ x 1)))\n"
    "(define ys (for/list ([x (vector 4 5)]) x))\n"
    "(define zs (for/list ([ch \"ab\"]) ch))\n"
    "(define ns (for/list ([i 3]) i))\n"
    "(define bstr #\"az\")\n"
    "(define ht (hash 'a 7 'b 8))\n"
    "(define bs (for/list ([b bstr]) b))\n"
    "(define hs (for/list ([(k v) ht]) v))\n"
    "(js-log (+ (length xs) (length ys) (length zs) (length ns) (length bs) (length hs)))\n")
   #rx"(?m:^14$)"))

(module+ main
  (void))
