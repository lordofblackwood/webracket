#lang racket/base

(require rackunit
         "module-variable.rkt")

(test-case "module variable starts uninitialized"
  (define cell (module-variable-make 'x))
  (check-true (module-variable? cell))
  (check-equal? (module-variable-name cell) 'x)
  (check-false (module-variable-initialized? cell))
  (check-false (module-variable-constance cell))
  (check-exn #rx"module variable is not initialized"
             (lambda () (module-variable-ref cell))))

(test-case "define initializes value and constance"
  (define cell (module-variable-make 'x))
  (check-equal? (module-variable-define! cell 12 'constant) (void))
  (check-true (module-variable-initialized? cell))
  (check-equal? (module-variable-ref cell) 12)
  (check-equal? (module-variable-ref/no-check cell) 12)
  (check-equal? (module-variable-constance cell) 'constant))

(test-case "set mutates and initializes cell"
  (define cell (module-variable-make 'x))
  (check-equal? (module-variable-set! cell 1) (void))
  (check-true (module-variable-initialized? cell))
  (check-equal? (module-variable-ref cell) 1)
  (check-equal? (module-variable-set! cell 2) (void))
  (check-equal? (module-variable-ref cell) 2))

(test-case "set/check rejects uninitialized cell"
  (define cell (module-variable-make 'x))
  (check-exn #rx"module variable is not initialized"
             (lambda () (module-variable-set!/check-undefined! cell 1)))
  (module-variable-define! cell 0 #f)
  (check-equal? (module-variable-set!/check-undefined! cell 1) (void))
  (check-equal? (module-variable-ref cell) 1))

(test-case "consistent batch definition"
  (define x (module-variable-make 'x))
  (define y (module-variable-make 'y))
  (check-equal? (module-variables-define-consistent! (vector x y) (vector 1 2)) (void))
  (check-equal? (module-variable-ref x) 1)
  (check-equal? (module-variable-ref y) 2)
  (check-equal? (module-variable-constance x) 'consistent)
  (check-equal? (module-variable-constance y) 'consistent)
  (check-exn #rx"same length"
             (lambda ()
               (module-variables-define-consistent! (vector x y) (vector 1)))))

(test-case "module variable reference records instance and cell"
  (define cell (module-variable-make 'x))
  (define ref (module-variable-reference 'instance cell))
  (check-true (module-variable-reference? ref))
  (check-equal? (module-variable-reference-instance ref) 'instance)
  (check-eq? (module-variable-reference-variable ref) cell)
  (check-exn #rx"module-variable-reference"
             (lambda ()
               (module-variable-reference 'instance 'not-a-cell))))

(test-case "module prompt helper is explicitly unsupported"
  (check-exn #rx"module prompts are not supported"
             (lambda ()
               (module-call-with-prompt (lambda () 1)))))
