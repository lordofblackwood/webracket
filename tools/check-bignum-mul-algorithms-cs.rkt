#lang racket/base

;;; Check Forced Bignum Multiplication Algorithms Against Racket CS
;;;
;; Keep algorithm-specific regression coverage even when a measured threshold
;; disables an implementation in the production dispatcher. Each profile gets
;; a fresh compiler cache under tmp/ so its private threshold overrides are
;; compiled into the runtime helper forms.

(require racket/cmdline
         racket/file
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         "../test/number-tower/cases.rkt"
         "check-bignum-mul-random-cs.rkt"
         "check-number-tower-cs.rkt")


;;; Profiles

;; algorithm-profile : symbol? (listof symbol?) (listof exact-positive-integer?) (listof (cons/c bytes? bytes?)) -> algorithm-profile?
;;   Named forced settings plus directed and seeded oracle cases.
(struct algorithm-profile (id case-ids random-limb-counts settings)
  #:transparent)

(define disabled-threshold #"2147483647")

(define karatsuba-profile
  (algorithm-profile
   'karatsuba
   '(bignum-mul-karatsuba-opposite-differences
     bignum-square-karatsuba-threshold)
   '(2 3 4 7 15 16 17 31 32 33)
   (list (cons #"WEBRACKET_BIGNUM_MUL_KARATSUBA_THRESHOLD" #"2")
         (cons #"WEBRACKET_BIGNUM_MUL_TOOM3_THRESHOLD" disabled-threshold)
         (cons #"WEBRACKET_BIGNUM_SQR_BASECASE_THRESHOLD" #"1")
         (cons #"WEBRACKET_BIGNUM_SQR_KARATSUBA_THRESHOLD" #"2")
         (cons #"WEBRACKET_BIGNUM_SQR_TOOM3_THRESHOLD" disabled-threshold))))

(define toom3-profile
  (algorithm-profile
   'toom3
   '(bignum-mul-toom3-negative-minus-one-evaluation
     bignum-mul-toom3-negative-result
     bignum-mul-wide-square)
   '(16 17 31 32 33 47 48 63 64 65)
   (list (cons #"WEBRACKET_BIGNUM_MUL_KARATSUBA_THRESHOLD" #"2")
         (cons #"WEBRACKET_BIGNUM_MUL_TOOM3_THRESHOLD" #"16")
         (cons #"WEBRACKET_BIGNUM_SQR_BASECASE_THRESHOLD" #"1")
         (cons #"WEBRACKET_BIGNUM_SQR_KARATSUBA_THRESHOLD" #"2")
         (cons #"WEBRACKET_BIGNUM_SQR_TOOM3_THRESHOLD" #"16"))))


;;; Environment And Selection

;; repo-dir : path?
;;   Absolute repository root.
(define-runtime-path repo-dir "..")
(define repo-root (simplify-path repo-dir))
(define tmp-root (build-path repo-root "tmp"))

;; select-cases : (listof symbol?) -> (listof number-tower-case?)
;;   Select known algorithm regression cases, preserving their declared order.
(define (select-cases ids)
  (for/list ([id (in-list ids)])
    (or (findf (lambda (candidate)
                 (eq? id (number-tower-case-id candidate)))
               number-tower-cases)
        (error 'check-bignum-mul-algorithms-cs
               "missing bignum algorithm case: ~a"
               id))))

;; profile-cases : algorithm-profile? -> (listof number-tower-case?)
;;   Combine directed edge cases with seeded shapes for a forced algorithm.
(define (profile-cases profile)
  (append
   (select-cases (algorithm-profile-case-ids profile))
   (random-bignum-mul-cases
    #x6d2b79f5
    (algorithm-profile-random-limb-counts profile))))

;; profile-environment : algorithm-profile? path? -> environment-variables?
;;   Isolate compiler cache and threshold settings for one forced profile.
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
  (for ([setting (in-list (algorithm-profile-settings profile))])
    (environment-variables-set! env (car setting) (cdr setting)))
  env)

;; run-profile : algorithm-profile? path-string? path-string? boolean? -> void?
;;   Run an algorithm profile through the normal WebRacket/Racket CS oracle.
(define (run-profile profile cs-path webracket-racket-path keep-temp?)
  (make-directory* tmp-root)
  (define profile-dir
    (make-temporary-directory
     (format "check-bignum-~a-~a" (algorithm-profile-id profile) "~a")
     #:base-dir tmp-root))
  (define compiled-root (build-path profile-dir "compiled"))
  (make-directory* compiled-root)
  (define env (profile-environment profile compiled-root))
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (printf "algorithm-temp-dir=~a\n" profile-dir)
                     (raise exn))])
    (define summary
      (parameterize ([current-environment-variables env])
        (run-number-tower-cases
         (profile-cases profile)
         #:cs-path cs-path
         #:webracket-racket-path webracket-racket-path)))
    (print-number-tower-summary summary)
    (when (positive? (summary-failure-count summary))
      (error 'check-bignum-mul-algorithms-cs
             "forced ~a profile had oracle failures"
             (algorithm-profile-id profile)))
    (unless keep-temp?
      (delete-directory/files profile-dir))))


;;; Command Line

;; parse-algorithm-list : string? -> (listof symbol?)
;;   Parse comma-separated forced profile names.
(define (parse-algorithm-list text)
  (for/list ([part (in-list (string-split text ","))]
             #:unless (string=? (string-trim part) ""))
    (string->symbol (string-trim part))))

;; main : -> void?
;;   Run selected forced bignum multiplication profiles.
(define (main)
  (define requested '())
  (define keep-temp? #f)
  (define cs-path (default-racket-cs-path))
  (define webracket-racket-path (default-webracket-racket-path))
  (command-line
   #:program "check-bignum-mul-algorithms-cs"
   #:once-each
   [("--algorithm") ids "karatsuba, toom3, or a comma-separated list"
                    (set! requested (append requested (parse-algorithm-list ids)))]
   [("--cs") path "Racket CS executable path"
             (set! cs-path path)]
   [("--webracket-racket") path "Racket executable for WebRacket compilation"
                           (set! webracket-racket-path path)]
   [("--keep-temp") "Keep generated compiler caches under tmp/"
                    (set! keep-temp? #t)])
  (define all-profiles (list karatsuba-profile toom3-profile))
  (define selected
    (if (null? requested)
        all-profiles
        (for/list ([id (in-list requested)])
          (or (findf (lambda (profile)
                       (eq? id (algorithm-profile-id profile)))
                     all-profiles)
              (error 'check-bignum-mul-algorithms-cs
                     "unknown algorithm profile: ~a"
                     id)))))
  (for ([profile (in-list selected)])
    (printf "algorithm=~a\n" (algorithm-profile-id profile))
    (run-profile profile cs-path webracket-racket-path keep-temp?)))

(module+ main
  (main))
