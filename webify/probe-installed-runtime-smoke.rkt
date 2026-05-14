#lang racket/base

(require racket/cmdline
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
    [(set-predicate
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
      set-types-predicate
      stream-rest
      hash-basic
      hash-kind-predicates
      hash-map-basic
      hash-clear-basic
      hash-iterate
      combined-list-string-set
      multi-module-list-string-set
      multi-module-reexport-installed
      pretty-require)
     (installed-runtime-smoke
      name
      (format "module case ~a reaches WebRacket runtime smoke" name)
      (module-case-data name)
      observations
      (if observe?
          (case name
            [(set-count set->list set-symmetric-difference set-map) #rx"(?m:^2$)"]
            [(set-member) #rx"(?m:^true$)"]
            [(set-add set-union) #rx"(?m:^3$)"]
            [(set-intersect) #rx"(?m:^1$)"]
            [(hash-kind-predicates) #rx"(?m:^true$)"]
            [(hash-map-basic) #rx"(?m:^3$)"]
            [(hash-clear-basic) #rx"(?m:^42$)"]
            [(hash-iterate) #rx"(?m:^9$)"]
            [(multi-module-list-string-set) #rx"(?m:^12$)"]
            [(multi-module-reexport-installed) #rx"(?m:^3$)"]
            [(pretty-require) #rx"(?m:^42$)"]
            [(hash-basic) #rx"(?m:^41$)"]
            [(stream-rest combined-list-string-set) #rx"(?m:^42$)"]
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
     (parameterize ([current-runtime-smoke-preserve-dir preserve-dir])
       (run-installed-runtime-smoke smoke))))
  0)

;; run-child/bounded! : any/c installed-runtime-smoke? (listof string?) -> exact-integer?
;;   Run one smoke in a child Racket process and kill it on timeout.
(define (run-child/bounded! label smoke selector-args)
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
           "--worker")
     selector-args
     (if preserve-dir
         (list "--preserve-dir" preserve-dir)
         '())
     (if no-observe?
         (list "--no-observe")
         '())
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
     (for ([name (in-list known-module-cases)])
       (printf "case:~a\tmodule case: ~a\n" name name))
     0]
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
     (for/fold ([status 0]) ([entry (in-list matches)])
       (define next-status
         (run-child/bounded!
          (car entry)
          (cdr entry)
          (list "--index" (number->string (car entry)))))
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
                    (set! selected-module-case (string->symbol name))])

(exit
 (if worker?
     (run-worker!)
     (run-parent!)))
