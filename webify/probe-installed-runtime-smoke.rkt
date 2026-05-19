#lang racket/base

(require racket/cmdline
         racket/async-channel
         racket/file
         racket/list
         racket/match
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         "probe-installed-module-deps.rkt"
         "module-runtime-smoke.rkt"
         "test-installed-module-runtime.rkt")

(define-runtime-path self-path "probe-installed-runtime-smoke.rkt")

(define timeout-seconds 120)
(define memory-mb 1024)
(define selected-index #f)
(define selected-category #f)
(define selected-name #f)
(define selected-module-case #f)
(define preserve-dir #f)
(define no-observe? #f)
(define list-only? #f)
(define worker? #f)
(define batch-worker? #f)
(define goal1-fast? #f)
(define goal1-slow? #f)
(define runtime-timings? #f)
(define extra-webracket-args '())
(define provider-cache-dir #f)
(define clear-provider-cache? #f)
(define force-provider-cache-refresh? #f)
(define batch-size 1)
(define jobs 1)
(define goal1-limit #f)
(define goal1-skip 0)
(define selected-module-cases '())

(define expander-read-module-cases
  '(read-list
    read-vector
    read-symbol-string
    read-comment
    read-public-list
    read-current-readtable
    read-accept-reader-param
    read-string->number
    read-regexp-literal
    read-pregexp-literal
    read-hash-literal
    read-port-location
    read-accept-dot-param))

;; module-case-needs-expander-read-provider? : symbol? -> boolean?
;;   Select tracking probes that exercise public `read` via expander/read.
(define (module-case-needs-expander-read-provider? name)
  (memq name expander-read-module-cases))

;; module-cases-extra-webracket-args : (listof symbol?) -> (listof string?)
;;   Extra driver flags needed by special provider-backed module cases.
(define (module-cases-extra-webracket-args names)
  (append
   (provider-cache-webracket-args)
   (if (ormap module-case-needs-expander-read-provider? names)
       '("--expander-read-provider")
       '())
   (if runtime-timings?
       '("--timings")
       '())
   extra-webracket-args))

;; provider-cache-webracket-args : -> (listof string?)
;;   Driver cache flags for the WebRacket invocation inside a worker.
(define (provider-cache-webracket-args)
  (append
   (if provider-cache-dir
       (list "--provider-cache-dir" provider-cache-dir)
       '())
   (if clear-provider-cache?
       '("--clear-provider-cache")
       '())
   (if force-provider-cache-refresh?
       '("--force-provider-cache-refresh")
       '())))

;; provider-cache-child-args : -> (listof string?)
;;   Smoke-runner cache flags safe to forward to child worker processes.
(define (provider-cache-child-args)
  (append
   (if provider-cache-dir
       (list "--provider-cache-dir" provider-cache-dir)
       '())
   ;; The parent owns cache clearing so parallel children do not race.
   (if force-provider-cache-refresh?
       '("--force-provider-cache-refresh")
       '())))

;; clear-provider-cache-for-parent! : -> void?
;;   Clear a shared provider cache once before launching child workers.
(define (clear-provider-cache-for-parent!)
  (when clear-provider-cache?
    (unless provider-cache-dir
      (raise-user-error 'probe-installed-runtime-smoke
                        "--clear-provider-cache requires --provider-cache-dir"))
    (define cache-path (path->complete-path provider-cache-dir))
    (when (directory-exists? cache-path)
      (delete-directory/files cache-path))))

;; goal1-fast-module-cases : (listof symbol?)
;;   Small must-have runtime subset for quick Goal 1 smoke checks.
(define goal1-fast-module-cases
  '(hash-basic
    hash-iterate
    hash-kind-predicates
    hash-map-basic
    hash-clear-basic
    hash-comparator-semantics
    set-require
    set-predicate
    set-union
    set-member
    set-add
    set-remove
    set->list
    set-intersect
    set-subtract
    set-symmetric-difference
    set-map
    set-comparator-semantics
    set-types-require
    set-types-predicate
    stream-first
    stream-rest
    promise-require
    promise-predicate-plain
    force-identity
    promise-basic
    promise-state
    vector-require
    vector-member-basic
    function-compose
    function-identity
    function-compose1
    function-negate
    function-const
    sequence-list
    sequence-range
    sequence-in-bytes
    sequence-in-hash
    sequence-in-hash-keys
    sequence-in-hash-values
    sequence-in-hash-pairs
    sequence-in-indexed
    sequence-stop-before-after
    sequence-in-sequences
    sequence-in-parallel
    sequence-in-cycle
    sequence-in-values-sequence
    sequence-generate-basic
    sequence-generate-star
    sequence-empty
    sequence-map-filter-count
    sequence-andmap-ormap
    sequence-for-each-fold
    sequence-add-between
    sequence-in-slice
    sequence-in-values-star
    sequence-predicate
    sequence-inclusive-range
    sequence-in-producer
    sequence-make-do
    sequence-in-syntax
    sequence-append-tail
    sequence-in-value
    sequence-ref-length
    sequence-for/list
    sequence-for/vector
    for/in-list
    for/in-vector
    for/in-string
    for/in-range
    for/in-naturals
    for/parallel-sequences
    for*/nested-sequences
    for/control-clauses
    for/list-basic
    for/fold-basic
    for*/list-basic
    for/first-basic
    values-call-with-values
    values-let-values
    sequence-for/fold
    match-basic
    match-literal-default
    match-let-basic
    match-predicate
    combined-list-string-set
    multi-module-list-string-set
    multi-module-reexport-installed
    pretty-require
    custom-write-require
    keyword-optional-direct
    keyword-plain-direct
    format-require
    format-single
    format-number
    format-write
    format-print
    format-print-string
    format-align
    format-fprintf-port
    read-list
    read-vector
    read-symbol-string
    read-comment
    read-public-list
    read-current-readtable
    read-accept-reader-param
    read-string->number
    read-regexp-literal
    read-pregexp-literal
    read-hash-literal
    read-port-location
    read-accept-dot-param
    regexp-literal
    regexp-capture
    regexp-replace
    class-require
    class-basic))

;; goal1-slow-module-cases : (listof symbol?)
;;   Passing Goal 1 smokes that are too slow for the compact fast tier.
;;   These cases are green, but they tend to spend around a minute or more in
;;   compile/tree-shake work when run as isolated bounded smokes.
(define goal1-slow-module-cases
  '(set-count
    format-basic))

;; smoke-label : installed-runtime-smoke? -> string?
;;   Render one installed smoke for list and worker diagnostics.
(define (smoke-label smoke)
  (format "~a: ~a"
          (installed-runtime-smoke-category smoke)
          (installed-runtime-smoke-name smoke)))

;; indexed-smokes : -> (listof (cons/c exact-nonnegative-integer? installed-runtime-smoke?))
;;   Pair installed runtime smokes with stable command-line indexes.
(define (indexed-smokes)
  (for/list ([smoke (in-list installed-runtime-smokes)]
             [index (in-naturals)])
    (cons index smoke)))

;; smoke-match? : exact-nonnegative-integer? installed-runtime-smoke? -> boolean?
;;   Check whether a smoke matches the command-line selector.
(define (smoke-match? index smoke)
  (and (or (not selected-index)
           (= index selected-index))
       (or (not selected-category)
           (eq? (installed-runtime-smoke-category smoke) selected-category))
       (or (not selected-name)
           (string=? (installed-runtime-smoke-name smoke) selected-name))))

;; selected-smokes : -> (listof (cons/c exact-nonnegative-integer? installed-runtime-smoke?))
;;   Return all installed smokes matching the command-line selector.
(define (selected-smokes)
  (filter (lambda (entry)
            (smoke-match? (car entry) (cdr entry)))
          (indexed-smokes)))

;; show-smokes : -> void?
;;   Print the installed smoke index for bounded one-at-a-time probes.
(define (show-smokes)
  (for ([entry (in-list (indexed-smokes))])
    (printf "~a\t~a\n" (car entry) (smoke-label (cdr entry)))))

;; module-case-root : symbol? -> symbol?
;;   Extract the root module name from a source-module probe case.
(define (module-case-root name)
  (match (reverse (module-case-data name))
    [(cons `(module ,(? symbol? root) . ,_) _) root]
    [_ (raise-arguments-error 'module-case-root
                              "expected module case data with a root module"
                              "case" name)]))

;; module-case-smoke : symbol? boolean? -> installed-runtime-smoke?
;;   Build an installed runtime smoke for one ad hoc source-module case.
(define (module-case-smoke name observe?)
  (define root (module-case-root name))
  (define observations
    (if observe?
        `((,root y))
        '()))
  (define expected-simple-output
    (if observe?
        #rx"(?m:^42$)"
        #rx""))
  (case name
    [(set-require
      set-predicate
      set-count
      set-member
      set-add
      set-remove
      set-union
      set->list
      set-intersect
      set-subtract
      set-symmetric-difference
      set-map
      set-types-require
      set-types-predicate
      stream-first
      stream-rest
      hash-basic
      hash-kind-predicates
      hash-map-basic
      hash-clear-basic
      hash-iterate
      combined-list-string-set
      multi-module-list-string-set
      multi-module-reexport-installed
      pretty-require
      promise-require
      promise-predicate-plain
      force-identity
      promise-basic
      promise-state
      vector-require
      vector-member-basic
      function-compose
      function-identity
      function-compose1
      function-negate
      function-const
      sequence-list
      sequence-range
      sequence-in-bytes
      sequence-in-hash
      sequence-in-hash-keys
      sequence-in-hash-values
      sequence-in-hash-pairs
      sequence-in-indexed
      sequence-stop-before-after
      sequence-in-sequences
      sequence-in-parallel
      sequence-in-cycle
      sequence-in-values-sequence
      sequence-generate-basic
      sequence-generate-star
      sequence-empty
      sequence-map-filter-count
      sequence-andmap-ormap
      sequence-for-each-fold
      sequence-add-between
      sequence-in-slice
      sequence-in-values-star
      sequence-predicate
      sequence-inclusive-range
      sequence-in-producer
      sequence-make-do
      sequence-in-syntax
      sequence-append-tail
      sequence-in-value
      sequence-ref-length
      sequence-for/list
      sequence-for/fold
      sequence-for/vector
      for/in-list
      for/in-vector
      for/in-string
      for/in-range
      for/in-naturals
      for/parallel-sequences
      for*/nested-sequences
      for/control-clauses
      for/list-basic
      for/fold-basic
      for*/list-basic
      for/first-basic
      class-require
      class-basic
      format-require
      format-single
      format-basic
      format-number
      format-write
      format-print
      format-print-string
      format-align
      format-fprintf-port
      read-list
      read-vector
      read-symbol-string
      read-comment
      read-public-list
      read-current-readtable
      read-accept-reader-param
      read-string->number
      read-regexp-literal
      read-pregexp-literal
      read-hash-literal
      read-port-location
      read-accept-dot-param
      regexp-literal
      regexp-capture
      regexp-replace
      match-basic
      match-literal-default
      match-let-basic
      match-predicate
      keyword-optional-direct
      keyword-plain-direct
      values-call-with-values
      values-let-values
      contract-wrapper-basic
      hash-comparator-semantics
      set-comparator-semantics)
     (installed-runtime-smoke
      name
      (format "module case ~a reaches WebRacket runtime smoke" name)
      (module-case-data name)
      observations
      (if observe?
          (case name
            [(set-count set->list set-symmetric-difference set-map) #rx"(?m:^2$)"]
            [(set-member) #rx"(?m:^true$)"]
            [(set-require set-types-require pretty-require) #rx"(?m:^42$)"]
            [(set-predicate set-remove set-subtract set-types-predicate promise-predicate-plain)
             #rx"(?m:^false$)"]
            [(set-add set-union) #rx"(?m:^3$)"]
            [(set-intersect) #rx"(?m:^1$)"]
            [(hash-kind-predicates) #rx"(?m:^true$)"]
            [(hash-map-basic) #rx"(?m:^3$)"]
            [(hash-clear-basic) #rx"(?m:^42$)"]
            [(hash-iterate) #rx"(?m:^9$)"]
            [(multi-module-list-string-set) #rx"(?m:^12$)"]
            [(multi-module-reexport-installed) #rx"(?m:^3$)"]
            [(pretty-require) #rx"(?m:^42$)"]
            [(promise-require force-identity) #rx"(?m:^42$)"]
            [(promise-basic) #rx"(?m:^42$)"]
            [(promise-state) #rx"(?m:^true$)"]
            [(vector-require function-compose function-identity function-compose1 function-const)
             #rx"(?m:^42$)"]
            [(vector-member-basic) #rx"(?m:^1$)"]
            [(function-negate) #rx"(?m:^true$)"]
            [(sequence-list
              sequence-range
              sequence-in-bytes
              sequence-for/list
              sequence-for/vector
              for/list-basic
              for/in-string)
             #rx"(?m:^3$)"]
            [(sequence-in-hash
              sequence-in-indexed)
             #rx"(?m:^3$)"]
            [(sequence-in-hash-values) #rx"(?m:^30$)"]
            [(sequence-in-hash-keys
              sequence-in-hash-pairs) #rx"(?m:^2$)"]
            [(sequence-stop-before-after) #rx"(?m:^5$)"]
            [(sequence-in-sequences) #rx"(?m:^4$)"]
            [(sequence-in-parallel) #rx"(?m:^66$)"]
            [(sequence-in-cycle) #rx"(?m:^7$)"]
            [(sequence-in-values-sequence) #rx"(?m:^2$)"]
            [(sequence-generate-basic) #rx"(?m:^31$)"]
            [(sequence-generate-star) #rx"(?m:^30$)"]
            [(sequence-empty) #rx"(?m:^0$)"]
            [(sequence-map-filter-count) #rx"(?m:^45$)"]
            [(sequence-andmap-ormap) #rx"(?m:^30$)"]
            [(sequence-for-each-fold) #rx"(?m:^18$)"]
            [(sequence-add-between) #rx"(?m:^5$)"]
            [(sequence-in-slice) #rx"(?m:^3$)"]
            [(sequence-in-values-star) #rx"(?m:^4$)"]
            [(sequence-predicate) #rx"(?m:^30$)"]
            [(sequence-inclusive-range) #rx"(?m:^27$)"]
            [(sequence-in-producer) #rx"(?m:^6$)"]
            [(sequence-make-do) #rx"(?m:^4$)"]
            [(sequence-in-syntax) #rx"(?m:^3$)"]
            [(sequence-append-tail) #rx"(?m:^24$)"]
            [(sequence-in-value) #rx"(?m:^42$)"]
            [(sequence-ref-length) #rx"(?m:^23$)"]
            [(sequence-for/fold for/fold-basic) #rx"(?m:^6$)"]
            [(for*/list-basic) #rx"(?m:^4$)"]
            [(for/in-list for/in-vector for/parallel-sequences)
             #rx"(?m:^42$)"]
            [(for*/nested-sequences) #rx"(?m:^44$)"]
            [(for/in-range) #rx"(?m:^24$)"]
            [(for/in-naturals) #rx"(?m:^45$)"]
            [(for/first-basic) #rx"(?m:^41$)"]
            [(for/control-clauses) #rx"(?m:^3$)"]
            [(hash-comparator-semantics set-comparator-semantics) #rx"(?m:^21$)"]
            [(hash-basic) #rx"(?m:^41$)"]
            [(stream-first
              stream-rest
              combined-list-string-set
              custom-write-require
              class-require
              class-basic
              match-basic
              match-literal-default
              match-let-basic
              match-predicate)
             #rx"(?m:^42$)"]
            [(format-require) #rx"(?m:^42$)"]
            [(format-single) #rx"(?m:^web$)"]
            [(format-basic) #rx"(?m:^web-racket$)"]
            [(format-number) #rx"(?m:^42$)"]
            [(format-write) #rx"(?m:^web$)"]
            [(format-print) #rx"(?m:^web$)"]
            [(format-print-string) #rx"(?m:^\"web\"$)"]
            [(format-align) #rx"(?m:^  web$)"]
            [(format-fprintf-port) #rx"(?m:^ok$)"]
            [(read-list read-vector read-public-list) #rx"(?m:^3$)"]
            [(read-symbol-string) #rx"(?m:^6$)"]
            [(read-comment) #rx"(?m:^42$)"]
            [(read-current-readtable read-accept-reader-param)
             #rx"(?m:^true$)"]
            [(read-string->number) #rx"(?m:^42$)"]
            [(read-regexp-literal read-pregexp-literal read-accept-dot-param)
             #rx"(?m:^true$)"]
            [(read-hash-literal) #rx"(?m:^41$)"]
            [(read-port-location) #rx"(?m:^8$)"]
            [(regexp-literal) #rx"(?m:^true$)"]
            [(regexp-capture) #rx"(?m:^2$)"]
            [(regexp-replace) #rx"(?m:^bonono$)"]
            [(keyword-optional-direct) #rx"(?m:^4$)"]
            [(keyword-plain-direct) #rx"(?m:^42$)"]
            [(values-call-with-values values-let-values contract-wrapper-basic)
             #rx"(?m:^42$)"]
            [else #rx"(?m:^false$)"])
          #rx"")
      '()
      #f)]
    [else
     (installed-runtime-smoke
      name
      (format "module case ~a reaches WebRacket runtime smoke" name)
      (module-case-data name)
      observations
      expected-simple-output
      '()
     #f)]))

;; parse-module-case-list : string? -> (listof symbol?)
;;   Parse a comma-separated module-case list for batched workers.
(define (parse-module-case-list text)
  (filter-map (lambda (part)
                (define trimmed (string-trim part))
                (and (not (string=? trimmed ""))
                     (string->symbol trimmed)))
              (regexp-split #rx"[, \t\r\n]+" text)))

;; parse-module-case-file : path-string? -> (listof symbol?)
;;   Parse a module-case list file, ignoring blank lines and `;` comments.
(define (parse-module-case-file path)
  (parse-module-case-list
   (string-join
    (for/list ([line (in-list (file->lines path))])
      (regexp-replace #rx";.*$" line ""))
    "\n")))

;; validate-module-case-selectors! : -> void?
;;   Reject ambiguous or unknown module-case selectors before spawning workers.
(define (validate-module-case-selectors!)
  (when (and selected-module-case (pair? selected-module-cases))
    (raise-user-error 'probe-installed-runtime-smoke
                      "use either --module-case or --module-cases, not both"))
  (define names
    (append (if selected-module-case
                (list selected-module-case)
                '())
            selected-module-cases))
  (for ([name (in-list names)])
    (unless (memq name known-module-cases)
      (raise-user-error 'probe-installed-runtime-smoke
                        "unknown module case: ~a"
                        name))))

;; chunk-list : (listof any/c) exact-positive-integer? -> (listof (listof any/c))
;;   Split xs into chunks of at most n items.
(define (chunk-list xs n)
  (let loop ([xs xs] [chunks '()])
    (cond
      [(null? xs) (reverse chunks)]
      [else
       (define-values (front rest)
         (split-at xs (min n (length xs))))
       (loop rest (cons front chunks))])))

;; select-goal1-cases : (listof symbol?) -> (listof symbol?)
;;   Apply Goal 1 skip/limit selectors to a tier without over-dropping.
(define (select-goal1-cases cases)
  (define skipped
    (drop cases (min goal1-skip (length cases))))
  (if goal1-limit
      (take skipped (min goal1-limit (length skipped)))
      skipped))

;; call-with-memory-limit : (or/c #f exact-positive-integer?) (-> any/c) -> any/c
;;   Optionally run thunk in a custodian-limited worker thread.
(define (call-with-memory-limit limit-bytes thunk)
  (cond
    [(not limit-bytes)
     (thunk)]
    [else
     ;; Custodian memory accounting limits this worker's Racket allocations.
     ;; It does not replace the parent process timeout, since subprocesses used
     ;; by extraction and WebRacket execution are outside this custodian.
     (define ch (make-channel))
     (define cust (make-custodian))
     (custodian-limit-memory cust limit-bytes cust)
     (parameterize ([current-custodian cust])
       (thread
        (lambda ()
          (channel-put
           ch
           (with-handlers ([exn:fail? (lambda (exn) (list 'exn exn))])
             (list 'values (call-with-values thunk list)))))))
     (match (channel-get ch)
       [(list 'values results) (apply values results)]
       [(list 'exn exn)        (raise exn)])]))

;; run-worker! : -> exact-integer?
;;   Run exactly one selected installed smoke in this process.
(define (run-worker!)
  (define smoke
    (cond
      [selected-module-case
       (module-case-smoke selected-module-case (not no-observe?))]
      [else
       (define matches (selected-smokes))
       (unless (= (length matches) 1)
         (raise-user-error 'probe-installed-runtime-smoke
                           "worker selector matched ~a smokes; expected exactly 1"
                           (length matches)))
       (cdar matches)]))
  (printf "worker-smoke: ~a\n" (smoke-label smoke))
  (when memory-mb
    (printf "worker-memory-limit-mb: ~a\n" memory-mb))
  (call-with-memory-limit
   (and memory-mb (* memory-mb 1024 1024))
   (lambda ()
     (parameterize ([current-runtime-smoke-preserve-dir preserve-dir]
                    [current-runtime-smoke-extra-webracket-args
                     (if selected-module-case
                         (module-cases-extra-webracket-args
                          (list selected-module-case))
                         '())])
       (run-installed-runtime-smoke smoke))))
  0)

;; run-batch-worker! : -> exact-integer?
;;   Run selected source-module smokes as one composed runtime program.
(define (run-batch-worker!)
  (when (null? selected-module-cases)
    (raise-user-error 'probe-installed-runtime-smoke
                      "batch worker requires --module-cases"))
  (define smokes
    (for/list ([name (in-list selected-module-cases)])
      (module-case-smoke name (not no-observe?))))
  (printf "worker-smoke-batch-count: ~a\n" (length smokes))
  (printf "worker-smoke-batch-cases: ~a\n"
          (string-join (map symbol->string selected-module-cases) ","))
  (when memory-mb
    (printf "worker-memory-limit-mb: ~a\n" memory-mb))
  (call-with-memory-limit
   (and memory-mb (* memory-mb 1024 1024))
   (lambda ()
     (parameterize ([current-runtime-smoke-preserve-dir preserve-dir]
                    [current-runtime-smoke-extra-webracket-args
                     (module-cases-extra-webracket-args selected-module-cases)])
       (run-installed-runtime-smokes smokes))))
  0)

;; print-runtime-dashboard-row : any/c symbol? symbol? symbol? -> void?
;;   Print a compact compile/runtime status row for bounded smoke dashboards.
(define (print-runtime-dashboard-row label compile-to-wat runtime detail)
  (printf "probe-dashboard\t~a\tcompile-to-wat\t~a\truntime\t~a\tdetail\t~a\n"
          label
          compile-to-wat
          runtime
          detail))

;; runtime-failure-detail : string? string? -> symbol?
;;   Classify a failed child smoke from the diagnostics it already emitted.
(define (runtime-failure-detail stdout stderr)
  (define output (string-append stdout "\n" stderr))
  (cond
    [(regexp-match? #rx"runtime-smoke-failure-" output)
     'runtime-composition-failed]
    [(regexp-match? #rx"unsafe-ffi-primitive|ffi file not found|foreign import|FFI" output)
     'ffi-resolution-failed]
    [(regexp-match? #rx"unsupported providers|external provider is not in the Goal 1 trial allowlist|unknown module|cannot resolve #lang" output)
     'provider-graph-failed]
    [(regexp-match? #rx"missing primitive-table entries" output)
     'missing-primitives]
    [(regexp-match? #rx"batched extraction failed|extract-installed" output)
     'extract-failed]
    [else 'failed]))

;; run-child/bounded! : any/c installed-runtime-smoke? (listof string?) -> exact-integer?
;;   Run one smoke in a child Racket process and kill it on timeout.
(define (run-child/bounded! label smoke selector-args)
  (define start-ms (current-inexact-milliseconds))
  (define exec-file (find-system-path 'exec-file))
  (define racket-bin
    (cond
      [(and (path? exec-file)
            (complete-path? exec-file))
       exec-file]
      [(and (path? exec-file)
            (file-exists? exec-file))
       (path->complete-path exec-file)]
      [else
       (find-executable-path (path->string exec-file))]))
  (unless racket-bin
    (raise-user-error 'probe-installed-runtime-smoke
                      "could not find current racket executable on PATH"))
  (define tmp-dir (make-temporary-file "webracket-installed-probe-~a" 'directory))
  (define out-path (build-path tmp-dir "stdout.txt"))
  (define err-path (build-path tmp-dir "stderr.txt"))
  (define out (open-output-file out-path #:exists 'truncate/replace))
  (define err (open-output-file err-path #:exists 'truncate/replace))
  (define args
    (append
     ;; Use the same Racket executable as the parent. Newer-checkout probes
     ;; should compile the local WebRacket entrypoints with that executable
     ;; first, so the worker does not load stale repo-local `.zo` files.
     (list "-y"
           (path->string self-path)
           "--worker")
     selector-args
     (if preserve-dir
         (list "--preserve-dir" preserve-dir)
         '())
     (if no-observe?
         (list "--no-observe")
         '())
     (if runtime-timings?
         (list "--runtime-timings")
         '())
     (provider-cache-child-args)
     (if memory-mb
         (list "--memory-mb" (number->string memory-mb))
         '())))
  (printf "probe-smoke: ~a\t~a\n" label (smoke-label smoke))
  (printf "probe-timeout-seconds: ~a\n" timeout-seconds)
  (flush-output)
  (define-values (proc child-out child-in child-err)
    (apply subprocess out #f err 'new (path->string racket-bin) args))
  (when child-out (close-input-port child-out))
  (when child-in  (close-output-port child-in))
  (when child-err (close-input-port child-err))
  (define completed (sync/timeout timeout-seconds proc))
  (unless completed
    (subprocess-kill proc #t))
  (subprocess-wait proc)
  (close-output-port out)
  (close-output-port err)
  (define stdout (file->string out-path))
  (define stderr (file->string err-path))
  (unless (string=? stdout "")
    (display stdout))
  (unless (string=? stderr "")
    (display stderr (current-error-port)))
  (define status (subprocess-status proc))
  (delete-directory/files tmp-dir)
  (define elapsed-ms
    (inexact->exact
     (round (- (current-inexact-milliseconds) start-ms))))
  (printf "probe-elapsed-ms: ~a\n" elapsed-ms)
  (cond
    [(not completed)
     (printf "probe-result: timeout\n")
     (print-runtime-dashboard-row label 'unknown 'timeout 'child-timeout)
     124]
    [(and (integer? status) (zero? status))
     (printf "probe-result: pass\n")
     (print-runtime-dashboard-row label 'pass 'pass 'ok)
     0]
    [else
     (printf "probe-result: fail status=~a\n" status)
     (define detail (runtime-failure-detail stdout stderr))
     (print-runtime-dashboard-row
      label
      (if (eq? detail 'runtime-composition-failed) 'pass 'unknown)
      'fail
      detail)
     (if (integer? status) status 1)]))

;; run-module-case-batch/bounded! : (listof symbol?) -> exact-integer?
;;   Run a source-module case batch in a child process and kill it on timeout.
(define (run-module-case-batch/bounded! names)
  (define label
    (format "batch:~a"
            (string-join (map symbol->string names) ",")))
  (define smoke
    (module-case-smoke (car names) (not no-observe?)))
  (run-child/bounded!
   label
   smoke
   (list "--batch-worker"
         "--module-cases"
         (string-join (map symbol->string names) ","))))

;; run-module-case-chunk/bounded! : (listof symbol?) -> exact-integer?
;;   Run a batch, then rerun individual cases to isolate a failing batch.
(define (run-module-case-chunk/bounded! names)
  (cond
    [(= (length names) 1)
     (define name (car names))
     (run-child/bounded!
      (format "case:~a" name)
      (module-case-smoke name (not no-observe?))
      (list "--module-case" (symbol->string name)))]
    [else
     (define batch-status (run-module-case-batch/bounded! names))
     (cond
       [(zero? batch-status) 0]
       [else
        (printf "probe-batch-fallback: rerunning ~a cases individually\n"
                (length names))
        (for/fold ([status batch-status]) ([name (in-list names)])
          (define next-status
            (run-child/bounded!
             (format "case:~a" name)
             (module-case-smoke name (not no-observe?))
             (list "--module-case" (symbol->string name))))
          (if (zero? status) next-status status))])]))

;; run-thunks : (listof (-> exact-integer?)) -> exact-integer?
;;   Run parent probe tasks serially or across a bounded number of lanes.
(define (run-thunks thunks)
  (cond
    [(or (<= jobs 1) (<= (length thunks) 1))
     (for/fold ([status 0]) ([thunk (in-list thunks)])
       (define next-status (thunk))
       (if (zero? status) next-status status))]
    [else
     (define task-ch (make-async-channel))
     (define result-ch (make-channel))
     (define worker-count (min jobs (length thunks)))
     (for ([worker-index (in-range worker-count)])
       (thread
        (lambda ()
          (let loop ()
            (define task (async-channel-get task-ch))
            (cond
              [(not task)
               (channel-put result-ch (cons worker-index #f))]
              [else
               (define status
                 (with-handlers ([exn:fail?
                                  (lambda (exn)
                                    (displayln (exn-message exn)
                                               (current-error-port))
                                    1)])
                   ((cdr task))))
               (channel-put result-ch (cons (car task) status))
               (loop)])))))
     (for ([thunk (in-list thunks)]
           [index (in-naturals)])
       (async-channel-put task-ch (cons index thunk)))
     (for ([_ (in-range worker-count)])
       (async-channel-put task-ch #f))
     (let loop ([remaining (+ (length thunks) worker-count)] [status 0])
       (cond
         [(zero? remaining) status]
         [else
          (match-define (cons _ result) (channel-get result-ch))
          (loop (sub1 remaining)
                (if (and result (zero? status)) result status))]))]))

;; run-parent! : -> exact-integer?
;;   List or run selected installed smokes one at a time with a hard timeout.
(define (run-parent!)
  (cond
    [list-only?
     (show-smokes)
     (for ([name (in-list goal1-fast-module-cases)]
           [index (in-naturals)])
       (printf "goal1-fast-case:~a\tindex: ~a\tmodule case: ~a\n" name index name))
     (for ([name (in-list goal1-slow-module-cases)]
           [index (in-naturals)])
       (printf "goal1-slow-case:~a\tindex: ~a\tmodule case: ~a\n" name index name))
     (for ([name (in-list known-module-cases)])
       (printf "case:~a\tmodule case: ~a\n" name name))
     0]
    [(pair? selected-module-cases)
     (define chunks (chunk-list selected-module-cases batch-size))
     (run-thunks
      (for/list ([names (in-list chunks)])
        (lambda ()
          (run-module-case-chunk/bounded! names))))]
    [goal1-fast?
     (define selected-cases (select-goal1-cases goal1-fast-module-cases))
     (define chunks (chunk-list selected-cases batch-size))
     (run-thunks
      (for/list ([names (in-list chunks)])
        (lambda ()
          (run-module-case-chunk/bounded! names))))]
    [goal1-slow?
     (set! runtime-timings? #t)
     (define selected-cases (select-goal1-cases goal1-slow-module-cases))
     (define chunks (chunk-list selected-cases batch-size))
     (run-thunks
      (for/list ([names (in-list chunks)])
        (lambda ()
          (run-module-case-chunk/bounded! names))))]
    [selected-module-case
     (run-child/bounded!
      (format "case:~a" selected-module-case)
      (module-case-smoke selected-module-case (not no-observe?))
      (list "--module-case" (symbol->string selected-module-case)))]
    [else
     (define matches (selected-smokes))
     (when (null? matches)
       (raise-user-error 'probe-installed-runtime-smoke
                         "selector matched no installed runtime smokes"))
     (run-thunks
      (for/list ([entry (in-list matches)])
        (lambda ()
          (run-child/bounded!
           (car entry)
           (cdr entry)
           (list "--index" (number->string (car entry)))))))]))

(command-line
 #:program "probe-installed-runtime-smoke"
 #:once-each
 [("--list") "list installed runtime smokes without running them"
             (set! list-only? #t)]
 [("--goal1-fast") "run a compact must-have Goal 1 runtime subset"
                   (set! goal1-fast? #t)]
 [("--goal1-slow") "run slow-but-passing Goal 1 runtime subset with timings"
                   (set! goal1-slow? #t)
                   (set! runtime-timings? #t)]
 [("--runtime-timings") "pass --timings through to child WebRacket runs"
                        (set! runtime-timings? #t)]
 [("--extra-webracket-arg") arg "pass one extra argument through to child WebRacket runs"
                            (set! extra-webracket-args
                                  (append extra-webracket-args (list arg)))]
 [("--provider-cache-dir") dir "pass --provider-cache-dir through to child WebRacket runs"
                           (set! provider-cache-dir dir)]
 [("--clear-provider-cache") "clear --provider-cache-dir once before parent smoke runs"
                             (set! clear-provider-cache? #t)]
 [("--force-provider-cache-refresh") "pass --force-provider-cache-refresh through to child WebRacket runs"
                                     (set! force-provider-cache-refresh? #t)]
 [("--worker") "internal mode: run the selected smoke in this process"
               (set! worker? #t)]
 [("--batch-worker") "internal mode: run selected module cases as one batch"
                     (set! batch-worker? #t)]
 [("--timeout") seconds "seconds before killing a child smoke process"
                (set! timeout-seconds (string->number seconds))]
 [("--memory-mb") mb "best-effort Racket worker memory limit in MiB"
                  (set! memory-mb (string->number mb))]
 [("--batch-size") n "module cases per child for Goal 1 tiers (default 1)"
                  (set! batch-size (max 1 (string->number n)))]
 [("--jobs") n "parent-side child processes to run concurrently (default 1)"
             (set! jobs (max 1 (string->number n)))]
 [("--goal1-limit") n "limit the selected Goal 1 tier to the first n cases"
                    (set! goal1-limit (string->number n))]
 [("--goal1-skip") n "skip the first n cases in the selected Goal 1 tier"
                   (set! goal1-skip (max 0 (string->number n)))]
 [("--preserve-dir") dir "copy generated runtime-smoke artifacts into dir"
                     (set! preserve-dir dir)]
 [("--no-observe") "for --module-case, instantiate without logging an export"
                   (set! no-observe? #t)]
 [("--index") index "run only the smoke at index"
              (set! selected-index (string->number index))]
 [("--category") category "run only smokes whose category matches the symbol"
                 (set! selected-category (string->symbol category))]
 [("--name") name "run only the smoke whose description exactly matches"
            (set! selected-name name)]
 [("--module-case") name "run one source-module case from probe-installed-module-deps"
                    (set! selected-module-case (string->symbol name))]
 [("--module-cases") names "comma-separated source-module cases to run from the parent"
                     (set! selected-module-cases (parse-module-case-list names))]
 [("--module-cases-file") path "read source-module cases from a file"
                          (set! selected-module-cases
                                (parse-module-case-file path))])

(validate-module-case-selectors!)

(exit
 (cond
   [batch-worker? (run-batch-worker!)]
   [worker?       (run-worker!)]
   [else
    (clear-provider-cache-for-parent!)
    (run-parent!)]))
