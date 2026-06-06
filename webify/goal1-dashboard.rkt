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
         goal1-dashboard-case-args
         goal1-dashboard-case-module-language?
         goal1-dashboard-module-bridge-arg
         goal1-dashboard-default-timeout-seconds
         goal1-dashboard-default-memory-mb
         goal1-dashboard-default-jobs
         goal1-dashboard-default-cache-warmup-timeout-seconds
         goal1-dashboard-fast-required-case-names
         goal1-dashboard-coverage-core-case-names
         goal1-dashboard-coverage-extended-case-names
         goal1-dashboard-composition-case-names
         goal1-dashboard-checkpoint-case-names
         goal1-dashboard-real-provider-readiness-case-names
         goal1-dashboard-composition-timeout-seconds
         goal1-dashboard-recommended-timeout-seconds
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
         classify-detail
         warm-goal1-dashboard-provider-cache!
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

;; goal1-dashboard-module-bridge-arg : string?
;;   Driver flag that keeps module-language dashboard rows on the module bridge.
(define goal1-dashboard-module-bridge-arg "--webracket-module-bridge")

;; webracket-module-language-source? : string? -> boolean?
;;   Check whether source text starts with a WebRacket module language.
(define (webracket-module-language-source? source)
  (regexp-match? #px"(?m:^#lang\\s+webracket/(base|full)(\\s|$))" source))

;; goal1-dashboard-case-module-language? : goal1-dashboard-case? -> boolean?
;;   Check whether a dashboard case contains WebRacket module-language source.
(define (goal1-dashboard-case-module-language? c)
  (for/or ([entry (in-list (goal1-dashboard-case-files c))])
    (webracket-module-language-source? (cdr entry))))

;; ensure-module-bridge-arg : (listof string?) boolean? -> (listof string?)
;;   Route module-language rows through the module bridge by default.
(define (ensure-module-bridge-arg args module-language?)
  (cond
    [(or (not module-language?)
         (member goal1-dashboard-module-bridge-arg args))
     args]
    [else
     (append args (list goal1-dashboard-module-bridge-arg))]))

;; dashboard-case : symbol? symbol? list? list? path-string? regexp? list? keyword-args -> goal1-dashboard-case?
;;   Construct a dashboard case with explicit tier and expectation metadata.
(define (dashboard-case name category libraries files main expected args
                              #:tier [tier (case category
                                             [(installed-provider-coverage) 'coverage]
                                             [else 'basic])]
                              #:expectation [expectation 'required])
  (define module-language?
    (for/or ([entry (in-list files)])
      (webracket-module-language-source? (cdr entry))))
  (goal1-dashboard-case name
                        category
                        tier
                        libraries
                        files
                        main
                        expected
                        (ensure-module-bridge-arg args module-language?)
                        expectation))

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

;; goal1-dashboard-default-jobs : exact-positive-integer?
;;   Keep command-line behavior serial unless parallelism is requested.
(define goal1-dashboard-default-jobs 1)

;; goal1-dashboard-default-cache-warmup-timeout-seconds : exact-positive-integer?
;;   Give cold provider-cache construction more room than an individual row.
(define goal1-dashboard-default-cache-warmup-timeout-seconds 480)

;; goal1-dashboard-composition-timeout-seconds : exact-positive-integer?
;;   Suggested per-row timeout for heavyweight cross-provider composition rows.
(define goal1-dashboard-composition-timeout-seconds 240)

;; goal1-dashboard-fast-required-case-names : (listof symbol?)
;;   Tiny inner-loop preset for checking the main routes quickly.
(define goal1-dashboard-fast-required-case-names
  '(base-local-expression
    full-generic-sequence
    installed-racket-list
    full-set
    ffi-js-math
    regexp-provider-literal))

;; goal1-dashboard-coverage-core-case-names : (listof symbol?)
;;   Everyday coverage preset for the highest-value curated surface.
(define goal1-dashboard-coverage-core-case-names
  '(installed-racket-list-coverage
    installed-racket-list-shim-coverage
    installed-racket-list-edge-coverage
    installed-racket-list-easy-coverage
    installed-racket-list-expanded-coverage
    installed-racket-string-coverage
    installed-racket-string-join
    real-racket-string-coverage
    full-bytes-coverage
    installed-racket-bool-coverage
    installed-racket-vector-coverage
    installed-racket-function-coverage
    installed-racket-port-coverage
    installed-racket-port-display
    full-math-coverage
    full-path-coverage
    full-match-coverage
    installed-racket-match-explicit
    goal1-full-callable-exports
    goal1-full-list-surface
    goal1-base-sort-keywords
    goal1-vector-sort-keywords
    base-sequence-core
    real-racket-sequence-coverage
    base-sequence-producers
    base-sequence-real-libraries
    base-sequence-hash-generate
    base-sequence-custom
    base-sequence-port-edges
    base-for-result-builders
    base-for-nested-control-coverage
    base-sequence-mpair
    base-sequence-ports
    base-sequence-prop
    base-sequence-prop-gen
    base-sequence-derived
    base-sequence-early-next
    base-sequence-add-between-lazy
    base-sequence-coverage
    full-sequence-coverage
    sequence-directory-coverage
    full-set-coverage
    full-promise-coverage
    full-stream-lazy
    full-stream-lazy-map
    full-stream-coverage
    full-file-coverage
    installed-racket-format-coverage
    installed-racket-format-printing
    installed-racket-format-printing-values
    installed-racket-format-print-parameter
    installed-racket-format-rational-precision
    regexp-provider-coverage))

;; goal1-dashboard-coverage-extended-case-names : (listof symbol?)
;;   Broader coverage preset for slower provider/FFI confidence checks.
(define goal1-dashboard-coverage-extended-case-names
  '(installed-racket-vector-append
    full-shared-coverage
    installed-racket-pretty-coverage
    installed-racket-pretty-style-coverage
    installed-racket-hash-coverage
    installed-racket-dict-coverage
    installed-racket-dict-extra-coverage
    installed-racket-file-coverage
    installed-data-queue-coverage
    installed-racket-logging-coverage
    full-class-coverage
    installed-racket-class-basic-coverage
    installed-racket-class-advanced-coverage
    installed-racket-unit-basic-coverage
    installed-racket-unit-compound-coverage
    installed-racket-unit-infer-coverage
    installed-racket-unit-prefix-rename-coverage
    full-unit-coverage
    ffi-js-array-coverage
    ffi-js-math-coverage
    ffi-js-performance-coverage
    ffi-js-standard-coverage
    ffi-js-temp-coverage
    ffi-js-console-coverage))

;; goal1-dashboard-composition-case-names : (listof symbol?)
;;   Heavy cross-provider rows for checkpoint confidence, not the everyday loop.
(define goal1-dashboard-composition-case-names
  '(goal1-real-library-composition
    goal1-sequence-format-composition
    goal1-match-set-hash-composition
    goal1-dict-pretty-sequence-composition))

;; goal1-dashboard-checkpoint-case-names : (listof symbol?)
;;   Larger required checkpoint preset: ordinary coverage plus composition.
(define goal1-dashboard-checkpoint-case-names
  (append goal1-dashboard-coverage-core-case-names
          goal1-dashboard-coverage-extended-case-names
          goal1-dashboard-composition-case-names))

;; goal1-dashboard-real-provider-readiness-case-names : (listof symbol?)
;;   Expected-fail rows that show which staged substitutions are replacement candidates.
(define goal1-dashboard-real-provider-readiness-case-names
  '(real-racket-dict-diagnostic
    real-racket-dict-coverage-diagnostic
    real-racket-function-diagnostic
    real-racket-function-coverage-diagnostic
    real-racket-list-diagnostic
    real-racket-private-for-diagnostic
    real-racket-private-kw-diagnostic
    real-racket-class-diagnostic
    real-racket-class-rich-diagnostic
    real-racket-class-error-diagnostic
    real-racket-contract-diagnostic
    real-racket-pretty-diagnostic
    real-racket-pretty-coverage-diagnostic))

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
    'full-bytes-coverage
    'installed-provider-coverage
    '(racket/bytes)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define b (bytes 65 66 67 68))\n"
         "(bytes-set! b 1 90)\n"
         "(define c (subbytes b 1 4))\n"
         "(define d (bytes-append #\"A\" c))\n"
         "(js-log (+ (bytes-length d)\n"
         "           (bytes-ref d 1)\n"
         "           (if (bytes=? d #\"AZCD\") -52 100)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-class
    'installed-provider-graph
    '(racket/class)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define point%\n"
         "  (class object%\n"
         "    (super-new)\n"
         "    (define/public (value) 42)))\n"
         "(js-log (send (new point%) value))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '())
   (dashboard-case
    'full-class-coverage
    'language-full
    '(webracket/full racket/class)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define valued<%> (interface () value next))\n"
         "(define base%\n"
         "  (class object%\n"
         "    (init-field [n 30])\n"
         "    (super-new)\n"
         "    (define/public (value) n)\n"
         "    (define/public (next) (+ (value) 1))))\n"
         "(define child%\n"
         "  (class* base% (valued<%>)\n"
         "    (init-field [delta 10])\n"
         "    (super-new)\n"
         "    (inherit value)\n"
         "    (define/override (next) (+ (super next) delta))))\n"
         "(define obj (new child% [n 39] [delta 2]))\n"
         "(define final%\n"
         "  (class object%\n"
         "    (super-new)\n"
         "    (define/public-final (sealed) 5)))\n"
         "(define caught\n"
         "  (with-handlers ([(lambda (e) #t) (lambda (e) 1)])\n"
         "    (class final%\n"
         "      (super-new)\n"
         "      (define/override (sealed) 6))\n"
         "    0))\n"
         "(js-log (+ (if (is-a? obj valued<%>) 1 0)\n"
         "           (if (is-a? obj child%) 2 0)\n"
         "           (send obj value)\n"
         "           (send obj next)\n"
         "           caught\n"
         "           -43))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--webracket-module-bridge")
    #:tier 'coverage)
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
    'installed-racket-dict-coverage
    'installed-provider-coverage
    '(racket/dict)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/dict)\n"
         "(define d (hash 'a 10 'b 20 'c 12))\n"
         "(define total 0)\n"
         "(for ([p (in-dict-pairs d)]) (set! total (+ total (cdr p))))\n"
         "(define mapped-values (dict-map d (lambda (k v) v)))\n"
         "(define updated (dict-update d 'a add1))\n"
         "(define rem (dict-remove updated 'b))\n"
         "(define copied (dict-map/copy rem (lambda (k v) (values k v))))\n"
         "(js-log (if (and (pair? mapped-values)\n"
         "                 (dict-can-functional-set? d)\n"
         "                 (dict-can-remove-keys? d)\n"
         "                 (= (dict-ref copied 'a) 11))\n"
         "            total\n"
         "            0))\n")))
   "main.rkt"
   #rx"(?m:^42$)"
   '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-dict-extra-coverage
    'installed-provider-coverage
    '(racket/dict)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/dict)\n"
         "(define (sum x y) (+ x y))\n"
         "(define kw-total\n"
         "  (keyword-apply/dict sum (hash) 20 '(22)))\n"
         "(define vector-key-ok ((dict-key-contract '#(a b)) 1))\n"
         "(define value-ok ((dict-value-contract (hash 'a 1)) 'anything))\n"
         "(define iter-ok ((dict-iter-contract '((a . 1))) (dict-iterate-first '((a . 1)))))\n"
         "(js-log (if (and vector-key-ok value-ok iter-ok) kw-total 0))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'real-racket-dict-diagnostic
    'installed-provider-diagnostic
    '(racket/dict)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/dict)\n"
         "(js-log (dict-count (hash 'a 1)))\n")))
    "main.rkt"
    #rx"(?m:^1$)"
   '("--no-io-format-provider" "--webracket-module-bridge" "--no-provider-substitutions")
   #:tier 'coverage
   #:expectation 'diagnostic)
   (dashboard-case
    'real-racket-dict-coverage-diagnostic
    'installed-provider-diagnostic
    '(racket/dict)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/dict)\n"
         "(define d (hash 'a 10 'b 20 'c 12))\n"
         "(define total 0)\n"
         "(for ([p (in-dict-pairs d)]) (set! total (+ total (cdr p))))\n"
         "(define mapped-values (dict-map d (lambda (k v) v)))\n"
         "(define updated (dict-update d 'a add1))\n"
         "(define rem (dict-remove updated 'b))\n"
         "(define copied (dict-map/copy rem (lambda (k v) (values k v))))\n"
         "(js-log (if (and (pair? mapped-values)\n"
         "                 (dict-can-functional-set? d)\n"
         "                 (dict-can-remove-keys? d)\n"
         "                 (= (dict-ref copied 'a) 11))\n"
         "            total\n"
         "            0))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage
    #:expectation 'diagnostic)
   (dashboard-case
    'real-racket-list-diagnostic
    'installed-provider-diagnostic
    '(racket/list)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/list)\n"
         "(define xs '(1 2 3 4 5))\n"
         "(define mapped (filter-map (lambda (x) (and (odd? x) x)) xs))\n"
         "(define prefix (take xs 2))\n"
         "(define suffix (drop xs 3))\n"
         "(define-values (left right) (split-at xs 3))\n"
         "(define groups (group-by odd? xs))\n"
         "(define unique (remove-duplicates '(1 2 1 3 2)))\n"
         "(js-log (+ (apply + (append-map (lambda (x) (list x x)) '(10 11)))\n"
         "           (length mapped)\n"
         "           (apply + prefix)\n"
         "           (apply + suffix)\n"
         "           (length left)\n"
         "           (length right)\n"
         "           (length groups)\n"
         "           (length unique)\n"
         "           -25))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage
    #:expectation 'diagnostic)
   (dashboard-case
    'installed-racket-bool-coverage
    'installed-provider-coverage
    '(racket/bool)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/bool)\n"
         "(define ok?\n"
         "  (and (xor #t #f)\n"
         "       (boolean=? #t (not #f))\n"
         "       (symbol=? 'web 'web)\n"
         "       (false? #f)))\n"
         "(js-log (if ok? 42 0))\n")))
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
    'installed-racket-list-shim-coverage
    'installed-provider-coverage
    '(racket/list webracket/list)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/list)\n"
         "(define xs '(1 2 3 4 5))\n"
         "(define-values (small large) (partition (lambda (x) (< x 4)) xs))\n"
         "(define-values (front back) (split-at xs 2))\n"
         "(define r (range 2 7 2))\n"
         "(define ir (inclusive-range 1 5 2))\n"
         "(define cleaned (remove* '(2 4) xs))\n"
         "(define pair (assoc 'b '((a . 10) (b . 20))))\n"
         "(js-log (+ (length small)\n"
         "           (length large)\n"
         "           (first back)\n"
         "           (first (drop xs 4))\n"
         "           (first r)\n"
         "           (second r)\n"
         "           (last ir)\n"
         "           (length cleaned)\n"
         "           (cdr pair)\n"
         "           -5))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-list-edge-coverage
    'installed-provider-coverage
    '(racket/list webracket/list)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/list)\n"
         "(define down (range 5 0 -2))\n"
         "(define inclusive-down (inclusive-range 5 1 -2))\n"
         "(define fm (filter-map (lambda (x y) (and (odd? x) (+ x y))) '(1 2 3) '(10 20 30)))\n"
         "(define am (append-map (lambda (x y) (list x y)) '(1 2) '(3 4)))\n"
         "(define member-score (length (member \"B\" '(\"a\" \"b\" \"c\") string-ci=?)))\n"
         "(define assoc-score (cdr (assoc \"B\" '((\"a\" . 1) (\"b\" . 7)) string-ci=?)))\n"
         "(define removed (remove \"B\" '(\"a\" \"b\" \"B\") string-ci=?))\n"
         "(define remove-score (if (string=? (second removed) \"B\") 5 0))\n"
         "(define last-score (cdr (last-pair '(1 2 . 3))))\n"
         "(js-log (+ (apply + down)\n"
         "           (apply + inclusive-down)\n"
         "           (apply + fm)\n"
         "           (apply + am)\n"
         "           member-score\n"
         "           assoc-score\n"
         "           remove-score\n"
         "           last-score\n"
         "           -47))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-list-easy-coverage
    'installed-provider-coverage
    '(racket/list webracket/list)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/list)\n"
         "(define xs '(1 2 3 4 5))\n"
         "(define odds (filter-not even? xs))\n"
         "(define flattened (flatten '((1) (2 . 3) () 4)))\n"
         "(define-values (taken dropped) (splitf-at xs (lambda (x) (< x 4))))\n"
         "(define-values (kept-right tail-right) (splitf-at-right xs (lambda (x) (> x 3))))\n"
         "(define idxs (indexes-where xs odd?))\n"
         "(define rem1 (remf even? xs))\n"
         "(define rem2 (remf* odd? xs))\n"
         "(js-log (+ (count odd? xs)\n"
         "           (apply + odds)\n"
         "           (apply + flattened)\n"
         "           (length taken)\n"
         "           (first dropped)\n"
         "           (length kept-right)\n"
         "           (apply + tail-right)\n"
         "           (index-of xs 4)\n"
         "           (index-where xs (lambda (x) (= x 5)))\n"
         "           (apply + idxs)\n"
         "           (apply + rem1)\n"
         "           (apply + rem2)\n"
         "           (length (append* '((1) (2 3))))\n"
         "           (if (empty? empty) 1 0)\n"
         "           -35))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-list-expanded-coverage
    'installed-provider-coverage
    '(racket/list webracket/list)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/list)\n"
         "(define cp (cartesian-product '(1 2) '(10 20)))\n"
         "(define combos (combinations '(a b c) 2))\n"
         "(define perms (permutations '(x x)))\n"
         "(define-values (prefix left right) (split-common-prefix '(a b c) '(a b d e)))\n"
         "(define-values (drop-left drop-right*) (drop-common-prefix '(a b c) '(a b d e)))\n"
         "(define updated (list-update '(1 2 3) 2 (lambda (x) (+ x 2))))\n"
         "(define grouped (group-by (lambda (x) (modulo x 3)) '(1 2 54 5 0)))\n"
         "(define between (add-between '(1 2 3) 10))\n"
         "(define spliced (add-between '(1 2 3) '(4) #:splice? #t #:before-first '(5) #:before-last '(6) #:after-last '(7)))\n"
         "(define unique (remove-duplicates '((1 a) (1 b) (2 c)) = #:key car))\n"
         "(define dup (check-duplicates '(\"A\" \"a\" \"B\") string-ci=? #:key values))\n"
         "(define none (check-duplicates '(1 2 3) #:default 'none))\n"
         "(define shuffled (shuffle '(1 2 3)))\n"
         "(js-log (+ (length cp)\n"
         "           (length combos)\n"
         "           (length perms)\n"
         "           (length prefix)\n"
         "           (length drop-left)\n"
         "           (length drop-right*)\n"
         "           (second (list-set '(1 2 3) 1 9))\n"
         "           (third updated)\n"
         "           (car (argmax car '((3 pears) (1 banana) (2 apples))))\n"
         "           (car (argmin car '((3 pears) (1 banana) (2 apples))))\n"
         "           (length grouped)\n"
         "           (if (list-prefix? '(a b) '(a b c)) 1 0)\n"
         "           (if (cons? '(ok)) 1 0)\n"
         "           (eleventh '(1 2 3 4 5 6 7 8 9 10 11))\n"
         "           (length (for/list ([x (in-combinations '(a b c) 2)]) x))\n"
         "           (length (for/list ([x (in-permutations '(x x))]) x))\n"
         "           (apply + between)\n"
         "           (apply + spliced)\n"
         "           (length unique)\n"
         "           (string-length dup)\n"
         "           (if (eq? none 'none) 3 0)\n"
         "           (length shuffled)\n"
         "           (if (and (member 1 shuffled) (member 2 shuffled) (member 3 shuffled)) 0 100)\n"
         "           -74))\n")))
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
    'real-racket-string-coverage
    'installed-provider-coverage
    '(racket/string)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/string)\n"
         "(define joined (string-join '(\"web\" \"racket\") \"\"))\n"
         "(define split (string-split \"a,b,c\" \",\"))\n"
         "(define trimmed (string-trim \"  web  \"))\n"
         "(define replaced (string-replace \"web-racket\" \"-\" \"\"))\n"
         "(define ok?\n"
         "  (and (string-prefix? \"webracket\" \"web\")\n"
         "       (string-suffix? \"webracket\" \"ket\")\n"
         "       (equal? joined \"webracket\")\n"
         "       (equal? trimmed \"web\")\n"
         "       (equal? replaced \"webracket\")))\n"
         "(js-log (if ok? (+ (length split) 39) 0))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage
    #:expectation 'required)
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
    'real-racket-function-diagnostic
    'installed-provider-diagnostic
    '(racket/function)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/function)\n"
         "(js-log ((compose add1 add1) 40))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage
    #:expectation 'diagnostic)
   (dashboard-case
    'real-racket-function-coverage-diagnostic
    'installed-provider-diagnostic
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
    '("--no-io-format-provider" "--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage
    #:expectation 'diagnostic)
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
    'full-shared-coverage
    'installed-provider-coverage
    '(racket/shared)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define ph (make-placeholder #f))\n"
         "(placeholder-set! ph (vector (cons 10 32)))\n"
         "(define v (make-reader-graph ph))\n"
         "(define p (vector-ref v 0))\n"
         "(define s (shared ([x (cons 20 22)]) x))\n"
         "(js-log (+ (car p) (cdr p) (car s) (cdr s) -42))\n")))
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
    'installed-racket-math
    'installed-provider-graph
    '(racket/math)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/math)\n"
         "(js-log (+ (sqr 5) (sgn -10) 18))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
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
    'installed-racket-path
    'installed-provider-graph
    '(racket/path)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/path)\n"
         "(define p (build-path \"alpha\" \"beta\"))\n"
         "(js-log (if (relative-path? p) 42 0))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
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
         "(pretty-print-columns 'infinity)\n"
         "(pretty-write '(\"web\" racket) out #:newline? #f)\n"
         "(js-log (string-append (pretty-format '(1 2) #:mode 'write)\n"
         "                       \"|\"\n"
         "                       (get-output-string out)))\n")))
   "main.rkt"
   #rx"(?m:^\\(1 2\\)\\|\\(\"web\" racket\\)$)"
   '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-pretty-style-coverage
    'installed-provider-coverage
    '(racket/pretty)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/pretty)\n"
         "(define table (pretty-print-extend-style-table #f '(lambda) '(lambda)))\n"
         "(define out (open-output-string))\n"
         "(pretty-print-newline out 0)\n"
         "(js-log (+ (if (pretty-print-style-table? table) 20 0)\n"
         "           (string-length (get-output-string out))\n"
         "           (if (procedure? (pretty-print-remap-stylable)) 21 0)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'real-racket-pretty-diagnostic
    'installed-provider-diagnostic
    '(racket/pretty)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/pretty)\n"
         "(js-log (pretty-format '(1 2) #:mode 'write))\n")))
    "main.rkt"
    #rx"(?m:^\\(1 2\\)$)"
   '("--no-io-format-provider" "--webracket-module-bridge" "--no-provider-substitutions")
   #:tier 'coverage
   #:expectation 'diagnostic)
   (dashboard-case
    'real-racket-pretty-coverage-diagnostic
    'installed-provider-diagnostic
    '(racket/pretty)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/pretty)\n"
         "(define out (open-output-string))\n"
         "(pretty-print-columns 'infinity)\n"
         "(pretty-write '(\"web\" racket) out #:newline? #f)\n"
         "(js-log (string-append (pretty-format '(1 2) #:mode 'write)\n"
         "                       \"|\"\n"
         "                       (get-output-string out)))\n")))
    "main.rkt"
    #rx"(?m:^\\(1 2\\)\\|\\(\"web\" racket\\)$)"
    '("--no-io-format-provider" "--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage
    #:expectation 'diagnostic)
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
    'installed-racket-file-coverage
    'installed-provider-coverage
    '(racket/file)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/file)\n"
         "(define p \"/app/data/goal1-installed-file-coverage.txt\")\n"
         "(write-to-file \"webracket\" p 'text 'replace)\n"
         "(define text (file->string p 'text))\n"
         "(define bytes (file->bytes p))\n"
         "(js-log (+ (string-length text)\n"
         "           (bytes-length bytes)\n"
         "           (if (file-exists? p) 20 100)))\n")))
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
    'installed-racket-match-explicit
    'installed-provider-coverage
    '(racket/match racket/match/runtime racket/match/gen-match)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/match)\n"
         "(define v '(tag 20 22))\n"
         "(js-log (match v\n"
         "          [(list 'tag x y) (+ x y)]\n"
         "          [_ 0]))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'goal1-real-library-composition
    'installed-provider-coverage
    '(webracket/full racket/string racket/hash racket/set racket/function racket/format
      webracket/hash webracket/set)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(require racket/string racket/hash racket/set racket/function racket/format)\n"
         "(define xs '(2 4 6))\n"
         "(define labels (map ~a xs))\n"
         "(define joined (string-join labels \":\"))\n"
         "(define ht (hash-union (hash 'count (length xs))\n"
         "                       (hash 'len (string-length joined))))\n"
         "(define s (for/set ([x (in-list xs)]\n"
         "                   #:when ((conjoin even? positive?) x))\n"
         "            x))\n"
         "(define score\n"
         "  (+ (hash-ref ht 'count)\n"
         "     (hash-ref ht 'len)\n"
         "     (set-count s)))\n"
         "(js-log (+ score 31))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge")
    #:tier 'composition)
   (dashboard-case
    'goal1-sequence-format-composition
    'installed-provider-coverage
    '(webracket/full racket/string racket/format)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(require racket/string racket/format)\n"
         "(define words '(\"web\" \"racket\" \"goal\"))\n"
         "(define labels\n"
         "  (for/list ([word (in-list words)]\n"
         "             [n (in-naturals 1)])\n"
         "    (~a word \":\" n)))\n"
         "(define joined (string-join labels \",\"))\n"
         "(js-log (+ (string-length joined)\n"
         "           (length (filter-map (lambda (s)\n"
         "                                (and (string-prefix? s \"r\") s))\n"
         "                              words))\n"
         "           20))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge")
    #:tier 'composition)
   (dashboard-case
    'goal1-match-set-hash-composition
    'installed-provider-coverage
    '(webracket/full racket/set racket/hash racket/format
      webracket/set webracket/hash)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(require racket/set racket/hash racket/format)\n"
         "(define h (hash 'kind 'point 'x 20 'y 22))\n"
         "(define keys (for/set ([k (in-list (hash-keys h))]) k))\n"
         "(define score\n"
         "  (match (list (hash-ref h 'kind) (set-member? keys 'x) (set-member? keys 'y))\n"
         "    [(list 'point #t #t) (+ (hash-ref h 'x) (hash-ref h 'y))]\n"
         "    [_ 0]))\n"
         "(js-log (~a score))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge")
    #:tier 'composition)
   (dashboard-case
    'goal1-dict-pretty-sequence-composition
    'installed-provider-coverage
    '(webracket/full racket/list racket/dict racket/pretty racket/sequence racket/format)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(require racket/list racket/dict racket/pretty racket/sequence racket/format)\n"
         "(define d (for/hash ([x (in-list (range 1 4))]) (values x (* x 10))))\n"
         "(define mapped (dict-map d (lambda (k v) v)))\n"
         "(define odd-count (sequence-count odd? '(1 2 3 4)))\n"
         "(define rendered (pretty-format mapped #:mode 'write))\n"
         "(js-log (+ 27 (length mapped) odd-count (string-length (~a rendered))))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge")
    #:tier 'composition)
   (dashboard-case
    'goal1-full-callable-exports
    'installed-provider-coverage
    '(webracket/full racket/vector racket/function racket/set racket/hash
      webracket/set webracket/hash)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define pos (vector-member 'b '#(a b c)))\n"
         "(define f identity)\n"
         "(define s (set-add (set 'a) 'b))\n"
         "(define h (hash 'x 37))\n"
         "(js-log (+ pos (f 2) (set-count s) (hash-ref h 'x)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'goal1-full-list-surface
    'installed-provider-coverage
    '(webracket/full racket/list)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define xs '(1 2 3 4))\n"
         "(define kept (filter-map (lambda (x) (and (even? x) x)) xs))\n"
         "(define spread (append-map (lambda (x) (list x x)) kept))\n"
         "(define member-bonus (if (member 3 (remove 2 xs)) 5 0))\n"
         "(define tail (rest (reverse '(1 2 3))))\n"
         "(js-log (+ (first spread)\n"
         "           (second spread)\n"
         "           (length tail)\n"
         "           member-bonus\n"
         "           31))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'goal1-base-sort-keywords
    'installed-provider-coverage
    '(webracket/base webracket/full)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define sorted (sort '(3 1 2) <))\n"
         "(define key-count 0)\n"
         "(define (counted-length s)\n"
         "  (set! key-count (add1 key-count))\n"
         "  (string-length s))\n"
         "(define by-len (sort '(\"aaa\" \"b\" \"cc\") < #:key counted-length #:cache-keys? #t))\n"
         "(js-log (+ (car sorted)\n"
         "           (cadr sorted)\n"
         "           (caddr sorted)\n"
         "           (string-length (car by-len))\n"
         "           (string-length (caddr by-len))\n"
         "           key-count\n"
         "           29))\n")))
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
    'base-sequence-core
    'installed-provider-coverage
    '(racket/private/for webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(define list-sum (for/sum ([x (in-list '(10 20 12))]) x))\n"
         "(define vector-sum (for/sum ([x (in-vector '#(9 8 7 6) 1 4 2)]) x))\n"
         "(define string-count (length (for/list ([ch (in-string \"abcd\" 1 4 2)]) ch)))\n"
         "(define range-sum (for/sum ([x (in-range 1 5)]) x))\n"
         "(define inclusive-sum (for/sum ([x (in-inclusive-range 1 5 2)]) x))\n"
         "(define natural-sum (for/sum ([x (in-naturals 10)] [i (in-range 3)]) x))\n"
         "(define bsum (for/sum ([b (in-bytes #\"abc\")]) b))\n"
         "(define indexed (for/sum ([(ch i) (in-indexed \"abc\")]) i))\n"
         "(define-values (more? get) (sequence-generate (list 10 20 1)))\n"
         "(define gen-sum (+ (if (more?) (get) 0)\n"
         "                   (if (more?) (get) 0)\n"
         "                   (if (more?) (get) 0)))\n"
         "(define one (for/first ([x (in-value 42)]) x))\n"
         "(js-log (+ list-sum vector-sum string-count range-sum inclusive-sum natural-sum\n"
         "           bsum indexed gen-sum one -438))\n")))
   "main.rkt"
   #rx"(?m:^42$)"
   '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'real-racket-sequence-coverage
    'installed-provider-coverage
    '(racket/sequence)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/sequence)\n"
         "(js-log (length (sequence->list '(10 20 12))))\n")))
    "main.rkt"
    #rx"(?m:^3$)"
    '("--no-io-format-provider" "--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage)
   (dashboard-case
    'base-sequence-producers
    'installed-provider-coverage
    '(racket/private/for racket/set racket/stream
      webracket/private/for webracket/set webracket/stream)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/set racket/stream)\n"
         "(define bsum (for/sum ([b (in-bytes #\"abc\")]) b))\n"
         "(define hsum (for/sum ([(k v) (in-hash (hash 'a 10 'b 20 'c 12))]) v))\n"
         "(define set-sum (for/sum ([x (in-set (set 10 20 12))]) x))\n"
         "(define stream-sum (for/sum ([x (in-stream (stream 1 2 3))]) x))\n"
         "(js-log (+ bsum hsum set-sum stream-sum -342))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-sequence-real-libraries
    'installed-provider-coverage
    '(racket/sequence racket/list racket/string racket/hash racket/set
      webracket/sequence webracket/string webracket/hash webracket/set)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/sequence racket/list racket/string racket/hash racket/set)\n"
         "(define evens (for/list ([x (filter even? (range 1 8))]) x))\n"
         "(define joined (string-join (for/list ([s (string-split \"a bb c\")]) s) \"\"))\n"
         "(define merged (hash-union (hash 'a 1) (hash 'b 2)))\n"
         "(define odds (for/set ([x (in-set (set 1 2 3))] #:when (odd? x)) x))\n"
         "(js-log (+ (length evens) (string-length joined) (hash-count merged) (set-count odds) 31))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-sequence-hash-generate
    'installed-provider-coverage
    '(racket/private/for webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(define h (hash 'a 10 'b 20 'c 12))\n"
         "(define hsum (for/sum ([(k v) (in-hash h)]) v))\n"
         "(define kcount (length (for/list ([k (in-hash-keys h)]) k)))\n"
         "(define pcount (length (for/list ([p (in-hash-pairs h)]) p)))\n"
         "(define-values (more? get) (sequence-generate h))\n"
         "(define gcount (let loop ([n 0]) (if (more?) (begin (get) (loop (+ n 1))) n)))\n"
         "(js-log (+ hsum kcount pcount gcount -9))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-sequence-custom
    'installed-provider-coverage
    '(racket/sequence racket/private/for webracket/sequence webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/sequence)\n"
         "(define values-seq\n"
         "  (make-do-sequence\n"
         "   (lambda ()\n"
         "     (values (lambda (xs) (values (car xs) (* 10 (car xs))))\n"
         "             cdr\n"
         "             '(1 2 3)\n"
         "             pair?\n"
         "             #f\n"
         "             #f))))\n"
         "(define stopped-seq\n"
         "  (make-do-sequence\n"
         "   (lambda ()\n"
         "     (values car cdr '(1 2 3 4) pair? #f (lambda (xs v) (< v 3))))))\n"
         "(define guarded-seq\n"
         "  (make-do-sequence\n"
         "   (lambda ()\n"
         "     (values car cdr '(1 2 3 4 5) pair? (lambda (v) (< v 4)) #f))))\n"
         "(define empty-seq\n"
         "  (make-do-sequence\n"
         "   (lambda ()\n"
         "     (values car cdr null pair? #f #f))))\n"
         "(define values-sum (for/sum ([(x y) values-seq]) (+ x y)))\n"
         "(define stopped-count (length (sequence->list stopped-seq)))\n"
         "(define guarded-count (length (sequence->list guarded-seq)))\n"
         "(define empty-count (length (sequence->list empty-seq)))\n"
         "(js-log (+ values-sum stopped-count guarded-count empty-count -30))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-sequence-early-next
    'installed-provider-coverage
    '(racket/sequence racket/private/for webracket/sequence webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/sequence)\n"
         "(define seq\n"
         "  (make-do-sequence\n"
         "   (lambda ()\n"
         "     (values car cdr values '(10 20 12) pair? #f #f))))\n"
         "(define-values (more? next) (sequence-generate seq))\n"
         "(define total (+ (if (more?) (next) 0)\n"
         "                 (if (more?) (next) 0)\n"
         "                 (if (more?) (next) 0)))\n"
         "(js-log total)\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-for-result-builders
    'installed-provider-coverage
    '(racket/private/for webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(define h1 (for/hasheq ([x (in-list '(a b))]) (values x 1)))\n"
         "(define h2 (for/hasheqv ([x (in-list '(1 2))]) (values x (* x 10))))\n"
         "(define h3 (for/hashalw ([x (in-list '(a b))]) (values (string->symbol (symbol->string x)) 4)))\n"
         "(define first-v (for/first ([x (in-list '(#f 41 42))] #:when x) x))\n"
         "(define last-v (for/last ([x (in-list '(10 20 12))]) x))\n"
         "(js-log (+ (hash-count h1)\n"
         "           (hash-ref h1 'a)\n"
         "           (hash-ref h2 2)\n"
         "           (hash-ref h3 'a)\n"
         "           first-v\n"
         "           last-v\n"
         "           (if (for/and ([x (in-list '(2 4 6))]) (even? x)) 10 0)\n"
         "           (if (for/or ([x (in-list '(1 3 4))]) (even? x)) 20 0)\n"
         "           -68))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-for-nested-control-coverage
    'installed-provider-coverage
    '(racket/private/for webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(define nested (for*/list ([x (in-list '(1 2))]\n"
         "                           [y (in-list '(10 20))]\n"
         "                           #:when (< (+ x y) 22))\n"
         "                 (+ x y)))\n"
         "(define vec (for*/vector ([x (in-list '(1 2))]\n"
         "                          [y (in-list '(3 4))])\n"
         "              (* x y)))\n"
         "(define-values (sum product)\n"
         "  (for/fold ([sum 0] [product 1]) ([x (in-list '(2 3 4))])\n"
         "    (values (+ sum x) (* product x))))\n"
         "(define h (for*/hash ([x (in-list '(1 2))]\n"
         "                       [y (in-list '(3 4))])\n"
         "            (values (+ (* 10 x) y) (* x y))))\n"
         "(define break-sum (apply + (for/list ([x (in-list '(1 2 3 4))] #:break (= x 3)) x)))\n"
         "(define final-sum (apply + (for/list ([x (in-list '(1 2 3 4))] #:final (= x 3)) x)))\n"
         "(js-log (+ (apply + nested)\n"
         "           (for/sum ([i (in-range (vector-length vec))]) (vector-ref vec i))\n"
         "           sum\n"
         "           product\n"
         "           (hash-count h)\n"
         "           (hash-ref h 14)\n"
         "           break-sum\n"
         "           final-sum\n"
         "           -73))\n")))
   "main.rkt"
   #rx"(?m:^42$)"
   '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'real-racket-private-for-diagnostic
    'installed-provider-diagnostic
    '(racket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/private/for)\n"
         "(js-log (for/sum ([x (in-list '(10 20 12))]) x))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
   '("--no-io-format-provider" "--webracket-module-bridge" "--no-provider-substitutions")
   #:tier 'coverage
   #:expectation 'diagnostic)
   (dashboard-case
    'real-racket-private-kw-diagnostic
    'installed-provider-diagnostic
    '(racket/private/kw)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/private/kw)\n"
         "(define-values (required allowed) (procedure-keywords +))\n"
         "(js-log (if (and (null? required) (null? allowed)) 42 0))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage
    #:expectation 'diagnostic)
   (dashboard-case
    'base-sequence-mpair
    'installed-provider-coverage
    '(racket/private/for racket/mpair webracket/private/for webracket/mpair)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(define xs (mcons 10 (mcons 20 (mcons 12 null))))\n"
         "(js-log (for/sum ([x (in-mlist xs)]) x))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-sequence-ports
    'installed-provider-coverage
    '(racket/private/for webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(define port-byte-sum (for/sum ([b (in-input-port-bytes (open-input-string \"AZ\"))]) b))\n"
         "(define port-char-count (length (for/list ([ch (in-input-port-chars (open-input-string \"xy\"))]) ch)))\n"
         "(define line-count (length (for/list ([line (in-lines (open-input-string \"a\\nb\"))]) line)))\n"
         "(define bytes-line-count (length (for/list ([line (in-bytes-lines (open-input-string \"a\\nb\"))]) line)))\n"
         "(js-log (+ port-byte-sum port-char-count line-count bytes-line-count -119))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-sequence-port-edges
    'installed-provider-coverage
    '(racket/private/for webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(define empty-lines (length (for/list ([line (in-lines (open-input-string \"\"))]) line)))\n"
         "(define trailing-lines (length (for/list ([line (in-lines (open-input-string \"a\\n\"))]) line)))\n"
         "(define two-lines (length (for/list ([line (in-lines (open-input-string \"a\\nb\"))]) line)))\n"
         "(define bytes-lines (length (for/list ([bs (in-bytes-lines (open-input-string \"a\\n\"))]) bs)))\n"
         "(define byte-sum (for/sum ([b (in-input-port-bytes (open-input-bytes #\"AZ\"))]) b))\n"
         "(js-log (+ empty-lines trailing-lines two-lines bytes-lines byte-sum -117))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-sequence-prop
    'installed-provider-coverage
    '(racket/private/for webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(struct seqbox (xs) #:property prop:sequence (lambda (self) (seqbox-xs self)))\n"
         "(define prop-sum (for/sum ([x (seqbox (list 10 20 12))]) x))\n"
         "(js-log prop-sum)\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-sequence-prop-gen
    'installed-provider-coverage
    '(racket/private/for webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(struct seqbox (xs)\n"
         "  #:property prop:gen-sequence\n"
         "  (lambda (self)\n"
         "    (define xs (seqbox-xs self))\n"
         "    (values (lambda (pos) (values (car pos) (* 10 (car pos))))\n"
         "            #f\n"
         "            cdr\n"
         "            xs\n"
         "            pair?\n"
         "            #f\n"
         "            #f)))\n"
         "(define prop-sum (for/sum ([(x y) (seqbox (list 1 2 3))]) (+ x y)))\n"
         "(js-log prop-sum)\n")))
    "main.rkt"
    #rx"(?m:^66$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-sequence-prop-gen-guard
    'diagnostic
    '(racket/private/for webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(struct bad-seq (xs)\n"
         "  #:property prop:gen-sequence\n"
         "  42)\n"
         "(js-log 0)\n")))
    "main.rkt"
    #rx"guard-for-prop:sequence"
    '("--no-io-format-provider" "--webracket-module-bridge")
    #:expectation 'diagnostic)
   (dashboard-case
    'base-sequence-derived
    'installed-provider-coverage
    '(racket/private/for webracket/private/for)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(define prod (let ([n 0]) (lambda () (set! n (+ n 1)) n)))\n"
         "(define psum (for/sum ([x (in-producer prod 4)]) x))\n"
         "(define chained (for/sum ([x (in-sequences (list 10 20) (list 12))]) x))\n"
         "(define cyclic (for/sum ([x (in-cycle (list 10 20 12))] [i (in-range 3)]) x))\n"
         "(define parallel (for/sum ([(x y) (in-parallel (list 10 20) (list 1 11))]) (+ x y)))\n"
         "(define parallel-values (for/sum ([(x y z) (in-parallel-values 2 (in-parallel (list 1 2) (list 10 20)) 1 (list 100 200))]) (+ x y z)))\n"
         "(define value-lists (for/list ([xs (in-values-sequence (in-parallel (list 'a 'b) (list 1 2)))]) xs))\n"
         "(define values-star-a (for/list ([xs (in-values*-sequence (in-parallel (list 'a 'b) (list 1 2)))]) xs))\n"
         "(define values-star-b (for/list ([xs (in-values*-sequence (list 'x 'y))]) xs))\n"
         "(define before (for/list ([x (stop-before (list 1 2 3 4) (lambda (x) (= x 3)))]) x))\n"
         "(define after (for/list ([x (stop-after (list 1 2 3 4) (lambda (x) (= x 3)))]) x))\n"
         "(js-log (+ psum chained cyclic parallel parallel-values\n"
         "           (length value-lists) (length values-star-a) (length values-star-b)\n"
         "           (length before) (length after)\n"
         "           -434))\n")))
   "main.rkt"
   #rx"(?m:^42$)"
   '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-sequence-add-between-lazy
    'installed-provider-coverage
    '(racket/sequence webracket/sequence)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/sequence)\n"
         "(define xs\n"
         "  (for/list ([x (sequence-add-between (in-cycle '(10)) 1)]\n"
         "             [i (in-range 5)])\n"
         "    x))\n"
         "(js-log (+ (apply + xs) 10))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'base-sequence-coverage
    'installed-provider-coverage
    '(racket/private/for racket/mpair webracket/private/for webracket/mpair)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(define bsum (for/sum ([b (in-bytes #\"abc\")]) b))\n"
         "(define h (hash 'a 10 'b 20 'c 12))\n"
         "(define hsum (for/sum ([(k v) (in-hash h)]) v))\n"
         "(define kcount (length (for/list ([k (in-hash-keys h)]) k)))\n"
         "(define pcount (length (for/list ([p (in-hash-pairs h)]) p)))\n"
         "(define indexed (for/sum ([(ch i) (in-indexed \"abc\")]) i))\n"
         "(define-values (more? get) (sequence-generate (list 10 20 1)))\n"
         "(define gen-sum (+ (if (more?) (get) 0)\n"
         "                   (if (more?) (get) 0)\n"
         "                   (if (more?) (get) 0)))\n"
         "(define prod (let ([n 0]) (lambda () (set! n (+ n 1)) n)))\n"
         "(define psum (for/sum ([x (in-producer prod 4)]) x))\n"
         "(define one (for/first ([x (in-value 42)]) x))\n"
         "(define chained (for/sum ([x (in-sequences (list 10 20) (list 12))]) x))\n"
         "(define cyclic (for/sum ([x (in-cycle (list 10 20 12))] [i (in-range 3)]) x))\n"
         "(define parallel (for/sum ([(x y) (in-parallel (list 10 20) (list 1 11))]) (+ x y)))\n"
         "(define parallel-values (for/sum ([(x y z) (in-parallel-values 2 (in-parallel (list 1 2) (list 10 20)) 1 (list 100 200))]) (+ x y z)))\n"
         "(define value-lists (for/list ([xs (in-values-sequence (in-parallel (list 'a 'b) (list 1 2)))]) xs))\n"
         "(define values-star-a (for/list ([xs (in-values*-sequence (in-parallel (list 'a 'b) (list 1 2)))]) xs))\n"
         "(define values-star-b (for/list ([xs (in-values*-sequence (list 'x 'y))]) xs))\n"
         "(define before (for/list ([x (stop-before (list 1 2 3 4) (lambda (x) (= x 3)))]) x))\n"
         "(define after (for/list ([x (stop-after (list 1 2 3 4) (lambda (x) (= x 3)))]) x))\n"
         "(define mlist-sum (for/sum ([x (in-mlist (mcons 1 (mcons 2 (mcons 3 null))))]) x))\n"
         "(define port-byte-sum (for/sum ([b (in-input-port-bytes (open-input-string \"AZ\"))]) b))\n"
         "(define port-char-count (length (for/list ([ch (in-input-port-chars (open-input-string \"xy\"))]) ch)))\n"
         "(define line-count (length (for/list ([line (in-lines (open-input-string \"a\\nb\"))]) line)))\n"
         "(define bytes-line-count (length (for/list ([line (in-bytes-lines (open-input-string \"a\\nb\"))]) line)))\n"
         "(struct seqbox (xs) #:property prop:sequence (lambda (self) (seqbox-xs self)))\n"
         "(define prop-sum (for/sum ([x (seqbox (list 1 2 3))]) x))\n"
         "(struct genbox (xs)\n"
         "  #:property prop:gen-sequence\n"
         "  (lambda (self)\n"
         "    (define xs (genbox-xs self))\n"
         "    (values (lambda (pos) (values (car pos) (* 10 (car pos))))\n"
         "            #f\n"
         "            cdr\n"
         "            xs\n"
         "            pair?\n"
         "            #f\n"
         "            #f)))\n"
         "(define prop-gen-sum (for/sum ([(x y) (genbox (list 1 2 3))]) (+ x y)))\n"
         "(define pair-seq (genbox (list 1 2)))\n"
         "(define-values (first-pair next-pair) (sequence-generate* pair-seq))\n"
         "(define-values (second-pair done-pairs) (next-pair))\n"
         "(define-values (third-pair _done-pairs-again) (done-pairs))\n"
         "(define star-sum (+ (car first-pair) (cadr first-pair)\n"
         "                    (car second-pair) (cadr second-pair)\n"
         "                    (if third-pair 100 0)))\n"
         "(js-log (+ bsum hsum kcount pcount indexed gen-sum psum one chained cyclic parallel parallel-values\n"
         "           (length value-lists) (length values-star-a) (length values-star-b)\n"
         "           (length before) (length after)\n"
         "           mlist-sum port-byte-sum port-char-count line-count bytes-line-count prop-sum\n"
         "           prop-gen-sum star-sum\n"
         "           -1012))\n")))
    "main.rkt"
    #rx"(?m:^154$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
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
         "(define d (for/sum ([x (in-inclusive-range 1 5 2)]) x))\n"
         "(define e (for/sum ([x (in-naturals 10)] [i (in-range 3)]) x))\n"
         "(define h (hash 'a 10 'b 20 'c 12))\n"
         "(define hsum (for/sum ([(k v) (in-hash h)]) v))\n"
         "(define indexed (for/sum ([(ch i) (in-indexed \"abc\")]) i))\n"
         "(define chained (for/sum ([x (in-sequences (list 10 20) (list 12))]) x))\n"
         "(define before (for/list ([x (stop-before (list 1 2 3 4) (lambda (x) (= x 3)))]) x))\n"
         "(define after (for/list ([x (stop-after (list 1 2 3 4) (lambda (x) (= x 3)))]) x))\n"
         "(js-log (+ (length a)\n"
         "           (length b)\n"
         "           (apply + c)\n"
         "           d\n"
         "           e\n"
         "           hsum\n"
         "           indexed\n"
         "           chained\n"
         "           (length before)\n"
         "           (length after)\n"
         "           -139))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'sequence-directory-coverage
    'installed-provider-coverage
    '(racket/sequence webracket/file racket/path)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(make-directory* \"/app/seq-dir/a\")\n"
         "(display-to-file \"root\" \"/app/seq-dir/root.txt\" 'text 'replace)\n"
         "(display-to-file \"leaf\" \"/app/seq-dir/a/leaf.txt\" 'text 'replace)\n"
         "(define paths (for/list ([p (in-directory \"/app/seq-dir\")]) p))\n"
         "(js-log paths)\n"
         "(js-log (+ (length paths) 39))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider")
    #:tier 'coverage
    #:expectation 'required)
   (dashboard-case
    'generator-real-diagnostic
    'installed-provider-diagnostic
    '(racket/generator webracket/generator)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/generator)\n"
         "(define g (generator () (yield 20) (yield 22)))\n"
         "(js-log (+ (g) (g)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge")
    #:tier 'coverage
    #:expectation 'diagnostic)
   (dashboard-case
    'goal1-vector-sort-keywords
    'installed-provider-coverage
    '(racket/vector)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define v (vector '(3) '(1) '(2)))\n"
         "(define sorted (vector-sort v < #:key car #:cache-keys? #t))\n"
         "(vector-sort! v < #:key car #:cache-keys? #t)\n"
         "(js-log (+ (car (vector-ref sorted 0))\n"
         "           (car (vector-ref v 0))\n"
         "           40))\n")))
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
    'real-racket-contract-diagnostic
    'installed-provider-diagnostic
    '(racket/contract)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/contract)\n"
         "(define/contract value integer? 42)\n"
         "(js-log value)\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage
    #:expectation 'diagnostic)
   (dashboard-case
    'real-racket-class-diagnostic
    'installed-provider-diagnostic
    '(racket/class)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/class)\n"
         "(define point%\n"
         "  (class object%\n"
         "    (super-new)\n"
         "    (define/public (value) 42)))\n"
         "(js-log (send (new point%) value))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
   '("--webracket-module-bridge" "--no-provider-substitutions")
   #:tier 'coverage
   #:expectation 'diagnostic)
   (dashboard-case
    'real-racket-class-rich-diagnostic
    'installed-provider-diagnostic
    '(racket/class)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/class)\n"
         "(define base%\n"
         "  (class object%\n"
         "    (super-new)\n"
         "    (field [n 40])\n"
         "    (define/pubment (value x) (+ n x (inner 0 value x)))))\n"
         "(define child%\n"
         "  (class base%\n"
         "    (super-new)\n"
         "    (inherit-field n)\n"
         "    (set! n 39)\n"
         "    (define/augment (value x) 1)\n"
         "    (define/public (next) (value 2))))\n"
         "(define obj (new child%))\n"
         "(js-log (if (and (object? obj) (is-a? obj child%))\n"
         "            (send obj next)\n"
         "            0))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage
    #:expectation 'diagnostic)
   (dashboard-case
    'real-racket-class-error-diagnostic
    'installed-provider-diagnostic
    '(racket/class)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/class)\n"
         "(define final%\n"
         "  (class object%\n"
         "    (super-new)\n"
         "    (define/public-final (value) 1)))\n"
         "(define y\n"
         "  (with-handlers ([(lambda (e) #t) (lambda (e) 42)])\n"
         "    (class final%\n"
         "      (super-new)\n"
         "      (define/override (value) 2))\n"
         "    0))\n"
         "(js-log y)\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage
    #:expectation 'diagnostic)
   (dashboard-case
    'installed-racket-class-basic-coverage
    'installed-provider-coverage
    '(racket/class)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/class)\n"
         "(define base%\n"
         "  (class object%\n"
         "    (super-new)\n"
         "    (init-field [n 40])\n"
         "    (define/public (value) n)))\n"
         "(define child%\n"
         "  (class base%\n"
         "    (super-new)\n"
         "    (inherit value)\n"
         "    (define/public (next) (+ (value) 2))))\n"
         "(define obj (new child%))\n"
         "(js-log (if (and (object? obj) (is-a? obj child%) (is-a? obj base%))\n"
         "            (send obj next)\n"
         "            0))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage)
   (dashboard-case
    'installed-racket-class-advanced-coverage
    'installed-provider-coverage
    '(racket/class)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/class)\n"
         "(define valued<%> (interface () value next))\n"
         "(define base%\n"
         "  (class object%\n"
         "    (init-field [n 30])\n"
         "    (super-new)\n"
         "    (define/public (value) n)\n"
         "    (define/public (next) (+ (value) 1))))\n"
         "(define child%\n"
         "  (class* base% (valued<%>)\n"
         "    (init-field [delta 10])\n"
         "    (super-new)\n"
         "    (inherit value)\n"
         "    (define/override (next) (+ (super next) delta))))\n"
         "(define obj (new child% [n 39] [delta 2]))\n"
         "(define final%\n"
         "  (class object%\n"
         "    (super-new)\n"
         "    (define/public-final (sealed) 5)))\n"
         "(define caught\n"
         "  (with-handlers ([(lambda (e) #t) (lambda (e) 1)])\n"
         "    (class final%\n"
         "      (super-new)\n"
         "      (define/override (sealed) 6))\n"
         "    0))\n"
         "(js-log (+ (if (is-a? obj valued<%>) 1 0)\n"
         "           (if (is-a? obj child%) 2 0)\n"
         "           (send obj value)\n"
         "           (send obj next)\n"
         "           caught\n"
         "           -43))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--webracket-module-bridge" "--no-provider-substitutions")
    #:tier 'coverage)
   (dashboard-case
    'installed-racket-unit-basic-coverage
    'installed-provider-coverage
    '(racket/unit)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/unit)\n"
         "(define-signature counter^ [inc get])\n"
         "(define-unit counter@\n"
         "  (import)\n"
         "  (export counter^)\n"
         "  (define n 40)\n"
         "  (define (inc) (set! n (add1 n)))\n"
         "  (define (get) n))\n"
         "(define-values/invoke-unit counter@\n"
         "  (import)\n"
         "  (export counter^))\n"
         "(inc)\n"
         "(inc)\n"
         "(js-log (get))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--webracket-module-bridge")
    #:tier 'coverage)
   (dashboard-case
    'installed-racket-unit-compound-coverage
    'installed-provider-coverage
    '(racket/unit)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/unit)\n"
         "(define-signature input^ [x])\n"
         "(define-signature out^ [y])\n"
         "(define add@\n"
         "  (unit\n"
         "    (import input^)\n"
         "    (export out^)\n"
         "    (define y (+ x 2))))\n"
         "(define compound@\n"
         "  (compound-unit\n"
         "    (import [IN : input^])\n"
         "    (export OUT)\n"
         "    (link [([OUT : out^]) add@ IN])))\n"
         "(define x 40)\n"
         "(define-values/invoke-unit compound@\n"
         "  (import input^)\n"
         "  (export out^))\n"
         "(js-log y)\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--webracket-module-bridge")
    #:tier 'coverage)
   (dashboard-case
    'installed-racket-unit-infer-coverage
    'installed-provider-coverage
    '(racket/unit)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/unit)\n"
         "(define-signature a^ [x])\n"
         "(define-signature b^ [y])\n"
         "(define-unit a@\n"
         "  (import)\n"
         "  (export a^)\n"
         "  (define x 40))\n"
         "(define-unit b@\n"
         "  (import a^)\n"
         "  (export b^)\n"
         "  (define y (+ x 2)))\n"
         "(define-compound-unit/infer both@\n"
         "  (import)\n"
         "  (export b^)\n"
         "  (link a@ b@))\n"
         "(define-values/invoke-unit both@\n"
         "  (import)\n"
         "  (export b^))\n"
         "(js-log y)\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--webracket-module-bridge")
    #:tier 'coverage)
   (dashboard-case
    'installed-racket-unit-prefix-rename-coverage
    'installed-provider-coverage
    '(racket/unit)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/unit)\n"
         "(define-signature source^ [value])\n"
         "(define-signature prefix-sink^ [prefix-answer])\n"
         "(define-signature rename-sink^ [rename-answer])\n"
         "(define-unit source@\n"
         "  (import)\n"
         "  (export source^)\n"
         "  (define value 40))\n"
         "(define-unit use-prefix@\n"
         "  (import (prefix src: source^))\n"
         "  (export prefix-sink^)\n"
         "  (define prefix-answer (+ src:value 1)))\n"
         "(define-unit use-rename@\n"
         "  (import (rename source^ [n value]))\n"
         "  (export rename-sink^)\n"
         "  (define rename-answer (+ n 1)))\n"
         "(define-compound-unit/infer both@\n"
         "  (import)\n"
         "  (export prefix-sink^ rename-sink^)\n"
         "  (link source@ use-prefix@ use-rename@))\n"
         "(define-values/invoke-unit both@\n"
         "  (import)\n"
         "  (export prefix-sink^ rename-sink^))\n"
         "(js-log (+ prefix-answer rename-answer -40))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--webracket-module-bridge")
    #:tier 'coverage)
   (dashboard-case
    'full-unit-coverage
    'language-full
    '(webracket/full racket/unit)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define-signature source^ [value])\n"
         "(define-signature sink^ [answer])\n"
         "(define-unit source@\n"
         "  (import)\n"
         "  (export source^)\n"
         "  (define value 40))\n"
         "(define-unit use-source@\n"
         "  (import (prefix src: source^))\n"
         "  (export sink^)\n"
         "  (define answer (+ src:value 2)))\n"
         "(define-compound-unit/infer both@\n"
         "  (import)\n"
         "  (export sink^)\n"
         "  (link source@ use-source@))\n"
         "(define-values/invoke-unit both@\n"
         "  (import)\n"
         "  (export sink^))\n"
         "(js-log answer)\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--webracket-module-bridge")
    #:tier 'coverage)
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
    'full-stream-lazy
    'installed-provider-coverage
    '(webracket/stream)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define s (stream 42 (error 'stream \"forced too early\")))\n"
         "(js-log (stream-first s))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider"))
   (dashboard-case
    'full-stream-lazy-map
    'installed-provider-coverage
    '(webracket/stream)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/full\n"
         "(define count 0)\n"
         "(define s\n"
         "  (stream-map (lambda (x)\n"
         "                (set! count (+ count 1))\n"
         "                (+ x 1))\n"
         "              (stream 10 20 (error 'stream \"forced too early\"))))\n"
         "(define first-before count)\n"
         "(define first-value (stream-first s))\n"
         "(define first-after count)\n"
         "(define filtered\n"
         "  (stream-filter even? (stream-map add1 (stream 1 2 3 4))))\n"
         "(define filtered-sum (for/sum ([x (in-stream filtered)]) x))\n"
         "(js-log (+ first-before first-value first-after filtered-sum 24))\n")))
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
         "(define direct-len (length (for/list ([x s]) x)))\n"
         "(define mapped (stream-map add1 s))\n"
         "(define filtered (stream-filter even? mapped))\n"
         "(define appended (stream-append (stream-take s 2) (stream 10)))\n"
         "(js-log (+ (apply + xs)\n"
         "           (length xs)\n"
         "           direct-len\n"
         "           (stream-length s)\n"
         "           (stream-ref s 1)\n"
         "           (stream-first (stream-tail s 2))\n"
         "           (apply + (stream->list filtered))\n"
         "           (apply + (stream->list appended))\n"
         "           (if (stream-empty? empty-stream) -81 100)))\n")))
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
    'installed-racket-bytes
    'installed-provider-graph
    '(racket/bytes)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/bytes)\n"
         "(define b (bytes-append #\"A\" #\"BC\"))\n"
         "(js-log (+ (bytes-length b)\n"
         "           (if (equal? (bytes->list (subbytes b 1 3)) '(66 67)) 39 0)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
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
    #rx"(?m:^web\\|\"racket\"\\|'\\(1 2\\)$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-format-printing
    'installed-provider-coverage
    '(racket/format racket/contract/base)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/format)\n"
         "(define text\n"
         "  (format \"~a|~s|~v\" \"a b\" \"a b\" '(\"a b\" 2)))\n"
         "(js-log text)\n")))
    "main.rkt"
    #rx"(?m:^a b\\|\"a b\"\\|'\\(\"a b\" 2\\)$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-format-printing-values
    'installed-provider-coverage
    '(racket/format racket/contract/base)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/format)\n"
         "(define text\n"
         "  (string-append\n"
         "   (~a #t) \"|\"\n"
         "   (~s \"a\\\"b\") \"|\"\n"
         "   (~s #\\space) \"|\"\n"
         "   (~v 'sym) \"|\"\n"
         "   (~v #(1 \"x\")) \"|\"\n"
         "   (~v (hash 'a 1))))\n"
         "(js-log text)\n")))
    "main.rkt"
    #rx"(?m:^#t\\|\"a\\\\\"b\"\\|#\\\\space\\|'sym\\|'#\\(1 \"x\"\\)\\|'#hash\\(\\(a \\. 1\\)\\)$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-format-print-parameter
    'installed-provider-coverage
    '(racket/format racket/contract/base)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/format)\n"
         "(define quoted (~v '(a b)))\n"
         "(print-as-expression #f)\n"
         "(define plain (~v '(a b)))\n"
         "(print-as-expression #t)\n"
         "(js-log (string-append quoted \"|\" plain))\n")))
    "main.rkt"
    #rx"(?m:^'\\(a b\\)\\|\\(a b\\)$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'installed-racket-format-rational-precision
    'installed-provider-coverage
    '(racket/format racket/contract/base)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/format)\n"
         "(define text\n"
         "  (string-append\n"
         "   (~r 3.14159 #:precision 2) \"|\"\n"
         "   (~r 1.5 #:precision 4) \"|\"\n"
         "   (~r 50 #:precision '(= 2)) \"|\"\n"
         "   (~r 1.5 #:precision '(= 4)) \"|\"\n"
         "   (~r 123.456 #:decimal-sep \",\") \"|\"\n"
         "   (~r -42 #:min-width 4 #:pad-string \"0\")))\n"
         "(js-log text)\n")))
    "main.rkt"
    #rx"(?m:^3\\.14\\|1\\.5\\|50\\.00\\|1\\.5000\\|123,456\\|-0042$)"
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
    'installed-data-queue-coverage
    'installed-provider-coverage
    '(data/queue racket/contract/base)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require data/queue)\n"
         "(define q (make-queue))\n"
         "(enqueue! q 40)\n"
         "(enqueue-front! q 2)\n"
         "(js-log (+ (dequeue! q) (dequeue! q)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
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
    'installed-racket-logging-coverage
    'installed-provider-coverage
    '(racket/logging racket/contract/base)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require racket/logging)\n"
         "(js-log (if (and log-level/c (not (log-level? (current-logger) 'info))) 42 0))\n")))
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
    'ffi-js-array-coverage
    'installed-provider-coverage
    '(js/array webracket/unsafe/array)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require js/array)\n"
         "(define arr (array-of 40 2))\n"
         "(js-log (apply + (vector->list (array->vector arr))))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'ffi-js-math-coverage
    'installed-provider-coverage
    '(js/math webracket/unsafe/math)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require js/math)\n"
         "(js-log (+ (math-floor 20.9)\n"
         "           (math-ceil 20.1)\n"
         "           (math-round 1.4)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
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
    'ffi-js-standard
    'ffi-module
    '(js/standard webracket/unsafe/standard)
    `(("main.rkt" .
       "#lang webracket/base\n(require js/standard)\n(js-log (standard-parse-int \"42\"))\n"))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'ffi-js-standard-coverage
    'installed-provider-coverage
    '(js/standard webracket/unsafe/standard)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require js/standard)\n"
         "(define parsed (standard-number-parse-int \"40\"))\n"
         "(js-log (+ parsed (if (standard-finite? 1.0) 2 0)))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'ffi-js-performance-coverage
    'installed-provider-coverage
    '(js/performance webracket/unsafe/performance)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require js/performance)\n"
         "(js-log (if (number? (performance-now)) 42 0))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'ffi-js-temp-coverage
    'installed-provider-coverage
    '(js/temp js/standard webracket/unsafe/temp webracket/unsafe/standard)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require js/temp js/standard)\n"
         "(define obj (standard-object '((x . 40))))\n"
         "(temp-set-x! obj 42)\n"
         "(js-log (temp-x obj))\n")))
    "main.rkt"
    #rx"(?m:^42$)"
    '("--no-io-format-provider" "--webracket-module-bridge"))
   (dashboard-case
    'ffi-js-console-coverage
    'installed-provider-coverage
    '(js/console webracket/unsafe/console)
    `(("main.rkt" .
       ,(string-append
         "#lang webracket/base\n"
         "(require js/console)\n"
         "(console-log \"console-module-a\")\n"
         "(console-warn \"console-module-b\")\n")))
    "main.rkt"
    #rx"console-module-a"
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
    '("--no-io-format-provider"))
   (dashboard-case
    'regexp-provider-coverage
    'installed-provider-coverage
    '(regexp)
    `(("main.rkt" .
       ,(string-append
         "(define m (regexp-match #rx\"w(.+)t\" \"webracket\"))\n"
         "(define r (regexp-replace #rx\"web\" \"webracket\" \"r\"))\n"
         "(js-log (string-append (car m) \"|\" r))\n")))
    "main.rkt"
    #rx"(?m:^webracket\\|rracket$)"
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

;; goal1-dashboard-recommended-timeout-seconds : (listof goal1-dashboard-case?) -> exact-positive-integer?
;;   Recommend a per-row timeout for the selected cases.
(define (goal1-dashboard-recommended-timeout-seconds cases)
  (if (for/or ([c (in-list cases)])
        (eq? (goal1-dashboard-case-tier c) 'composition))
      goal1-dashboard-composition-timeout-seconds
      goal1-dashboard-default-timeout-seconds))

;; warn-if-dashboard-timeout-too-low! : (listof goal1-dashboard-case?) exact-positive-integer? -> void?
;;   Tell the user when a selected preset is likely too heavyweight for the bound.
(define (warn-if-dashboard-timeout-too-low! selected-cases timeout-seconds)
  (define recommended-timeout
    (goal1-dashboard-recommended-timeout-seconds selected-cases))
  (when (< timeout-seconds recommended-timeout)
    (fprintf (current-error-port)
             "dashboard: selected rows include tier(s) that usually need --timeout ~a; current --timeout is ~a\n"
             recommended-timeout
             timeout-seconds)))

;; cache-file-count : path? -> exact-nonnegative-integer?
;;   Count provider-cache files recursively.
(define (cache-file-count cache-dir)
  (if (directory-exists? cache-dir)
      (for/sum ([path (in-list (find-files file-exists? cache-dir))]
                #:when (file-exists? path))
        1)
      0))

;; max-dashboard-output-scan-chars : exact-positive-integer?
;;   Bound post-run regex work so huge failure output cannot hang the dashboard.
(define max-dashboard-output-scan-chars 200000)

;; dashboard-output-scan-sample : string? -> string?
;;   Keep the beginning and end of a diagnostic stream for bounded scanning.
(define (dashboard-output-scan-sample output)
  (define len (string-length output))
  (cond
    [(<= len max-dashboard-output-scan-chars) output]
    [else
     (define half (quotient max-dashboard-output-scan-chars 2))
     (string-append
      (substring output 0 half)
      "\n... dashboard output omitted ...\n"
      (substring output (- len half) len))]))

;; cache-events : string? exact-nonnegative-integer? exact-nonnegative-integer? -> symbol?
;;   Summarize provider-cache diagnostics from a dashboard run.
(define (cache-events output before after)
  (define sample (dashboard-output-scan-sample output))
  (define hit? (regexp-match? #rx"provider-cache: .* hit" sample))
  (define miss? (regexp-match? #rx"provider-cache: .* miss" sample))
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
  (define sample (dashboard-output-scan-sample output))
  (cond
    [(= status 124) 'timeout]
    [(and (zero? status) (regexp-match? expected sample)) 'ok]
    [(zero? status) 'output-mismatch]
    [(regexp-match? #rx"Skipping temporary stdlib/provider prelude for module-language input" sample)
     'module-language-prelude-skip-but-failed]
    [(regexp-match? #rx"external provider is not in the Goal 1 trial allowlist|transitive provider is not in the Goal 1 trial allowlist|unsupported providers|unsupported provider" sample)
     'provider-graph-failed]
    [(and (regexp-match? #rx"application: not a procedure;" sample)
          (regexp-match? #rx"given:" sample))
     'provider-alias-not-callable]
    [(regexp-match? #rx"unbound identifier|undefined" sample) 'unbound]
    [else 'failed]))

;; output-note : exact-integer? string? -> string?
;;   Keep one compact diagnostic line for failed dashboard rows.
(define (output-note status output)
  (define normalized
    (string-replace (string-trim (dashboard-output-scan-sample output)) "\t" " "))
  (cond
    [(string=? normalized "") (format "exit ~a with no output" status)]
    [else
     (define raw-lines (string-split normalized "\n"))
     (define last-provider-cache-line
       (for/last ([line (in-list raw-lines)]
                  #:when (regexp-match? #rx"^provider-cache:" line))
         line))
     (define lines
       (filter
        (lambda (line)
          (not (regexp-match? #rx"^provider-cache:" line)))
        raw-lines))
     (define message-line
       (for/first ([line (in-list lines)]
                   #:when (regexp-match? #rx"^  message: " line))
         line))
     (define diagnostic-line
       (for/first ([line (in-list lines)]
                   #:when (regexp-match?
                            #rx"unsupported provider|unsupported providers|missing-after-reflection|ambiguous-after-reflection|namespace mismatch|module bridge graph extraction failed|unbound identifier|undefined"
                            line))
         line))
     (define line (or message-line
                      diagnostic-line
                      (and (= status 124)
                           last-provider-cache-line
                           (format "timeout after ~a" last-provider-cache-line))
                      (if (null? lines)
                          (first raw-lines)
                          (first lines))))
     (if (> (string-length line) 300)
         (string-append (substring line 0 297) "...")
         line)]))

(module+ test
  (require rackunit)

  (test-case "output-note keeps last provider-cache line for timeouts"
    (check-equal?
     (output-note
      124
      (string-append
       "provider-cache: cache directory: /tmp/cache\n"
       "provider-cache: regexp demod miss; regenerating: /tmp/cache/regexp.rktl\n"))
     "timeout after provider-cache: regexp demod miss; regenerating: /tmp/cache/regexp.rktl"))

  (test-case "output-note still prefers semantic diagnostics"
    (check-equal?
     (output-note
      1
      (string-append
       "provider-cache: cache directory: /tmp/cache\n"
       "foo.rkt:1:0: unbound identifier\n"))
     "foo.rkt:1:0: unbound identifier"))

  (test-case "classify-detail avoids multiline alias backtracking"
    (define large-output
      (string-append
       "application: not a procedure;\n"
       (make-string (+ max-dashboard-output-scan-chars 1000) #\x)
       "\ngiven: #f\n"))
    (check-equal? (classify-detail 1 large-output #rx"42")
                  'provider-alias-not-callable))

  (test-case "real-provider diagnostics are scheduled exclusively"
    (check-true
     (goal1-dashboard-case-exclusive?
      (dashboard-case
       'real
       'installed-provider-diagnostic
       '(racket/list)
       '(("main.rkt" . "#lang webracket/base\n42\n"))
       "main.rkt"
       #rx"42"
       '())))
    (check-false
     (goal1-dashboard-case-exclusive?
      (dashboard-case
       'local
       'local-module-graph
       '(webracket/base)
       '(("main.rkt" . "#lang webracket/base\n42\n"))
       "main.rkt"
       #rx"42"
       '())))))

;; run-goal1-dashboard-case : case path? exact-positive-integer? exact-positive-integer? [path?] -> row
;;   Run one compact Goal 1 case through `webracket.rkt -r --no-stdlib`.
(define (run-goal1-dashboard-case c
                                  cache-dir
                                  timeout-seconds
                                  memory-mb
                                  [shared-compiled-root-dir #f])
  (define source-dir (make-temporary-file "webracket-goal1-dashboard-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-goal1-dashboard-dest-~a" 'directory))
  (define own-compiled-root? (not shared-compiled-root-dir))
  (define compiled-root-dir
    (or shared-compiled-root-dir
        (make-temporary-file "webracket-goal1-dashboard-compiled-~a" 'directory)))
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
          (environment-variables-set!
           (current-environment-variables)
           #"PLTCOMPILEDROOTS"
           (string->bytes/utf-8 (path->string compiled-root-dir)))
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
      (for ([dir (in-list (if own-compiled-root?
                              (list source-dir dest-dir compiled-root-dir)
                              (list source-dir dest-dir)))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

;; goal1-dashboard-cache-warmup-case : goal1-dashboard-case?
;;   Tiny module used to build shared provider artifacts before measured rows.
(define goal1-dashboard-cache-warmup-case
  (dashboard-case
   'provider-cache-warmup
   'dashboard-infrastructure
   '(regexp-provider)
   `(("main.rkt" . "#lang webracket/base\n(js-log 0)\n"))
   "main.rkt"
   #rx"(?m:^0$)"
   '("--no-io-format-provider")))

;; warm-goal1-dashboard-provider-cache! : path? exact-positive-integer? exact-positive-integer? -> goal1-dashboard-row?
;;   Prime shared provider-cache artifacts outside individual dashboard rows.
(define (warm-goal1-dashboard-provider-cache!
         cache-dir
         [timeout-seconds goal1-dashboard-default-cache-warmup-timeout-seconds]
         [memory-mb goal1-dashboard-default-memory-mb]
         [shared-compiled-root-dir #f])
  (run-goal1-dashboard-case
   goal1-dashboard-cache-warmup-case
   cache-dir
   timeout-seconds
   memory-mb
   shared-compiled-root-dir))

;; normalize-dashboard-jobs : any/c -> exact-positive-integer?
;;   Validate a requested dashboard worker count.
(define (normalize-dashboard-jobs jobs)
  (cond
    [(and (exact-integer? jobs) (positive? jobs)) jobs]
    [else (raise-argument-error 'run-goal1-dashboard "exact-positive-integer?" jobs)]))

;; goal1-dashboard-case-exclusive? : goal1-dashboard-case? -> boolean?
;;   Avoid running heavyweight real-provider diagnostics against each other.
(define (goal1-dashboard-case-exclusive? c)
  (eq? (goal1-dashboard-case-category c) 'installed-provider-diagnostic))

;; run-goal1-dashboard-cases/parallel : list? path? exact-positive-integer? exact-positive-integer? exact-positive-integer? path? -> list?
;;   Run cases with stable result order while allowing independent child processes.
(define (run-goal1-dashboard-cases/parallel cases
                                           cache-dir
                                           timeout-seconds
                                           memory-mb
                                           jobs
                                           compiled-root-dir)
  (define indexed-cases cases)
  (define next-box (box indexed-cases))
  (define results  (make-hasheq))
  (define lock     (make-semaphore 1))
  (define results-lock (make-semaphore 1))
  (define (take-next!)
    (call-with-semaphore
     lock
     (lambda ()
       (match (unbox next-box)
         ['() #f]
         [(cons item rest)
          (set-box! next-box rest)
          item]))))
  (define worker-count (min jobs (length cases)))
  (define workers
    (for/list ([_ (in-range worker-count)])
      (thread
       (lambda ()
         (let loop ()
           (match (take-next!)
             [#f (void)]
             [(cons idx c)
              (define row
                (run-goal1-dashboard-case c
                                          cache-dir
                                          timeout-seconds
                                          memory-mb
                                          compiled-root-dir))
              (call-with-semaphore
               results-lock
               (lambda ()
                 (hash-set! results idx row)))
              (loop)]))))))
  (for ([worker (in-list workers)])
    (thread-wait worker))
  results)

;; run-goal1-dashboard-cases/scheduled : list? path? exact-positive-integer? exact-positive-integer? exact-positive-integer? path? -> list?
;;   Run heavyweight diagnostics serially while preserving parallelism elsewhere.
(define (run-goal1-dashboard-cases/scheduled cases
                                             cache-dir
                                             timeout-seconds
                                             memory-mb
                                             jobs
                                             compiled-root-dir)
  (define indexed-cases
    (for/list ([c (in-list cases)]
               [idx (in-naturals)])
      (cons idx c)))
  (define-values (exclusive regular)
    (partition (lambda (item)
                 (goal1-dashboard-case-exclusive? (cdr item)))
               indexed-cases))
  (define results (make-vector (length indexed-cases) #f))
  (for ([item (in-list exclusive)])
    (match-define (cons idx c) item)
    (vector-set! results idx
                 (run-goal1-dashboard-case c
                                           cache-dir
                                           timeout-seconds
                                           memory-mb
                                           compiled-root-dir)))
  (define parallel-results
    (run-goal1-dashboard-cases/parallel regular
                                       cache-dir
                                       timeout-seconds
                                       memory-mb
                                       jobs
                                       compiled-root-dir))
  (for ([(idx row) (in-hash parallel-results)])
    (vector-set! results idx row))
  (vector->list results))

;; run-goal1-dashboard : keyword-args -> (listof goal1-dashboard-row?)
;;   Run the compact Goal 1 no-stdlib dashboard.
(define (run-goal1-dashboard #:cache-dir [cache-dir (make-temporary-file "webracket-goal1-dashboard-cache-~a" 'directory)]
                             #:timeout-seconds [timeout-seconds goal1-dashboard-default-timeout-seconds]
                             #:cache-warmup-timeout-seconds [cache-warmup-timeout-seconds goal1-dashboard-default-cache-warmup-timeout-seconds]
                             #:memory-mb [memory-mb goal1-dashboard-default-memory-mb]
                             #:cases [cases goal1-dashboard-cases]
                             #:jobs [jobs goal1-dashboard-default-jobs]
                             #:warm-cache? [warm-cache? 'auto])
  (define normalized-jobs (normalize-dashboard-jobs jobs))
  (define should-warm-cache?
    (if (eq? warm-cache? 'auto)
        (> normalized-jobs 1)
        warm-cache?))
  (define compiled-root-dir
    (make-temporary-file "webracket-goal1-dashboard-compiled-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (when (and should-warm-cache? (pair? cases))
        (define warmup-row
          (warm-goal1-dashboard-provider-cache!
           cache-dir
           cache-warmup-timeout-seconds
           memory-mb
           compiled-root-dir))
        (unless (eq? (goal1-dashboard-row-status warmup-row) 'pass)
          (error 'run-goal1-dashboard
                 "provider cache warmup failed: ~a: ~a"
                 (goal1-dashboard-row-detail warmup-row)
                 (goal1-dashboard-row-note warmup-row))))
      (cond
        [(or (null? cases) (= normalized-jobs 1))
         (for/list ([c (in-list cases)])
           (run-goal1-dashboard-case c
                                     cache-dir
                                     timeout-seconds
                                     memory-mb
                                     compiled-root-dir))]
        [else
         (run-goal1-dashboard-cases/scheduled
          cases
          cache-dir
          timeout-seconds
          memory-mb
          normalized-jobs
          compiled-root-dir)]))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files compiled-root-dir)))))

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
                               #:cache-warmup-timeout-seconds [cache-warmup-timeout-seconds goal1-dashboard-default-cache-warmup-timeout-seconds]
                               #:memory-mb [memory-mb goal1-dashboard-default-memory-mb]
                               #:jobs [jobs goal1-dashboard-default-jobs]
                               #:warm-cache? [warm-cache? 'auto]
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
     (warn-if-dashboard-timeout-too-low! selected-cases timeout-seconds)
     (define rows
       (run-goal1-dashboard #:cache-dir actual-cache-dir
                            #:timeout-seconds timeout-seconds
                            #:cache-warmup-timeout-seconds cache-warmup-timeout-seconds
                            #:memory-mb memory-mb
                            #:jobs jobs
                            #:warm-cache? warm-cache?
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
  (define cache-warmup-timeout-seconds goal1-dashboard-default-cache-warmup-timeout-seconds)
  (define memory-mb goal1-dashboard-default-memory-mb)
  (define jobs goal1-dashboard-default-jobs)
  (define warm-cache? 'auto)
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
   [("--cache-warmup-timeout") n "provider cache warmup timeout in seconds"
                               (set! cache-warmup-timeout-seconds (string->number n))]
   [("--memory-mb") n "per-case memory limit in MiB"
                    (set! memory-mb (string->number n))]
   [("--jobs") n "number of dashboard cases to run in parallel"
                (set! jobs (string->number n))]
   [("--warm-cache") "run a shared provider-cache warmup before selected cases"
                     (set! warm-cache? #t)]
   [("--no-cache-warmup") "skip the shared provider-cache warmup run"
                          (set! warm-cache? #f)]
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
   [("--fast-required") "run/list the tiny required inner-loop preset"
                        (set! case-names goal1-dashboard-fast-required-case-names)
                        (set! expectations '(required))]
   [("--coverage-core") "run/list the everyday Goal 1 coverage preset"
                        (set! case-names goal1-dashboard-coverage-core-case-names)
                        (set! expectations '(required))]
   [("--coverage-extended") "run/list the broader Goal 1 coverage preset"
                            (set! case-names goal1-dashboard-coverage-extended-case-names)
                            (set! expectations '(required))]
   [("--composition") "run/list heavyweight Goal 1 cross-provider composition rows"
                      (set! case-names goal1-dashboard-composition-case-names)
                      (set! expectations '(required))]
   [("--checkpoint") "run/list all required Goal 1 checkpoint rows"
                     (set! case-names goal1-dashboard-checkpoint-case-names)
                     (set! expectations '(required))]
   [("--real-provider-readiness") "run/list diagnostic rows for replacing staged providers with real Racket providers"
                                  (set! case-names goal1-dashboard-real-provider-readiness-case-names)
                                  (set! expectations '(diagnostic))]
   [("--provider-readiness") "alias for --real-provider-readiness"
                             (set! case-names goal1-dashboard-real-provider-readiness-case-names)
                             (set! expectations '(diagnostic))])
  (print-goal1-dashboard #:tsv? tsv?
                         #:json? json?
                         #:list? list?
                         #:cache-dir cache-dir
                         #:timeout-seconds timeout-seconds
                         #:cache-warmup-timeout-seconds cache-warmup-timeout-seconds
                         #:memory-mb memory-mb
                         #:jobs jobs
                         #:warm-cache? warm-cache?
                         #:case-names case-names
                         #:categories categories
                         #:tiers tiers
                         #:expectations expectations))
