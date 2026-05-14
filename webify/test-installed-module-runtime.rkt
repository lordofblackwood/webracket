#lang racket/base

(provide installed-runtime-smokes)

(require rackunit
         racket/runtime-path
         racket/system
         "module-runtime-smoke.rkt")

(define-runtime-path probe-installed-runtime-smoke-path
  "probe-installed-runtime-smoke.rkt")

;; getenv/default : string? string? -> string?
;;   Read a test-control environment variable with a safe default.
(define (getenv/default name default)
  (or (getenv name) default))

;; run-installed-runtime-smoke/bounded : exact-nonnegative-integer? -> exact-integer?
;;   Run one installed smoke through the bounded probe wrapper.
(define (run-installed-runtime-smoke/bounded index)
  (system*/exit-code
   (find-executable-path "racket")
   (path->string probe-installed-runtime-smoke-path)
   "--index" (number->string index)
   "--timeout" (getenv/default "WEBIFY_INSTALLED_TEST_TIMEOUT_SECONDS" "120")
   "--memory-mb" (getenv/default "WEBIFY_INSTALLED_TEST_MEMORY_MB" "1024")))

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
    'racket/vector
    "installed racket/vector graph reaches WebRacket runtime smoke"
    '((module use-vector racket/base
        (require racket/vector)
        (provide y)
        (define y (vector-member 2 (vector 1 2 3)))))
    '((use-vector y))
    #rx"(?m:^1$)"
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
    'racket/vector+racket/list
    "installed racket/vector and racket/list graph reaches shared provider smoke"
    '((module use-vector-and-list racket/base
        (require racket/list racket/vector)
        (provide y)
        (define y (+ (vector-member 2 (vector 1 2 3))
                     (first '(40 41 42))))))
    '((use-vector-and-list y))
    #rx"(?m:^41$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/set
    "installed racket/set can be required without forcing set operations"
    '((module use-set-require-only racket/base
        (require racket/set)
        (provide y)
        (define y 42)))
    '((use-set-require-only y))
    #rx"(?m:^42$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/set
    "installed racket/set predicate reaches WebRacket runtime smoke"
    '((module use-set-predicate racket/base
        (require racket/set)
        (provide y)
        (define y (set? 42))))
    '((use-set-predicate y))
    #rx"(?m:^false$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/set
    "installed racket/set count reaches WebRacket runtime smoke"
    '((module use-set racket/base
        (require racket/set)
        (provide y)
        (define y (set-count (set 1 2 2)))))
    '((use-set y))
    #rx"(?m:^2$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/set
    "installed racket/set member reaches WebRacket runtime smoke"
    '((module use-set-member racket/base
        (require racket/set)
        (provide y)
        (define y (set-member? (set 'a 'b) 'b))))
    '((use-set-member y))
    #rx"(?m:^true$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/set
    "installed racket/set add reaches WebRacket runtime smoke"
    '((module use-set-add racket/base
        (require racket/set)
        (provide y)
        (define y (set-count (set-add (set 1 2) 3)))))
    '((use-set-add y))
    #rx"(?m:^3$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/set
    "installed racket/set remove reaches WebRacket runtime smoke"
    '((module use-set-remove racket/base
        (require racket/set)
        (provide y)
        (define y (set-member? (set-remove (set 'a 'b) 'a) 'a))))
    '((use-set-remove y))
    #rx"(?m:^false$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/set
    "installed racket/set union reaches WebRacket runtime smoke"
    '((module use-set-union racket/base
        (require racket/set)
        (provide y)
        (define y (set-count (set-union (set 1 2) (set 2 3))))))
    '((use-set-union y))
    #rx"(?m:^3$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/set
    "installed racket/set to-list reaches WebRacket runtime smoke"
    '((module use-set-to-list racket/base
        (require racket/set)
        (provide y)
        (define y (length (set->list (set 1 2))))))
    '((use-set-to-list y))
    #rx"(?m:^2$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/set
    "installed racket/set intersect reaches WebRacket runtime smoke"
    '((module use-set-intersect racket/base
        (require racket/set)
        (provide y)
        (define y (set-count (set-intersect (set 1 2) (set 2 3))))))
    '((use-set-intersect y))
    #rx"(?m:^1$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/set
    "installed racket/set subtract reaches WebRacket runtime smoke"
    '((module use-set-subtract racket/base
        (require racket/set)
        (provide y)
        (define y (set-member? (set-subtract (set 1 2) (set 2)) 2))))
    '((use-set-subtract y))
    #rx"(?m:^false$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/set
    "installed racket/set symmetric difference reaches WebRacket runtime smoke"
    '((module use-set-symmetric-difference racket/base
        (require racket/set)
        (provide y)
        (define y (set-count (set-symmetric-difference (set 1 2) (set 2 3))))))
    '((use-set-symmetric-difference y))
    #rx"(?m:^2$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/set
    "installed racket/set map reaches WebRacket runtime smoke"
    '((module use-set-map racket/base
        (require racket/set)
        (provide y)
        (define y (length (set-map (set 1 2) add1)))))
    '((use-set-map y))
    #rx"(?m:^2$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/stream
    "installed racket/stream first reaches WebRacket runtime smoke"
    '((module use-stream-first racket/base
        (require racket/stream)
        (provide y)
        (define y (stream-first (stream 42)))))
    '((use-stream-first y))
    #rx"(?m:^42$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/stream
    "installed racket/stream rest reaches WebRacket runtime smoke"
    '((module use-stream-rest racket/base
        (require racket/stream)
        (provide y)
        (define y (stream-first (stream-rest (stream 40 42))))))
    '((use-stream-rest y))
    #rx"(?m:^42$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/hash
    "installed immutable hash constructor and update reach WebRacket runtime smoke"
    '((module use-hash-basic racket/base
        (provide y)
        (define y
          (hash-ref (hash-set (make-immutable-hash '((a . 1))) 'b 41)
                    'b))))
    '((use-hash-basic y))
    #rx"(?m:^41$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/hash
    "installed immutable hash iteration reaches WebRacket runtime smoke"
    '((module use-hash-iterate racket/base
        (provide y)
        (define y
          (let ([h (make-immutable-hash '((a . 1) (b . 2)))])
            (+ (length (hash-keys h))
               (length (hash-values h))
               (length (hash->list h))
               (let ([sum 0])
                 (hash-for-each h (lambda (k v) (set! sum (+ sum v))))
                 sum))))))
    '((use-hash-iterate y))
    #rx"(?m:^9$)"
    '()
    #f)
   (installed-runtime-smoke
    'racket/list+racket/string+racket/set
    "installed list string and set compose in WebRacket runtime smoke"
    '((module use-combined-list-string-set racket/base
        (require racket/list racket/string racket/set)
        (provide y)
        (define y
          (+ (first '(37 38))
             (string-length (string-join '("ab" "c") ""))
             (set-count (set 'x 'y 'y))))))
    '((use-combined-list-string-set y))
    #rx"(?m:^42$)"
    '()
    #f)
   (installed-runtime-smoke
    'local-source-installed-libraries
    "installed list string and set compose across local source modules"
    '((module set-provider racket/base
        (require racket/set)
        (provide selected)
        (define selected (set-add (set 'alpha) 'beta)))
      (module string-provider racket/base
        (require racket/list racket/string)
        (provide joined)
        (define joined (string-join (map symbol->string '(alpha beta)) ",")))
      (module use-multi-module-list-string-set racket/base
        (require racket/set 'set-provider 'string-provider)
        (provide y)
        (define y (+ (set-count selected) (string-length joined)))))
    '((use-multi-module-list-string-set y))
    #rx"(?m:^12$)"
    '()
    #f)
   (installed-runtime-smoke
    'local-source-transitive
    "installed source modules share a quoted local provider"
    '((module base-values racket/base
        (require racket/list)
        (provide picked)
        (define picked (first '(40 41 42))))
      (module left-values racket/base
        (require 'base-values)
        (provide left)
        (define left (+ picked 1)))
      (module right-values racket/base
        (require 'base-values)
        (provide right)
        (define right (+ picked 2)))
      (module use-transitive racket/base
        (require 'left-values 'right-values)
        (provide y)
        (define y (+ left right))))
    '((use-transitive y))
    #rx"(?m:^83$)"
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

(module+ test
  (when (file-exists? racket92-bin)
    (for ([smoke (in-list installed-runtime-smokes)]
          [index (in-naturals)])
      (test-case (format "~a: ~a"
                         (installed-runtime-smoke-category smoke)
                         (installed-runtime-smoke-name smoke))
        (check-equal? (run-installed-runtime-smoke/bounded index) 0)))))

(module+ main
  (void))
