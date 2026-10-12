#lang webracket/base

;; Regression repro for `#lang webracket/base` selecting recursive list
;; traversals, which exhausted the Wasm stack at the math editor's 10,000-node
;; document limit.
;;
;; Run:
;;   racket -S pkgs webracket.rkt --node --run --no-stdlib \
;;     --dest /tmp/webracket-racket-list-large-traversal \
;;     test/repro-racket-list-large-traversal.rkt

(require (only-in racket/list remove-duplicates))

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
(for-each (lambda (_value) (void)) traversal-input)

(displayln (list (length mapped)
                 (length selected)
                 all-zero?
                 first-zero
                 (length deduplicated)
                 (filter odd? (list 1 2 3))))
