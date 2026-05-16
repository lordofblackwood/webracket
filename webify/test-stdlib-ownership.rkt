#lang racket/base

(require racket/file
         racket/list
         racket/match
         racket/string
         rackunit
         "test-module-support.rkt"
         "../stdlib/module-exports.rkt")

;; symbols-subset? : (listof symbol?) (listof symbol?) -> boolean?
;;   Check whether every symbol in xs appears in ys.
(define (symbols-subset? xs ys)
  (for/and ([x (in-list xs)])
    (and (memq x ys) #t)))

;; write-program! : path-string? string? -> void?
;;   Write a temporary source program for stdlib bridge smokes.
(define (write-program! path text)
  (call-with-output-file path
    (lambda (out) (display text out))
    #:exists 'truncate/replace))

;; run-temp-webracket : string? (listof string?) -> (values exact-integer? string?)
;;   Run a temporary source program through WebRacket.
(define (run-temp-webracket source args)
  (define source-dir (make-temporary-file "webracket-stdlib-ownership-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-stdlib-ownership-dest-~a" 'directory))
  (define source-path (build-path source-dir "stdlib-ownership.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-program! source-path source)
      (run-webracket (append args
                             (list "--dest" (path->string dest-dir)
                                   (path->string source-path)))
                     source-dir
                     #:timeout-seconds 120
                     #:memory-mb 1024))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

;; forms-contain? : (any/c -> boolean?) (listof any/c) -> boolean?
;;   Recursively search generated bridge forms.
(define (forms-contain? pred forms)
  (define (walk v)
    (or (pred v)
        (cond
          [(pair? v)   (or (walk (car v)) (walk (cdr v)))]
          [(vector? v) (for/or ([elem (in-vector v)]) (walk elem))]
          [else        #f])))
  (for/or ([form (in-list forms)])
    (walk form)))

(test-case "node and browser stdlib roots expose distinct public surfaces"
  (define node-exports (stdlib-module-export-symbols #f))
  (define browser-exports (stdlib-module-export-symbols #t))
  (check-not-false (memq 'displayln node-exports))
  (check-not-false (memq 'sxml->dom browser-exports))
  (check-false (memq 'sxml->dom node-exports))
  (check-true (symbols-subset? node-exports browser-exports)))

(test-case "stdlib bridge rewrites public definitions to private names"
  (define-values (forms bindings) (stdlib-module-private-forms+bindings #f))
  (define error-binding (assoc 'error bindings))
  (define raise-star-binding (assoc 'raise-argument-error* bindings))
  (check-not-false error-binding)
  (check-not-false raise-star-binding)
  (check-true (symbol? (cdr error-binding)))
  (check-true (regexp-match? #rx"^webify-stdlib-private\\$"
                             (symbol->string (cdr error-binding))))
  (check-true
   (forms-contain?
    (lambda (v)
      (match v
        [`(define-values ,names . ,_)
         (and (member (cdr error-binding) names) #t)]
        [_ #f]))
    forms))
  (check-false
   (forms-contain?
    (lambda (v)
      (match v
        [`(define-values ,names . ,_)
         (and (member 'error names) #t)]
        [_ #f]))
    forms)))

(test-case "stdlib bridge aliases skip primitive-owned exports"
  (define aliases (stdlib-module-alias-symbols #f))
  (check-not-false (memq 'error aliases))
  (check-not-false (memq 'raise-argument-error* aliases))
  (check-false (memq 'format aliases))
  (check-false (memq 'raise-argument-error aliases))
  (check-false (memq 'read aliases)))

(test-case "exception ownership lists classify temporary primitive helpers"
  (for ([sym (in-list '(format
                        fprintf
                        raise-argument-error
                        raise-arguments-error
                        read
                        read-syntax))])
    (check-not-false (memq sym stdlib-primitive-owned-export-symbols)
                     (format "~a should be temporary primitive-owned" sym)))
  (for ([sym (in-list '(error
                        primitive-realm
                        error-message->adjusted-string
                        error-value->string
                        raise-argument-error*
                        raise-arguments-error*
                        raise-range-error
                        raise-range-error*
                        raise-result-error))])
    (check-false (memq sym stdlib-primitive-owned-export-symbols)
                 (format "~a should be stdlib-owned" sym))))

(test-case "stdlib-owned exception helpers are visible through --stdlib bridge"
  (define-values (status output)
    (run-temp-webracket
     (string-append
      "(js-log (error-message->adjusted-string \"add1\" 'realm \"problem\" 'other))\n"
      "(js-log (symbol? primitive-realm))\n"
      "(with-handlers ([exn:fail? (lambda (e) (js-log \"caught\"))])\n"
      "  (raise-argument-error* 'map 'racket/primitive \"list?\" 0 42))\n")
     (list "-r" "--stdlib")))
  (check-equal? status 0 output)
  (check-regexp-match #rx"(?m:^add1: problem$)" output)
  (check-regexp-match #rx"(?m:^true$)" output)
  (check-regexp-match #rx"(?m:^caught$)" output))

(test-case "stdlib-owned exception helpers are absent with --no-stdlib"
  (define-values (status output)
    (run-temp-webracket
     "(js-log error-message->adjusted-string)\n"
     (list "-r" "--no-stdlib")))
  (check-not-equal? status 0 output)
  (check-true
   (or (string-contains? output "error-message->adjusted-string")
       (string-contains? output "unbound"))
   output))

(module+ main
  (void))
