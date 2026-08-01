#lang racket/base

(provide check-no-stdlib-result-tree
         check-no-stdlib-result-tree/chunked
         env-positive-integer/default
         make-no-stdlib-result-tree-fixture
         select-indexed-items
         check-no-stdlib-result-tree-fixtures/parallel
         (struct-out no-stdlib-result-tree-fixture))

(require racket/list
         racket/async-channel
         racket/file
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         rackunit
         "../webify/test-module-support.rkt")

(define-runtime-path repo-root "..")

(struct no-stdlib-result-tree-fixture
  (path timeout-seconds chunked? max-datum-bytes)
  #:transparent)

(struct fixture-result
  (index fixture ok? message)
  #:transparent)

(struct chunk-job
  (index count path name)
  #:transparent)

(struct chunk-result
  (index name ok? message)
  #:transparent)

(struct false-leaf
  (path labels)
  #:transparent)

;; make-no-stdlib-result-tree-fixture : path-string? [#:timeout-seconds exact-positive-integer?] [#:chunked? boolean?] [#:max-datum-bytes exact-positive-integer?] -> no-stdlib-result-tree-fixture?
;;   Build a generated-output fixture description for the parallel checker.
(define (make-no-stdlib-result-tree-fixture path
                                            #:timeout-seconds [timeout-seconds 180]
                                            #:chunked? [chunked? #f]
                                            #:max-datum-bytes [max-datum-bytes 160000])
  (no-stdlib-result-tree-fixture path timeout-seconds chunked? max-datum-bytes))

;; env-positive-integer/default : string? exact-positive-integer? -> exact-positive-integer?
;;   Read a positive integer environment variable, falling back to default.
(define (env-positive-integer/default name default)
  (define raw (getenv name))
  (define n (and raw (string->number raw)))
  (if (and (exact-integer? n) (positive? n))
      n
      default))

;; parse-positive-index : symbol? string? -> exact-positive-integer?
;;   Parse one positive one-based index.
(define (parse-positive-index who s)
  (define n (string->number s))
  (unless (and (exact-integer? n) (positive? n))
    (error who "expected a positive integer index, got: ~a" s))
  n)

;; parse-index-spec : (or/c string? #f) -> (or/c hash? #f)
;;   Parse an index/range selection such as "1", "1-4", or "1,3-5".
(define (parse-index-spec spec)
  (define who 'parse-index-spec)
  (define trimmed (and spec (string-trim spec)))
  (cond
    [(or (not trimmed)
         (string=? trimmed "")
         (string-ci=? trimmed "all")
         (string=? trimmed "*"))
     #f]
    [else
     (define selected (make-hash))
     (for ([piece (in-list (string-split trimmed ","))])
       (define p (string-trim piece))
       (cond
         [(regexp-match #px"^([0-9]+)$" p)
          => (lambda (m)
               (hash-set! selected
                          (parse-positive-index who (second m))
                          #t))]
         [(regexp-match #px"^([0-9]+)-([0-9]+)$" p)
          => (lambda (m)
               (define start (parse-positive-index who (second m)))
               (define end (parse-positive-index who (third m)))
               (when (> start end)
                 (error who "range start is greater than end: ~a" p))
               (for ([index (in-range start (add1 end))])
                 (hash-set! selected index #t)))]
         [else
          (error who
                 "expected comma-separated indexes/ranges, got: ~a"
                 spec)]))
     selected]))

;; parse-shard-spec : (or/c string? #f) -> (or/c (cons/c exact-positive-integer? exact-positive-integer?) #f)
;;   Parse a one-based shard spec of the form K/N.
(define (parse-shard-spec spec)
  (define who 'parse-shard-spec)
  (define trimmed (and spec (string-trim spec)))
  (cond
    [(or (not trimmed) (string=? trimmed ""))
     #f]
    [(regexp-match #px"^([0-9]+)/([0-9]+)$" trimmed)
     => (lambda (m)
          (define shard-index (parse-positive-index who (second m)))
          (define shard-count (parse-positive-index who (third m)))
          (when (> shard-index shard-count)
            (error who
                   "shard index must be <= shard count, got: ~a"
                   trimmed))
          (cons shard-index shard-count))]
    [else
     (error who "expected shard spec K/N, got: ~a" spec)]))

;; shard-selected-index? : exact-positive-integer? (cons/c exact-positive-integer? exact-positive-integer?) -> boolean?
;;   Check whether one-based index belongs to a one-based K/N shard.
(define (shard-selected-index? index shard)
  (= (modulo (sub1 index) (cdr shard))
     (sub1 (car shard))))

;; select-indexed-items :
;;   list? [#:index-spec (or/c string? #f)] [#:shard-spec (or/c string? #f)]
;;   -> (listof pair?)
;;   Select one-based indexed items, preserving original indexes in the result.
(define (select-indexed-items items
                              #:index-spec [index-spec #f]
                              #:shard-spec [shard-spec #f])
  (define selected-indexes (parse-index-spec index-spec))
  (define shard (parse-shard-spec shard-spec))
  (for/list ([item (in-list items)]
             [index (in-naturals 1)]
             #:when (and (or (not selected-indexes)
                             (hash-ref selected-indexes index #f))
                         (or (not shard)
                             (shard-selected-index? index shard))))
    (cons index item)))

;; read-single-datum : string? -> any/c
;;   Read the one result tree that a no-stdlib test program prints.
(define (read-single-datum output)
  (define in (open-input-string output))
  (define datum (read in))
  (when (eof-object? datum)
    (raise-user-error 'read-single-datum
                      "test program should print one result datum"))
  (define trailing (read in))
  (unless (eof-object? trailing)
    (raise-user-error
     'read-single-datum
     "test program should not print extra data after the result datum"))
  datum)

;; false-leaf-locations : any/c -> (listof false-leaf?)
;;   Find false leaves in a nested result tree, preserving nearby labels.
(define (false-leaf-locations datum)
  (let loop ([v datum] [path '()])
    (cond
      [(eq? v #f) (list (false-leaf (reverse path) '()))]
      [(pair? v)
       (append* (for/list ([child (in-list v)]
                           [index (in-naturals)])
                  (define child-locations
                    (loop child (cons index path)))
                  (if (and (zero? index) (string? child))
                      child-locations
                      (attach-parent-label v child-locations))))]
      [(vector? v)
       (append* (for/list ([child (in-vector v)]
                           [index (in-naturals)])
                  (loop child (cons index path))))]
      [else '()])))

;; attach-parent-label : any/c (listof false-leaf?) -> (listof false-leaf?)
;;   Attach a leading string label from a list node to child false-leaf reports.
(define (attach-parent-label v locations)
  (cond
    [(and (pair? v) (string? (car v)))
     (for/list ([location (in-list locations)])
       (false-leaf (false-leaf-path location)
                   (cons (car v) (false-leaf-labels location))))]
    [else locations]))

;; false-leaf-paths : any/c -> (listof (listof any/c))
;;   Find false leaves in a nested result tree.
(define (false-leaf-paths datum)
  (map false-leaf-path (false-leaf-locations datum)))

;; false-leaf->string : false-leaf? -> string?
;;   Render a false-leaf report with labels and the raw tree path.
(define (false-leaf->string location)
  (define labels (false-leaf-labels location))
  (define label-text
    (if (null? labels)
        "<unlabeled>"
        (string-join labels " > ")))
  (format "~a at result-tree path ~s"
          label-text
          (false-leaf-path location)))

;; list-form-datum? : any/c -> boolean?
;;   Check whether datum is a source-level `(list ...)` form.
(define (list-form-datum? datum)
  (and (pair? datum)
       (eq? (car datum) 'list)))

;; result-section-datum? : any/c -> boolean?
;;   Check whether datum looks like a labeled result-tree section.
(define (result-section-datum? datum)
  (and (list-form-datum? datum)
       (pair? (cdr datum))
       (string? (cadr datum))))

;; datum-write-size : any/c -> exact-nonnegative-integer?
;;   Estimate source size by measuring the printed datum.
(define (datum-write-size datum)
  (string-length
   (with-output-to-string
     (lambda ()
       (write datum)))))

;; pack-datum-chunks : (listof any/c) ((listof any/c) -> any/c) exact-positive-integer? -> (listof any/c)
;;   Pack already-split items under make-datum without exceeding max-bytes when possible.
(define (pack-datum-chunks items make-datum max-bytes)
  (define empty-size (datum-write-size (make-datum '())))
  (define groups '())
  (define current '())
  (define current-size empty-size)
  (define (flush!)
    (unless (null? current)
      (set! groups (cons (reverse current) groups))
      (set! current '())
      (set! current-size empty-size)))
  (for ([item (in-list items)])
    (define item-size (datum-write-size item))
    (define candidate-size (+ current-size item-size 1))
    (when (and (pair? current)
               (> candidate-size max-bytes))
      (flush!))
    (set! current (cons item current))
    (set! current-size (+ current-size item-size 1)))
  (flush!)
  (for/list ([group (in-list (reverse groups))])
    (make-datum group)))

;; result-tree-datum-chunks : any/c exact-positive-integer? -> (listof any/c)
;;   Split an oversized result-tree datum into independently runnable chunks.
(define (result-tree-datum-chunks datum max-bytes)
  (cond
    [(<= (datum-write-size datum) max-bytes)
     (list datum)]
    [(result-section-datum? datum)
     (define label (cadr datum))
     (define children
       (append-map (lambda (child)
                     (result-tree-datum-chunks child max-bytes))
                   (cddr datum)))
     (pack-datum-chunks children
                        (lambda (group) `(list ,label ,@group))
                        max-bytes)]
    [(list-form-datum? datum)
     (define children
       (append-map (lambda (child)
                     (result-tree-datum-chunks child max-bytes))
                   (cdr datum)))
     (pack-datum-chunks children
                        (lambda (group) `(list ,@group))
                        max-bytes)]
    [else
     (list datum)]))

;; resolve-test-path : path-string? -> path?
;;   Resolve relative test paths against the repository root.
(define (resolve-test-path test-path)
  (define path
    (if (path? test-path)
        test-path
        (string->path test-path)))
  (if (relative-path? path)
      (build-path repo-root path)
      path))

;; check-result-tree-output : path-string? string? -> void?
;;   Check one no-stdlib result-tree program output.
(define (check-result-tree-output test-path output)
  (define datum (read-single-datum output))
  (define failures (false-leaf-locations datum))
  (unless (null? failures)
    (raise-user-error
     'check-result-tree-output
     "~a false leaves:\n~a"
     test-path
     (string-join
      (map false-leaf->string failures)
      "\n"))))

;; check-no-stdlib-result-tree : path-string? [#:timeout-seconds exact-positive-integer?] -> void?
;;   Run a no-stdlib WebRacket result-tree program with bounded resources.
(define (check-no-stdlib-result-tree test-path #:timeout-seconds [timeout-seconds 180])
  (define-values (status output)
    (run-webracket (list "--no-stdlib"
                         "--internal-bind-immutable-hash-debug-shape"
                         "-r"
                         test-path)
                   repo-root
                   #:timeout-seconds timeout-seconds
                   #:memory-mb 4096))
  (check-equal? status 0 output)
  (check-result-tree-output test-path output))

;; repo-tmp-root : -> path?
;;   Return the repository-local temporary directory for generated chunk files.
(define (repo-tmp-root)
  (define root (build-path repo-root "tmp"))
  (make-directory* root)
  root)

;; write-chunk-jobs! : path-string? path-string? (listof pair?) exact-nonnegative-integer? -> (listof chunk-job?)
;;   Materialize selected chunk programs and describe runnable chunk jobs.
(define (write-chunk-jobs! test-path tmp-dir indexed-chunks chunk-count)
  (for/list ([indexed-chunk (in-list indexed-chunks)])
    (define index (car indexed-chunk))
    (define chunk (cdr indexed-chunk))
    (define chunk-path
      (build-path tmp-dir
                  (format "chunk-~a.rkt" index)))
    (write-datum-program! chunk-path chunk)
    (chunk-job index
               chunk-count
               chunk-path
               (format "~a chunk ~a/~a" test-path index chunk-count))))

;; run-chunk-job! : chunk-job? exact-positive-integer? -> void?
;;   Run one generated no-stdlib chunk program and check its result tree.
(define (run-chunk-job! job timeout-seconds)
  (define-values (status output)
    (run-webracket (list "--no-stdlib"
                         "--internal-bind-immutable-hash-debug-shape"
                         "-r"
                         (path->string (chunk-job-path job)))
                   repo-root
                   #:timeout-seconds timeout-seconds
                   #:memory-mb 4096))
  (unless (zero? status)
    (raise-user-error 'run-chunk-job!
                      "~a exited with status ~a\n~a"
                      (chunk-job-name job)
                      status
                      output))
  (check-result-tree-output (chunk-job-name job) output))

;; run-chunk-job/capture : chunk-job? exact-positive-integer? -> chunk-result?
;;   Run one chunk job and capture any rackunit failure for parallel reporting.
(define (run-chunk-job/capture job timeout-seconds)
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (chunk-result (chunk-job-index job)
                                   (chunk-job-name job)
                                   #f
                                   (exn-message exn)))])
    (run-chunk-job! job timeout-seconds)
    (chunk-result (chunk-job-index job)
                  (chunk-job-name job)
                  #t
                  "")))

;; chunk-result<? : chunk-result? chunk-result? -> boolean?
;;   Compare chunk results by original chunk index.
(define (chunk-result<? a b)
  (< (chunk-result-index a) (chunk-result-index b)))

;; chunk-failure-message : chunk-result? -> string?
;;   Render one failed chunk for a combined rackunit failure.
(define (chunk-failure-message result)
  (format "~a failed:\n~a"
          (chunk-result-name result)
          (chunk-result-message result)))

;; report-chunk-result! : chunk-result? -> void?
;;   Print a one-line progress report for a completed result-tree chunk.
(define (report-chunk-result! result)
  (printf "result-tree-chunk: ~a ~a\n"
          (if (chunk-result-ok? result) "ok" "failed")
          (chunk-result-name result))
  (flush-output))

;; check-no-stdlib-result-tree-chunks/parallel :
;;   (listof chunk-job?) exact-positive-integer? [#:jobs exact-positive-integer?] -> void?
;;   Run selected generated result-tree chunks with a bounded worker pool.
(define (check-no-stdlib-result-tree-chunks/parallel chunk-jobs
                                                     timeout-seconds
                                                     #:jobs [jobs 1])
  (define chunk-count (length chunk-jobs))
  (define worker-count (if (zero? chunk-count)
                           0
                           (max 1 (min jobs chunk-count))))
  (define done (gensym 'done))
  (define job-ch (make-async-channel))
  (define result-ch (make-async-channel))
  (define workers
    (for/list ([_ (in-range worker-count)])
      (thread
       (lambda ()
         (let loop ()
           (define job (async-channel-get job-ch))
           (unless (eq? job done)
             (async-channel-put
              result-ch
              (run-chunk-job/capture job timeout-seconds))
             (loop)))))))
  (for ([job (in-list chunk-jobs)])
    (async-channel-put job-ch job))
  (for ([_ (in-range worker-count)])
    (async-channel-put job-ch done))
  (define results
    (for/list ([_ (in-range chunk-count)])
      (define result (async-channel-get result-ch))
      (report-chunk-result! result)
      result))
  (for ([worker (in-list workers)])
    (thread-wait worker))
  (define failures
    (filter (lambda (result)
              (not (chunk-result-ok? result)))
            (sort results chunk-result<?)))
  (unless (null? failures)
    (fail (string-join (map chunk-failure-message failures) "\n\n"))))

;; check-no-stdlib-result-tree/chunked :
;;   path-string? [#:timeout-seconds exact-positive-integer?]
;;                [#:max-datum-bytes exact-positive-integer?]
;;                [#:jobs exact-positive-integer?]
;;                [#:chunk-spec (or/c string? #f)]
;;                [#:shard-spec (or/c string? #f)]
;;   -> void?
;;   Run an oversized no-stdlib result-tree program as temporary chunks.
(define (check-no-stdlib-result-tree/chunked test-path
                                            #:timeout-seconds [timeout-seconds 180]
                                            #:max-datum-bytes [max-datum-bytes 160000]
                                            #:jobs [jobs 1]
                                            #:chunk-spec [chunk-spec #f]
                                            #:shard-spec [shard-spec #f])
  (define source-path (resolve-test-path test-path))
  (define datum (call-with-input-file source-path read))
  (define chunks (result-tree-datum-chunks datum max-datum-bytes))
  (define chunk-count (length chunks))
  (define indexed-chunks
    (select-indexed-items chunks
                          #:index-spec chunk-spec
                          #:shard-spec shard-spec))
  (when (null? indexed-chunks)
    (fail (format "~a selected no result-tree chunks out of ~a total chunks"
                  test-path
                  chunk-count)))
  (define tmp-dir
    (make-temporary-file "webracket-result-tree-chunks-~a"
                         'directory
                         (repo-tmp-root)))
  (dynamic-wind
    void
    (lambda ()
      (define chunk-jobs
        (write-chunk-jobs! test-path tmp-dir indexed-chunks chunk-count))
      (check-no-stdlib-result-tree-chunks/parallel
       chunk-jobs
       timeout-seconds
       #:jobs jobs))
    (lambda ()
      (with-handlers ([exn:fail? void])
        (delete-directory/files tmp-dir)))))

;; run-no-stdlib-result-tree-fixture : no-stdlib-result-tree-fixture? -> void?
;;   Run one generated-output fixture using the appropriate checker.
(define (run-no-stdlib-result-tree-fixture fixture)
  (define test-path (no-stdlib-result-tree-fixture-path fixture))
  (define timeout-seconds (no-stdlib-result-tree-fixture-timeout-seconds fixture))
  (if (no-stdlib-result-tree-fixture-chunked? fixture)
      (check-no-stdlib-result-tree/chunked
       test-path
       #:timeout-seconds timeout-seconds
       #:max-datum-bytes (no-stdlib-result-tree-fixture-max-datum-bytes fixture)
       #:jobs (env-positive-integer/default
               "WEBRACKET_RESULT_TREE_CHUNK_JOBS"
               4)
       #:chunk-spec (getenv "WEBRACKET_RESULT_TREE_CHUNKS")
       #:shard-spec (getenv "WEBRACKET_RESULT_TREE_SHARD"))
      (check-no-stdlib-result-tree
       test-path
       #:timeout-seconds timeout-seconds)))

;; run-fixture/capture : exact-nonnegative-integer? no-stdlib-result-tree-fixture? -> fixture-result?
;;   Run one fixture and capture any rackunit failure for parallel reporting.
(define (run-fixture/capture index fixture)
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (fixture-result index fixture #f (exn-message exn)))])
    (run-no-stdlib-result-tree-fixture fixture)
    (fixture-result index fixture #t "")))

;; fixture-result<? : fixture-result? fixture-result? -> boolean?
;;   Compare fixture results by original fixture order.
(define (fixture-result<? a b)
  (< (fixture-result-index a) (fixture-result-index b)))

;; fixture-failure-message : fixture-result? -> string?
;;   Render one failed fixture for a combined rackunit failure.
(define (fixture-failure-message result)
  (format "~a failed:\n~a"
          (no-stdlib-result-tree-fixture-path (fixture-result-fixture result))
          (fixture-result-message result)))

;; report-fixture-result! : fixture-result? -> void?
;;   Print a one-line progress report for a completed generated-output fixture.
(define (report-fixture-result! result)
  (printf "result-tree-fixture: ~a ~a\n"
          (if (fixture-result-ok? result) "ok" "failed")
          (no-stdlib-result-tree-fixture-path (fixture-result-fixture result)))
  (flush-output))

;; check-no-stdlib-result-tree-fixtures/parallel : (listof no-stdlib-result-tree-fixture?) [#:jobs exact-positive-integer?] -> void?
;;   Run independent generated-output fixtures with a bounded worker pool.
(define (check-no-stdlib-result-tree-fixtures/parallel fixtures #:jobs [jobs 4])
  (define fixture-count (length fixtures))
  (define worker-count (if (zero? fixture-count)
                           0
                           (max 1 (min jobs fixture-count))))
  (define done (gensym 'done))
  (define job-ch (make-async-channel))
  (define result-ch (make-async-channel))
  (define workers
    (for/list ([_ (in-range worker-count)])
      (thread
       (lambda ()
         (let loop ()
           (define job (async-channel-get job-ch))
           (unless (eq? job done)
             (async-channel-put
              result-ch
              (run-fixture/capture (car job) (cdr job)))
             (loop)))))))
  (for ([fixture (in-list fixtures)]
        [index (in-naturals)])
    (async-channel-put job-ch (cons index fixture)))
  (for ([_ (in-range worker-count)])
    (async-channel-put job-ch done))
  (define results
    (for/list ([_ (in-range fixture-count)])
      (define result (async-channel-get result-ch))
      (report-fixture-result! result)
      result))
  (for ([worker (in-list workers)])
    (thread-wait worker))
  (define failures
    (filter (lambda (result)
              (not (fixture-result-ok? result)))
            (sort results fixture-result<?)))
  (unless (null? failures)
    (fail (string-join (map fixture-failure-message failures) "\n\n"))))

(module+ test
  (check-equal? (map car (select-indexed-items '(a b c d e)
                                               #:index-spec "1,3-4"))
                '(1 3 4))
  (check-equal? (map cdr (select-indexed-items '(a b c d e)
                                               #:index-spec "2-3"))
                '(b c))
  (check-equal? (map car (select-indexed-items '(a b c d e)
                                               #:shard-spec "2/3"))
                '(2 5))
  (check-equal? (map car (select-indexed-items '(a b c d e)
                                               #:index-spec "2-5"
                                               #:shard-spec "1/2"))
                '(3 5))
  (check-equal? (env-positive-integer/default
                 "WEBRACKET_NO_SUCH_POSITIVE_INTEGER_ENV"
                 7)
                7))
