#lang racket/base

(require racket/file
         racket/path
         rackunit
         "../webify/test-module-support.rkt")

;; write-program! : path-string? string? -> void?
;;   Write a temporary WebRacket source program for runtime smoke checks.
(define (write-program! path text)
  (call-with-output-file path
    (lambda (out) (display text out))
    #:exists 'truncate/replace))

;; check-webracket-output : string? regexp? -> void?
;;   Run a no-stdlib WebRacket program and match its observable output.
(define (check-webracket-output source expected-output)
  (define source-dir (make-temporary-file "webracket-keyword-proc-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-keyword-proc-dest-~a" 'directory))
  (define source-path (build-path source-dir "keyword-procedure-surface.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-program! source-path source)
      (define-values (status output)
        (run-webracket (list "--no-stdlib"
                             "-r"
                             "--dest" (path->string dest-dir)
                             (path->string source-path))
                       source-dir))
      (check-equal? status 0 output)
      (check-regexp-match expected-output output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

;; check-webracket-output/files : (listof (cons/c string? string?)) string regexp? -> void?
;;   Run a temporary multi-file WebRacket program and match its observable output.
(define (check-webracket-output/files files entry-file expected-output)
  (define source-dir (make-temporary-file "webracket-keyword-proc-files-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-keyword-proc-files-dest-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (for ([entry (in-list files)])
        (define rel-path (car entry))
        (define text     (cdr entry))
        (define full-path (build-path source-dir rel-path))
        (make-directory* (path-only full-path))
        (write-program! full-path text))
      (define-values (status output)
        (run-webracket (list "--no-stdlib"
                             "-r"
                             "--dest" (path->string dest-dir)
                             (path->string (build-path source-dir entry-file)))
                       source-dir))
      (check-equal? status 0 output)
      (check-regexp-match expected-output output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "struct proc-spec field makes instances callable"
  (check-webracket-output
   (string-append
    "(define-values (struct:p make-p p? p-ref p-set!)\n"
    "  (make-struct-type 'p #f 1 0 #f null #f 0 '(0)))\n"
    "(define p (make-p (lambda (x) (+ x 1))))\n"
    "(js-log (procedure? p))\n"
    "(js-log (p 41))\n")
   #rx"(?m:^true\n42\n#<void>$)"))

(test-case "struct proc-spec procedure makes instances callable"
  (check-webracket-output
   (string-append
    "(define-values (struct:p make-p p? p-ref p-set!)\n"
    "  (make-struct-type\n"
    "   'p #f 1 0 #f null #f\n"
    "   (lambda (self delta)\n"
    "     (+ (p-ref self 0) delta))))\n"
    "(define p (make-p 10))\n"
    "(js-log (procedure? p))\n"
    "(js-log (p 5))\n")
   #rx"(?m:^true\n15\n#<void>$)"))

(test-case "keyword-procedure-shaped subtype dispatches through child proc-spec field"
  (check-webracket-output
   (string-append
    "(define-values (struct:keyword-procedure make-kp kp? kp-ref kp-set!)\n"
    "  (make-struct-type 'keyword-procedure #f 4 0 #f null #f #f '(0 1 2 3)))\n"
    "(define-values (struct:optional-keyword-procedure make-okp okp? okp-ref okp-set!)\n"
    "  (make-struct-type 'procedure struct:keyword-procedure 1 0 #f null #f 0 '(0)))\n"
    "(define okp\n"
    "  (make-okp 'checker 'keyword-proc 'required 'allowed\n"
    "            (lambda (x) (+ x 1))))\n"
    "(js-log (procedure? okp))\n"
    "(js-log (okp 41))\n"
    "(js-log (okp? okp))\n"
    "(js-log (kp? okp))\n")
   #rx"(?m:^true\n42\ntrue\ntrue\n#<void>$)"))

(test-case "webracket/private/kw supports make-keyword-procedure and keyword-apply"
  (check-webracket-output
   (string-append
    "#lang webracket/base\n"
    "(require webracket/private/kw)\n"
    "(define show\n"
    "  (make-keyword-procedure\n"
    "   (lambda (kws kw-args . rest)\n"
    "     (apply + (length kws) (append kw-args rest)))\n"
    "   (lambda args (apply + args))))\n"
    "(js-log (show 10 20 12))\n"
    "(js-log (keyword-apply show '(#:y) '(20) '(21)))\n")
   #rx"(?m:^42\nundefined\n42\nundefined\n#<void>$)"))

(test-case "webracket/private/kw reports and reduces keyword arity"
  (check-webracket-output
   (string-append
    "#lang webracket/base\n"
    "(require webracket/private/kw)\n"
    "(define show\n"
    "  (make-keyword-procedure\n"
    "   (lambda (kws kw-args . rest)\n"
    "     (apply + (length kws) (append kw-args rest)))\n"
    "   (lambda args (apply + args))))\n"
    "(js-log (keyword-apply show '(#:x #:y) '(10 11) '(20)))\n"
    "(define reduced\n"
    "  (procedure-reduce-keyword-arity show 1 '(#:y) '(#:y)))\n"
    "(define-values (required allowed) (procedure-keywords reduced))\n"
    "(js-log (and (equal? required '(#:y)) (equal? allowed '(#:y))))\n"
    "(js-log (keyword-apply reduced '(#:y) '(20) '(21)))\n")
   #rx"(?m:^43\nundefined\ntrue\nundefined\n42\nundefined\n#<void>$)"))

(test-case "webracket/private/kw direct keyword calls reach reduced procedures"
  (check-webracket-output
   (string-append
    "#lang webracket/base\n"
    "(require webracket/private/kw)\n"
    "(define base\n"
    "  (make-keyword-procedure\n"
    "   (lambda (kws kw-args . rest)\n"
    "     (list 'keyword kws kw-args rest))\n"
    "   (lambda rest\n"
    "     (list 'plain rest))))\n"
    "(define proc\n"
    "  (procedure-reduce-keyword-arity\n"
    "   base\n"
    "   (arity-at-least 0)\n"
    "   '()\n"
    "   '(#:attrs)\n"
    "   'local-proc))\n"
    "(js-log (proc #:attrs '((id . \"x\")) \"hi\"))\n")
   #rx"(?m:^\\(keyword \\(#:attrs\\) \\(\\(\\(id \\. \"x\"\\)\\)\\) \\(\"hi\"\\)\\)\n#<void>$)"))

(test-case "webracket/private/kw imported reduced keyword procedures accept direct keyword calls"
  (check-webracket-output/files
   (list
    (cons "helper.rkt"
          (string-append
           "#lang webracket/base\n"
           "(require webracket/private/kw)\n"
           "(define base\n"
           "  (make-keyword-procedure\n"
           "   (lambda (kws kw-args . rest)\n"
           "     (list 'keyword kws kw-args rest))\n"
           "   (lambda rest\n"
           "     (list 'plain rest))))\n"
           "(define proc\n"
           "  (procedure-reduce-keyword-arity\n"
           "   base\n"
           "   (arity-at-least 0)\n"
           "   '()\n"
           "   '(#:attrs)\n"
           "   'helper-proc))\n"
           "(provide proc)\n"))
    (cons "main.rkt"
          (string-append
           "#lang webracket/base\n"
           "(require \"helper.rkt\")\n"
           "(js-log (proc #:attrs '((id . \"x\")) \"hi\"))\n")))
   "main.rkt"
   #rx"(?m:^\\(keyword \\(#:attrs\\) \\(\\(\\(id \\. \"x\"\\)\\)\\) \\(\"hi\"\\)\\)\n#<void>$)"))

(test-case "webracket/private/sort exports a callable positional sort"
  (check-webracket-output
   (string-append
    "#lang webracket/base\n"
    "(require webracket/private/sort)\n"
    "(define sorted\n"
    "  (sort (list (list 'a 10 20)\n"
    "              (list 'b 12 20)\n"
    "              (list 'c 5 18))\n"
    "        (lambda (a b)\n"
    "          (let ([ay (caddr a)]\n"
    "                [by (caddr b)])\n"
    "            (cond\n"
    "              [(> ay by) #t]\n"
    "              [(= ay by) (> (cadr a) (cadr b))]\n"
    "              [else #f])))))\n"
    "(displayln sorted)\n")
   #rx"(?m:^\\(\\(b 12 20\\) \\(a 10 20\\) \\(c 5 18\\)\\)\n#<void>$)"))

(module+ main
  (void))
