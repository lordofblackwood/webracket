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

;; contains-symbol? : any/c symbol? -> boolean?
;;   Check whether v contains the symbol s.
(define (contains-symbol? v s)
  (let loop ([v v])
    (cond
      [(syntax? v) (loop (syntax->datum v))]
      [(symbol? v) (eq? v s)]
      [(pair? v)   (or (loop (car v)) (loop (cdr v)))]
      [(vector? v) (for/or ([e (in-vector v)]) (loop e))]
      [else        #f])))

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
        (define-values (webified _exports _exports-info)
          (run-first-slice-top-level datum))
        (check-false (contains-symbol? webified 'unsafe-struct))
        (define wat (wat-string (comp webified)))
        (check-true (positive? (string-length wat)))
        (define startup-rkt (build-path out-dir "regexp-startup.rkt"))
        (write-datum-program!
         (path->string startup-rkt)
         (append-top-level-form (syntax->datum webified) '(js-log 123)))
        (define-values (startup-status startup-output)
          (run-webracket (list "--no-stdlib" "-r" (path->string startup-rkt))
                         out-dir))
        (check-equal? startup-status 0 startup-output)
        (check-regexp-match #rx"(?m:^123$)" startup-output)
        (define regexp-call-rkt (build-path out-dir "regexp-call.rkt"))
        (write-datum-program!
         (path->string regexp-call-rkt)
         (append-top-level-form (syntax->datum webified)
                                '(js-log (regexp? (regexp "a")))))
        (define-values (call-status call-output)
          (run-webracket (list "--no-stdlib" "-r" (path->string regexp-call-rkt))
                         out-dir))
        (check-equal? call-status 0 call-output)
        (check-regexp-match #rx"(?m:^true$)" call-output)
        (define regexp-match-pred-rkt (build-path out-dir "regexp-match-pred.rkt"))
        (write-datum-program!
         (path->string regexp-match-pred-rkt)
         (append-top-level-form (syntax->datum webified)
                                '(js-log (regexp-match? (regexp "a") "a"))))
        (define-values (match-pred-status match-pred-output)
          (run-webracket (list "--no-stdlib" "-r" (path->string regexp-match-pred-rkt))
                         out-dir))
        (check-equal? match-pred-status 0 match-pred-output)
        (check-regexp-match #rx"(?m:^true$)" match-pred-output)
        (define regexp-match-rkt (build-path out-dir "regexp-match.rkt"))
        (write-datum-program!
         (path->string regexp-match-rkt)
         (append-top-level-form (syntax->datum webified)
                                '(js-log (regexp-match (regexp "a") "cat"))))
        (define-values (match-status match-output)
          (run-webracket (list "--no-stdlib" "-r" (path->string regexp-match-rkt))
                         out-dir))
        (check-equal? match-status 0 match-output)
        (check-regexp-match #rx"car: 'a'" match-output)
        (define regexp-shapes-rkt (build-path out-dir "regexp-shapes.rkt"))
        (write-datum-program!
         (path->string regexp-shapes-rkt)
         (append-top-level-form (syntax->datum webified)
                                '(begin
                                   (js-log (regexp-match? (regexp "ab") "xxabyy"))
                                   (js-log (regexp-match? (regexp "[ab]") "b"))
                                   (js-log (regexp-match (regexp "(a)") "cat")))))
        (define-values (shapes-status shapes-output)
          (run-webracket (list "--no-stdlib" "-r" (path->string regexp-shapes-rkt))
                         out-dir))
        (check-equal? shapes-status 0 shapes-output)
        (check-equal? (length (regexp-match* #rx"(?m:^true$)" shapes-output)) 2)
        (check-regexp-match #rx"cdr: \\{ tag: 'pair', car: 'a'" shapes-output)
        (define regexp-repetition-rkt (build-path out-dir "regexp-repetition.rkt"))
        (write-datum-program!
         (path->string regexp-repetition-rkt)
         (append-top-level-form (syntax->datum webified)
                                '(begin
                                   (js-log (regexp-match? (regexp "a*") "bbb"))
                                   (js-log (regexp-match? (regexp "a+") "bbb"))
                                   (js-log (regexp-match? (regexp "^a") "ba"))
                                   (js-log (regexp-match? (regexp "^a") "ab")))))
        (define-values (repetition-status repetition-output)
          (run-webracket (list "--no-stdlib" "-r" (path->string regexp-repetition-rkt))
                         out-dir))
        (check-equal? repetition-status 0 repetition-output)
        (check-equal? (regexp-match* #rx"(?m:^(true|false)$)" repetition-output)
                      '("true" "false" "false" "true"))
        (define regexp-byte-pregexp-rkt (build-path out-dir "regexp-byte-pregexp.rkt"))
        (write-datum-program!
         (path->string regexp-byte-pregexp-rkt)
         (append-top-level-form (syntax->datum webified)
                                '(begin
                                   (js-log (regexp-match? (byte-regexp #"a") #"cat"))
                                   (js-log (regexp-match? (pregexp "a|b") "b"))
                                   (js-log (regexp-match? (regexp "a?") "bbb")))))
        (define-values (byte-pregexp-status byte-pregexp-output)
          (run-webracket (list "--no-stdlib" "-r" (path->string regexp-byte-pregexp-rkt))
                         out-dir))
        (check-equal? byte-pregexp-status 0 byte-pregexp-output)
        (check-equal? (length (regexp-match* #rx"(?m:^true$)" byte-pregexp-output)) 3))
      (lambda ()
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files out-dir))))))

(module+ main
  (void))
