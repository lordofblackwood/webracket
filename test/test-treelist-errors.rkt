;; Focused no-stdlib generated-output checks for treelist errors.
;;
;; Compile this file with `--no-stdlib`.

(define (catch-contract/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail:contract?
                          (lambda (exn)
                            (exn-message exn))])
           (thunk)
           #f)])
	    (and message
	         (andmap (lambda (needle)
	                   (string-contains? message needle))
	                 needles))))

(define (catch-fail/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail?
                          (lambda (exn)
                            (exn-message exn))])
           (thunk)
           #f)])
    (and message
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(struct treelist-plain ())

(define treelist-plain-given "given: #(struct treelist-plain)")
(define too-large-treelist-index 536870912)

(list
 (list "treelist index range errors are catchable with range details"
       (let ([tl (treelist 1 2)])
         (and
          (catch-contract/contains?
           (lambda () (treelist-ref tl 2))
           "treelist-ref"
           "index is out of range"
           "index: 2"
           "valid range: [0, 1]"
           "treelist length: 2")
          (catch-contract/contains?
           (lambda () (treelist-set tl 2 'x))
           "treelist-set"
           "index is out of range"
           "index: 2"
           "valid range: [0, 1]"
           "treelist length: 2")
          (catch-contract/contains?
           (lambda () (treelist-insert tl 3 'x))
           "treelist-insert"
           "index is out of range"
           "index: 3"
           "valid range: [0, 2]"
           "treelist length: 2")
          (catch-contract/contains?
           (lambda () (treelist-delete tl 2))
           "treelist-delete"
           "index is out of range"
           "index: 2"
           "valid range: [0, 1]"
           "treelist length: 2"))))
 (list "treelist bignum indexes are catchable range errors"
       (let ([tl (treelist 1 2)])
         (and
          (catch-contract/contains?
           (lambda () (treelist-ref tl too-large-treelist-index))
           "treelist-ref"
           "index is out of range"
           "index: 536870912"
           "treelist length: 2")
          (catch-contract/contains?
           (lambda () (treelist-insert tl too-large-treelist-index 'x))
           "treelist-insert"
           "index is out of range"
           "index: 536870912"
           "treelist length: 2")
          (catch-contract/contains?
           (lambda () (treelist-take tl too-large-treelist-index))
           "treelist-take"
           "index is out of range"
           "index: 536870912"
           "treelist length: 2")
          (catch-contract/contains?
           (lambda () (treelist-sublist tl 0 too-large-treelist-index))
           "treelist-sublist"
           "index is out of range"
           "index: 536870912"
           "treelist length: 2"))))
 (list "make-treelist bignum length fails catchably"
       (catch-fail/contains?
        (lambda () (make-treelist too-large-treelist-index 'x))
        "make-treelist"
        "requested length is too large for WebRacket"))
 (list "negative treelist indexes preserve the public contract"
       (let ([tl (treelist 1 2)])
         (and
          (catch-contract/contains?
           (lambda () (treelist-ref tl -1))
           "treelist-ref"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (treelist-set tl -1 'x))
           "treelist-set"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (treelist-insert tl -1 'x))
           "treelist-insert"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (treelist-delete tl -1))
           "treelist-delete"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (treelist-take tl -1))
           "treelist-take"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (treelist-drop tl -1))
           "treelist-drop"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (treelist-take-right tl -1))
           "treelist-take-right"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (treelist-drop-right tl -1))
           "treelist-drop-right"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (treelist-sublist tl -1 1))
           "treelist-sublist"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (treelist-sublist tl 0 -1))
           "treelist-sublist"
           "exact-nonnegative-integer?"
           "given: -1"))))
 (list "treelist index success still works"
       (let ([tl (treelist 1 2)])
         (and (equal? (treelist-ref tl 1) 2)
              (equal? (treelist-ref (treelist-set tl 1 'x) 1) 'x)
              (equal? (treelist-ref (treelist-insert tl 2 'x) 2) 'x)
              (equal? (treelist->list (treelist-delete tl 1)) '(1)))))
	 (list "higher-order treelist procedure errors preserve who"
	       (let ([tl (treelist 1 2)])
         (and
          (catch-contract/contains?
           (lambda () (treelist-sort tl 42))
           "treelist-sort"
           "(procedure-arity-includes/c 2)"
           "given: 42")
          (catch-contract/contains?
           (lambda () (treelist-map tl 42))
           "treelist-map"
           "(procedure-arity-includes/c 1)"
           "given: 42")
          (catch-contract/contains?
           (lambda () (treelist-for-each tl 42))
           "treelist-for-each"
           "(procedure-arity-includes/c 1)"
           "given: 42")
          (catch-contract/contains?
           (lambda () (treelist-filter 42 tl))
           "treelist-filter"
           "(procedure-arity-includes/c 1)"
           "given: 42")
          (catch-contract/contains?
           (lambda () (treelist-find tl 42))
           "treelist-find"
           "(procedure-arity-includes/c 1)"
           "given: 42")
          (catch-contract/contains?
           (lambda () (treelist-member? tl 1 42))
           "treelist-member?"
           "(procedure-arity-includes/c 2)"
           "given: 42")
	          (catch-contract/contains?
	           (lambda () (treelist-index-of tl 1 42))
		   "treelist-index-of"
		   "(procedure-arity-includes/c 2)"
		   "given: 42"))))
	 (list "higher-order treelist procedure positions reject plain structs"
	       (let ([tl (treelist 1 2)])
	         (and
	          (catch-contract/contains?
	           (lambda () (treelist-sort tl (treelist-plain)))
	           "treelist-sort"
	           "(procedure-arity-includes/c 2)"
	           treelist-plain-given)
	          (catch-contract/contains?
	           (lambda () (treelist-map tl (treelist-plain)))
	           "treelist-map"
	           "(procedure-arity-includes/c 1)"
	           treelist-plain-given)
	          (catch-contract/contains?
	           (lambda () (treelist-for-each tl (treelist-plain)))
	           "treelist-for-each"
	           "(procedure-arity-includes/c 1)"
	           treelist-plain-given)
	          (catch-contract/contains?
	           (lambda () (treelist-filter (treelist-plain) tl))
	           "treelist-filter"
	           "(procedure-arity-includes/c 1)"
	           treelist-plain-given)
	          (catch-contract/contains?
	           (lambda () (treelist-find tl (treelist-plain)))
	           "treelist-find"
	           "(procedure-arity-includes/c 1)"
	           treelist-plain-given)
	          (catch-contract/contains?
	           (lambda () (treelist-member? tl 1 (treelist-plain)))
	           "treelist-member?"
	           "(procedure-arity-includes/c 2)"
	           treelist-plain-given)
	          (catch-contract/contains?
	           (lambda () (treelist-index-of tl 1 (treelist-plain)))
	           "treelist-index-of"
	           "(procedure-arity-includes/c 2)"
	           treelist-plain-given)))))
