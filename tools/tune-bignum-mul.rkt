#lang racket/base

;;; Tune Bignum Multiplication
;;;
;; Compare the internal schoolbook, Karatsuba, and Toom-3 multiplication
;; profiles. Each profile gets a dedicated compiled-module cache under tmp/ so
;; the private WEBRACKET_BIGNUM_* compiler settings cannot leak between runs.

(require racket/cmdline
         racket/file
         racket/format
         racket/list
         racket/match
         racket/path
         racket/runtime-path
         racket/string
         "measure-bignum-mul.rkt")


;;; Profiles

;; tune-profile : symbol? (listof (cons/c bytes? bytes?)) -> tune-profile?
;;   A private compiler threshold configuration to benchmark.
(struct tune-profile (id settings)
  #:transparent)

(define disabled-threshold #"2147483647")

(define tuning-profiles
  (list
   (tune-profile
    'basecase
    (list (cons #"WEBRACKET_BIGNUM_MUL_KARATSUBA_THRESHOLD" disabled-threshold)
          (cons #"WEBRACKET_BIGNUM_MUL_TOOM3_THRESHOLD" disabled-threshold)
          (cons #"WEBRACKET_BIGNUM_SQR_BASECASE_THRESHOLD" disabled-threshold)
          (cons #"WEBRACKET_BIGNUM_SQR_KARATSUBA_THRESHOLD" disabled-threshold)
          (cons #"WEBRACKET_BIGNUM_SQR_TOOM3_THRESHOLD" disabled-threshold)))
   (tune-profile
    'square-basecase
    (list (cons #"WEBRACKET_BIGNUM_MUL_KARATSUBA_THRESHOLD" disabled-threshold)
          (cons #"WEBRACKET_BIGNUM_MUL_TOOM3_THRESHOLD" disabled-threshold)
          (cons #"WEBRACKET_BIGNUM_SQR_BASECASE_THRESHOLD" #"1")
          (cons #"WEBRACKET_BIGNUM_SQR_KARATSUBA_THRESHOLD" disabled-threshold)
          (cons #"WEBRACKET_BIGNUM_SQR_TOOM3_THRESHOLD" disabled-threshold)))
   (tune-profile
    'karatsuba
    (list (cons #"WEBRACKET_BIGNUM_MUL_KARATSUBA_THRESHOLD" #"2")
          (cons #"WEBRACKET_BIGNUM_MUL_TOOM3_THRESHOLD" disabled-threshold)
          (cons #"WEBRACKET_BIGNUM_SQR_BASECASE_THRESHOLD" #"1")
          (cons #"WEBRACKET_BIGNUM_SQR_KARATSUBA_THRESHOLD" #"2")
          (cons #"WEBRACKET_BIGNUM_SQR_TOOM3_THRESHOLD" disabled-threshold)))
   (tune-profile
    'toom3
    (list (cons #"WEBRACKET_BIGNUM_MUL_KARATSUBA_THRESHOLD" #"2")
          (cons #"WEBRACKET_BIGNUM_MUL_TOOM3_THRESHOLD" #"16")
          (cons #"WEBRACKET_BIGNUM_SQR_BASECASE_THRESHOLD" #"1")
          (cons #"WEBRACKET_BIGNUM_SQR_KARATSUBA_THRESHOLD" #"2")
          (cons #"WEBRACKET_BIGNUM_SQR_TOOM3_THRESHOLD" #"16")))))


;;; Repository Paths

;; repo-dir : path?
;;   Absolute path to the repository root.
(define-runtime-path repo-dir "..")
(define repo-root (simplify-path repo-dir))

;; tmp-root : path?
;;   Repository-local scratch directory for tuning artifacts.
(define tmp-root (build-path repo-root "tmp"))

;; make-tuning-directory : string? -> path?
;;   Allocate a tuning directory under tmp/.
(define (make-tuning-directory template)
  (make-directory* tmp-root)
  (make-temporary-directory template #:base-dir tmp-root))


;;; Measurement Helpers

;; row-id : list? -> symbol?
;;   Extract a benchmark case id.
(define (row-id row)
  (match row
    [(list (? symbol? id) _ _ _) id]
    [_ (error 'tune-bignum-mul "bad benchmark row: ~s" row)]))

;; row-runtime-ms : list? -> real?
;;   Extract a benchmark timing in milliseconds.
(define (row-runtime-ms row)
  (match row
    [(list _ _ (? real? milliseconds) _) milliseconds]
    [_ (error 'tune-bignum-mul "bad benchmark row: ~s" row)]))

;; row-checksum : list? -> exact-integer?
;;   Extract a benchmark checksum.
(define (row-checksum row)
  (match row
    [(list _ _ _ (? exact-integer? checksum)) checksum]
    [_ (error 'tune-bignum-mul "bad benchmark row: ~s" row)]))

;; median : (listof real?) -> real?
;;   Return the middle sample, averaging the two central samples when needed.
(define (median xs)
  (unless (pair? xs)
    (error 'tune-bignum-mul "cannot calculate the median of no samples"))
  (define ordered (sort xs <))
  (define count (length ordered))
  (define middle (quotient count 2))
  (if (odd? count)
      (list-ref ordered middle)
      (/ (+ (list-ref ordered (sub1 middle))
            (list-ref ordered middle))
         2.0)))

;; samples->medians : (listof (listof list?)) -> hash?
;;   Reduce per-sample benchmark rows to per-case median timings.
(define (samples->medians samples)
  (define timings (make-hasheq))
  (for ([rows (in-list samples)])
    (for ([row (in-list rows)])
      (hash-update! timings
                    (row-id row)
                    (lambda (values)
                      (cons (row-runtime-ms row) values))
                    '())))
  (for/hasheq ([(id timing-samples) (in-hash timings)])
    (values id (median timing-samples))))

;; check-matching-checksums! : (listof list?) (listof list?) -> void?
;;   Ensure two profile samples evaluated exactly the same integer products.
(define (check-matching-checksums! expected actual)
  (define expected-map
    (for/hasheq ([row (in-list expected)])
      (values (row-id row) (row-checksum row))))
  (define actual-map
    (for/hasheq ([row (in-list actual)])
      (values (row-id row) (row-checksum row))))
  (unless (equal? expected-map actual-map)
    (error 'tune-bignum-mul
           "threshold profile changed a benchmark checksum\nexpected: ~s\nactual: ~s"
           expected-map
           actual-map)))

;; profile-environment : tune-profile? path? -> environment-variables?
;;   Build an isolated compiler environment for one algorithm profile.
(define (profile-environment profile compiled-root)
  (define env (environment-variables-copy (current-environment-variables)))
  (environment-variables-set!
   env
   #"PLTCOMPILEDROOTS"
   (string->bytes/utf-8 (path->string compiled-root)))
  (environment-variables-set!
   env
   #"WEBRACKET_BIGNUM_MUL_MAX_BALANCE_RATIO"
   #"2")
  (for ([setting (in-list (tune-profile-settings profile))])
    (environment-variables-set! env (car setting) (cdr setting)))
  env)

;; profile-samples : tune-profile? exact-positive-integer? path-string? any/c exact-positive-integer? boolean? -> (listof (listof list?))
;;   Compile and run one threshold profile repeatedly with an isolated cache.
(define (profile-samples profile samples racket-path expr timeout-seconds keep-temp?)
  (define profile-dir
    (make-tuning-directory
     (format "tune-bignum-mul-~a-~a" (tune-profile-id profile) "~a")))
  (define compiled-root (build-path profile-dir "compiled"))
  (make-directory* compiled-root)
  (define env (profile-environment profile compiled-root))
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (printf "tuning-temp-dir=~a\n" profile-dir)
                     (raise exn))])
    (define rows
      (parameterize ([current-environment-variables env])
        (for/list ([sample (in-range samples)])
          (define work-dir (make-benchmark-directory))
          (define-values (sample-rows ignored)
            (run-webracket-benchmark racket-path work-dir expr timeout-seconds))
          (unless keep-temp?
            (delete-directory/files work-dir))
          sample-rows)))
    (unless keep-temp?
      (delete-directory/files profile-dir))
    rows))

;; generated-case-id : symbol? exact-positive-integer? -> symbol?
;;   Name a generated dense benchmark case.
(define (generated-case-id kind limbs)
  (string->symbol (format "dense-~a-~a-limbs" kind limbs)))

;; stable-crossover : (listof exact-positive-integer?) hash? hash? symbol? -> (or/c #f exact-positive-integer?)
;;   Find the first three-size run where candidate beats baseline by five percent.
(define (stable-crossover limb-counts candidate baseline kind)
  (for/first ([start (in-range 0 (max 0 (- (length limb-counts) 2)))]
              #:when
              (for/and ([limbs (in-list (take (drop limb-counts start) 3))])
                (define id (generated-case-id kind limbs))
                (<= (hash-ref candidate id)
                    (* 0.95 (hash-ref baseline id)))))
    (list-ref limb-counts start)))

;; format-ms : real? -> string?
;;   Render a median benchmark time compactly.
(define (format-ms value)
  (~r value #:precision 3))

;; print-profile-table : (listof exact-positive-integer?) hash? hash? hash? hash? -> void?
;;   Print a compact median table for the four profiles.
(define (print-profile-table limb-counts base square-basecase karatsuba toom3)
  (printf "limbs\tmul-base\tmul-kara\tmul-toom3\tsqr-base\tsqr-kara\tsqr-toom3\n")
  (for ([limbs (in-list limb-counts)])
    (define mul-id (generated-case-id 'mul limbs))
    (define square-id (generated-case-id 'square limbs))
    (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
            limbs
            (format-ms (hash-ref base mul-id))
            (format-ms (hash-ref karatsuba mul-id))
            (format-ms (hash-ref toom3 mul-id))
            (format-ms (hash-ref square-basecase square-id))
            (format-ms (hash-ref karatsuba square-id))
            (format-ms (hash-ref toom3 square-id)))))


;;; Command Line

;; parse-limb-list : string? -> (listof exact-positive-integer?)
;;   Parse comma-separated requested bignum limb widths.
(define (parse-limb-list text)
  (for/list ([part (in-list (string-split text ","))]
             #:unless (string=? (string-trim part) ""))
    (define value (string->number (string-trim part)))
    (unless (exact-positive-integer? value)
      (error 'tune-bignum-mul "expected a positive exact limb count, got ~e" part))
    value))

;; main : -> void?
;;   Run the threshold crossover experiment.
(define (main)
  (define limb-counts '(16 24 32 40 48 64 96 128 192 256 384 512 768 1024))
  (define samples 5)
  (define reps 2000)
  (define warmup-reps 250)
  (define timeout-seconds 600)
  (define include-cs? #t)
  (define keep-temp? #f)
  (define racket-path (default-webracket-racket-path))
  (define cs-path (default-racket-cs-path))
  (command-line
   #:program "tune-bignum-mul"
   #:once-each
   [("--limbs") counts "Comma-separated balanced limb widths"
                (set! limb-counts (parse-limb-list counts))]
   [("--samples") count "Independent samples per profile; defaults to 5"
                  (set! samples (string->number count))]
   [("--reps") count "Products per case and sample; defaults to 2000"
               (set! reps (string->number count))]
   [("--warmup") count "Untimed products per case; defaults to 250"
                 (set! warmup-reps (string->number count))]
   [("--timeout") count "Timeout in seconds per WebRacket run; defaults to 600"
                  (set! timeout-seconds (string->number count))]
   [("--webracket-racket") path "Racket executable for WebRacket compilation"
                           (set! racket-path path)]
   [("--cs") path "Racket CS executable path"
             (set! cs-path path)]
   [("--no-cs") "Do not verify the first profile checksum with Racket CS"
                (set! include-cs? #f)]
   [("--keep-temp") "Keep generated tuning artifacts under tmp/"
                    (set! keep-temp? #t)])
  (unless (and (>= (length limb-counts) 3)
               (andmap exact-positive-integer? limb-counts)
               (exact-positive-integer? samples)
               (exact-positive-integer? reps)
               (exact-nonnegative-integer? warmup-reps)
               (exact-positive-integer? timeout-seconds))
    (error 'tune-bignum-mul
           "need at least three positive limb widths, positive samples/reps/timeout, and a nonnegative warmup"))
  (define sorted-limb-counts (sort (remove-duplicates limb-counts) <))
  (define cases (dense-bignum-mul-cases sorted-limb-counts))
  (define expr (benchmark-expression reps warmup-reps cases))
  (define profile-results
    (for/hasheq ([profile (in-list tuning-profiles)])
      (printf "profile=~a samples=~a\n" (tune-profile-id profile) samples)
      (flush-output)
      (values (tune-profile-id profile)
              (profile-samples profile
                               samples
                               racket-path
                               expr
                               timeout-seconds
                               keep-temp?))))
  (define base-rows (hash-ref profile-results 'basecase))
  (for ([(profile-id samples) (in-hash profile-results)])
    (for ([rows (in-list samples)])
      (check-matching-checksums! (car base-rows) rows)))
  (when include-cs?
    (define cs-dir (make-tuning-directory "tune-bignum-mul-cs-~a"))
    (define-values (cs-rows ignored)
      (run-cs-benchmark cs-path cs-dir expr timeout-seconds))
    (check-checksums! (car base-rows) cs-rows)
    (unless keep-temp?
      (delete-directory/files cs-dir)))
  (define base (samples->medians base-rows))
  (define square-basecase
    (samples->medians (hash-ref profile-results 'square-basecase)))
  (define karatsuba
    (samples->medians (hash-ref profile-results 'karatsuba)))
  (define toom3
    (samples->medians (hash-ref profile-results 'toom3)))
  (print-profile-table sorted-limb-counts base square-basecase karatsuba toom3)
  (define recommendations
    (list
     (list 'sqr-basecase
           (stable-crossover sorted-limb-counts square-basecase base 'square))
     (list 'mul-karatsuba
           (stable-crossover sorted-limb-counts karatsuba base 'mul))
     (list 'sqr-karatsuba
           (stable-crossover sorted-limb-counts karatsuba square-basecase 'square))
     (list 'mul-toom3
           (stable-crossover sorted-limb-counts toom3 karatsuba 'mul))
     (list 'sqr-toom3
           (stable-crossover sorted-limb-counts toom3 karatsuba 'square))))
  (printf "\nforced-recursive-crossover-estimates=~s\n" recommendations)
  (printf "raw-median-ms=~s\n"
          (list (cons 'basecase base)
                (cons 'square-basecase square-basecase)
                (cons 'karatsuba karatsuba)
                (cons 'toom3 toom3))))

(module+ main
  (main))
