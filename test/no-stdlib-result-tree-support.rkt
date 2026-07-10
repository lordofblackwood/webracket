#lang racket/base

(provide check-no-stdlib-result-tree
         check-no-stdlib-result-tree/chunked
         make-no-stdlib-result-tree-fixture
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

;; make-no-stdlib-result-tree-fixture : path-string? [#:timeout-seconds exact-positive-integer?] [#:chunked? boolean?] [#:max-datum-bytes exact-positive-integer?] -> no-stdlib-result-tree-fixture?
;;   Build a generated-output fixture description for the parallel checker.
(define (make-no-stdlib-result-tree-fixture path
                                            #:timeout-seconds [timeout-seconds 180]
                                            #:chunked? [chunked? #f]
                                            #:max-datum-bytes [max-datum-bytes 160000])
  (no-stdlib-result-tree-fixture path timeout-seconds chunked? max-datum-bytes))

;; read-single-datum : string? -> any/c
;;   Read the one result tree that a no-stdlib test program prints.
(define (read-single-datum output)
  (define in (open-input-string output))
  (define datum (read in))
  (check-false (eof-object? datum) "test program should print one result datum")
  (define trailing (read in))
  (check-true (eof-object? trailing)
              "test program should not print extra data after the result datum")
  datum)

;; false-leaf-paths : any/c -> (listof (listof any/c))
;;   Find false leaves in a nested result tree.
(define (false-leaf-paths datum)
  (let loop ([v datum] [path '()])
    (cond
      [(eq? v #f) (list (reverse path))]
      [(pair? v)
       (append* (for/list ([child (in-list v)]
                           [index (in-naturals)])
                  (loop child (cons index path))))]
      [(vector? v)
       (append* (for/list ([child (in-vector v)]
                           [index (in-naturals)])
                  (loop child (cons index path))))]
      [else '()])))

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
  (define failures (false-leaf-paths datum))
  (check-equal? (length failures)
                0
                (format "~a false leaves at result-tree paths: ~s"
                        test-path
                        failures)))

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

;; check-no-stdlib-result-tree/chunked : path-string? [#:timeout-seconds exact-positive-integer?] [#:max-datum-bytes exact-positive-integer?] -> void?
;;   Run an oversized no-stdlib result-tree program as temporary chunks.
(define (check-no-stdlib-result-tree/chunked test-path
                                            #:timeout-seconds [timeout-seconds 180]
                                            #:max-datum-bytes [max-datum-bytes 160000])
  (define source-path (resolve-test-path test-path))
  (define datum (call-with-input-file source-path read))
  (define chunks (result-tree-datum-chunks datum max-datum-bytes))
  (define chunk-count (length chunks))
  (define tmp-dir (make-temporary-file "webracket-result-tree-chunks-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (for ([chunk (in-list chunks)]
            [index (in-naturals 1)])
        (define chunk-path
          (build-path tmp-dir
                      (format "chunk-~a.rkt" index)))
        (write-datum-program! chunk-path chunk)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "--internal-bind-immutable-hash-debug-shape"
                               "-r"
                               (path->string chunk-path))
                         repo-root
                         #:timeout-seconds timeout-seconds
                         #:memory-mb 4096))
        (define chunk-name
          (format "~a chunk ~a/~a" test-path index chunk-count))
        (check-equal? status 0 (format "~a\n~a" chunk-name output))
        (check-result-tree-output chunk-name output)))
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
       #:max-datum-bytes (no-stdlib-result-tree-fixture-max-datum-bytes fixture))
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
      (async-channel-get result-ch)))
  (for ([worker (in-list workers)])
    (thread-wait worker))
  (define failures
    (filter (lambda (result)
              (not (fixture-result-ok? result)))
            (sort results fixture-result<?)))
  (unless (null? failures)
    (fail (string-join (map fixture-failure-message failures) "\n\n"))))
