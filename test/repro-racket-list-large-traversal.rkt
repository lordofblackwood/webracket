#lang webracket/base

;; Regression repro for `#lang webracket/base` selecting host-recursive `map`
;; and `filter`, which exhausted the Wasm stack at the math editor's 10,000-node
;; document limit. A separate `racket/list` import is intentionally unnecessary:
;; the failure originated in the base-language binding itself.
;;
;; Run:
;;   racket -S pkgs webracket.rkt --node --run --no-stdlib \
;;     --dest /tmp/webracket-racket-list-large-traversal \
;;     test/repro-racket-list-large-traversal.rkt

(define traversal-count 10000)
(define traversal-input
  (let loop ([remaining traversal-count] [reversed null])
    (if (zero? remaining)
        reversed
        (loop (sub1 remaining) (cons 0 reversed)))))
(define mapped (map add1 traversal-input))
(define selected (filter zero? traversal-input))
(define all-zero? (andmap zero? traversal-input))
(define first-zero (ormap zero? traversal-input))
(for-each (lambda (_value) (void)) traversal-input)

(displayln (list (length mapped)
                 (length selected)
                 all-zero?
                 first-zero
                 (filter odd? (list 1 2 3))))
