#lang racket/base

;; Guard the module-based stdlib bridge against reintroducing the old textual
;; stdlib failure mode: a generated top-level stdlib alias must not also be a
;; compiler primitive.

(require racket/list
         racket/set
         "../driver.rkt"
         "../stdlib/module-exports.rkt")

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
  '(format
    fprintf
    raise-argument-error
    raise-arguments-error
    read
    read-syntax))

(define expected-primitive-owned-exports
  (sort (remove-duplicates
         (append runtime-primitive-substrate
                 temporary-primitive-owned-public-helpers)
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
(displayln "stdlib primitive ownership guard passed")
