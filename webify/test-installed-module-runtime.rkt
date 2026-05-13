#lang racket/base

(require rackunit
         "module-runtime-smoke.rkt")

(define installed-runtime-smokes
  (list
   (installed-runtime-smoke
    'racket/bool
    "installed racket/bool graph reaches WebRacket runtime smoke"
    '((module use-bool racket/base
        (require racket/bool)
        (provide y)
        (define y (boolean=? #t #t))))
    '((use-bool y))
    #rx"(?m:^(#t|true)$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/fixnum
    "installed racket/fixnum graph reaches WebRacket runtime smoke"
    '((module use-fixnum racket/base
        (require racket/fixnum)
        (provide y)
        (define y (fx+ 1 2))))
    '((use-fixnum y))
    #rx"(?m:^3$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/list
    "installed racket/list graph reaches WebRacket runtime smoke"
    '((module use-list racket/base
        (require racket/list)
        (provide y)
        (define y (first '(#t #f)))))
    '((use-list y))
    #rx"(?m:^(#t|true)$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/list
    "installed racket/list rest reaches WebRacket runtime smoke"
    '((module use-list-rest racket/base
        (require racket/list)
        (provide y)
        (define y (first (rest '(#t #f))))))
    '((use-list-rest y))
    #rx"(?m:^(#f|false)$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/list
    "installed racket/list add-between reaches WebRacket runtime smoke"
    '((module use-list-add-between racket/base
        (require racket/list)
        (provide y)
        (define y (car (cdr (add-between '("a" "b") ","))))))
    '((use-list-add-between y))
    #rx"(?m:^,$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/list
    "installed racket/list range and reverse reach WebRacket runtime smoke"
    '((module use-list-range-reverse racket/base
        (require racket/list)
        (provide y)
        (define y (first (reverse (range 2 7 2))))))
    '((use-list-range-reverse y))
    #rx"(?m:^6$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/string
    "installed racket/string graph reaches WebRacket runtime smoke"
    '((module use-string racket/base
        (require racket/string)
        (provide y)
        (define y (string-join '("a" "b") ","))))
    '((use-string y))
    #rx"(?m:^a,b$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/string
    "installed racket/string prefix reaches WebRacket runtime smoke"
    '((module use-string-prefix racket/base
        (require racket/string)
        (provide y)
        (define y (string-prefix? "abc" "ab"))))
    '((use-string-prefix y))
    #rx"(?m:^(#t|true)$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/list+racket/string
    "installed racket/list and racket/string compose in WebRacket runtime smoke"
    '((module use-list-and-string racket/base
        (require racket/list racket/string)
        (provide y)
        (define y
          (string-join
           (map number->string (take '(1 2 3 4) 3))
           ","))))
    '((use-list-and-string y))
    #rx"(?m:^1,2,3$)"
    '()
    #f)
   (installed-runtime-smoke
    'local-module
    "local multi-export module observes multiple values"
    '((module local-multi-export racket/base
        (provide a b)
        (define a 20)
        (define b 22)))
    '((local-multi-export a)
      (local-multi-export b))
    #rx"(?s:20.*22)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/function
    "installed racket/function compose reaches WebRacket runtime smoke"
    '((module use-function-compose racket/base
        (require racket/function)
        (provide y)
        (define y ((compose add1 add1) 40))))
    '((use-function-compose y))
    #rx"(?m:^42$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/function
    "installed racket/function identity reaches WebRacket runtime smoke"
    '((module use-function-identity racket/base
        (require racket/function)
        (provide y)
        (define y (identity 42))))
    '((use-function-identity y))
    #rx"(?m:^42$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/function
    "installed racket/function compose1 reaches WebRacket runtime smoke"
    '((module use-function-compose1 racket/base
        (require racket/function)
        (provide y)
        (define y ((compose1 add1 add1) 40))))
    '((use-function-compose1 y))
    #rx"(?m:^42$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/function
    "installed racket/function negate reaches WebRacket runtime smoke"
    '((module use-function-negate racket/base
        (require racket/function)
        (provide y)
        (define y ((negate symbol?) 42))))
    '((use-function-negate y))
    #rx"(?m:^(#t|true)$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/function
    "installed racket/function const reaches WebRacket runtime smoke"
    '((module use-function-const racket/base
        (require racket/function)
        (provide y)
        (define y ((const 42) 'ignored))))
    '((use-function-const y))
    #rx"(?m:^42$)"
    '()
    #f)))

(when (file-exists? racket92-bin)
  (for ([smoke (in-list installed-runtime-smokes)])
    (test-case (format "~a: ~a"
                       (installed-runtime-smoke-category smoke)
                       (installed-runtime-smoke-name smoke))
      (run-installed-runtime-smoke smoke))))

(module+ main
  (void))
