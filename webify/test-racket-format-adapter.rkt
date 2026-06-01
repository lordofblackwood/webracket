#lang racket/base

(require rackunit
         (prefix-in web: "../racket-src/racket/format-web.rkt")
         (only-in "../pkgs/webracket/private/kw.rkt"
                  [keyword-apply web-keyword-apply]))

;; call/keywords : procedure? (listof keyword?) list? list? -> any/c
;;   Apply a WebRacket keyword-procedure using the same helper that compiled
;;   keyword calls target; direct host keyword calls intentionally do not work.
(define (call/keywords proc kws vals args)
  (web-keyword-apply proc kws vals args))

(test-case "racket/format adapter supports common precision forms for ~r"
  (check-equal? (call/keywords web:~r '(#:precision) '(2) '(3.14159)) "3.14")
  (check-equal? (call/keywords web:~r '(#:precision) '(4) '(1.5)) "1.5")
  (check-equal? (call/keywords web:~r '(#:precision) '((= 2)) '(50)) "50.00")
  (check-equal? (call/keywords web:~r '(#:precision) '((= 4)) '(1.5)) "1.5000")
  (check-equal? (call/keywords web:~r '(#:precision) '(0) '(1.5)) "2")
  (check-equal? (call/keywords web:~r '(#:precision) '((= 0)) '(1.5)) "2."))

(test-case "racket/format adapter keeps precision scoped to ~r"
  (check-exn #rx"supported racket/format keyword"
             (lambda () (call/keywords web:~a '(#:precision) '(2) '(1))))
  (check-exn #rx"supported racket/format keyword"
             (lambda () (call/keywords web:~s '(#:precision) '(2) '(1))))
  (check-exn #rx"supported racket/format keyword"
             (lambda () (call/keywords web:~v '(#:precision) '(2) '(1)))))

(module+ main
  (void))
