#lang racket/base

(require rackunit
         "../racket-src/io/format/printf-web.rkt")

;; printf-result : string? (listof any/c) -> string?
;;   Run adapted do-printf into a string port.
(define (printf-result fmt args)
  (define out (open-output-string))
  (do-printf 'adapter-test out fmt args)
  (get-output-string out))

(test-case "adapted do-printf handles core directives"
  (check-equal? (printf-result "value=~a write=~s print=~v~n"
                               (list 42 'ok "hi"))
                "value=42 write=ok print=\"hi\"\n")
  (check-equal? (printf-result "hex=~x oct=~o bin=~b char=~c ~~"
                               (list 255 9 5 #\A))
                "hex=ff oct=11 bin=101 char=A ~"))

(test-case "adapted do-printf handles dot and error directives"
  (check-equal? (printf-result "dot=~.a err=~e"
                               (list "abcdef" '(bad value)))
                "dot=abcdef err=(bad value)"))

(test-case "adapted do-printf keeps Racket format validation"
  (check-exn #rx"format string requires 2 arguments, given 1"
             (lambda ()
               (printf-result "~a ~s" (list 'only-one))))
  (check-exn #rx"ill-formed pattern string"
             (lambda ()
               (printf-result "~q" '()))))

(module+ main
  (void))
