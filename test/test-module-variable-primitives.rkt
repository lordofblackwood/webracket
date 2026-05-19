#lang racket/base

(require racket/file
         racket/path
         racket/runtime-path
         racket/string
         racket/system
         rackunit
         "../pkgs/webracket-lib/compiler/private/priminfo.rkt")

(define-runtime-path repo-root "..")
(define-runtime-path webracket-rkt "../webracket.rkt")
(define sibling-racket
  (build-path repo-root ".." "racket" "racket" "bin" "racket"))

;; racket-executable : -> path-string?
;;   Prefer the sibling Racket checkout used for current Webify/linklet work.
(define (racket-executable)
  (or (and (file-exists? sibling-racket) sibling-racket)
      (find-executable-path "racket")))

;; module-variable-primitives : (listof symbol?)
;;   Lowered module-variable helper names that must be visible as primitives.
(define module-variable-primitives
  '(module-variable?
    module-variable-name
    module-variable-constance
    module-variable-initialized?
    module-variable-make
    module-variable-ref
    module-variable-ref/no-check
    module-variable-set!
    module-variable-set!/check-undefined!
    module-variable-define!
    module-variables-define-consistent!
    module-variable-reference?
    module-variable-reference-instance
    module-variable-reference-variable
    module-variable-reference
    module-call-with-prompt))

;; run-webracket : (listof string?) path? -> (values exact-integer? string?)
;;   Run the local webracket command and capture combined output.
(define (run-webracket args cwd)
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define status
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr]
                   [current-directory cwd])
      (apply system*/exit-code
             (racket-executable)
             (path->string webracket-rkt)
             args)))
  (values status
          (string-append (get-output-string stdout)
                         (get-output-string stderr))))

;; write-program! : path-string? string? -> void?
;;   Write a temporary source program for compile-smoke checks.
(define (write-program! path text)
  (call-with-output-file path
    (lambda (out) (display text out))
    #:exists 'truncate/replace))

;; string-count-substring : string? string? -> exact-nonnegative-integer?
;;   Count non-overlapping occurrences of needle in haystack.
(define (string-count-substring haystack needle)
  (define rx (regexp (regexp-quote needle)))
  (let loop ([start 0] [count 0])
    (define m (regexp-match-positions rx haystack start))
    (if m
        (loop (cdar m) (add1 count))
        count)))

(test-case "module-variable helpers are exported by #lang webracket"
  (for ([sym (in-list module-variable-primitives)])
    (check-true (procedure? (dynamic-require (build-path repo-root "main.rkt") sym))
                (format "~a should be a value export" sym))))

(test-case "module-variable helpers have primitive metadata"
  (for ([sym (in-list module-variable-primitives)])
    (define desc (primitive->description sym))
    (check-not-false desc (format "~a should have a primitive description" sym))))

(test-case "module-variable helpers compile without stdlib"
  (define source-dir (make-temporary-file "webracket-module-variable-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-module-variable-dest-~a" 'directory))
  (define source-path (build-path source-dir "module-variable-smoke.rkt"))
  (define wat-path    (build-path dest-dir "module-variable-smoke.wat"))
  (dynamic-wind
    void
    (lambda ()
      (write-program!
       source-path
        (string-append
        "#lang webracket\n"
        "(define (install! cell)\n"
        "  (define ref (module-variable-reference 'instance cell))\n"
        "  (module-variable-define! cell 40 'consistent)\n"
        "  (module-variable? cell)\n"
        "  (module-variable-name cell)\n"
        "  (module-variable-constance cell)\n"
        "  (module-variable-initialized? cell)\n"
        "  (module-variable-reference? ref)\n"
        "  (module-variable-reference-instance ref)\n"
        "  (module-variable-reference-variable ref)\n"
        "  (module-variable-set!/check-undefined! cell (+ (module-variable-ref cell) 2))\n"
        "  (module-variable-ref/no-check cell))\n"
        "(define cell (module-variable-make 'x))\n"
        "(install! cell)\n"))
      (define-values (status output)
        (run-webracket (list "--no-stdlib"
                             "--dest" (path->string dest-dir)
                             (path->string source-path))
                       source-dir))
      (check-equal? status 0 output)
      (check-true (file-exists? wat-path))
      (define wat (file->string wat-path))
      (check-true (string-contains? wat "(type $ModuleVariable "))
      (check-true (string-contains? wat "(func $module-variable-ref "))
      (for ([needle (in-list '("(call $module-variable-make"
                               "(call $module-variable?"
                               "(call $module-variable-name"
                               "(call $module-variable-constance"
                               "(call $module-variable-initialized?"
                               "(call $module-variable-define!"
                               "(call $module-variable-set!/check-undefined!"
                               "(call $module-variable-ref"
                               "(call $module-variable-ref/no-check"
                               "(call $module-variable-reference?"
                               "(call $module-variable-reference-instance"
                               "(call $module-variable-reference-variable"
                               "(call $module-variable-reference"))])
        (check-true (positive? (string-count-substring wat needle))
                    (format "expected generated WAT to call ~a" needle))))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(module+ main
  (void))
