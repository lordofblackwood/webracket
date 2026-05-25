#lang racket/base

(require racket/file
         racket/list
         racket/match
         racket/runtime-path
         racket/string
         racket/system
         rackunit
         "../pkgs/webracket-lib/compiler/webify/module-extractor.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-input.rkt"
         "probe-installed-module-deps.rkt"
         "../pkgs/webracket-lib/compiler/webify/primitive-demands.rkt")

(define-runtime-path probe-installed-module-deps-path
  "probe-installed-module-deps.rkt")

(define-runtime-path probe-installed-runtime-smoke-path
  "probe-installed-runtime-smoke.rkt")

;; source-defined-quoted-list : path-string? symbol? -> (listof symbol?)
;;   Read a quoted list definition from a script without running that script.
(define (source-defined-quoted-list path name)
  (define forms
    (call-with-input-file path
      (lambda (in)
        (read-line in) ; skip #lang line
        (let loop ([forms '()])
          (define form (read in))
          (if (eof-object? form)
              (reverse forms)
              (loop (cons form forms)))))))
  (define value
    (for/first ([form (in-list forms)]
                #:when (match form
                         [`(define ,candidate ,_) (eq? candidate name)]
                         [_ #f]))
      (match form
        [`(define ,_ ,value) value])))
  (match value
    [`(quote ,xs) xs]
    [_ (raise-arguments-error 'source-defined-quoted-list
                              "expected a quoted list definition"
                              "path" path
                              "name" name)]))

(test-case "primitive demand audit collects resolved primitive imports"
  (define input
    (webify-module-linklet-input
     'uses-primitives
     '(linklet (((cons cons)
                 (raise-argument-error raise-argument-error)))
        (out)
        (define-values (out) cons))
     '((cons #%kernel cons)
       (raise-argument-error #%kernel raise-argument-error)
       (ordinary racket/list reverse))))
  (define report
    (webify-module-linklet-inputs->primitive-demands (list input)))
  (check-equal?
   (map (lambda (d)
          (list (webify-primitive-demand-module d)
                (webify-primitive-demand-name d)
                (webify-primitive-demand-sources d)))
        (webify-primitive-demand-report-demands report))
   '((#%kernel cons (uses-primitives))
     (#%kernel raise-argument-error (uses-primitives))))
  (check-equal? (webify-primitive-demand-report-table-requests report) '()))

(test-case "primitive demand audit records literal primitive-table requests"
  (define requests
    (webify-linklet-primitive-table-requests
     '(linklet () (out)
        (define-values (kernel-table) (primitive-table '#%kernel))
        (define-values (unsafe-table) (primitive-table (quote #%unsafe)))
        (define-values (ignored) (primitive-table dynamic-name)))
     'literal-probe))
  (check-equal?
   (map (lambda (request)
          (list (webify-primitive-table-request-module request)
                (webify-primitive-table-request-sources request)))
        requests)
   '((#%kernel (literal-probe))
     (#%unsafe (literal-probe)))))

(test-case "primitive demand audit records literal primitive-table key reads"
  (define demands
    (webify-linklet-primitive-table-key-demands
     '(linklet () (out)
        (define-values (kernel) (primitive-table '#%kernel))
        (define-values (unsafe) (primitive-table (quote #%unsafe)))
        (define-values (syntax-p?) (hash-ref kernel 'syntax?))
        (define-values (datum->syntax*) (hash-ref kernel (quote datum->syntax) #f))
        (define-values (unsafe-car*) (hash-has-key? unsafe 'unsafe-car))
        (define-values (ignored) (hash-ref dynamic-table 'not-a-primitive)))
     'key-probe))
  (check-equal?
   (map (lambda (d)
          (list (webify-primitive-demand-module d)
                (webify-primitive-demand-name d)
                (webify-primitive-demand-sources d)))
        demands)
   '((#%kernel datum->syntax (key-probe))
     (#%kernel syntax? (key-probe))
     (#%unsafe unsafe-car (key-probe)))))

(test-case "primitive demand audit compares explicit imports against availability"
  (define input
    (webify-module-linklet-input
     'availability-probe
     '(linklet (((present present) (missing missing))) (out)
        (define-values (out) present))
     '((present #%kernel present)
       (missing #%kernel missing))))
  (define report
    (webify-module-linklet-inputs->primitive-demands (list input)))
  (define missing
    (webify-primitive-demand-report-missing
     report
     #:available
     (lambda (module)
       (case module
         [(#%kernel) '(present)]
         [else '()]))))
  (check-equal?
   (map (lambda (d)
          (list (webify-primitive-demand-module d)
                (webify-primitive-demand-name d)
                (webify-primitive-demand-sources d)))
        missing)
   '((#%kernel missing (availability-probe)))))

(test-case "primitive demand audit combines reports and resolved inputs"
  (define module-report
    (webify-module-report
     'table-user
     '(#f)
     '(0)
     (list
      (webify-module-bundle-entry
       0
       'linklet
       '()
       '(out)
       '(linklet () (out)
          (define-values (out) (primitive-table '#%linklet)))
       #f))
     '()
     '(out)
     '(linklet () (out)
        (define-values (out) (primitive-table '#%linklet)))
     #t
     '()))
  (define input
    (webify-module-linklet-input
     'input-user
     '(linklet (((primitive-table primitive-table))) (out)
        (define-values (out) primitive-table))
     '((primitive-table #%linklet primitive-table))))
  (define report
    (webify-module-reports->primitive-demands
     (list module-report)
     #:inputs (list input)))
  (check-equal?
   (map webify-primitive-demand-name
        (webify-primitive-demand-report-demands report))
   '(primitive-table))
  (check-equal?
   (map webify-primitive-table-request-module
        (webify-primitive-demand-report-table-requests report))
   '(#%linklet)))

(test-case "primitive demand audit combines report key reads"
  (define module-report
    (webify-module-report
     'kernel-user
     '(#f)
     '(0)
     (list
      (webify-module-bundle-entry
       0
       'linklet
       '()
       '(out)
       '(linklet () (out)
          (define-values (kernel) (primitive-table '#%kernel))
          (define-values (out) (hash-ref kernel 'syntax-e)))
       #f))
     '()
     '(out)
     '(linklet () (out)
        (define-values (kernel) (primitive-table '#%kernel))
        (define-values (out) (hash-ref kernel 'syntax-e)))
     #t
     '()))
  (define report
    (webify-module-reports->primitive-demands (list module-report)))
  (check-equal?
   (map (lambda (d)
          (list (webify-primitive-demand-module d)
                (webify-primitive-demand-name d)
                (webify-primitive-demand-sources d)))
        (webify-primitive-demand-report-demands report))
   '((#%kernel syntax-e ((kernel-user 0))))))

(test-case "primitive demand ownership classifies runtime and provider names"
  (check-equal? (webify-primitive-name-ownership 'cons) 'runtime-owned)
  (check-equal? (webify-primitive-name-ownership 'read)
                'runtime-owned-but-provider-shadowed)
  (check-equal? (webify-primitive-name-ownership 'regexp-match?) 'provider-owned)
  (check-equal? (webify-primitive-name-ownership 'format) 'provider-owned)
  (check-equal? (webify-primitive-name-ownership 'call-with-parameterization)
                'runtime-preferred)
  (check-equal? (webify-primitive-name-ownership 'not-a-webracket-name)
                'unknown)
  (check-not-false (member 'read (webify-primitive-provider-shadowed-names)))
  (check-equal? (webify-provider-owned-primitive-provider 'read)
                'expander/read)
  (check-equal? (webify-primitive-provider-shadowed-status 'read)
                'temporary))

(test-case "primitive demand ownership counts summarize reports"
  (define input
    (webify-module-linklet-input
     'ownership-probe
     '(linklet (((cons cons)
                 (read read)
                 (call-with-parameterization call-with-parameterization)
                 (missing missing)))
        (out)
        (define-values (out) cons))
     '((cons #%kernel cons)
       (read #%kernel read)
       (call-with-parameterization #%kernel call-with-parameterization)
       (missing #%kernel not-a-webracket-name))))
  (define report
    (webify-module-linklet-inputs->primitive-demands (list input)))
  (check-equal? (webify-primitive-demand-report-ownership-counts report)
                '((runtime-owned . 1)
                  (runtime-owned-but-provider-shadowed . 1)
                  (runtime-preferred . 1)
                  (unknown . 1))))

(test-case "primitive ownership TSV exposes cleanup status"
  (define tmp-dir (make-temporary-file "webracket-ownership-tsv-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define out-path (build-path tmp-dir "out.tsv"))
      (define err-path (build-path tmp-dir "err.txt"))
      (define status
        (call-with-output-file out-path
          #:exists 'truncate
          (lambda (out)
            (call-with-output-file err-path
              #:exists 'truncate
              (lambda (err)
                (parameterize ([current-output-port out]
                               [current-error-port err])
                  (system*/exit-code
                   (find-system-path 'exec-file)
                   "-y"
                   (path->string probe-installed-module-deps-path)
                   "--primitive-ownership-collisions-tsv")))))))
      (define stdout (file->string out-path))
      (define stderr (file->string err-path))
      (check-equal? status 0 stderr)
      (define lines (string-split stdout "\n" #:trim? #t))
      (check-equal? (first lines) "name\townership\tprovider\tstatus")
      (check-not-false
       (member "read\truntime-owned-but-provider-shadowed\texpander/read\ttemporary"
               (rest lines))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files tmp-dir)))))

(test-case "Goal 1 module matrix names are known probe cases"
  (check-not-false (member 'promise-state goal1-module-cases))
  (check-not-false (member 'sequence-range goal1-module-cases))
  (check-not-false (member 'sequence-for/fold goal1-module-cases))
  (check-not-false (member 'for/list-basic goal1-module-cases))
  (check-not-false (member 'for*/list-basic goal1-module-cases))
  (check-not-false (member 'for/in-list goal1-module-cases))
  (check-not-false (member 'for/in-vector goal1-module-cases))
  (check-not-false (member 'for/parallel-sequences goal1-module-cases))
  (check-not-false (member 'for/control-clauses goal1-module-cases))
  (check-not-false (member 'match-basic goal1-module-cases))
  (check-not-false (member 'match-let-basic goal1-module-cases))
  (check-not-false (member 'format-basic goal1-module-cases))
  (check-not-false (member 'read-public-list goal1-module-cases))
  (check-not-false (member 'read-current-readtable goal1-module-cases))
  (check-not-false (member 'read-accept-reader-param goal1-module-cases))
  (check-not-false (member 'read-string->number goal1-module-cases))
  (check-not-false (member 'read-regexp-literal goal1-module-cases))
  (check-not-false (member 'read-pregexp-literal goal1-module-cases))
  (check-not-false (member 'read-hash-literal goal1-module-cases))
  (check-not-false (member 'read-port-location goal1-module-cases))
  (check-not-false (member 'read-accept-dot-param goal1-module-cases))
  (check-not-false (member 'bytes-append-basic goal1-module-cases))
  (check-false (member 'read-language-no-lang goal1-module-cases))
  (check-not-false (member 'regexp-literal goal1-module-cases))
  (check-not-false (member 'regexp-capture goal1-module-cases))
  (check-not-false (member 'regexp-replace goal1-module-cases))
  (check-not-false (member 'set-member goal1-module-cases))
  (check-not-false (member 'sequence-for/list goal1-module-cases))
  (check-not-false (member 'match-basic goal1-module-cases))
  (check-not-false (member 'format-basic goal1-module-cases))
  (check-not-false (member 'format-print goal1-module-cases))
  (check-not-false (member 'format-print-string goal1-module-cases))
  (check-not-false (member 'list-provider-basic goal1-module-cases))
  (check-not-false (member 'string-provider-basic goal1-module-cases))
  (check-not-false (member 'bool-provider-basic goal1-module-cases))
  (check-not-false (member 'vector-provider-basic goal1-module-cases))
  (check-not-false (member 'function-provider-basic goal1-module-cases))
  (check-not-false (member 'class-basic goal1-module-cases))
  (check-not-false (member 'class-init-field goal1-module-cases))
  (check-not-false (member 'class-field-access goal1-module-cases))
  (check-not-false (member 'class-inheritance goal1-module-cases))
  (check-not-false (member 'class-predicate goal1-module-cases))
  (check-not-false (member 'class-super-override goal1-module-cases))
  (check-not-false (member 'class-interface-basic goal1-module-cases))
  (check-not-false (member 'class-generic-basic goal1-module-cases))
  (check-not-false (member 'class-mixin-basic goal1-module-cases))
  (check-not-false (member 'class-object-equality goal1-module-cases))
  (check-not-false (member 'class-reflection-basic goal1-module-cases))
  (check-not-false (member 'class-relationships goal1-module-cases))
  (check-not-false (member 'class-info-basic goal1-module-cases))
  (check-not-false (member 'class-construction-basic goal1-module-cases))
  (check-not-false (member 'class-send-forms goal1-module-cases))
  (check-not-false (member 'class-dynamic-field-send goal1-module-cases))
  (check-not-false (member 'class-with-method goal1-module-cases))
  (check-not-false (member 'class-send-apply goal1-module-cases))
  (check-not-false (member 'class-augment-inner goal1-module-cases))
  (check-not-false (member 'class-private-final goal1-module-cases))
  (check-not-false (member 'class-abstract-basic goal1-module-cases))
  (check-not-false (member 'class-init-rest-basic goal1-module-cases))
  (for ([name (in-list goal1-module-cases)])
    (check-not-false (member name known-module-cases))))

(test-case "Goal 1 dependency matrix is covered by runtime tiers"
  (define runtime-goal1-cases
    (append
     (source-defined-quoted-list probe-installed-runtime-smoke-path
                                 'goal1-fast-module-cases)
     (source-defined-quoted-list probe-installed-runtime-smoke-path
                                 'goal1-slow-module-cases)))
  (for ([name (in-list goal1-module-cases)])
    (check-not-false
     (member name runtime-goal1-cases)
     (format "~a is in goal1-module-cases but not in a runtime smoke tier"
             name))))

(test-case "new reader Goal 1 cases extract without missing primitive demands"
  (for ([name (in-list '(read-regexp-literal
                         read-pregexp-literal
                         read-hash-literal
                         read-port-location
                         read-accept-dot-param))])
    (define inputs (extract-case-inputs name))
    (define report (webify-module-linklet-inputs->primitive-demands inputs))
    (check-equal? (webify-primitive-demand-report-missing report)
                  '()
                  (format "~a should have no missing primitive demands" name))))
