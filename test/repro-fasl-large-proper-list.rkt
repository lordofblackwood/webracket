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

(displayln (bytes-length (s-exp->fasl input)))
