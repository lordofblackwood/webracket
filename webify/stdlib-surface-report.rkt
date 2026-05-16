#lang racket/base

(require racket/list
         "../driver.rkt"
         "../stdlib/module-exports.rkt"
         "io-format-provider.rkt")

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

(define temporary-stdlib-owned
  (remove-symbols
   (stdlib-module-alias-symbols #f)
   (append stdlib-transitional-export-symbols
           staged-original-racket-owned)))

(report-line "node exports" (sorted-symbols node-exports))
(report-line "browser-only exports" (sorted-symbols browser-only))
(report-line "node primitive-owned overlaps" (sorted-symbols (primitive-owned node-exports)))
(report-line "browser primitive-owned overlaps" (sorted-symbols (primitive-owned browser-exports)))
(report-line "node stdlib aliases" (sorted-symbols (stdlib-module-alias-symbols #f)))
(report-line "browser stdlib aliases" (sorted-symbols (stdlib-module-alias-symbols #t)))
(report-line "staged original Racket providers" (sorted-symbols staged-original-racket-owned))
(report-line "temporary stdlib-owned aliases" (sorted-symbols temporary-stdlib-owned))
(report-line "transitional stdlib exports" (sorted-symbols stdlib-transitional-export-symbols))
(report-line "temporary primitive-owned exports" (sorted-symbols stdlib-primitive-owned-export-symbols))
