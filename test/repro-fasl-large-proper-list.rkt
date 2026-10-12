#lang webracket

;; Regression repro for the F09 document-limit bridge: recursive FASL pair
;; encoding exhausted the Wasm stack before passing a 10,000-element proper
;; list through the console-bridge boundary.
;;
;; Run:
;;   racket -S pkgs webracket.rkt --node --run --no-stdlib \
;;     --dest /tmp/webracket-fasl-large-proper-list \
;;     test/repro-fasl-large-proper-list.rkt

(define element-count 10000)

(define input
  (let loop ([remaining element-count] [reversed null])
    (if (zero? remaining)
        reversed
        (loop (sub1 remaining) (cons 0 reversed)))))

(define encoded (s-exp->fasl input))
(define decoded (fasl->s-exp encoded))
(define nested
  (vector 1/2 3+4i (vector "FASL" #t)))

;; Each pair is a car child of its predecessor, unlike the flat proper list
;; above. This exercises a document-shaped value with a long structural path.
(define deep-pair
  (let loop ([remaining 1000] [result 0])
    (if (zero? remaining)
        result
        (loop (sub1 remaining) (cons result null)))))
(define deep-pair-encoded (s-exp->fasl deep-pair))
(define deep-pair-decoded (fasl->s-exp deep-pair-encoded))

(displayln (list (bytes-length encoded) (length decoded)))
(displayln (equal? nested (fasl->s-exp (s-exp->fasl nested))))
(displayln (list (bytes-length deep-pair-encoded) (pair? deep-pair-decoded)))
