#lang racket/base

(provide generated-import-origin-row
         generated-import-origin-row?
         generated-import-origin-row-module
         generated-import-origin-row-local
         generated-import-origin-row-external
         generated-import-origin-row-dependency
         generated-import-origin-row-provider-export
         generated-import-origin-row-base-name
         generated-import-origin-row-alternative-providers
         generated-import-origin-rows
         print-generated-import-origin-report)

;;; Report generated imports that resolve to exact generated exports even though
;;; another provider in the same dependency closure exports the unsuffixed base
;;; name. Those rows are suspicious because generated names such as `sort.1`
;;; often represent imported public bindings, not durable provider APIs.

(require racket/cmdline
         racket/list
         racket/match
         racket/string
         "../pkgs/webracket-lib/compiler/webify/module-extractor.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-input.rkt"
         "../pkgs/webracket-lib/compiler/webify/provider-trials.rkt")

(struct generated-import-origin-row
  (module local external dependency provider-export base-name alternative-providers)
  #:transparent)

;; generated-name? : symbol? -> boolean?
;;   Recognize common decompiler-generated import/export spelling.
(define (generated-name? name)
  (define s (symbol->string name))
  (or (regexp-match? #rx"^[0-9]+/.+" s)
      (regexp-match? #rx"^.+[.][0-9]+$" s)))

;; generated-base-name : symbol? -> symbol?
;;   Strip common generated prefixes/suffixes from a binding name.
(define (generated-base-name name)
  (define s (symbol->string name))
  (cond
    [(regexp-match #rx"^[0-9]+/(.+)$" s)
     => (lambda (m) (string->symbol (cadr m)))]
    [(regexp-match #rx"^(.+)[.][0-9]+$" s)
     => (lambda (m) (string->symbol (cadr m)))]
    [else name]))

;; dependency-exports-ref : dependency-exports symbol? -> (listof symbol?)
;;   Return the export list for a provider dependency row.
(define (dependency-exports-ref dependency-exports dependency)
  (match (assoc dependency dependency-exports)
    [(list _ exports) exports]
    [_ '()]))

;; base-name-provider-alternatives : dependency-exports symbol? symbol? -> (listof symbol?)
;;   Find providers other than selected-dependency that export base-name exactly.
(define (base-name-provider-alternatives dependency-exports selected-dependency base-name)
  (for/list ([row (in-list dependency-exports)]
             #:do [(match-define (list dependency exports) row)]
             #:when (and (not (eq? dependency selected-dependency))
                         (memq base-name exports)))
    dependency))

;; import-external-map : report -> hasheq?
;;   Map local imports to their original external names from the report import map.
(define (import-external-map report)
  (define import-map (webify-module-report-import-map report))
  (define bindings
    (apply append (webify-module-import-map-phase0-import-groups import-map)))
  (for/fold ([table (hasheq)])
            ([binding (in-list bindings)])
    (match-define (list local external) binding)
    (if (hash-has-key? table local)
        table
        (hash-set table local external))))

;; report-generated-import-origin-rows : report reports dependency-exports -> rows
;;   Inspect one resolved provider report for suspicious exact generated exports.
(define (report-generated-import-origin-rows report reports dependency-exports)
  (define module-name (webify-module-report-name report))
  (define external-map (import-external-map report))
  (with-handlers ([exn:fail? (lambda (_exn) '())])
    (define input
      (webify-module-report->resolved-linklet-input/providers report reports))
    (filter values
            (for/list ([triple (in-list (webify-module-linklet-input-imports input))])
              (match-define (list local dependency provider-export) triple)
              (define external (hash-ref external-map local local))
              (define base-name (generated-base-name provider-export))
              (define alternatives
                (if (generated-name? provider-export)
                    (base-name-provider-alternatives dependency-exports dependency base-name)
                    '()))
              (and (generated-name? provider-export)
                   (pair? alternatives)
                   (generated-import-origin-row module-name
                                                local
                                                external
                                                dependency
                                                provider-export
                                                base-name
                                                alternatives))))))

;; fetch-provider-closure : (listof symbol?) -> (listof report?)
;;   Fetch root provider reports and their transitive provider closure.
(define (fetch-provider-closure modules)
  (define provider-cache (make-webify-module-provider-cache webify-module-path->report))
  (define roots
    (for/list ([module (in-list modules)])
      (webify-module-provider-cache-ref provider-cache module)))
  (webify-module-reports->required-provider-closure
   roots
   #:fetch-provider
   (lambda (module)
     (webify-module-provider-cache-ref provider-cache module))
   #:skip-unfetchable? #t))

;; generated-import-origin-rows : (listof symbol?) -> (listof generated-import-origin-row?)
;;   Build suspicious generated-import origin rows for provider module closures.
(define (generated-import-origin-rows modules)
  (define reports (fetch-provider-closure modules))
  (define dependency-exports (webify-module-reports-dependency-exports reports))
  (append*
   (for/list ([report (in-list reports)])
     (report-generated-import-origin-rows report reports dependency-exports))))

;; join-symbols : (listof symbol?) -> string?
;;   Render a symbol list as a comma-separated cell.
(define (join-symbols symbols)
  (string-join (map symbol->string symbols) ","))

;; print-generated-import-origin-row-tsv : row output-port? -> void?
;;   Print one TSV watchlist row.
(define (print-generated-import-origin-row-tsv row out)
  (printf "~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
          (generated-import-origin-row-module row)
          (generated-import-origin-row-local row)
          (generated-import-origin-row-external row)
          (generated-import-origin-row-dependency row)
          (generated-import-origin-row-provider-export row)
          (generated-import-origin-row-base-name row)
          (join-symbols (generated-import-origin-row-alternative-providers row))))

;; print-generated-import-origin-report : (listof symbol?) [#:tsv? boolean?] -> void?
;;   Print a watchlist for generated imports with plausible base-name providers.
(define (print-generated-import-origin-report modules #:tsv? [tsv? #f])
  (define rows (generated-import-origin-rows modules))
  (cond
    [tsv?
     (displayln "module\tlocal\texternal\tdependency\tprovider_export\tbase_name\talternative_providers")
     (for ([row (in-list rows)])
       (print-generated-import-origin-row-tsv row (current-output-port)))]
    [else
     (printf "Generated import origin watchlist\n")
     (printf "modules: ~a\n" (join-symbols modules))
     (printf "rows: ~a\n" (length rows))
     (for ([row (in-list rows)])
       (printf "- ~a imports ~a/~a -> ~a:~a; base ~a also exported by ~a\n"
               (generated-import-origin-row-module row)
               (generated-import-origin-row-local row)
               (generated-import-origin-row-external row)
               (generated-import-origin-row-dependency row)
               (generated-import-origin-row-provider-export row)
               (generated-import-origin-row-base-name row)
               (join-symbols (generated-import-origin-row-alternative-providers row))))]))

;; parse-modules : string? -> (listof symbol?)
;;   Parse a comma-separated module list.
(define (parse-modules str)
  (filter-map (lambda (part)
                (define trimmed (string-trim part))
                (and (not (string=? trimmed ""))
                     (string->symbol trimmed)))
              (string-split str ",")))

(module+ main
  (define tsv? #f)
  (define modules
    '(racket/list
      racket/string
      racket/function
      racket/set
      racket/sequence
      racket/class
      racket/dict
      racket/pretty))
  (command-line
   #:program "generated-import-origin-report.rkt"
   #:once-each
   [("--tsv") "Print tab-separated watchlist rows"
              (set! tsv? #t)]
   [("--modules") module-list "Comma-separated provider modules to inspect"
                  (set! modules (parse-modules module-list))])
  (print-generated-import-origin-report modules #:tsv? tsv?))
