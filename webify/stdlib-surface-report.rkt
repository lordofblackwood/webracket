#lang racket/base

(provide node-exports
         browser-exports
         browser-only
         staged-original-racket-owned
         provider-owned-public-symbols
         runtime-writing-substrate-symbols
         high-level-printing-provider-symbols
         legacy-printing-script-symbols
         webracket-base-owned
         webracket-full-owned
         temporary-stdlib-owned
         stdlib-file-ownership-row
         stdlib-file-ownership-row?
         stdlib-file-ownership-row-file
         stdlib-file-ownership-row-owner
         stdlib-file-ownership-row-replacement
         stdlib-file-ownership-row-note
         stdlib-file-ownership-rows
         stdlib-symbol-ownership-row
         stdlib-symbol-ownership-row?
         stdlib-symbol-ownership-row-name
         stdlib-symbol-ownership-row-owner
         stdlib-symbol-ownership-row-replacement
         stdlib-symbol-ownership-rows
         stdlib-symbol-owner
         stdlib-symbol-replacement
         report-stdlib-surface)

(require racket/list
         "../driver.rkt"
         "../stdlib/module-exports.rkt"
         "io-format-provider.rkt"
         "io-print-provider.rkt"
         "webracket-base-surface.rkt"
         "webracket-full-surface.rkt")

(define (sorted-symbols xs)
  (sort (remove-duplicates xs eq?) symbol<?))

(define node-exports (stdlib-module-export-symbols #f))
(define browser-exports (stdlib-module-export-symbols #t))
(define primitives (list-available-primitives))
(define browser-only
  (filter (lambda (sym) (not (memq sym node-exports)))
          browser-exports))

(define (primitive-owned exports)
  (filter (lambda (sym) (memq sym primitives))
          exports))

(define (report-line label xs)
  (printf "~a (~a): ~s\n" label (length xs) xs))

(define (remove-symbols xs removals)
  (remove* removals xs eq?))

(define staged-original-racket-owned
  io-format-provider-symbols)

(define provider-owned-public-symbols
  (append staged-original-racket-owned
          '(read read-syntax)))

(define runtime-writing-substrate-symbols
  (append
   io-print-runtime-substrate-symbols
   '(current-print
    error-print-width
    error-value->string-handler
    print-as-expression
    print-boolean-long-form
    print-box
    print-graph
    print-hash-table
    print-mpair-curly-braces
    print-pair-curly-braces
    print-reader-abbreviations
    print-struct
    print-syntax-width
    print-unreadable
    print-vector-length)))

(define high-level-printing-provider-symbols
  io-print-provider-symbols)

(define legacy-printing-script-symbols
  '(fprintf
    printf
    eprintf))

(define webracket-base-owned
  (append (list webracket-base-foundation)
          webracket-base-addon-libraries))

(define webracket-full-owned
  (append (list webracket-full-foundation)
          webracket-full-addon-libraries))

(define temporary-stdlib-owned
  (remove-symbols
   (stdlib-module-alias-symbols #f)
   (append stdlib-transitional-export-symbols
           staged-original-racket-owned)))

(struct stdlib-file-ownership-row (file owner replacement note)
  #:transparent)

(struct stdlib-symbol-ownership-row (name owner replacement)
  #:transparent)

(define stdlib-file-ownership-rows
  (list
   (stdlib-file-ownership-row "shared-library-structs.rkt"
                              'legacy-script-only
                              'webracket-module
                              "Shared wrappers used by old include-lib style libraries.")
   (stdlib-file-ownership-row "qq-and-or.rkt"
                              'legacy-script-only
                              'host-expander
                              "Syntax sugar belongs in expanded module input, not stdlib.")
   (stdlib-file-ownership-row "ellipses.rkt"
                              'legacy-script-only
                              'host-expander
                              "Syntax helper for legacy script programs.")
   (stdlib-file-ownership-row "parameters.rkt"
                              'runtime-substrate
                              'runtime-primitive
                              "Poor-man parameter support is being replaced by runtime primitives.")
   (stdlib-file-ownership-row "ports.rkt"
                              'mixed-runtime-and-legacy
                              'runtime-primitive
                              "Ports need runtime ownership; script wrappers remain temporary.")
   (stdlib-file-ownership-row "exceptions.rkt"
                              'mixed-runtime-and-legacy
                              'runtime-primitive
                              "Exception constructors use formatting support and need a runtime/provider split.")
   (stdlib-file-ownership-row "writing.rkt"
                              'mixed-runtime-and-legacy
                              'runtime-primitive
                              "write/display/print and print parameters are not fully retired yet.")
   (stdlib-file-ownership-row "reading.rkt"
                              'replace-with-original-racket-provider
                              'expander/read
                              "read/read-syntax should come from the staged expander reader.")
   (stdlib-file-ownership-row "evaluation.rkt"
                              'legacy-script-only
                              'runtime-primitive
                              "current-print/print-values are runtime substrate for now.")
   (stdlib-file-ownership-row "hash-code.rkt"
                              'runtime-substrate
                              'runtime-primitive
                              "Hash-code helpers are runtime primitives now.")
   (stdlib-file-ownership-row "intmap.rkt"
                              'legacy-script-only
                              'delete-or-provider
                              "Temporary legacy helper; not part of Goal 1 modules.")
   (stdlib-file-ownership-row "formatting-numbers.rkt"
                              'replace-with-original-racket-provider
                              'racket-src/io/format
                              "Number formatting belongs with staged io/format.")
   (stdlib-file-ownership-row "browser.rkt"
                              'legacy-script-only
                              'browser-modules
                              "Browser helpers should move to browser/* and js/* modules.")
   (stdlib-file-ownership-row "hash.rkt"
                              'obsolete
                              'runtime-hamt
                              "Abandoned immutable-hash attempt; not included by stdlib root.")
   (stdlib-file-ownership-row "regexp.rkt"
                              'obsolete
                              'regexp-provider
                              "Obsolete regexp attempt; regexp/ provider is the replacement.")
   (stdlib-file-ownership-row "kw.rkt"
                              'obsolete
                              'runtime-keywords
                              "Old keyword experiment; keyword support is runtime/provider-owned.")))

(define (symbol-replacement name)
  (cond
    [(memq name staged-original-racket-owned) 'racket-src/io/format]
    [(memq name '(read read-syntax)) 'expander/read]
    [(memq name runtime-writing-substrate-symbols) 'runtime-primitive]
    [(memq name high-level-printing-provider-symbols) 'racket-src/io/print]
    [(memq name legacy-printing-script-symbols) 'racket-src/io/format]
    [(memq name stdlib-transitional-export-symbols) 'none]
    [(memq name stdlib-primitive-owned-export-symbols) 'runtime-primitive]
    [else 'legacy-script-only]))

(define (symbol-owner name)
  (cond
    [(memq name staged-original-racket-owned)
     'replace-with-original-racket-provider]
    [(memq name '(read read-syntax))
     'replace-with-original-racket-provider]
    [(memq name runtime-writing-substrate-symbols)
     'runtime-writing-substrate]
    [(memq name high-level-printing-provider-symbols)
     'replace-with-original-racket-provider]
    [(memq name legacy-printing-script-symbols)
     'replace-with-original-racket-provider]
    [(memq name stdlib-transitional-export-symbols)
     'legacy-script-only]
    [(memq name stdlib-primitive-owned-export-symbols)
     'runtime-primitive]
    [else
     'temporary-stdlib-owned]))

(define stdlib-symbol-ownership-rows
  (sort
   (for/list ([name (in-list (sorted-symbols
                              (append (stdlib-module-export-symbols #f)
                                      staged-original-racket-owned)))])
     (stdlib-symbol-ownership-row name
                                  (symbol-owner name)
                                  (symbol-replacement name)))
   symbol<?
   #:key stdlib-symbol-ownership-row-name))

;; stdlib-symbol-owner : symbol? -> symbol?
;;   Return the current retirement owner for a public stdlib-adjacent name.
(define (stdlib-symbol-owner name)
  (symbol-owner name))

;; stdlib-symbol-replacement : symbol? -> symbol?
;;   Return the planned replacement provider/category for a public stdlib-adjacent name.
(define (stdlib-symbol-replacement name)
  (symbol-replacement name))

;; report-stdlib-surface : -> void?
;;   Print the current public ownership split for stdlib migration work.
(define (report-stdlib-surface)
  (report-line "node exports" (sorted-symbols node-exports))
  (report-line "browser-only exports" (sorted-symbols browser-only))
  (report-line "node primitive-owned overlaps" (sorted-symbols (primitive-owned node-exports)))
  (report-line "browser primitive-owned overlaps" (sorted-symbols (primitive-owned browser-exports)))
  (report-line "node stdlib aliases" (sorted-symbols (stdlib-module-alias-symbols #f)))
  (report-line "browser stdlib aliases" (sorted-symbols (stdlib-module-alias-symbols #t)))
  (report-line "staged original Racket providers" (sorted-symbols staged-original-racket-owned))
  (report-line "provider-owned public symbols" (sorted-symbols provider-owned-public-symbols))
  (report-line "runtime writing substrate" (sorted-symbols runtime-writing-substrate-symbols))
  (report-line "staged io/print high-level provider" (sorted-symbols high-level-printing-provider-symbols))
  (report-line "webracket/base foundation" (sorted-symbols webracket-base-owned))
  (report-line "webracket/full foundation+addons" (sorted-symbols webracket-full-owned))
  (report-line "temporary stdlib-owned aliases" (sorted-symbols temporary-stdlib-owned))
  (report-line "transitional stdlib exports" (sorted-symbols stdlib-transitional-export-symbols))
  (report-line "temporary primitive-owned exports" (sorted-symbols stdlib-primitive-owned-export-symbols))
  (for ([row (in-list stdlib-file-ownership-rows)])
    (printf "stdlib-file\t~a\towner\t~a\treplacement\t~a\tnote\t~a\n"
            (stdlib-file-ownership-row-file row)
            (stdlib-file-ownership-row-owner row)
            (stdlib-file-ownership-row-replacement row)
            (stdlib-file-ownership-row-note row)))
  (for ([row (in-list stdlib-symbol-ownership-rows)])
    (printf "stdlib-symbol\t~a\towner\t~a\treplacement\t~a\n"
            (stdlib-symbol-ownership-row-name row)
            (stdlib-symbol-ownership-row-owner row)
            (stdlib-symbol-ownership-row-replacement row))))

(module+ main
  (report-stdlib-surface))
