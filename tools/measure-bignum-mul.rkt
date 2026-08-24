#lang racket/base

;;; Measure Bignum Multiplication
;;;
;; This benchmark runs a focused set of exact-integer multiplication shapes
;; through WebRacket. It is intended for comparing multiplication runtime
;; changes across commits, especially single-limb, asymmetric, sparse, and
;; power-of-two bignum products.
;;
;; Invoke it from the repository root:
;;
;;   racket tools/measure-bignum-mul.rkt
;;
;; Scratch files are written under the repository-local tmp/ directory.

(require racket/cmdline
         racket/file
         racket/format
         racket/list
         racket/match
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         "check-number-tower-cs.rkt")

(provide (struct-out bench-case)
         bignum-mul-cases
         dense-bignum-mul-cases
         benchmark-expression
         make-benchmark-directory
         run-webracket-benchmark
         run-cs-benchmark
         check-checksums!
         default-webracket-racket-path
         default-racket-cs-path)


;;; Benchmark Model

;; bench-case : symbol? any/c any/c string? -> bench-case?
;;   A pair of source expressions to multiply repeatedly.
(struct bench-case (id lhs rhs note)
  #:transparent)

;; bignum-mul-cases : (listof bench-case?)
;;   Operand shapes that exercise the current schoolbook and fast-path code.
(define bignum-mul-cases
  (list
   (bench-case 'fixnum-by-bignum
               123456789
               '(+ (arithmetic-shift 1 160) 12345)
               "Mixed fixnum and multi-limb bignum.")
   (bench-case 'single-limb-by-bignum
               4294967295
               '(+ (arithmetic-shift 1 160) 12345)
               "One-limb bignum times multi-limb bignum.")
   (bench-case 'dense-same-size
               '(- (arithmetic-shift 1 160) 1)
               '(- (arithmetic-shift 1 160) 12345)
               "Dense operands with similar limb counts.")
   (bench-case 'asymmetric-short-left
               '(+ (arithmetic-shift 1 33) 17)
               '(- (arithmetic-shift 1 512) 123456789)
               "Short bignum on the left, long bignum on the right.")
   (bench-case 'asymmetric-short-right
               '(- (arithmetic-shift 1 512) 123456789)
               '(+ (arithmetic-shift 1 33) 17)
               "Long bignum on the left, short bignum on the right.")
   (bench-case 'sparse-internal-zero-limbs
               '(+ (arithmetic-shift 1 288)
                   (arithmetic-shift 1 96)
                   1)
               '(+ (arithmetic-shift 1 224) 7)
               "Sparse operands with internal zero limbs.")
   (bench-case 'power-of-two-left
               '(arithmetic-shift 1 256)
               '(+ (arithmetic-shift 1 160) 12345)
               "Power-of-two bignum on the left.")
   (bench-case 'power-of-two-right
               '(+ (arithmetic-shift 1 160) 12345)
               '(arithmetic-shift 1 256)
               "Power-of-two bignum on the right.")
   (bench-case 'mixed-power-of-two
               123456789
               '(arithmetic-shift 1 256)
               "Fixnum times power-of-two bignum.")
   (bench-case 'dense-square-shape
               '(- (arithmetic-shift 1 192) 987654321)
               '(- (arithmetic-shift 1 192) 987654321)
               "Dense equal operands for squaring work.")
   (bench-case 'dense-square-neighbor
               '(- (arithmetic-shift 1 192) 987654321)
               '(- (arithmetic-shift 1 192) 987654322)
               "Dense same-width neighboring operands for square comparisons.")
   (bench-case 'wide-dense-square-shape
               '(- (arithmetic-shift 1 1024) 987654321)
               '(- (arithmetic-shift 1 1024) 987654321)
               "Wider dense equal operands for squaring work.")
   (bench-case 'wide-dense-square-neighbor
               '(- (arithmetic-shift 1 1024) 987654321)
               '(- (arithmetic-shift 1 1024) 987654322)
               "Wider same-width neighboring operands for square comparisons.")
   (bench-case 'huge-dense-square-shape
               '(- (arithmetic-shift 1 4096) 987654321)
               '(- (arithmetic-shift 1 4096) 987654321)
               "Large dense equal operands for squaring work.")
   (bench-case 'huge-dense-square-neighbor
               '(- (arithmetic-shift 1 4096) 987654321)
               '(- (arithmetic-shift 1 4096) 987654322)
               "Large same-width neighboring operands for square comparisons.")))

;; dense-bignum-mul-cases : (listof exact-positive-integer?) -> (listof bench-case?)
;;   Build balanced dense multiplication and square cases at selected limb widths.
(define (dense-bignum-mul-cases limb-counts)
  (append*
   (for/list ([limbs (in-list limb-counts)])
     (define bits (* limbs 32))
     (define lhs `(- (arithmetic-shift 1 ,bits) 123456789))
     (define rhs `(- (arithmetic-shift 1 ,bits) 987654321))
     (list
      (bench-case (string->symbol (format "dense-mul-~a-limbs" limbs))
                  lhs
                  rhs
                  "Dense balanced multiplication at a requested limb width.")
      (bench-case (string->symbol (format "dense-square-~a-limbs" limbs))
                  lhs
                  lhs
                  "Dense balanced square at a requested limb width.")))))


;;; Repository Paths

;; repo-dir : path?
;;   Absolute path to the repository root.
(define-runtime-path repo-dir "..")
(define repo-root
  (simplify-path repo-dir))

;; tmp-root : path?
;;   Repository-local scratch directory.
(define tmp-root
  (build-path repo-root "tmp"))

;; ensure-tmp-root! : -> void?
;;   Ensure benchmark scratch files stay under tmp/.
(define (ensure-tmp-root!)
  (make-directory* tmp-root))

;; make-benchmark-directory : -> path?
;;   Create a fresh benchmark work directory under tmp/.
(define (make-benchmark-directory)
  (ensure-tmp-root!)
  (make-temporary-directory "measure-bignum-mul-~a"
                            #:base-dir tmp-root))


;;; Source Generation

;; benchmark-expression : exact-positive-integer? exact-nonnegative-integer? (listof bench-case?) -> any/c
;;   Build the expression run by WebRacket and Racket CS.
(define (benchmark-expression reps warmup-reps cases)
  `(letrec ([bench
             (lambda (name reps lhs rhs)
               (letrec ([loop
                         (lambda (i checksum)
                           (if (= i 0)
                               checksum
                               (let ([product (* lhs rhs)])
                                 (loop (- i 1)
                                       (+ checksum
                                          (integer-length product))))))])
                 (loop ,warmup-reps 0)
                 (let ([t0 (current-inexact-milliseconds)])
                   (let ([checksum (loop reps 0)])
                     (list name
                           reps
                           (- (current-inexact-milliseconds) t0)
                           checksum)))))])
     (list
      ,@(for/list ([c (in-list cases)])
          `(bench ',(bench-case-id c)
                  ,reps
                  ,(bench-case-lhs c)
                  ,(bench-case-rhs c))))))

;; write-webracket-source! : path? any/c -> void?
;;   Materialize the generated WebRacket expression.
(define (write-webracket-source! path expr)
  (call-with-output-file path
    (lambda (out)
      (write expr out)
      (newline out))
    #:exists 'truncate/replace))

;; write-cs-source! : path? any/c -> void?
;;   Materialize a Racket CS wrapper that prints the benchmark result datum.
(define (write-cs-source! path expr)
  (call-with-output-file path
    (lambda (out)
      (display "#lang racket/base\n" out)
      (write `(begin
                (write ,expr)
                (newline))
             out)
      (newline out))
    #:exists 'truncate/replace))


;;; Subprocess Helpers

;; command-result : exact-nonnegative-integer? string? string? real? -> command-result?
;;   Captured subprocess result.
(struct command-result (status stdout stderr wall-ms)
  #:transparent)

;; run-command/capture : path? path-string? (listof string?) exact-positive-integer? -> command-result?
;;   Run a subprocess under cwd with captured output and a timeout.
(define (run-command/capture cwd command args timeout-seconds)
  (ensure-tmp-root!)
  (define stdout-path
    (make-temporary-file "measure-bignum-mul-stdout-~a.txt"
                         #:base-dir tmp-root))
  (define stderr-path
    (make-temporary-file "measure-bignum-mul-stderr-~a.txt"
                         #:base-dir tmp-root))
  (define stdout (open-output-file stdout-path #:exists 'truncate))
  (define stderr (open-output-file stderr-path #:exists 'truncate))
  (define start-ms (current-inexact-milliseconds))
  (define-values (proc child-out child-in child-err)
    (parameterize ([current-directory cwd])
      (apply subprocess stdout #f stderr command args)))
  (when child-out (close-input-port child-out))
  (when child-in (close-output-port child-in))
  (when child-err (close-input-port child-err))
  (define completed? (sync/timeout timeout-seconds proc))
  (unless completed?
    (subprocess-kill proc #t))
  (subprocess-wait proc)
  (close-output-port stdout)
  (close-output-port stderr)
  (define end-ms (current-inexact-milliseconds))
  (define status (subprocess-status proc))
  (define stdout-text (file->string stdout-path))
  (define stderr-text (file->string stderr-path))
  (with-handlers ([exn:fail? void])
    (delete-file stdout-path))
  (with-handlers ([exn:fail? void])
    (delete-file stderr-path))
  (command-result
   (cond
     [(not completed?) 124]
     [(integer? status) status]
     [else 1])
   stdout-text
   stderr-text
   (- end-ms start-ms)))

;; read-single-datum : string? -> any/c
;;   Read exactly one datum from subprocess output.
(define (read-single-datum text)
  (define in (open-input-string text))
  (define datum (read in))
  (when (eof-object? datum)
    (error 'measure-bignum-mul "expected one datum, got empty output"))
  (define trailing (read in))
  (unless (eof-object? trailing)
    (error 'measure-bignum-mul
           "expected one datum, got trailing output: ~s"
           trailing))
  datum)


;;; Running Benchmarks

;; run-webracket-benchmark : path-string? path? any/c exact-positive-integer? -> (values (listof list?) command-result?)
;;   Compile and run the benchmark expression through WebRacket.
(define (run-webracket-benchmark racket-path work-dir expr timeout-seconds)
  (define source (build-path work-dir "bignum-mul-bench.rkt"))
  (define dest (build-path work-dir "wr-out"))
  (make-directory* dest)
  (write-webracket-source! source expr)
  (define result
    (run-command/capture
     repo-root
     racket-path
     (list "-S" (path->string (build-path repo-root "pkgs"))
           (path->string (build-path repo-root "webracket.rkt"))
           "--no-stdlib"
           "--no-io-format-provider"
           "--no-split-runtime"
           "-n"
           "-r"
           "--dest" (path->string dest)
           (path->string source))
     timeout-seconds))
  (unless (zero? (command-result-status result))
    (error 'measure-bignum-mul
           "WebRacket benchmark failed with status ~a\nstdout:\n~a\nstderr:\n~a"
           (command-result-status result)
           (command-result-stdout result)
           (command-result-stderr result)))
  (values (read-single-datum (command-result-stdout result))
          result))

;; run-cs-benchmark : path-string? path? any/c exact-positive-integer? -> (values (listof list?) command-result?)
;;   Run the benchmark expression under Racket CS.
(define (run-cs-benchmark cs-path work-dir expr timeout-seconds)
  (define info (query-number-tower-cs-info cs-path))
  (validate-number-tower-cs-info! info)
  (define source (build-path work-dir "bignum-mul-bench-cs.rkt"))
  (write-cs-source! source expr)
  (define result
    (run-command/capture
     repo-root
     cs-path
     (list (path->string source))
     timeout-seconds))
  (unless (zero? (command-result-status result))
    (error 'measure-bignum-mul
           "Racket CS benchmark failed with status ~a\nstdout:\n~a\nstderr:\n~a"
           (command-result-status result)
           (command-result-stdout result)
           (command-result-stderr result)))
  (values (read-single-datum (command-result-stdout result))
          result))


;;; Result Checking and Formatting

;; row-id : list? -> symbol?
;;   Extract a benchmark row id.
(define (row-id row)
  (match row
    [(list (? symbol? id) _ _ _) id]
    [_
     (error 'measure-bignum-mul "bad benchmark row: ~s" row)]))

;; row-checksum : list? -> exact-integer?
;;   Extract a benchmark row checksum.
(define (row-checksum row)
  (match row
    [(list _ _ _ (? exact-integer? checksum)) checksum]
    [_
     (error 'measure-bignum-mul "bad benchmark row: ~s" row)]))

;; checksum-map : (listof list?) -> hash?
;;   Map row ids to checksums.
(define (checksum-map rows)
  (for/hasheq ([row (in-list rows)])
    (values (row-id row) (row-checksum row))))

;; check-checksums! : (listof list?) (listof list?) -> void?
;;   Fail if WebRacket and CS produced different benchmark checksums.
(define (check-checksums! wr-rows cs-rows)
  (define wr (checksum-map wr-rows))
  (define cs (checksum-map cs-rows))
  (unless (equal? wr cs)
    (error 'measure-bignum-mul
           "WebRacket and Racket CS benchmark checksums differ\nWebRacket: ~s\nCS: ~s"
           wr
           cs)))

;; format-ms : real? -> string?
;;   Format milliseconds compactly.
(define (format-ms x)
  (~r x #:precision 3))

;; print-result-table : symbol? command-result? (listof list?) -> void?
;;   Print benchmark rows for one runtime.
(define (print-result-table label result rows)
  (printf "~a external-ms=~a\n"
          label
          (format-ms (command-result-wall-ms result)))
  (printf "case\treps\truntime-ms\titer-us\tchecksum\n")
  (for ([row (in-list rows)])
    (match row
      [(list (? symbol? id) (? exact-positive-integer? reps) (? real? ms) checksum)
       (printf "~a\t~a\t~a\t~a\t~a\n"
               id
               reps
               (format-ms ms)
               (format-ms (* 1000.0 (/ ms reps)))
               checksum)]
      [_
       (error 'measure-bignum-mul "bad benchmark row: ~s" row)]))
  (newline))

;; selected-bignum-mul-cases : (listof symbol?) -> (listof bench-case?)
;;   Select benchmark cases by id, or all cases when ids is empty.
(define (selected-bignum-mul-cases ids)
  (if (null? ids)
      bignum-mul-cases
      (for/list ([id (in-list ids)])
        (or (findf (lambda (c) (eq? (bench-case-id c) id))
                   bignum-mul-cases)
            (error 'measure-bignum-mul
                   "unknown benchmark case: ~a"
                   id)))))

;; parse-symbol-list : string? -> (listof symbol?)
;;   Parse comma-separated symbol command-line arguments.
(define (parse-symbol-list s)
  (filter values
          (for/list ([part (in-list (string-split s ","))])
            (define trimmed (string-trim part))
            (and (not (string=? trimmed ""))
                 (string->symbol trimmed)))))

;; parse-limb-list : string? -> (listof exact-positive-integer?)
;;   Parse comma-separated requested bignum limb widths.
(define (parse-limb-list s)
  (for/list ([part (in-list (string-split s ","))]
             #:unless (string=? (string-trim part) ""))
    (define value (string->number (string-trim part)))
    (unless (exact-positive-integer? value)
      (error 'measure-bignum-mul
             "expected a positive exact limb count, got ~e"
             part))
    value))


;;; Main

;; main : -> void?
;;   Run the bignum multiplication benchmark.
(define (main)
  (define reps 100000)
  (define warmup-reps 10000)
  (define timeout-seconds 300)
  (define include-cs? #t)
  (define keep-temp? #f)
  (define case-ids '())
  (define limb-counts '())
  (define list-cases? #f)
  (define racket-path (default-webracket-racket-path))
  (define cs-path (default-racket-cs-path))
  (command-line
   #:program "measure-bignum-mul"
   #:once-each
   [("--reps") n "Repetitions per case; defaults to 100000"
               (set! reps (string->number n))]
   [("--warmup") n "Warmup repetitions per case before timing; defaults to 10000"
                 (set! warmup-reps (string->number n))]
   [("--timeout") n "Timeout in seconds for each subprocess; defaults to 300"
                  (set! timeout-seconds (string->number n))]
   [("--webracket-racket") path "Racket executable for WebRacket compilation"
                           (set! racket-path path)]
   [("--cs") path "Racket CS executable path"
             (set! cs-path path)]
   [("--no-cs") "Do not run the Racket CS checksum/timing baseline"
               (set! include-cs? #f)]
   [("--keep-temp") "Keep generated benchmark files under tmp/"
                  (set! keep-temp? #t)]
   [("--list-cases") "List benchmark cases and exit"
                    (set! list-cases? #t)]
   #:multi
   [("--case") id "Run one case id or comma-separated case ids"
              (set! case-ids (append case-ids (parse-symbol-list id)))]
   [("--limbs") counts
                "Run generated dense multiply and square cases at comma-separated limb widths"
                (set! limb-counts
                      (append limb-counts (parse-limb-list counts)))])
  (unless (and (exact-positive-integer? reps)
               (exact-nonnegative-integer? warmup-reps)
               (exact-positive-integer? timeout-seconds))
    (error 'measure-bignum-mul
           "--reps and --timeout must be positive integers; --warmup must be a nonnegative integer"))
  (cond
    [list-cases?
     (for ([c (in-list bignum-mul-cases)])
       (printf "~a\t~a\n" (bench-case-id c) (bench-case-note c)))]
    [else
     (when (and (pair? limb-counts) (pair? case-ids))
       (error 'measure-bignum-mul
              "--limbs selects generated cases and cannot be combined with --case"))
     (define cases
       (if (pair? limb-counts)
           (dense-bignum-mul-cases limb-counts)
           (selected-bignum-mul-cases case-ids)))
     (define expr (benchmark-expression reps warmup-reps cases))
     (define work-dir (make-benchmark-directory))
     (with-handlers ([exn:fail?
                      (lambda (exn)
                        (printf "benchmark-temp-dir=~a\n" work-dir)
                        (raise exn))])
       (define-values (wr-rows wr-result)
         (run-webracket-benchmark racket-path
                                  work-dir
                                  expr
                                  timeout-seconds))
       (define cs-rows #f)
       (define cs-result #f)
       (when include-cs?
         (define-values (rows result)
           (run-cs-benchmark cs-path
                             work-dir
                             expr
                             timeout-seconds))
         (set! cs-rows rows)
         (set! cs-result result)
         (check-checksums! wr-rows cs-rows))
       (printf "benchmark-temp-dir=~a (~a)\n"
               work-dir
               (if keep-temp? "kept" "deleted on success"))
       (printf "reps=~a warmup=~a cases=~a\n\n"
               reps
               warmup-reps
               (length cases))
       (print-result-table 'webracket wr-result wr-rows)
       (when include-cs?
         (print-result-table 'racket-cs cs-result cs-rows))
       (unless keep-temp?
         (delete-directory/files work-dir)))]))

(module+ main
  (main))
