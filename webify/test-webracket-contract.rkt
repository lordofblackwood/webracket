#lang racket/base

(require racket/file
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         rackunit
         (prefix-in racket-contract: racket/contract)
         (prefix-in erased: "../pkgs/webracket/contract.rkt")
         "test-module-support.rkt")

(define-runtime-path repo-root* "..")
(define repo-root (simplify-path repo-root*))

;; phase-0-export-names : export-table export-table -> (listof symbol?)
;;   Collect value and syntax exports for API-surface comparisons.
(define (phase-0-export-names value-exports syntax-exports)
  (define (names exports)
    (define row (assoc 0 exports))
    (if row (map car (cdr row)) '()))
  (sort (remove-duplicates (append (names value-exports)
                                   (names syntax-exports))
                           eq?)
        symbol<?))

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
           (string->bytes/utf-8 (webracket-collection-env-value)))
          (run-webracket
           (list "-r" "--no-stdlib" "--no-io-format-provider" "--webracket-module-bridge"
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
  (require "../pkgs/webracket/contract.rkt")
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
  (require "../pkgs/webracket/contract.rkt")
  (provide/contract [answer integer?])
  (define answer "not-an-integer"))

(module define-contract-module racket/base
  (require "../pkgs/webracket/contract.rkt")
  (provide value add1-erased)
  (define/contract value integer? "not-an-integer")
  (define/contract (add1-erased x) (-> integer? integer?) (+ x 1)))

(module with-contract-module racket/base
  (require "../pkgs/webracket/contract.rkt")
  (provide value)
  (with-contract here ([value integer?]) ()
    (define value "not-an-integer")))

(module advanced-contract-expression-module racket/base
  (require "../pkgs/webracket/contract.rkt")
  (provide total)
  (define contract-values
    (list (*list/c integer? string?)
          (->d ([x integer?]) () [result integer?])
          any
          (box-immutable/c integer?)
          (channel/c integer?)
          (char-in/c #\a #\z)
          (cons/dc [hd integer?] [tl (hd) integer?])
          (continuation-mark-key/c integer?)
          (contract-exercise integer?)
          (contract-pos/neg-doubling integer?)
          (dynamic->* '() '() any/c)
          (first-or/c integer? string?)
          (flat-contract-with-explanation integer?)
          (flat-murec-contract ([self integer?]) self)
          (flat-rec-contract self integer?)
          (hash/dc [k symbol?] [v (k) integer?])
          (invariant-assertion integer?)
          (list*of integer?)
          (mutable-treelist/c integer?)
          (new-∀/c 'opaque)
          (new-∃/c 'opaque)
          (non-empty-listof integer?)
          (opt/c integer?)
          (prompt-tag/c integer?)
          (property/c length integer?)
          (string-len/c 3)
          (struct-guard/c integer? integer?)
          (struct/dc posn ([x integer?] [y (x) integer?]))
          (syntax/c identifier?)
          (treelist/c integer?)
          (unconstrained-domain-> integer?)
          (values/drop integer? string?)
          (vector-immutable/c integer?)
          (vector-immutableof integer?)
          (with-contract-continuation-mark 'key 'value integer?)))
  (define total (length contract-values)))

(module advanced-contract-definition-module racket/base
  (require "../pkgs/webracket/contract.rkt")
  (provide total)
  (struct/contract posn ([x integer?] [y integer?]))
  (define-struct/contract point ([x integer?] [y integer?]))
  (define-contract-struct cell (value))
  (define total
    (+ (posn-x (posn 10 20))
       (point-y (make-point 1 21))
       (cell-value (make-cell 11)))))

(module advanced-contract-struct-options-module racket/base
  (require "../pkgs/webracket/contract.rkt")
  (provide total)
  (struct/contract base ([x integer?]) #:transparent)
  (struct/contract child base ([y integer?]) #:transparent #:mutable)
  (define-struct/contract parent ([x integer?]) #:transparent)
  (define-struct/contract (kid parent) ([y integer?]) #:transparent)
  (define b (base 10))
  (define c (child 20 1))
  (set-child-y! c 11)
  (define k (make-kid 5 16))
  (define total
    (+ (base-x b)
       (base-x c)
       (child-y c)
       (parent-x k)
       (kid-y k))))

(module erased-semantics-module racket/base
  (require "../pkgs/webracket/contract.rkt")
  (provide total)
  (struct/contract checked-posn ([x integer?] [y integer?]))
  (define bad-value (contract integer? "bad" 'positive 'negative))
  (define/contract bad-defined integer? "also-bad")
  (define bad-posn (checked-posn "x" "y"))
  (define total
    (+ (string-length bad-value)
       (string-length bad-defined)
       (string-length (checked-posn-x bad-posn))
       (string-length (checked-posn-y bad-posn)))))

(require (prefix-in contract-out: (submod "." contract-out-module))
         (prefix-in provide-contract: (submod "." provide-contract-module))
         (prefix-in define-contract: (submod "." define-contract-module))
         (prefix-in with-contract: (submod "." with-contract-module))
         (prefix-in advanced-expression: (submod "." advanced-contract-expression-module))
         (prefix-in advanced-definition: (submod "." advanced-contract-definition-module))
         (prefix-in advanced-struct-options: (submod "." advanced-contract-struct-options-module))
         (prefix-in erased-semantics: (submod "." erased-semantics-module)))

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
  (check-false (erased:contract-first-order-passes? (erased:listof integer?) "not-a-list"))
  (check-true (erased:contract-first-order-passes? (erased:listof integer?) '(1 2 3)))
  (check-false (erased:contract-first-order-passes? (erased:listof integer?) '(1 bad 3)))
  (check-equal? (erased:contract-name (erased:listof integer?)) '(listof integer?))
  (check-equal? (erased:contract-name (erased:flat-named-contract 'evenish even?)) 'evenish)
  (check-true ((erased:flat-contract-predicate (erased:flat-named-contract 'evenish even?)) 4))
  (check-false ((erased:flat-contract-predicate (erased:flat-named-contract 'evenish even?)) 5))
  (check-true (erased:contract-first-order-passes? (erased:and/c integer? (erased:>=/c 0)) 3))
  (check-false (erased:contract-first-order-passes? (erased:and/c integer? (erased:>=/c 0)) -1))
  (check-equal? (erased:contract-name erased:false/c) #f)
  (check-true (erased:contract-first-order-passes? erased:false/c #f))
  (check-false (erased:contract-first-order-passes? erased:false/c 'not-false))
  (check-true (erased:natural-number/c 3))
  (check-false (erased:natural-number/c -1))
  (check-equal? (erased:contract-name erased:natural-number/c) 'natural-number/c)
  (check-true (erased:contract-first-order-passes? (erased:or/c symbol? string?) 'ok))
  (check-true (erased:contract-first-order-passes? (erased:or/c symbol? string?) "ok"))
  (check-false (erased:contract-first-order-passes? (erased:or/c symbol? string?) 42))
  (check-true (erased:contract-first-order-passes? (erased:hash/c symbol? integer?) (hash 'a 1 'b 2)))
  (check-false (erased:contract-first-order-passes? (erased:hash/c symbol? integer?) (hash 'a "bad")))
  (check-true (erased:contract-first-order-passes? (erased:char-in #\a #\b) #\a))
  (check-false (erased:contract-first-order-passes? (erased:char-in #\a #\b) #\z))
  (check-true (erased:contract-first-order-passes? (erased:non-empty-listof integer?) '(1)))
  (check-false (erased:contract-first-order-passes? (erased:non-empty-listof integer?) '()))
  (check-true (erased:contract-first-order-passes? (erased:string-len/c 3) "abc"))
  (check-false (erased:contract-first-order-passes? (erased:string-len/c 3) "abcd"))
  (for ([ctc (in-list (list (erased:list/c integer? string?)
                            (erased:vector/c integer? string?)
                            (erased:vector-immutable/c integer?)
                            (erased:between/c 0 10)
                            (erased:integer-in #f 10)
                            (erased:one-of/c 'a 'b)
                            (erased:symbols 'a 'b)
                            (erased:parameter/c string?)
                            (erased:promise/c integer?)
                            (erased:procedure-arity-includes/c 2)))])
    (check-true (erased:contract? ctc))))

(test-case "webracket/contract exports match racket/contract"
  (define-values (racket-values racket-syntax)
    (module->exports 'racket/contract))
  (define-values (webracket-values webracket-syntax)
    (module->exports
     (make-resolved-module-path
      (simplify-path (build-path repo-root "pkgs" "webracket" "contract.rkt")))))
  (check-equal? (phase-0-export-names webracket-values webracket-syntax)
                (phase-0-export-names racket-values racket-syntax)))

(test-case "syntax-only contract helpers erase to inert contracts"
  (define dependent (erased:->i ([x integer?]) [result integer?]))
  (define recursive (erased:recursive-contract (erased:listof integer?) #:flat))
  (define parametric (erased:parametric->/c [a] (erased:-> a a)))
  (define struct-contract (erased:struct/c posn integer? integer?))
  (for ([ctc (in-list (list dependent recursive parametric struct-contract))])
    (check-true (erased:contract? ctc))))

(test-case "advanced erased contract expression forms are usable"
  (check-equal? advanced-expression:total 35))

(test-case "advanced erased contract definition forms are usable"
  (check-equal? advanced-definition:total 42))

(test-case "advanced erased struct contract forms preserve struct options"
  (check-equal? advanced-struct-options:total 62))

(test-case "erased contracts deliberately do not enforce values"
  (check-equal? erased-semantics:total 13))

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
    "(define list-pass? (contract-first-order-passes? (listof integer?) '(1 2 3)))\n"
    "(define list-fail? (contract-first-order-passes? (listof integer?) '(1 bad 3)))\n"
    "(define vec-pass? (contract-first-order-passes? (vector/c integer? string?) #(1 \"x\")))\n"
    "(define vec-fail? (contract-first-order-passes? (vector/c integer? string?) #(1 2)))\n"
    "(struct/contract posn ([x integer?] [y integer?]))\n"
    "(define-struct/contract point ([x integer?] [y integer?]))\n"
    "(define-contract-struct cell (value))\n"
    "(define contract-values\n"
    "  (list (->d ([x integer?]) () [result integer?])\n"
    "        (dynamic->* '() '() any/c)\n"
    "        (hash/dc [k symbol?] [v (k) integer?])\n"
    "        (struct/dc posn ([x integer?] [y (x) integer?]))\n"
    "        (values/drop integer? string?)\n"
    "        (vector-immutable/c integer?)\n"
    "        (with-contract-continuation-mark 'key 'value integer?)))\n"
    "(js-log (+ (string-length value)\n"
    "           boundary-value\n"
    "           (if (contract? dependent) 1 0)\n"
    "           (if (contract? recursive) 1 0)\n"
    "           (if list-pass? 1 0)\n"
    "           (if list-fail? 100 0)\n"
    "           (if vec-pass? 1 0)\n"
    "           (if vec-fail? 100 0)\n"
    "           (length contract-values)\n"
    "           (posn-x (posn -5 20))\n"
    "           (point-y (make-point 1 -4))\n"
    "           (cell-value (make-cell 0))))\n")
   #rx"(?m:^42$)"))

(test-case "#lang webracket/base substitutes racket/contract with erased provider"
  (run-contract-smoke
   (string-append
    "#lang webracket/base\n"
    "(require (only-in racket/contract\n"
    "                  contract-out define/contract integer-in\n"
    "                  contract-first-order-passes? natural-number/c\n"
    "                  false/c string-len/c))\n"
    "(provide (contract-out [value integer?]))\n"
    "(define/contract value integer? \"web\")\n"
    "(define range-ok? (contract-first-order-passes? (integer-in 0 10) 7))\n"
    "(define range-bad? (contract-first-order-passes? (integer-in 0 10) 99))\n"
    "(define natural-ok? (natural-number/c 5))\n"
    "(define natural-bad? (natural-number/c -1))\n"
    "(define false-ok? (contract-first-order-passes? false/c #f))\n"
    "(define len-ok? (contract-first-order-passes? (string-len/c 3) \"web\"))\n"
    "(js-log (+ (string-length value)\n"
    "           (if range-ok? 27 0)\n"
    "           (if range-bad? 100 1)\n"
    "           (if natural-ok? 2 0)\n"
    "           (if natural-bad? 100 3)\n"
    "           (if false-ok? 4 0)\n"
    "           (if len-ok? 2 0)))\n")
   #rx"(?m:^42$)"))

(test-case "#lang webracket/base substitutes racket/contract/base with erased provider"
  (run-contract-smoke
   (string-append
    "#lang webracket/base\n"
    "(require (only-in racket/contract/base\n"
    "                  and/c contract-first-order-passes?\n"
    "                  contract-name integer-in listof or/c))\n"
    "(define range (integer-in 0 10))\n"
    "(define either (or/c symbol? string?))\n"
    "(define both (and/c integer? range))\n"
    "(define list-pass? (contract-first-order-passes? (listof integer?) '(1 2 3)))\n"
    "(define list-fail? (contract-first-order-passes? (listof integer?) '(1 no 3)))\n"
    "(define either-pass? (contract-first-order-passes? either 'ok))\n"
    "(define both-pass? (contract-first-order-passes? both 7))\n"
    "(js-log (+ (if (equal? (contract-name range) '(integer-in 0 10)) 20 0)\n"
    "           (if list-pass? 10 0)\n"
    "           (if list-fail? 100 1)\n"
    "           (if either-pass? 5 0)\n"
    "           (if both-pass? 6 0)))\n")
   #rx"(?m:^42$)"))

(module+ main
  (void))
