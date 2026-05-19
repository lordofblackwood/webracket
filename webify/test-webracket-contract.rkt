#lang racket/base

(require racket/file
         racket/path
         racket/runtime-path
         racket/string
         rackunit
         (prefix-in erased: "../contract.rkt")
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

;; run-contract-smoke : string? regexp? -> void?
;;   Compile and run one tiny module-language contract smoke with bounded resources.
(define (run-contract-smoke source expected)
  (define source-dir (make-temporary-file "webracket-contract-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-contract-dest-~a" 'directory))
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

(module contract-out-module racket/base
  (require "../contract.rkt")
  (provide (contract-out [answer integer?]
                         [add1-erased (-> integer? integer?)]
                         [rename internal-renamed external-renamed integer?]
                         [struct posn ([x integer?] [y integer?])]
                         #:exists hidden/c))
  (define answer "not-an-integer")
  (define (add1-erased x) (+ x 1))
  (define internal-renamed 38)
  (struct posn (x y)))

(module provide-contract-module racket/base
  (require "../contract.rkt")
  (provide/contract [answer integer?])
  (define answer "not-an-integer"))

(module define-contract-module racket/base
  (require "../contract.rkt")
  (provide value add1-erased)
  (define/contract value integer? "not-an-integer")
  (define/contract (add1-erased x) (-> integer? integer?) (+ x 1)))

(module with-contract-module racket/base
  (require "../contract.rkt")
  (provide value)
  (with-contract here ([value integer?]) ()
    (define value "not-an-integer")))

(require (prefix-in contract-out: (submod "." contract-out-module))
         (prefix-in provide-contract: (submod "." provide-contract-module))
         (prefix-in define-contract: (submod "." define-contract-module))
         (prefix-in with-contract: (submod "." with-contract-module)))

(test-case "contract-out erases annotations but preserves exports"
  (check-equal? contract-out:answer "not-an-integer")
  (check-equal? (contract-out:add1-erased 41) 42)
  (check-equal? contract-out:external-renamed 38)
  (define p (contract-out:posn 20 22))
  (check-equal? (+ (contract-out:posn-x p) (contract-out:posn-y p)) 42))

(test-case "provide/contract erases annotations but preserves exports"
  (check-equal? provide-contract:answer "not-an-integer"))

(test-case "define/contract erases variable and function annotations"
  (check-equal? define-contract:value "not-an-integer")
  (check-equal? (define-contract:add1-erased 41) 42))

(test-case "with-contract erases definition-context boundary"
  (check-equal? with-contract:value "not-an-integer"))

(test-case "runtime contract helpers erase boundaries"
  (define boundary-value (erased:contract integer? "not-an-integer" 'positive 'negative))
  (check-equal? boundary-value "not-an-integer")
  (check-true (erased:contract? (erased:-> integer? integer?)))
  (check-true (erased:contract-first-order-passes? (erased:listof integer?) "not-a-list"))
  (for ([ctc (in-list (list (erased:list/c integer? string?)
                            (erased:vector/c integer? string?)
                            (erased:immutable-vector/c integer?)
                            (erased:between/c 0 10)
                            (erased:integer-in #f 10)
                            (erased:one-of/c 'a 'b)
                            (erased:symbols 'a 'b)
                            (erased:parameter/c string?)
                            (erased:promise/c integer?)
                            (erased:procedure-arity-includes/c 2)))])
    (check-true (erased:contract? ctc))))

(test-case "syntax-only contract helpers erase to inert contracts"
  (define dependent (erased:->i ([x integer?]) [result integer?]))
  (define recursive (erased:recursive-contract (erased:listof integer?) #:flat))
  (define parametric (erased:parametric->/c [a] (erased:-> a a)))
  (define struct-contract (erased:struct/c posn integer? integer?))
  (for ([ctc (in-list (list dependent recursive parametric struct-contract))])
    (check-true (erased:contract? ctc))))

(test-case "#lang webracket/base can require erased webracket/contract"
  (run-contract-smoke
   (string-append
    "#lang webracket/base\n"
    "(require webracket/contract)\n"
    "(provide (contract-out [value integer?]))\n"
    "(define/contract value integer? \"web\")\n"
    "(define boundary-value (contract (between/c 0 100) 37 'positive 'negative))\n"
    "(define dependent (->i ([x integer?]) [result integer?]))\n"
    "(define recursive (recursive-contract (listof integer?) #:flat))\n"
    "(js-log (+ (string-length value) boundary-value (if (contract? dependent) 1 0) (if (contract? recursive) 1 0)))\n")
   #rx"(?m:^42$)"))

(module+ main
  (void))
