#lang racket/base

(require (prefix-in web: "../racket-src/io/format/main-web.rkt")
         rackunit)

(test-case "adapted format main exports format and fprintf"
  (check-equal? (web:format "~a/~s/~x/~c" "x" 'y 255 #\A)
                "x/y/ff/A")
  (check-equal? (web:format "~a/~a" #t #f)
                "#t/#f")
  (check-equal? (web:format "~a" #"bytes")
                "bytes")
  (define out (open-output-string))
  (check-equal? (web:fprintf out "value=~a~n" 42) (void))
  (check-equal? (get-output-string out) "value=42\n"))

(test-case "adapted printf and eprintf use current ports"
  (define original-out (current-output-port))
  (define original-err (current-error-port))
  (define captured-out (open-output-string))
  (define captured-err (open-output-string))
  (dynamic-wind
    (lambda ()
      (current-output-port captured-out)
      (current-error-port captured-err))
    (lambda ()
      (web:printf "out=~a" 'ok)
      (web:eprintf "err=~s" 'bad))
    (lambda ()
      (current-output-port original-out)
      (current-error-port original-err)))
  (check-equal? (get-output-string captured-out) "out=ok")
  (check-equal? (get-output-string captured-err) "err=bad"))

(test-case "adapted format main preserves validation"
  (check-exn #rx"format string requires 2 arguments, given 1"
             (lambda ()
               (web:format "~a ~a" 'one)))
  (check-exn #rx"expected: string\\?"
             (lambda ()
               (web:format 42))))

(module+ main
  (void))
