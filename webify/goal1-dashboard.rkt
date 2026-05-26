#lang racket/base

;;; Compact Goal 1 no-stdlib runtime dashboard.
;;;
;;; This is intentionally much smaller than the installed-provider probes. It
;;; answers "does a representative module-language program run without the
;;; legacy stdlib?" and records enough cache information to diagnose slow runs.

(provide goal1-dashboard-case
         goal1-dashboard-case?
         goal1-dashboard-case-name
         goal1-dashboard-case-category
         goal1-dashboard-case-tier
         goal1-dashboard-case-libraries
         goal1-dashboard-case-expectation
         goal1-dashboard-default-timeout-seconds
         goal1-dashboard-default-memory-mb
         goal1-dashboard-cases
         goal1-dashboard-select-cases
         goal1-dashboard-row
         goal1-dashboard-row?
         goal1-dashboard-row-name
         goal1-dashboard-row-category
         goal1-dashboard-row-tier
         goal1-dashboard-row-libraries
         goal1-dashboard-row-expectation
         goal1-dashboard-row-status
         goal1-dashboard-row-detail
         goal1-dashboard-row-note
         goal1-dashboard-row-cache-events
         goal1-dashboard-row-cache-files-before
         goal1-dashboard-row-cache-files-after
         run-goal1-dashboard
         print-goal1-dashboard)

(require json
         racket/cmdline
         racket/file
         racket/list
         racket/match
         racket/path
         racket/runtime-path
         racket/string
         "test-module-support.rkt")

(define-runtime-path repo-root* "..")

(define repo-root
  (simplify-path repo-root*))

(struct goal1-dashboard-case
  (name category tier libraries files main expected args expectation)
  #:transparent)

(struct goal1-dashboard-row
  (name category tier libraries expectation status detail note cache-events cache-files-before cache-files-after)
  #:transparent)

;; dashboard-case : symbol? symbol? list? list? path-string? regexp? list? keyword-args -> goal1-dashboard-case?
;;   Construct a dashboard case with explicit tier and expectation metadata.
(define (dashboard-case name category libraries files main expected args
                              #:tier [tier (case category
                                             [(installed-provider-coverage) 'coverage]
                                             [else 'basic])]
                              #:expectation [expectation 'required])
  (goal1-dashboard-case name category tier libraries files main expected args expectation))

;; dashboard-row : symbol? symbol? list? symbol? symbol? symbol? string? symbol? exact? exact? keyword-args -> goal1-dashboard-row?
;;   Construct a dashboard row with explicit tier metadata.
(define (dashboard-row name category libraries expectation status detail note
                             cache-events cache-files-before cache-files-after
                             #:tier [tier 'basic])
  (goal1-dashboard-row name category tier libraries expectation status detail note
                       cache-events cache-files-before cache-files-after))

;; goal1-dashboard-default-timeout-seconds : exact-positive-integer?
;;   Keep compact dashboard runs bounded by default.
(define goal1-dashboard-default-timeout-seconds 120)

;; goal1-dashboard-default-memory-mb : exact-positive-integer?
;;   Keep compact dashboard runs from exhausting the developer machine.
(define goal1-dashboard-default-memory-mb 1024)

(define goal1-dashboard-cases
  (list
   (dashboard-case
    'base-local-expression
    'local-module-graph
    '(webracket/base)
    `(("main.rkt" . "#lang webracket/base\n(js-log (+ 40 2))\n"))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'base-local-require
    'local-module-graph
    '(webracket/base)
    `(("lib.rkt" . "#lang webracket/base\n(provide add2)\n(define (add2 x) (+ x 2))\n")
      ("main.rkt" . "#lang webracket/base\n(require \"lib.rkt\")\n(js-log (add2 40))\n"))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-generic-sequence
    'local-module-graph
    '(webracket/full)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define xs (for/list ([x (list 1 2 3)]) (+ x 1)))\n"
         "(define ys (for/list ([x (vector 4 5)]) x))\n"
         "(define zs (for/list ([ch \"ab\"]) ch))\n"
         "(define ns (for/list ([i 3]) i))\n"
         "(define bstr #\"az\")\n"
         "(define ht (hash 'a 7 'b 8))\n"
         "(define bs (for/list ([b bstr]) b))\n"
         "(define hs (for/list ([(k v) ht]) v))\n"
         "(js-log (+ (length xs) (length ys) (length zs) (length ns) (length bs) (length hs)))\n")))
    "main.rkt"
    #rx"(?m:^14$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-bool
    'installed-provider-graph
    '(racket/bool)
    `(("main.rkt" . "#lang webracket/full\n(js-log (boolean=? #t (not #f)))\n"))
    "main.rkt"
    #rx"(?m:^true$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-bytes
    'installed-provider-graph
    '(racket/bytes)
    `(("main.rkt" . "#lang webracket/full\n(js-log (bytes-length #\"abc\"))\n"))
    "main.rkt"
    #rx"(?m:^3$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-bytes-more
    'installed-provider-graph
    '(racket/bytes)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define b (bytes 65 66))\n"
         "(bytes-set! b 1 67)\n"
         "(define c (bytes-copy b))\n"
         "(define d (bytes-append c #\"D\"))\n"
         "(define e (list->bytes (bytes->list (subbytes d 1 3))))\n"
         "(js-log (+ (bytes-length d)\n"
         "           (bytes-ref e 0)\n"
         "           (if (bytes=? e #\"CD\") 10 0)\n"
         "           (string-length (bytes->string/utf-8 #\"ok\"))))\n")))
    "main.rkt"
    #rx"(?m:^82$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-list
    'installed-provider-graph
    '(racket/list)
    `(("main.rkt" . "#lang webracket/full\n(js-log (first '(42 99)))\n"))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-string
    'installed-provider-graph
    '(racket/string)
    `(("main.rkt" . "#lang webracket/full\n(js-log (string-join '(\"a\" \"b\") \"\"))\n"))
    "main.rkt"
    #rx"(?m:^ab$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-list-more
    'installed-provider-graph
    '(racket/list)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define xs '(1 2 3 4))\n"
         "(define ys (filter-map (lambda (x) (and (even? x) (+ x 10))) xs))\n"
         "(define zs (append-map (lambda (x) (list x x)) '(5 6)))\n"
         "(js-log (+ (first ys) (length zs) (first (rest ys)) 12))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-local
    'host-expanded-syntax
    '(racket/local)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(js-log (local [(define x 40)] (+ x 2)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-include
    'host-expanded-syntax
    '(racket/include)
    `(("defs.rkt" . "(define x 42)\n")
      ("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(include \"defs.rkt\")\n"
         "(js-log x)\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-vector
    'installed-provider-graph
    '(racket/vector)
    `(("main.rkt" . "#lang webracket/full\n(js-log (vector-member 'b '#(a b c)))\n"))
    "main.rkt"
    #rx"(?m:^1$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'installed-racket-dict
    'installed-provider-graph
    '(racket/dict)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/dict)\n"
         "(define d (hash 'a 40 'b 2))\n"
         "(js-log (+ (dict-ref d 'a) (dict-ref d 'b)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-bool
    'installed-provider-graph
    '(racket/bool)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/bool)\n"
         "(js-log (if (and (xor #t #f) (boolean=? #t #t)) 42 0))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-list
    'installed-provider-graph
    '(racket/list)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/list)\n"
         "(js-log (+ (first '(40 1)) (first (rest '(0 2)))))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-list-coverage
    'installed-provider-coverage
    '(racket/list)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/list)\n"
         "(define xs '(1 2 3 4))\n"
         "(define ys (filter-map (lambda (x) (and (even? x) (+ x 10))) xs))\n"
         "(define zs (append-map (lambda (x) (list x x)) '(5 6)))\n"
         "(js-log (+ (first ys) (length zs) (first (rest ys)) 12))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-string
    'installed-provider-graph
    '(racket/string)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/string)\n"
         "(js-log (if (and (string-prefix? \"web\" \"we\")\n"
         "                 (string-suffix? \"web\" \"eb\"))\n"
         "            42\n"
         "            0))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-string-coverage
    'installed-provider-coverage
    '(racket/string)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/string)\n"
         "(define joined (string-append \"web\" \"racket\"))\n"
         "(js-log (+ (string-length joined)\n"
         "           (if (string-prefix? joined \"web\") 10 0)\n"
         "           (if (string-suffix? joined \"et\") 20 0)\n"
         "           (if (string=? (substring joined 3 6) \"rac\") 3 0)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-string-join
    'installed-provider-coverage
    '(racket/string)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/string)\n"
         "(js-log (string-join '(\"web\" \"racket\") \"\"))\n")))
    "main.rkt"
    #rx"(?m:^webracket$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-vector
    'installed-provider-graph
    '(racket/vector)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/vector)\n"
         "(js-log (+ (vector-member 'b '#(a b c)) 41))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-vector-append
    'installed-provider-coverage
    '(racket/vector)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/vector)\n"
         "(define v (vector-append '#(10 20) '#(12)))\n"
         "(js-log (+ (vector-ref v 0)\n"
         "           (vector-ref v 1)\n"
         "           (vector-ref v 2)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-vector-coverage
    'installed-provider-coverage
    '(racket/vector)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/vector)\n"
         "(define v '#(10 20 12))\n"
         "(js-log (+ (vector-ref v 0)\n"
         "           (vector-ref v 1)\n"
         "           (vector-ref v 2)\n"
         "           (if (equal? (vector-member 20 v) 1) 0 100)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-function
    'installed-provider-graph
    '(racket/function)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/function)\n"
         "(js-log ((compose add1 add1) 40))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-function-coverage
    'installed-provider-coverage
    '(racket/function)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/function)\n"
         "(define p (conjoin exact-integer? (negate zero?)))\n"
         "(define k (const 40))\n"
         "(js-log (+ (k 'ignored)\n"
         "           (if (p 2) 2 0)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'full-function
    'installed-provider-graph
    '(racket/function)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(js-log ((compose add1 add1) 40))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-math
    'installed-provider-graph
    '(racket/math)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(js-log (+ (sqr 5) (sgn -10) 18))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-math-coverage
    'installed-provider-coverage
    '(racket/math)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define x (sqr 5))\n"
         "(define y (sgn -10))\n"
         "(define z (gcd 18 24))\n"
         "(js-log (+ x y z 12))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-path
    'installed-provider-graph
    '(racket/path)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define p (build-path \"alpha\" \"beta\"))\n"
         "(js-log (if (relative-path? p) 42 0))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-path-coverage
    'installed-provider-coverage
    '(racket/path)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define p (build-path \"alpha\" \"beta\" \"gamma.rkt\"))\n"
         "(define name (path->string (file-name-from-path p)))\n"
         "(js-log (+ (string-length name)\n"
         "           (if (relative-path? p) 20 0)\n"
         "           (if (path-has-extension? p #\".rkt\") 13 0)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'installed-racket-port
    'installed-provider-graph
    '(racket/port)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/port)\n"
         "(define s (port->string (open-input-string \"web\")))\n"
         "(js-log (+ (string-length s) 39))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-port-coverage
    'installed-provider-coverage
    '(racket/port)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/port)\n"
         "(define out (open-output-string))\n"
         "(write-string \"web\" out)\n"
         "(define s (get-output-string out))\n"
         "(js-log (+ (string-length s) 39))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-port-display
    'installed-provider-coverage
    '(racket/port)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/port)\n"
         "(define out (open-output-string))\n"
         "(display \"web\" out)\n"
         "(js-log (+ (string-length (get-output-string out)) 39))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-pretty
    'installed-provider-graph
    '(racket/pretty)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/pretty)\n"
         "(js-log (pretty-format '(1 2 3) #:mode 'write))\n")))
    "main.rkt"
    #rx"(?m:^\\(1 2 3\\)$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-pretty-coverage
    'installed-provider-coverage
    '(racket/pretty)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/pretty)\n"
         "(define out (open-output-string))\n"
         "(pretty-write '(\"web\" racket) out #:newline? #f)\n"
         "(js-log (string-append (pretty-format '(1 2) #:mode 'write)\n"
         "                       \"|\"\n"
         "                       (get-output-string out)))\n")))
    "main.rkt"
    #rx"(?m:^\\(1 2\\)\\|\\(\"web\" racket\\)$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-file
    'installed-provider-graph
    '(racket/file)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/file)\n"
         "(display-to-file \"web\" \"/app/data/goal1-file.txt\" 'text 'replace)\n"
         "(js-log (+ (string-length (file->string \"/app/data/goal1-file.txt\")) 39))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'full-shared
    'installed-provider-graph
    '(racket/shared)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define v (shared ([x (cons 40 2)]) x))\n"
         "(js-log (+ (car v) (cdr v)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-reader-graph-containers
    'installed-provider-graph
    '(racket/shared)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define ph (make-placeholder #f))\n"
         "(placeholder-set! ph (box (vector (cons 40 2))))\n"
         "(define v (make-reader-graph ph))\n"
         "(define inner (vector-ref (unbox v) 0))\n"
         "(js-log (+ (car inner) (cdr inner)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-match
    'installed-provider-graph
    '(racket/match)
    `(("main.rkt" . "#lang webracket/full\n(js-log (match '(1 41) [(list _ x) (+ x 1)]))\n"))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-match-coverage
    'installed-provider-coverage
    '(racket/match)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define v (vector 'tag 40 2))\n"
         "(define ht (hash 'a 10 'b 32))\n"
         "(js-log\n"
         " (match (list v ht)\n"
         "   [(list (vector 'tag x y) h)\n"
         "    (+ x y (hash-ref h 'missing 0))]))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-sequence-for
    'installed-provider-graph
    '(racket/sequence)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define from-list (for/sum ([x (in-list '(1 2 3))]) x))\n"
         "(define from-vector (for/sum ([x (in-vector '#(4 5))]) x))\n"
         "(js-log (+ from-list from-vector))\n")))
    "main.rkt"
    #rx"(?m:^15$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-sequence-coverage
    'installed-provider-coverage
    '(racket/sequence)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define a (for/list ([x (in-range 3)]) x))\n"
         "(define b (for/list ([x (in-string \"ab\")]) x))\n"
         "(define c (for/list ([x (in-vector '#(10 20 12))]) x))\n"
         "(js-log (+ (length a)\n"
         "           (length b)\n"
         "           (apply + c)\n"
         "           -5))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-set
    'language-staged-provider
    '(webracket/set)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define s (set-add (set 1 2 2) 3))\n"
         "(js-log (+ (set-count s) (if (set-member? s 2) 10 0)))\n")))
    "main.rkt"
    #rx"(?m:^13$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-set-list
    'language-staged-provider
    '(webracket/set)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define s (set 'a 'b 'c))\n"
         "(js-log (+ (length (set->list s)) (set-count (set-rest s))))\n")))
    "main.rkt"
    #rx"(?m:^5$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-set-variants
    'language-staged-provider
    '(webracket/set)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define immutable (seteq 'a 'b))\n"
         "(define mutable (mutable-seteq 'b 'c))\n"
         "(set-add! mutable 'd)\n"
         "(define symmetric (set-symmetric-difference immutable mutable))\n"
         "(define copied (set-copy immutable))\n"
         "(set-add! copied 'z)\n"
         "(define weak-ok (and (set-weak? (weak-seteq 'w))\n"
         "                     (set-eq? (weak-seteq 'w))))\n"
         "(js-log (+ (set-count symmetric)\n"
         "           (set-count copied)\n"
         "           (if weak-ok 10 0)))\n")))
    "main.rkt"
    #rx"(?m:^16$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-set-coverage
    'installed-provider-coverage
    '(webracket/set)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define a (set 1 2 3))\n"
         "(define b (set 3 4 5))\n"
         "(define u (set-union a b))\n"
         "(define i (set-intersect a b))\n"
         "(define s (set-subtract u i))\n"
         "(js-log (+ (set-count u)\n"
         "           (set-count i)\n"
         "           (set-count s)\n"
         "           (if (subset? i u) 32 100)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-promise
    'language-staged-provider
    '(webracket/promise)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define p (delay (+ 20 22)))\n"
         "(define before (promise-forced? p))\n"
         "(define v (force p))\n"
         "(js-log (+ v (if before 100 0) (if (promise-forced? p) 1 0)))\n")))
    "main.rkt"
    #rx"(?m:^43$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-promise-coverage
    'installed-provider-coverage
    '(webracket/promise)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define count 0)\n"
         "(define p (delay (set! count (+ count 1)) 41))\n"
         "(define a (force p))\n"
         "(define b (force p))\n"
         "(define strict (delay/strict (+ a 1)))\n"
         "(js-log (+ count\n"
         "           (if (promise-forced? p) 0 100)\n"
         "           (if (promise-running? p) 100 0)\n"
         "           (- (force strict) b)))\n")))
    "main.rkt"
    #rx"(?m:^2$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-contract-erased
    'language-staged-provider
    '(webracket/contract)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(provide (contract-out [value integer?]))\n"
         "(define/contract value integer? \"web\")\n"
         "(define boundary-value (contract integer? 39 'positive 'negative))\n"
         "(js-log (+ (string-length value) boundary-value))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'base-make-do-sequence
    'language-staged-provider
    '(racket/private/for webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(define seq\n"
         "  (make-do-sequence\n"
         "   (lambda ()\n"
         "     (values car cdr '(10 20 12) pair? #f #f))))\n"
         "(js-log (for/sum ([x seq]) x))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'staged-stream
    'language-staged-provider
    '(webracket/stream)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require webracket/stream)\n"
         "(define s (stream 10 20 12))\n"
         "(js-log (+ (stream-first s) (stream-first (stream-rest s)) (stream-first (stream-rest (stream-rest s)))))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-stream
    'language-staged-provider
    '(webracket/stream)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define s (stream 10 20 12))\n"
         "(js-log (+ (stream-first s)\n"
         "           (stream-first (stream-rest s))\n"
         "           (stream-first (stream-rest (stream-rest s)))))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-stream-coverage
    'installed-provider-coverage
    '(webracket/stream)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define s (stream 10 20 12))\n"
         "(define xs (stream->list s))\n"
         "(js-log (+ (apply + xs)\n"
         "           (length xs)\n"
         "           (if (stream-empty? empty-stream) -3 100)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-file
    'language-staged-provider
    '(webracket/file)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(display-to-file \"web\" \"/app/data/goal1-full-file.txt\" 'text 'replace)\n"
         "(js-log (+ (string-length (file->string \"/app/data/goal1-full-file.txt\")) 39))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-file-coverage
    'installed-provider-coverage
    '(webracket/file racket/path)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define p \"/app/data/goal1-full-file-coverage.txt\")\n"
         "(display-to-file \"webracket\" p 'text 'replace)\n"
         "(define s (file->string p))\n"
         "(js-log (+ (string-length s)\n"
         "           (if (file-exists? p) 33 100)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'installed-racket-stream
    'installed-provider-graph
    '(racket/stream)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/stream)\n"
         "(define s (stream 10 20 12))\n"
         "(js-log (+ (stream-first s)\n"
         "           (stream-first (stream-rest s))\n"
         "           (stream-first (stream-rest (stream-rest s)))))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-set
    'installed-provider-graph
    '(racket/set)
    `(("main.rkt" . "#lang webracket/base\n(require racket/set)\n(js-log (set-count (set 1 2 2)))\n"))
    "main.rkt"
    #rx"(?m:^2$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-promise
    'installed-provider-graph
    '(racket/promise)
    `(("main.rkt" . "#lang webracket/base\n(require racket/promise)\n(js-log (force (delay (+ 20 22))))\n"))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'full-format
    'installed-provider-graph
    '(racket/format)
    `(("main.rkt" . "#lang webracket/full\n(js-log (format \"fmt ~a\" 'web))\n"))
    "main.rkt"
    #rx"(?m:^fmt web$)"
    '())
   (dashboard-case
    'installed-racket-hash
    'installed-provider-graph
    '(racket/hash racket/contract/base)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/hash)\n"
         "(define merged (hash-union (hash 'a 1) (hash 'b 2)))\n"
         "(js-log (hash-count merged))\n")))
    "main.rkt"
    #rx"(?m:^2$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-hash-coverage
    'installed-provider-coverage
    '(racket/hash racket/contract/base)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/hash)\n"
         "(define h (hash-union (hash 'a 10 'b 20)\n"
         "                      (hash 'c 12)))\n"
         "(define keys (hash-keys-subset? (hash 'a 0) h))\n"
         "(js-log (+ (hash-ref h 'a)\n"
         "           (hash-ref h 'b)\n"
         "           (hash-ref h 'c)\n"
         "           (if keys 0 100)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-format
    'installed-provider-graph
    '(racket/format racket/contract/base)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/format)\n"
         "(js-log (~a 'web #:width 3))\n")))
    "main.rkt"
    #rx"(?m:^web$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-format-coverage
    'installed-provider-coverage
    '(racket/format racket/contract/base)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/format)\n"
         "(js-log (string-append (~a 'web #:width 3)\n"
         "                       \"|\"\n"
         "                       (~s \"racket\")\n"
         "                       \"|\"\n"
         "                       (~v '(1 2))))\n")))
    "main.rkt"
    #rx"(?m:^web\\|\"racket\"\\|\\(1 2\\)$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-data-queue-contract
    'installed-provider-graph
    '(data/queue racket/contract/base)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require data/queue)\n"
         "(define q (make-queue))\n"
         "(enqueue! q 40)\n"
         "(enqueue! q 2)\n"
         "(define before (queue->list q))\n"
         "(js-log (+ (dequeue! q) (dequeue! q) (length before)))\n")))
    "main.rkt"
    #rx"(?m:^44$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-logging
    'installed-provider-graph
    '(racket/logging racket/contract/base)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/logging)\n"
         "(js-log (if log-level/c 42 0))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'ffi-js-math
    'ffi-module
    '(js/math webracket/unsafe/math)
    `(("main.rkt" . "#lang webracket/base\n(require js/math)\n(js-log (math-sqrt 9.0))\n"))
    "main.rkt"
    #rx"(?m:^3$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'ffi-js-console
    'ffi-module
    '(js/console webracket/unsafe/console)
    `(("main.rkt" . "#lang webracket/base\n(require js/console)\n(console-log \"console-module\")\n"))
    "main.rkt"
    #rx"console-module"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'format-provider
    'staged-provider-slice
    '(io/format)
    `(("main.rkt" . "(js-log (format \"fmt ~a\" 'web))\n"))
    "main.rkt"
    #rx"(?m:^fmt web$)"
    '())
   (dashboard-case
    'regexp-provider-literal
    'staged-provider-slice
    '(regexp)
    `(("main.rkt" . "(js-log (regexp-match? #rx\"a+\" \"cat\"))\n"))
    "main.rkt"
    #rx"(?m:^true$)"
    '("--no-io-format-provider"))))

;; split-selectors : (or/c string? #f) -> (listof symbol?)
;;   Parse a comma-separated command-line selector list.
(define (split-selectors value)
  (cond
    [(not value) '()]
    [else
     (for/list ([part (in-list (string-split value ","))]
                #:do [(define trimmed (string-trim part))]
                #:unless (string=? trimmed ""))
       (string->symbol trimmed))]))

;; goal1-dashboard-select-cases : list [#:names list] [#:categories list] [#:tiers list] [#:expectations list] -> list
;;   Select compact dashboard cases by name, category, tier, and/or expectation.
(define (goal1-dashboard-select-cases cases
                                      #:names [names '()]
                                      #:categories [categories '()]
                                      #:tiers [tiers '()]
                                      #:expectations [expectations '()])
  (define name-set (for/hasheq ([name (in-list names)]) (values name #t)))
  (define category-set (for/hasheq ([category (in-list categories)]) (values category #t)))
  (define tier-set (for/hasheq ([tier (in-list tiers)]) (values tier #t)))
  (define expectation-set (for/hasheq ([expectation (in-list expectations)])
                            (values expectation #t)))
  (for/list ([c (in-list cases)]
             #:when (and (or (null? names)
                             (hash-ref name-set (goal1-dashboard-case-name c) #f))
                         (or (null? categories)
                             (hash-ref category-set
                                       (goal1-dashboard-case-category c)
                                       #f))
                         (or (null? tiers)
                             (hash-ref tier-set
                                       (goal1-dashboard-case-tier c)
                                       #f))
                         (or (null? expectations)
                             (hash-ref expectation-set
                                       (goal1-dashboard-case-expectation c)
                                       #f))))
    c))

;; cache-file-count : path? -> exact-nonnegative-integer?
;;   Count provider-cache files recursively.
(define (cache-file-count cache-dir)
  (if (directory-exists? cache-dir)
      (for/sum ([path (in-list (find-files file-exists? cache-dir))]
                #:when (file-exists? path))
        1)
      0))

;; cache-events : string? exact-nonnegative-integer? exact-nonnegative-integer? -> symbol?
;;   Summarize provider-cache diagnostics from a dashboard run.
(define (cache-events output before after)
  (define hit? (regexp-match? #rx"provider-cache: .* hit" output))
  (define miss? (regexp-match? #rx"provider-cache: .* miss" output))
  (cond
    [(and hit? miss?) 'mixed]
    [hit? 'hit]
    [miss? 'miss]
    [(> after before) 'wrote-cache]
    [(positive? after) 'warm-no-event]
    [else 'none]))

;; write-case-files! : path? goal1-dashboard-case? -> path?
;;   Materialize one dashboard case in a temporary source directory.
(define (write-case-files! dir c)
  (for ([entry (in-list (goal1-dashboard-case-files c))])
    (define path (build-path dir (car entry)))
    (make-directory* (or (path-only path) dir))
    (call-with-output-file path
      (lambda (out) (display (cdr entry) out))
      #:exists 'truncate/replace))
  (build-path dir (goal1-dashboard-case-main c)))

;; classify-detail : exact-integer? string? regexp? -> symbol?
;;   Classify a compact dashboard result.
(define (classify-detail status output expected)
  (cond
    [(= status 124) 'timeout]
    [(and (zero? status) (regexp-match? expected output)) 'ok]
    [(zero? status) 'output-mismatch]
    [(regexp-match? #rx"Skipping temporary stdlib/provider prelude for module-language input" output)
     'module-language-prelude-skip-but-failed]
    [(regexp-match? #rx"external provider is not in the Goal 1 trial allowlist|transitive provider is not in the Goal 1 trial allowlist|unsupported providers|unsupported provider" output)
     'provider-graph-failed]
    [(regexp-match? #rx"unbound identifier|undefined" output) 'unbound]
    [else 'failed]))

;; output-note : exact-integer? string? -> string?
;;   Keep one compact diagnostic line for failed dashboard rows.
(define (output-note status output)
  (define normalized
    (string-replace (string-trim output) "\t" " "))
  (cond
    [(string=? normalized "") (format "exit ~a with no output" status)]
    [else
     (define lines
       (filter
        (lambda (line)
          (not (regexp-match? #rx"^provider-cache: cache directory:" line)))
        (string-split normalized "\n")))
     (define diagnostic-line
       (for/first ([line (in-list lines)]
                   #:when (regexp-match?
                            #rx"unsupported provider|unsupported providers|missing-after-reflection|ambiguous-after-reflection"
                            line))
         line))
     (define line (or diagnostic-line
                      (if (null? lines)
                          (first (string-split normalized "\n"))
                          (first lines))))
     (if (> (string-length line) 300)
         (string-append (substring line 0 297) "...")
         line)]))

;; run-goal1-dashboard-case : case path? exact-positive-integer? exact-positive-integer? -> row
;;   Run one compact Goal 1 case through `webracket.rkt -r --no-stdlib`.
(define (run-goal1-dashboard-case c cache-dir timeout-seconds memory-mb)
  (define source-dir (make-temporary-file "webracket-goal1-dashboard-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-goal1-dashboard-dest-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define source-path (write-case-files! source-dir c))
      (define before (cache-file-count cache-dir))
      (define-values (status output)
        (parameterize ([current-environment-variables
                        (environment-variables-copy
                         (current-environment-variables))])
          (environment-variables-set!
           (current-environment-variables)
           #"PLTCOLLECTS"
           (string->bytes/utf-8 (webracket-collection-env-value)))
          (run-webracket
           (append
            (list "-v" "-r" "--no-stdlib"
                  "--provider-cache-dir" (path->string cache-dir)
                  "--dest" (path->string dest-dir))
            (goal1-dashboard-case-args c)
            (list (path->string source-path)))
           source-dir
           #:timeout-seconds timeout-seconds
           #:memory-mb memory-mb)))
      (define after (cache-file-count cache-dir))
      (define detail
        (classify-detail status output (goal1-dashboard-case-expected c)))
      (define expectation (goal1-dashboard-case-expectation c))
      (dashboard-row
       (goal1-dashboard-case-name c)
       (goal1-dashboard-case-category c)
       (goal1-dashboard-case-libraries c)
       expectation
       (cond
         [(eq? detail 'ok) 'pass]
         [(eq? expectation 'diagnostic) 'expected-fail]
         [else 'fail])
       detail
       (if (eq? detail 'ok) "" (output-note status output))
       (cache-events output before after)
       before
       after
       #:tier (goal1-dashboard-case-tier c)))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

;; run-goal1-dashboard : keyword-args -> (listof goal1-dashboard-row?)
;;   Run the compact Goal 1 no-stdlib dashboard.
(define (run-goal1-dashboard #:cache-dir [cache-dir (make-temporary-file "webracket-goal1-dashboard-cache-~a" 'directory)]
                             #:timeout-seconds [timeout-seconds goal1-dashboard-default-timeout-seconds]
                             #:memory-mb [memory-mb goal1-dashboard-default-memory-mb]
                             #:cases [cases goal1-dashboard-cases])
  (for/list ([c (in-list cases)])
    (run-goal1-dashboard-case c cache-dir timeout-seconds memory-mb)))

(define (row->jsexpr row)
  (hasheq 'name (symbol->string (goal1-dashboard-row-name row))
          'category (symbol->string (goal1-dashboard-row-category row))
          'tier (symbol->string (goal1-dashboard-row-tier row))
          'libraries (map symbol->string (goal1-dashboard-row-libraries row))
          'expectation (symbol->string (goal1-dashboard-row-expectation row))
          'status (symbol->string (goal1-dashboard-row-status row))
          'detail (symbol->string (goal1-dashboard-row-detail row))
          'note (goal1-dashboard-row-note row)
          'cache_events (symbol->string (goal1-dashboard-row-cache-events row))
          'cache_files_before (goal1-dashboard-row-cache-files-before row)
          'cache_files_after (goal1-dashboard-row-cache-files-after row)))

;; print-goal1-dashboard : keyword-args -> void?
;;   Print compact Goal 1 no-stdlib dashboard rows.
(define (print-goal1-dashboard #:tsv? [tsv? #f]
                               #:json? [json? #f]
                               #:list? [list? #f]
                               #:cache-dir [cache-dir #f]
                               #:timeout-seconds [timeout-seconds goal1-dashboard-default-timeout-seconds]
                               #:memory-mb [memory-mb goal1-dashboard-default-memory-mb]
                               #:case-names [case-names '()]
                               #:categories [categories '()]
                               #:tiers [tiers '()]
                               #:expectations [expectations '()])
  (define selected-cases
    (goal1-dashboard-select-cases goal1-dashboard-cases
                                  #:names case-names
                                  #:categories categories
                                  #:tiers tiers
                                  #:expectations expectations))
  (cond
    [list?
     (for ([c (in-list selected-cases)])
       (printf "~a\tcategory\t~a\ttier\t~a\texpectation\t~a\tlibraries\t~a\n"
               (goal1-dashboard-case-name c)
               (goal1-dashboard-case-category c)
               (goal1-dashboard-case-tier c)
               (goal1-dashboard-case-expectation c)
               (string-join (map symbol->string (goal1-dashboard-case-libraries c))
                            ",")))]
    [else
     (define actual-cache-dir
       (or cache-dir
           (make-temporary-file "webracket-goal1-dashboard-cache-~a" 'directory)))
     (define rows
       (run-goal1-dashboard #:cache-dir actual-cache-dir
                            #:timeout-seconds timeout-seconds
                            #:memory-mb memory-mb
                            #:cases selected-cases))
     (cond
       [json?
        (write-json (map row->jsexpr rows))
        (newline)]
       [else
        (when tsv?
          (displayln
           "name\tcategory\ttier\tlibraries\texpectation\tstatus\tdetail\tnote\tcache-events\tcache-files-before\tcache-files-after"))
        (for ([row (in-list rows)])
          (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
                  (goal1-dashboard-row-name row)
                  (goal1-dashboard-row-category row)
                  (goal1-dashboard-row-tier row)
                  (string-join (map symbol->string (goal1-dashboard-row-libraries row))
                               ",")
                  (goal1-dashboard-row-expectation row)
                  (goal1-dashboard-row-status row)
                  (goal1-dashboard-row-detail row)
                  (goal1-dashboard-row-note row)
                  (goal1-dashboard-row-cache-events row)
                  (goal1-dashboard-row-cache-files-before row)
                  (goal1-dashboard-row-cache-files-after row)))])]))

(module+ main
  (define tsv? #f)
  (define json? #f)
  (define list? #f)
  (define cache-dir #f)
  (define timeout-seconds goal1-dashboard-default-timeout-seconds)
  (define memory-mb goal1-dashboard-default-memory-mb)
  (define case-names '())
  (define categories '())
  (define tiers '())
  (define expectations '())
  (command-line
   #:once-each
   [("--tsv") "print TSV rows" (set! tsv? #t)]
   [("--json") "print JSON rows" (set! json? #t)]
   [("--list") "list compact dashboard cases without running them" (set! list? #t)]
   [("--provider-cache-dir") dir "provider cache directory"
                             (set! cache-dir (string->path dir))]
   [("--timeout") n "per-case timeout in seconds"
                  (set! timeout-seconds (string->number n))]
   [("--memory-mb") n "per-case memory limit in MiB"
                    (set! memory-mb (string->number n))]
   [("--case") names "comma-separated case names to run/list"
               (set! case-names (split-selectors names))]
   [("--category") names "comma-separated categories to run/list"
                   (set! categories (split-selectors names))]
   [("--tier") names "comma-separated tiers to run/list"
               (set! tiers (split-selectors names))]
   [("--expectation") names "comma-separated expectations to run/list"
                      (set! expectations (split-selectors names))]
   [("--required") "run/list only required rows"
                   (set! expectations '(required))]
   [("--fast-required") "run/list the basic required inner-loop rows"
                        (set! tiers '(basic))
                        (set! expectations '(required))])
  (print-goal1-dashboard #:tsv? tsv?
                         #:json? json?
                         #:list? list?
                         #:cache-dir cache-dir
                         #:timeout-seconds timeout-seconds
                         #:memory-mb memory-mb
                         #:case-names case-names
                         #:categories categories
                         #:tiers tiers
                         #:expectations expectations))
