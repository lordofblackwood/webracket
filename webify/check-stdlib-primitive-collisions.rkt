#lang racket/base

;; Guard the module-based stdlib bridge against reintroducing the old textual
;; stdlib failure mode: a generated top-level stdlib alias must not also be a
;; compiler primitive.

(require racket/list
         racket/set
         "../driver.rkt"
         "../stdlib/module-exports.rkt"
         "stdlib-surface-report.rkt")

(define runtime-primitive-substrate
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
    print-vector-length))

(define temporary-primitive-owned-public-helpers
  '(raise-argument-error
    raise-arguments-error
    read
    read-syntax))

(define expected-primitive-owned-exports
  (sort (remove-duplicates
         (append runtime-primitive-substrate
                 temporary-primitive-owned-public-helpers)
         eq?)
        symbol<?))

(define provider-owned-primitive-transition-allowlist
  '(read
    read-syntax))

(define runtime-writing-primitive-transition-allowlist
  runtime-writing-substrate-symbols)

(define (unexpected-provider-owned-primitives)
  (define primitives (list->seteq (list-available-primitives)))
  (define provider-owned (list->seteq provider-owned-public-symbols))
  (sort
   (remove* provider-owned-primitive-transition-allowlist
            (set->list (set-intersect primitives provider-owned))
            eq?)
   symbol<?))

(define (unexpected-temporary-stdlib-primitives)
  (define primitives (list->seteq (list-available-primitives)))
  (define temporary-owned
    (list->seteq
     (for/list ([row (in-list stdlib-symbol-ownership-rows)]
                #:when (eq? (stdlib-symbol-ownership-row-owner row)
                            'temporary-stdlib-owned))
       (stdlib-symbol-ownership-row-name row))))
  (sort (set->list (set-intersect primitives temporary-owned)) symbol<?))

(define (unexpected-writing-substrate-primitives)
  (define primitives (list->seteq (list-available-primitives)))
  (define writing-substrate (list->seteq runtime-writing-substrate-symbols))
  (sort
   (remove* runtime-writing-primitive-transition-allowlist
            (set->list (set-intersect primitives writing-substrate))
            eq?)
   symbol<?))

(define (check-root! browser?)
  (define exports (list->seteq (stdlib-module-export-symbols browser?)))
  (define aliases (list->seteq (stdlib-module-alias-symbols browser?)))
  (define primitives (list->seteq (list-available-primitives)))
  (define alias-collisions
    (sort (set->list (set-intersect aliases primitives)) symbol<?))
  (define primitive-owned
    (sort (set->list (set-intersect exports primitives)) symbol<?))
  (define unexpected-primitive-owned
    (remove* expected-primitive-owned-exports primitive-owned eq?))
  (printf "stdlib-root: ~a\n" (if browser? 'browser 'node))
  (printf "stdlib-primitive-owned-exports: ~s\n" primitive-owned)
  (printf "stdlib-transitional-exports: ~s\n"
          (sort (filter (lambda (sym) (set-member? exports sym))
                        stdlib-transitional-export-symbols)
                symbol<?))
  (printf "stdlib-alias-count: ~a\n" (set-count aliases))
  (unless (null? alias-collisions)
    (error 'check-stdlib-primitive-collisions
           "stdlib aliases collide with compiler primitives for ~a root: ~s"
           (if browser? 'browser 'node)
           alias-collisions))
  (unless (null? unexpected-primitive-owned)
    (error 'check-stdlib-primitive-collisions
           "unclassified primitive-owned stdlib exports for ~a root: ~s"
           (if browser? 'browser 'node)
           unexpected-primitive-owned)))

(check-root! #f)
(check-root! #t)
(define provider-owned-primitive-collisions
  (unexpected-provider-owned-primitives))
(define temporary-stdlib-primitive-collisions
  (unexpected-temporary-stdlib-primitives))
(define writing-substrate-primitive-collisions
  (unexpected-writing-substrate-primitives))
(printf "provider-owned-primitive-transition-allowlist: ~s\n"
        provider-owned-primitive-transition-allowlist)
(printf "provider-owned-primitive-collisions: ~s\n"
        provider-owned-primitive-collisions)
(printf "temporary-stdlib-primitive-collisions: ~s\n"
        temporary-stdlib-primitive-collisions)
(printf "writing-substrate-primitive-collisions: ~s\n"
        writing-substrate-primitive-collisions)
(unless (null? provider-owned-primitive-collisions)
  (error 'check-stdlib-primitive-collisions
         "provider-owned public names unexpectedly remain compiler primitives: ~s"
         provider-owned-primitive-collisions))
(unless (null? temporary-stdlib-primitive-collisions)
  (error 'check-stdlib-primitive-collisions
         "temporary stdlib-owned public names unexpectedly became compiler primitives: ~s"
         temporary-stdlib-primitive-collisions))
(unless (null? writing-substrate-primitive-collisions)
  (error 'check-stdlib-primitive-collisions
         "unclassified writing substrate primitive names: ~s"
         writing-substrate-primitive-collisions))
(displayln "stdlib primitive ownership guard passed")
