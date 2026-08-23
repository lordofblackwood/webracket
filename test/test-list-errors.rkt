;; Focused no-stdlib generated-output checks for list index and length errors.
;;
;; Compile this file with `--no-stdlib`.

(define (catch-contract/message thunk)
  (with-handlers ([exn:fail:contract?
                   (lambda (exn)
                     (exn-message exn))])
    (thunk)
    #f))

(define (catch-fail/message thunk)
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (exn-message exn))])
    (thunk)
    #f))

(define (catch-contract/contains? thunk . needles)
  (let ([message (catch-contract/message thunk)])
    (and message
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(define (catch-fail/contains? thunk . needles)
  (let ([message (catch-fail/message thunk)])
    (and message
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(define (catch-contract/prefix+contains? thunk prefix . needles)
  (let ([message (catch-contract/message thunk)])
    (and message
         (<= (string-length prefix) (string-length message))
         (string=? (substring message 0 (string-length prefix)) prefix)
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(struct list-plain ())

(define list-plain-given "given: #(struct list-plain)")

(list
   (list "mutable pair operations reject non-mpairs with who"
         (and
          (catch-contract/contains?
           (lambda () (mcar 42))
           "mcar"
           "mpair?"
           "given: 42")
          (catch-contract/contains?
           (lambda () (mcdr 42))
           "mcdr"
           "mpair?"
           "given: 42")
          (catch-contract/contains?
           (lambda () (set-mcar! 42 'x))
           "set-mcar!"
           "mpair?"
           "given: 42")
          (catch-contract/contains?
           (lambda () (set-mcdr! 42 'x))
           "set-mcdr!"
           "mpair?"
           "given: 42")))
   (list "mutable pair contracts use error-value->string-handler"
         (let ([old (error-value->string-handler)])
           (error-value->string-handler
            (lambda (v _width)
              (cond
                [(number? v) "CUSTOM-NUMBER"]
                [(boolean? v) "CUSTOM-BOOLEAN"]
                [else "CUSTOM-VALUE"])))
           (let ([ok (and
                      (catch-contract/contains?
                       (lambda () (mcar 42))
                       "mcar"
                       "mpair?"
                       "given: CUSTOM-NUMBER")
                      (catch-contract/contains?
                       (lambda () (mcdr #f))
                       "mcdr"
                       "mpair?"
                       "given: CUSTOM-BOOLEAN")
                      (catch-contract/contains?
                       (lambda () (set-mcar! 42 'x))
                       "set-mcar!"
                       "mpair?"
                       "given: CUSTOM-NUMBER")
                      (catch-contract/contains?
                       (lambda () (set-mcdr! #f 'x))
                       "set-mcdr!"
                       "mpair?"
                       "given: CUSTOM-BOOLEAN"))])
             (error-value->string-handler old)
             ok)))
   (list "mutable pair success cases still work"
         (let ([p (mcons 'a 'b)])
           (and (mpair? p)
                (not (mpair? '(a . b)))
                (equal? (mcar p) 'a)
                (equal? (mcdr p) 'b)
                (void? (set-mcar! p 'c))
                (void? (set-mcdr! p 'd))
                (equal? (mcar p) 'c)
                (equal? (mcdr p) 'd))))
   (list "make-list/build-list constructor errors preserve public contracts"
         (and
        (catch-contract/contains?
         (lambda () (make-list #f 'x))
         "make-list"
         "exact-nonnegative-integer?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (make-list -1 'x))
         "make-list"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (build-list #f values))
         "build-list"
         "exact-nonnegative-integer?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (build-list -1 values))
         "build-list"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-fail/contains?
         (lambda () (make-list 536870912 'x))
         "make-list"
         "requested length is too large for WebRacket")
        (catch-fail/contains?
         (lambda () (build-list 536870912 values))
         "build-list"
         "requested length is too large for WebRacket")
          (catch-contract/contains?
           (lambda () (build-list 1 #f))
           "build-list"
           "(exact-nonnegative-integer? . -> . any/c)"
           "given: #f")
        (catch-contract/contains?
         (lambda () (build-list 1 (lambda () 'x)))
         "build-list"
         "(exact-nonnegative-integer? . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (build-list 1 (lambda (x y) x)))
         "build-list"
         "(exact-nonnegative-integer? . -> . any/c)"
         "given:")))
   (list "list higher-order procedure positions reject plain structs"
         (and
          (catch-contract/contains?
           (lambda () (build-list 1 (list-plain)))
           "build-list"
           "(exact-nonnegative-integer? . -> . any/c)"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (memf (list-plain) '(1 2)))
           "memf"
           "(any/c . -> any/c)"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (assf (list-plain) '((1 . a))))
           "assf"
           "(any/c . -> . any/c)"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (findf (list-plain) '(1 2)))
           "findf"
           "(any/c . -> . any/c)"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (map (list-plain) '(1 2)))
           "map"
           "procedure?"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (andmap (list-plain) '(1 2)))
           "andmap"
           "procedure?"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (ormap (list-plain) '(1 2)))
           "ormap"
           "procedure?"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (for-each (list-plain) '(1 2)))
           "for-each"
           "procedure?"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (filter-map (list-plain) '(1 2)))
           "filter-map"
           "procedure?"
           list-plain-given)
          (catch-contract/prefix+contains?
           (lambda () (append-map (list-plain) '(1 2)))
           "map:"
           "procedure?"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (count (list-plain) '(1 2)))
           "count"
           "procedure?"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (foldl (list-plain) 0 '(1 2)))
           "foldl"
           "procedure?"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (foldr (list-plain) 0 '(1 2)))
           "foldr"
           "procedure?"
           list-plain-given)))
   (list "list optional procedure positions reject plain structs"
         (and
          (catch-contract/contains?
           (lambda () (member 1 '(1 2) (list-plain)))
           "member"
           "(procedure-arity-includes/c 2)"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (assoc 1 '((1 . a)) (list-plain)))
           "assoc"
           "(any/c any/c . -> . any/c)"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (index-of '(1 2) 1 (list-plain)))
           "index-of"
           "(-> any/c any/c any/c)"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (indexes-of '(1 2) 1 (list-plain)))
           "indexes-of"
           "(-> any/c any/c any/c)"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (group-by values '(1 2) (list-plain)))
           "group-by"
           "(any/c any/c . -> . any/c)"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (remove 1 '(1 2) (list-plain)))
           "remove"
           "(any/c any/c . -> . any/c)"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (sort '(1 2) (list-plain)))
           "sort"
           "(any/c any/c . -> . any/c)"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (sort/expanded-keywords '(1 2) < 'key (list-plain) 'cache-keys? #f))
           "sort"
           "(any/c . -> . any/c)"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (takef '(1 2) (list-plain)))
           "takef"
           "procedure?"
           list-plain-given)
          (catch-contract/contains?
           (lambda () (list-prefix? '(1) '(1) (list-plain)))
           "list-prefix?"
           "(any/c any/c . -> . any/c)"
           list-plain-given)))
   (list "list search predicate errors use public contracts"
       (and
        (catch-contract/contains?
         (lambda () (memf #f '(1 2)))
         "memf"
         "(any/c . -> any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (assf #f '((1 . a))))
         "assf"
         "(any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (findf #f '(1 2)))
         "findf"
         "(any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (index-where '(1 2) #f))
         "index-where"
         "(-> any/c any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (indexes-where '(1 2) #f))
         "indexes-where"
         "(-> any/c any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (group-by #f '(1 2)))
         "group-by"
         "(-> any/c any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (memf (lambda () #t) '(1 2)))
         "memf"
         "(any/c . -> any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (assf (lambda () #t) '((1 . a))))
         "assf"
         "(any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (findf (lambda () #t) '(1 2)))
         "findf"
         "(any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (index-where '(1 2) (lambda () #t)))
         "index-where"
         "(-> any/c any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (indexes-where '(1 2) (lambda () #t)))
         "indexes-where"
         "(-> any/c any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (group-by (lambda () 'k) '(1 2)))
         "group-by"
         "(-> any/c any/c)"
         "given:")))
 (list "list optional comparator errors use public contracts"
       (and
        (catch-contract/contains?
         (lambda () (member 1 '(1 2) #f))
         "member"
         "(procedure-arity-includes/c 2)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (assoc 1 '((1 . a)) #f))
         "assoc"
         "(any/c any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (index-of '(1 2) 1 #f))
         "index-of"
         "(-> any/c any/c any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (indexes-of '(1 2) 1 #f))
         "indexes-of"
         "(-> any/c any/c any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (group-by (lambda (x) x) '(1 2) #f))
         "group-by"
         "(any/c any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (list-prefix? '(1) '(1) #f))
         "list-prefix?"
         "(any/c any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (take-common-prefix '(1) '(1) #f))
         "take-common-prefix"
         "(any/c any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (drop-common-prefix '(1) '(1) #f))
         "drop-common-prefix"
         "(any/c any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (split-common-prefix '(1) '(1) #f))
         "split-common-prefix"
         "(any/c any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (member 1 '(1 2) (lambda (x) #t)))
         "member"
         "(procedure-arity-includes/c 2)"
         "given:")
        (catch-contract/contains?
         (lambda () (assoc 1 '((1 . a)) (lambda (x) #t)))
         "assoc"
         "(any/c any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (index-of '(1 2) 1 (lambda (x) #t)))
         "index-of"
         "(-> any/c any/c any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (indexes-of '(1 2) 1 (lambda (x) #t)))
         "indexes-of"
         "(-> any/c any/c any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (group-by values '(1 2) (lambda (x) #t)))
         "group-by"
         "(any/c any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (list-prefix? '(1) '(1) (lambda (x) #t)))
         "list-prefix?"
         "(any/c any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (take-common-prefix '(1) '(1) (lambda (x) #t)))
         "take-common-prefix"
         "(any/c any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (drop-common-prefix '(1) '(1) (lambda (x) #t)))
         "drop-common-prefix"
         "(any/c any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (split-common-prefix '(1) '(1) (lambda (x) #t)))
         "split-common-prefix"
         "(any/c any/c . -> . any/c)"
         "given:")))
 (list "list filter/removal/sort procedure errors use public contracts"
       (and
        (catch-contract/contains?
         (lambda () (list-update '(1 2) 0 #f))
         "list-update"
         "(-> any/c any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (argmax #f '(1 2)))
         "argmax"
         "(any/c . -> . real?)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (argmin #f '(1 2)))
         "argmin"
         "(any/c . -> . real?)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (argmax (lambda () 1) '(1)))
         "argmax"
         "(any/c . -> . real?)"
         "given:")
        (catch-contract/contains?
         (lambda () (argmin (lambda () 1) '(1)))
         "argmin"
         "(any/c . -> . real?)"
         "given:")
        (catch-contract/contains?
         (lambda () (argmax (lambda (x) 'a) '(1)))
         "argmax"
         "expected: real?"
         "result: 'a")
        (catch-contract/contains?
         (lambda () (argmin (lambda (x) 'a) '(1)))
         "argmin"
         "expected: real?"
         "result: 'a")
        (catch-contract/contains?
         (lambda () (filter #f '(1 2)))
         "filter"
         "(any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (filter-not #f '(1 2)))
         "filter-not"
         "(any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (partition #f '(1 2)))
         "partition"
         "(any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (remove 1 '(1 2) #f))
         "remove"
         "(any/c any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (remove* '(1) '(1 2) #f))
         "remove*"
         "(any/c any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (remf #f '(1 2)))
         "remf"
         "(-> any/c any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (remf* #f '(1 2)))
         "remf*"
         "(-> any/c any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (sort '(1 2) #f))
         "sort"
         "(any/c any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (filter (lambda () #t) '(1 2)))
         "filter"
         "(any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (filter-not (lambda () #t) '(1 2)))
         "filter-not"
         "(any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (partition (lambda () #t) '(1 2)))
         "partition"
         "(any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (remove 1 '(1 2) (lambda (x) #t)))
         "remove"
         "(any/c any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (remove* '(1) '(1 2) (lambda (x) #t)))
         "remove*"
         "(any/c any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (remf (lambda () #t) '(1 2)))
         "remf"
         "(-> any/c any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (remf* (lambda () #t) '(1 2)))
         "remf*"
         "(-> any/c any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (sort '(1 2) (lambda (x) #t)))
         "sort"
         "(any/c any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (sort/expanded-keywords '(1 2) < 'key (lambda () 1) 'cache-keys? #f))
         "sort"
         "(any/c . -> . any/c)"
         "given:")))
 (list "fixed list predicate errors include argument position"
       (and
        (catch-contract/contains?
         (lambda () (dropf '(1 2) #f))
         "dropf"
         "expected: procedure?"
         "given: #f"
         "argument position: 2nd"
         "'(1 2)")
        (catch-contract/contains?
         (lambda () (dropf-right '(1 2) #f))
         "dropf-right"
         "expected: procedure?"
         "given: #f"
         "argument position: 2nd"
         "'(1 2)")
        (catch-contract/contains?
         (lambda () (splitf-at '(1 2) #f))
         "splitf-at"
         "expected: procedure?"
         "given: #f"
         "argument position: 2nd"
         "'(1 2)")
        (catch-contract/contains?
         (lambda () (splitf-at-right '(1 2) #f))
         "splitf-at-right"
         "expected: procedure?"
         "given: #f"
         "argument position: 2nd"
         "'(1 2)")
        (catch-contract/contains?
         (lambda () (takef '(1 2) #f))
         "takef"
         "expected: procedure?"
         "given: #f"
         "argument position: 2nd"
         "'(1 2)")
        (catch-contract/contains?
         (lambda () (takef-right '(1 2) #f))
         "takef-right"
         "expected: procedure?"
         "given: #f"
         "argument position: 2nd"
         "'(1 2)")
        (catch-contract/prefix+contains?
         (lambda () (append-map #f '(1 2)))
         "map:"
         "expected: procedure?"
         "given: #f")))
 (list "list-ref/list-tail index errors include range context"
       (and
        (catch-contract/contains?
         (lambda () (list-ref '(a b) 2))
         "list-ref"
         "index too large for list"
         "index: 2"
         "in: '(a b)")
        (catch-contract/contains?
         (lambda () (list-ref '(a . b) 1))
         "list-ref"
         "index reaches a non-pair"
         "index: 1"
         "in: '(a . b)")
        (catch-contract/contains?
         (lambda () (list-tail '(a b) 3))
         "list-tail"
         "index too large for list"
         "index: 3"
         "in: '(a b)")
        (catch-contract/contains?
         (lambda () (list-tail '(a . b) 2))
         "list-tail"
         "index reaches a non-pair"
         "index: 2"
         "in: '(a . b)")
        (catch-contract/contains?
         (lambda () (list-tail 'bad 1))
         "list-tail"
         "index reaches a non-pair"
         "index: 1"
         "in: 'bad")
        (catch-contract/contains?
         (lambda () (list-ref '(a b) 536870912))
         "list-ref"
         "index too large for list"
         "in: '(a b)")
        (catch-contract/contains?
         (lambda () (list-tail 'bad 536870912))
         "list-tail"
         "index reaches a non-pair"
         "in: 'bad")))
 (list "list index errors use error-value->string-handler for rendered values"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(list? v) "CUSTOM-LIST"]
              [(number? v) "CUSTOM-NUMBER"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (list-ref '(a b) 2))
                     "list-ref"
                     "index too large for list"
                     "index: CUSTOM-NUMBER"
                     "in: CUSTOM-LIST")
                    (catch-contract/contains?
                     (lambda () (list-tail 'bad 1))
                     "list-tail"
                     "index reaches a non-pair"
                     "index: CUSTOM-NUMBER"
                     "in: CUSTOM-VALUE"))])
           (error-value->string-handler old)
           ok)))
 (list "list-set/list-update index errors include range context"
       (and
        (catch-contract/contains?
         (lambda () (list-set '(a b) 2 'x))
         "list-set"
         "index too large for list"
         "index: 2"
         "in: '(a b)")
        (catch-contract/contains?
         (lambda () (list-update '(a b) 2 values))
         "list-update"
         "index too large for list"
         "index: 2"
         "in: '(a b)")
        (catch-contract/contains?
         (lambda () (list-set '(a b) 536870912 'x))
         "list-set"
         "index too large for list"
         "in: '(a b)")
        (catch-contract/contains?
         (lambda () (list-update '(a b) 536870912 values))
         "list-update"
         "index too large for list"
         "in: '(a b)")))
 (list "take/drop length errors report required list size"
       (and
        (catch-contract/contains?
         (lambda () (take '(a b) 3))
         "take"
         "a list with at least 3 elements"
         "given: '(a b)")
        (catch-contract/contains?
         (lambda () (drop '(a b) 3))
         "drop"
         "a list with at least 3 elements"
         "given: '(a b)")
        (catch-contract/contains?
         (lambda () (take-right '(a b) 3))
         "take-right"
         "a list with at least 3 elements"
         "given: '(a b)")
        (catch-contract/contains?
         (lambda () (drop-right '(a b) 3))
         "drop-right"
         "a list with at least 3 elements"
         "given: '(a b)")))
 (list "take/drop length errors use error-value->string-handler for given lists"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(list? v) "CUSTOM-LIST"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (take '(a b) 3))
                     "take"
                     "a list with at least 3 elements"
                     "given: CUSTOM-LIST")
                    (catch-contract/contains?
                     (lambda () (drop 'bad 1))
                     "drop"
                     "a (possibly improper) list with at least 1 pairs"
                     "given: CUSTOM-VALUE"))])
           (error-value->string-handler old)
           ok)))
 (list "take/drop improper-list errors report required pair count"
       (and
        (catch-contract/contains?
         (lambda () (take '(a . b) 2))
         "take"
         "a (possibly improper) list with at least 2 pairs"
         "given: '(a . b)")
        (catch-contract/contains?
         (lambda () (drop '(a . b) 2))
         "drop"
         "a (possibly improper) list with at least 2 pairs"
         "given: '(a . b)")
        (catch-contract/contains?
         (lambda () (take-right 'bad 1))
         "take-right"
         "a (possibly improper) list with at least 1 pairs"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (drop-right 'bad 1))
         "drop-right"
         "a (possibly improper) list with at least 1 pairs"
         "given: 'bad")))
 (list "list index and slice success cases still work"
       (and (equal? (list-ref '(a b c) 2) 'c)
            (equal? (list-tail '(a b c) 2) '(c))
            (equal? (list-set '(a b c) 1 'x) '(a x c))
            (equal? (list-update '(a b c) 1 symbol->string) '(a "b" c))
            (equal? (take '(a b c) 2) '(a b))
            (equal? (drop '(a b c) 2) '(c))
            (equal? (take-right '(a b c) 2) '(b c))
            (equal? (drop-right '(a b c) 2) '(a)))))
