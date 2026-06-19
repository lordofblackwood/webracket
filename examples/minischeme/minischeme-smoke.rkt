#lang webracket/base

(require racket/string
         "minischeme.rkt")

;; check-output-contains! : string? string? -> void?
;;   Run src through the MiniScheme interpreter and require expected in the output.
(define (check-output-contains! src expected)
  (define actual (minischeme-process-input src))
  (unless (and (string? actual)
               (string-contains? actual expected))
    (error 'minischeme-smoke
           "expected output containing ~s for ~s, got ~s"
           expected src actual)))

(check-output-contains! "42" "42")
(check-output-contains! "(+ 1 2)" "3")
(check-output-contains! "((lambda (x) x) 5)" "5")

(displayln "ok")
