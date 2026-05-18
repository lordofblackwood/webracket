#lang racket/base

(provide node-exports
         browser-exports
         browser-only
         staged-original-racket-owned
         webracket-base-owned
         webracket-full-owned
         temporary-stdlib-owned
         report-stdlib-surface)

(require racket/list
         "../driver.rkt"
         "../stdlib/module-exports.rkt"
         "io-format-provider.rkt"
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
  (report-line "webracket/base foundation" (sorted-symbols webracket-base-owned))
  (report-line "webracket/full foundation+addons" (sorted-symbols webracket-full-owned))
  (report-line "temporary stdlib-owned aliases" (sorted-symbols temporary-stdlib-owned))
  (report-line "transitional stdlib exports" (sorted-symbols stdlib-transitional-export-symbols))
  (report-line "temporary primitive-owned exports" (sorted-symbols stdlib-primitive-owned-export-symbols)))

(module+ main
  (report-stdlib-surface))
