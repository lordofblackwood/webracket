#lang webracket/base

;; Regression repro for `#lang webracket/base` selecting recursive list
;; traversals, which exhausted the Wasm stack at the math editor's 10,000-node
;; document limit.
;;
;; Run:
;;   racket -S pkgs webracket.rkt --node --run --no-stdlib \
;;     --dest /tmp/webracket-racket-list-large-traversal \
;;     test/repro-racket-list-large-traversal.rkt

(require (only-in racket/list
                  add-between
                  drop-right
                  filter-map
                  flatten
                  last
                  list-update
                  remove-duplicates
                  take
                  take-common-prefix))

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
(define unique-input
  (let loop ([remaining traversal-count] [reversed null])
    (if (zero? remaining)
        reversed
        (loop (sub1 remaining) (cons remaining reversed)))))
(define deduplicated (remove-duplicates unique-input))
(define mapped-ones (filter-map (lambda (_value) 1) traversal-input))
(define first-half (take traversal-input (quotient traversal-count 2)))
(define without-last (drop-right traversal-input 1))
(define updated-last (list-update traversal-input (sub1 traversal-count) add1))
(define flattened (flatten traversal-input))
(define common-prefix (take-common-prefix traversal-input traversal-input))
(define separated (add-between traversal-input 1))
(for-each (lambda (_value) (void)) traversal-input)

(displayln (list (length mapped)
                 (length selected)
                 all-zero?
                 first-zero
                 (length deduplicated)
                 (length mapped-ones)
                 (length first-half)
                 (length without-last)
                 (last updated-last)
                 (length flattened)
                 (length common-prefix)
                 (length separated)
                 (filter odd? (list 1 2 3))))
