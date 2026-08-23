#lang racket/base

(require rackunit
         "../tools/check-number-tower-cs.rkt")

(test-case "number tower oracle rejects non-CS VM metadata"
  (check-exn
   #rx"Racket CS"
   (lambda ()
     (validate-number-tower-cs-info!
      (number-tower-cs-info "tmp/not-cs-racket" "0.0" 'racketcgc)))))

(module+ main
  (void))
