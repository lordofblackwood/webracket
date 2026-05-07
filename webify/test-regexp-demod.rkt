#lang racket/base

(require racket/file
         racket/list
         racket/path
         racket/runtime-path
         racket/system
         rackunit
         "test-module-support.rkt")

(define-runtime-path repo-root "..")

(define racket-root (simplify-path (build-path repo-root "../racket/racket")))
(define racket-bin  (build-path racket-root "bin/racket"))
(define bootstrap-run-rkt
  (build-path racket-root "src/expander/bootstrap-run.rkt"))
(define regexp-main-rkt
  (build-path racket-root "src/regexp/main.rkt"))

;; regexp-exports : (listof symbol?)
;;   Public exports expected from the flattened regexp layer linklet.
(define regexp-exports
  '(byte-pregexp
    byte-pregexp?
    byte-regexp
    byte-regexp?
    pregexp
    pregexp?
    regexp
    regexp-capture-group-count
    regexp-match
    regexp-match-peek
    regexp-match-peek-immediate
    regexp-match-peek-positions
    regexp-match-peek-positions-immediate
    regexp-match-peek-positions-immediate/end
    regexp-match-peek-positions/end
    regexp-match-positions
    regexp-match-positions/end
    regexp-match/end
    regexp-match?
    regexp-max-lookbehind
    regexp-place-init!
    regexp-replace
    regexp-replace*
    regexp?))

;; demod-regexp! : path? -> (values exact-integer? string?)
;;   Generate the flattened regexp linklet using the Racket CS demod recipe.
(define (demod-regexp! out-dir)
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define out-rktl (build-path out-dir "regexp.rktl"))
  (define dep-rktd (build-path out-dir "regexp-dep.rktd"))
  (define cache-dir (build-path out-dir "cache"))
  (define status
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr])
      (system*/exit-code
       (path->string racket-bin)
       (path->string bootstrap-run-rkt)
       "-t" (path->string regexp-main-rkt)
       "-c" (path->string cache-dir)
       "-k" (path->string racket-root)
       "-s" "-x"
       "--depends" (path->string dep-rktd)
       "--no-global"
       "-o" (path->string out-rktl))))
  (values status
          (string-append (get-output-string stdout)
                         (get-output-string stderr))))

;; linklet-export-external-names : any/c -> (listof symbol?)
;;   Extract external export names from a linklet datum.
(define (linklet-export-external-names datum)
  (check-match datum `(linklet ,_ ,_ . ,_))
  (define exports (caddr datum))
  (for/list ([export (in-list exports)])
    (cond
      [(symbol? export) export]
      [(and (list? export) (= (length export) 2) (symbol? (cadr export)))
       (cadr export)]
      [else
       (fail-check (format "unexpected regexp export shape: ~s" export))])))

(when (and (file-exists? racket-bin)
           (file-exists? bootstrap-run-rkt)
           (file-exists? regexp-main-rkt))
  (test-case "Racket CS regexp layer demods to one linklet"
    (define out-dir (make-temporary-file "webracket-regexp-demod-~a" 'directory))
    (dynamic-wind
      void
      (lambda ()
        (define-values (status output) (demod-regexp! out-dir))
        (check-equal? status 0 output)
        (define out-rktl (build-path out-dir "regexp.rktl"))
        (check-true (file-exists? out-rktl))
        (define datum (call-with-input-file out-rktl read))
        (check-equal? (car datum) 'linklet)
        (check-equal? (cadr datum) '())
        (check-true (positive? (length (cdddr datum))))
        (check-equal? (sort (linklet-export-external-names datum) symbol<?)
                      (sort regexp-exports symbol<?))
        (check-exn
         #rx"unsupported webify compatibility form remains after lowering: unsafe-struct\\*-ref"
         (lambda ()
           (run-first-slice-top-level datum))))
      (lambda ()
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files out-dir))))))

(module+ main
  (void))
