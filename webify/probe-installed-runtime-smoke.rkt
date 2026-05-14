#lang racket/base

(require racket/cmdline
         racket/file
         racket/list
         racket/match
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         "module-runtime-smoke.rkt"
         "test-installed-module-runtime.rkt")

(define-runtime-path self-path "probe-installed-runtime-smoke.rkt")

(define timeout-seconds 120)
(define memory-mb #f)
(define selected-index #f)
(define selected-category #f)
(define selected-name #f)
(define list-only? #f)
(define worker? #f)

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
  (define matches (selected-smokes))
  (unless (= (length matches) 1)
    (raise-user-error 'probe-installed-runtime-smoke
                      "worker selector matched ~a smokes; expected exactly 1"
                      (length matches)))
  (define smoke (cdar matches))
  (printf "worker-smoke: ~a\n" (smoke-label smoke))
  (when memory-mb
    (printf "worker-memory-limit-mb: ~a\n" memory-mb))
  (call-with-memory-limit
   (and memory-mb (* memory-mb 1024 1024))
   (lambda ()
     (run-installed-runtime-smoke smoke)))
  0)

;; run-child/bounded! : exact-nonnegative-integer? installed-runtime-smoke? -> exact-integer?
;;   Run one smoke in a child Racket process and kill it on timeout.
(define (run-child/bounded! index smoke)
  (define racket-bin (find-executable-path "racket"))
  (unless racket-bin
    (raise-user-error 'probe-installed-runtime-smoke
                      "could not find racket executable on PATH"))
  (define tmp-dir (make-temporary-file "webracket-installed-probe-~a" 'directory))
  (define out-path (build-path tmp-dir "stdout.txt"))
  (define err-path (build-path tmp-dir "stderr.txt"))
  (define out (open-output-file out-path #:exists 'truncate/replace))
  (define err (open-output-file err-path #:exists 'truncate/replace))
  (define args
    (append
     (list (path->string self-path)
           "--worker"
           "--index" (number->string index))
     (if memory-mb
         (list "--memory-mb" (number->string memory-mb))
         '())))
  (printf "probe-smoke: ~a\t~a\n" index (smoke-label smoke))
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
  (cond
    [(not completed)
     (printf "probe-result: timeout\n")
     124]
    [(and (integer? status) (zero? status))
     (printf "probe-result: pass\n")
     0]
    [else
     (printf "probe-result: fail status=~a\n" status)
     (if (integer? status) status 1)]))

;; run-parent! : -> exact-integer?
;;   List or run selected installed smokes one at a time with a hard timeout.
(define (run-parent!)
  (cond
    [list-only?
     (show-smokes)
     0]
    [else
     (define matches (selected-smokes))
     (when (null? matches)
       (raise-user-error 'probe-installed-runtime-smoke
                         "selector matched no installed runtime smokes"))
     (for/fold ([status 0]) ([entry (in-list matches)])
       (define next-status (run-child/bounded! (car entry) (cdr entry)))
       (if (zero? status) next-status status))]))

(command-line
 #:program "probe-installed-runtime-smoke"
 #:once-each
 [("--list") "list installed runtime smokes without running them"
             (set! list-only? #t)]
 [("--worker") "internal mode: run the selected smoke in this process"
               (set! worker? #t)]
 [("--timeout") seconds "seconds before killing a child smoke process"
                (set! timeout-seconds (string->number seconds))]
 [("--memory-mb") mb "best-effort Racket worker memory limit in MiB"
                  (set! memory-mb (string->number mb))]
 [("--index") index "run only the smoke at index"
              (set! selected-index (string->number index))]
 [("--category") category "run only smokes whose category matches the symbol"
                 (set! selected-category (string->symbol category))]
 [("--name") name "run only the smoke whose description exactly matches"
            (set! selected-name name)])

(exit
 (if worker?
     (run-worker!)
     (run-parent!)))
