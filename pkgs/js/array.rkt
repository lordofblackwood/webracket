#lang racket/base

(require (prefix-in unsafe: webracket/unsafe/array)
         (only-in webracket/unsafe/standard
                  [js-constructible? unsafe:js-constructible?]))

(provide (struct-out array)
         array->bytes
         array->list
         array->vector
         array-at
         array-concat
         array-copy-within!
         array-fill!
         array-flat
         array-from
         array-from-async
         array-items->vector
         array-join
         array-length
         array-of
         array-pop
         array-push!
         array-push
         array-ref
         array-reverse!
         array-sequence->vector
         array-set-length!
         array-shift
         array-slice
         array-sort!
         array-splice!
         array-stringish->string
         array-to-locale-string
         array-to-reversed
         array-to-sorted
         array-to-spliced
         array-to-string
         array-unshift!
         array-unwrap
         array-with
         array-wrap
         list->array
         sequence->array
         vector->array)

;; This is the canonical module version of the old `include-lib array` safe
;; wrapper. Raw bindings remain in `webracket/unsafe/array`.

(struct array (raw) #:transparent)

;; array-stringish->string : symbol? (or/c string? symbol?) -> string?
;;   Normalize a string-like array argument.
(define (array-stringish->string who v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [else
     (raise-argument-error who "(or/c string? symbol?)" v)]))

;; array-sequence->vector : symbol? (or/c list? vector?) -> vector?
;;   Normalize a list or vector to a vector for array construction.
(define (array-sequence->vector who value)
  (cond
    [(vector? value) (list->vector (map array-unwrap (vector->list value)))]
    [(list? value) (list->vector (map array-unwrap value))]
    [else
     (raise-argument-error who "(or/c list? vector?)" value)]))

;; array-wrap : any/c -> array?
;;   Wrap a browser JavaScript Array value.
(define (array-wrap value)
  (array value))

;; array-wrap-result : symbol? string? any/c -> array?
;;   Wrap a JavaScript Array result after checking the host boundary.
(define (array-wrap-result who method-name value)
  (when (zero? (unsafe:js-array-is-array value))
    (raise-arguments-error who
                           (string-append "Array."
                                          method-name
                                          " result must be an Array")))
  (array value))

;; array-unwrap : any/c -> any/c
;;   Unwrap a browser JavaScript Array value when available.
(define (array-unwrap value)
  (if (array? value)
      (array-raw value)
      value))

;; array-items->vector : (listof any/c) -> vector?
;;   Pack rest arguments into the vector shape expected by Array methods.
(define (array-items->vector items)
  (list->vector (map array-unwrap items)))

;; check-array-global-method : symbol? string? -> external/raw
;;   Return the Array constructor after checking a required static method.
(define (check-array-global-method who method-name)
  (define array-ctor (unsafe:js-var "Array"))
  (unless (unsafe:js-constructible? array-ctor)
    (raise-arguments-error who "Array is not available"))
  (define method (unsafe:js-ref/extern array-ctor method-name))
  (unless (and (not (unsafe:js-nullish? method))
               (string=? (unsafe:js-typeof method) "function"))
    (raise-arguments-error who
                           (string-append "Array."
                                          method-name
                                          " is not available")))
  array-ctor)

;; array-from : any/c [(or/c procedure? external?) #f] [any/c #f] -> array?
;;   Build an array from an iterable or array-like value.
;;   When map-function is supplied, it is called with each element and its
;;   index; this-arg becomes the JavaScript this value during those calls.
(define (array-from source [map-function #f] [this-arg #f])
  (define source* (array-unwrap source))
  (define array-ctor (check-array-global-method 'array-from "from"))
  (cond
    [(eq? map-function #f)
     (array-wrap-result 'array-from
                        "from"
                        (unsafe:js-send/extern array-ctor "from" (vector source*)))]
    [(eq? this-arg #f)
     (array-wrap-result 'array-from
                        "from"
                        (unsafe:js-send/extern array-ctor "from" (vector source* map-function)))]
    [else
     (array-wrap-result
      'array-from
      "from"
      (unsafe:js-send/extern array-ctor "from"
                             (vector source* map-function (array-unwrap this-arg))))]))

;; array-from-async : any/c [(or/c procedure? external?) #f] [any/c #f] -> array?
;;   Build an array from an async iterable or array-like value.
;;   When map-function is supplied, it is called with each element and its
;;   index; this-arg becomes the JavaScript this value during those calls.
(define (array-from-async source [map-function #f] [this-arg #f])
  (define source* (array-unwrap source))
  (define array-ctor (check-array-global-method 'array-from-async "fromAsync"))
  (cond
    [(eq? map-function #f)
     (array-wrap (unsafe:js-send/extern array-ctor "fromAsync" (vector source*)))]
    [(eq? this-arg #f)
     (array-wrap (unsafe:js-send/extern array-ctor "fromAsync" (vector source* map-function)))]
    [else
     (array-wrap (unsafe:js-send/extern array-ctor "fromAsync"
                                        (vector source* map-function (array-unwrap this-arg))))]))

;; array-of : any/c ... -> array?
;;   Build a JavaScript array from the given items.
(define (array-of . items)
  (array-wrap-result 'array-of
                     "of"
                     (unsafe:js-array-of (array-items->vector items))))

;; array-length : any/c -> exact-nonnegative-integer?
;;   Read the length of a JavaScript array.
(define (array-length arr)
  (unsafe:js-array-length (array-unwrap arr)))

;; array-set-length! : any/c exact-nonnegative-integer? -> void?
;;   Set the length of a JavaScript array.
(define (array-set-length! arr len)
  (unsafe:js-set-array-length! (array-unwrap arr) len)
  (void))

;; array-ref : any/c exact-integer? -> any/c
;;   Read an array element.
(define (array-ref arr index)
  (unsafe:js-array-ref (array-unwrap arr) index))

;; array-at : any/c exact-integer? -> any/c
;;   Read an array element using Array.prototype.at semantics.
(define (array-at arr index)
  (unsafe:js-array-at (array-unwrap arr) index))

;; array->vector : any/c -> vector?
;;   Convert a JavaScript array into a Racket vector.
(define (array->vector arr)
  (define arr* (array-unwrap arr))
  (cond
    [(vector? arr*) arr*]
    [(list? arr*) (list->vector arr*)]
    [else
     (unsafe:js-array->vector arr*)]))

;; array->list : any/c -> list?
;;   Convert a JavaScript array into a Racket list.
(define (array->list arr)
  (vector->list (array->vector arr)))

;; array->bytes : any/c -> bytes?
;;   Convert a JavaScript byte array or typed array into Racket bytes.
(define (array->bytes arr)
  (unsafe:js-array->bytes (array-unwrap arr)))

;; vector->array : vector? -> array?
;;   Convert a Racket vector into a JavaScript array.
(define (vector->array vec)
  (array-wrap-result 'vector->array
                     "of"
                     (unsafe:js-array-of
                      (array-sequence->vector 'vector->array vec))))

;; list->array : list? -> array?
;;   Convert a Racket list into a JavaScript array.
(define (list->array xs)
  (array-wrap-result 'list->array
                     "of"
                     (unsafe:js-array-of
                      (array-sequence->vector 'list->array xs))))

;; sequence->array : (or/c list? vector?) -> array?
;;   Convert a Racket list or vector into a JavaScript array.
(define (sequence->array items)
  (array-wrap-result 'sequence->array
                     "of"
                     (unsafe:js-array-of
                      (array-sequence->vector 'sequence->array items))))

;; array-join : any/c [any/c #f] -> string?
;;   Join the array elements into a string.
(define (array-join arr [separator #f])
  (if (eq? separator #f)
      (unsafe:js-array-join (array-unwrap arr) (void))
      (unsafe:js-array-join (array-unwrap arr)
                            (array-stringish->string 'array-join separator))))

;; array-slice : any/c [any/c #f] [any/c #f] -> array?
;;   Return a sliced copy of the array.
;;   start and end are forwarded to JavaScript's slice method unchanged.
(define (array-slice arr [start #f] [end #f])
  (define arr* (array-unwrap arr))
  (cond
    [(and (eq? start #f) (eq? end #f))
     (array-wrap-result 'array-slice
                        "slice"
                        (unsafe:js-array-slice arr* (void) (void)))]
    [(eq? end #f)
     (array-wrap-result 'array-slice
                        "slice"
                        (unsafe:js-array-slice arr* start (void)))]
    [else
     (array-wrap-result 'array-slice
                        "slice"
                        (unsafe:js-array-slice arr* start end))]))

;; array-concat : any/c any/c ... -> array?
;;   Concatenate arrays and values into a new array.
(define (array-concat arr . items)
  (array-wrap-result 'array-concat
                     "concat"
                     (unsafe:js-array-concat (array-unwrap arr)
                                             (array-items->vector items))))

;; array-copy-within! : any/c exact-integer? exact-integer? [any/c #f] -> array?
;;   Copy a slice of the array within the array itself.
;;   The optional end index is forwarded to JavaScript unchanged.
(define (array-copy-within! arr target start [end #f])
  (define arr* (array-unwrap arr))
  (if (eq? end #f)
      (array-wrap-result 'array-copy-within!
                         "copyWithin"
                         (unsafe:js-array-copy-within arr* target start (void)))
      (array-wrap-result 'array-copy-within!
                         "copyWithin"
                         (unsafe:js-array-copy-within arr* target start end))))

;; array-fill! : any/c any/c [any/c #f] [any/c #f] -> array?
;;   Fill a range of the array in place.
;;   start and end are forwarded to JavaScript's fill method unchanged.
(define (array-fill! arr value [start #f] [end #f])
  (define arr* (array-unwrap arr))
  (cond
    [(and (eq? start #f) (eq? end #f))
     (array-wrap-result 'array-fill!
                        "fill"
                        (unsafe:js-array-fill arr* (array-unwrap value) (void) (void)))]
    [(eq? end #f)
     (array-wrap-result 'array-fill!
                        "fill"
                        (unsafe:js-array-fill arr* (array-unwrap value) start (void)))]
    [else
     (array-wrap-result 'array-fill!
                        "fill"
                        (unsafe:js-array-fill arr* (array-unwrap value) start end))]))

;; array-push! : any/c any/c ... -> exact-nonnegative-integer?
;;   Append one or more values to the end of the array.
(define (array-push! arr . items)
  (unsafe:js-array-push (array-unwrap arr) (array-items->vector items)))

;; array-push : any/c any/c ... -> exact-nonnegative-integer?
;;   Compatibility alias for `array-push!`.
(define array-push array-push!)

;; array-pop : any/c -> any/c
;;   Remove and return the last array element.
(define (array-pop arr)
  (unsafe:js-array-pop (array-unwrap arr)))

;; array-reverse! : any/c -> array?
;;   Reverse the array in place.
(define (array-reverse! arr)
  (array-wrap-result 'array-reverse!
                     "reverse"
                     (unsafe:js-array-reverse (array-unwrap arr))))

;; array-shift : any/c -> any/c
;;   Remove and return the first array element.
(define (array-shift arr)
  (unsafe:js-array-shift (array-unwrap arr)))

;; array-sort! : any/c [(or/c procedure? external?) #f] -> array?
;;   Sort the array in place.
;;   When compare-function is supplied, it is called with two elements and
;;   should return a negative, zero, or positive value.
(define (array-sort! arr [compare-function #f])
  (define arr* (array-unwrap arr))
  (if (eq? compare-function #f)
      (array-wrap-result 'array-sort!
                         "sort"
                         (unsafe:js-array-sort arr* (unsafe:js-undefined)))
      (array-wrap-result 'array-sort!
                         "sort"
                         (unsafe:js-array-sort arr* compare-function))))

;; array-splice! : any/c exact-integer? exact-integer? any/c ... -> array?
;;   Replace array elements in place and return the removed items.
(define (array-splice! arr start delete-count . items)
  (array-wrap-result
   'array-splice!
   "splice"
   (unsafe:js-array-splice (array-unwrap arr)
                           (array-items->vector (cons start (cons delete-count items))))))

;; array-to-locale-string : any/c [any/c #f] -> string?
;;   Convert the array to a localized string.
(define (array-to-locale-string arr [locales-options #f])
  (if (eq? locales-options #f)
      (unsafe:js-array-to-locale-string (array-unwrap arr) (void))
      (unsafe:js-array-to-locale-string (array-unwrap arr) locales-options)))

;; array-to-string : any/c -> string?
;;   Convert the array to a string.
(define (array-to-string arr)
  (unsafe:js-array-to-string (array-unwrap arr)))

;; array-unshift! : any/c any/c ... -> exact-nonnegative-integer?
;;   Prepend one or more values to the array.
(define (array-unshift! arr . items)
  (unsafe:js-array-unshift (array-unwrap arr) (array-items->vector items)))

;; array-flat : any/c [any/c #f] -> array?
;;   Flatten one level or an explicit depth.
;;   depth is forwarded to JavaScript's flat method unchanged.
(define (array-flat arr [depth #f])
  (define arr* (array-unwrap arr))
  (if (eq? depth #f)
      (array-wrap-result 'array-flat
                         "flat"
                         (unsafe:js-array-flat arr* (void)))
      (array-wrap-result 'array-flat
                         "flat"
                         (unsafe:js-array-flat arr* depth))))

;; array-to-reversed : any/c -> array?
;;   Return a reversed copy of the array.
(define (array-to-reversed arr)
  (array-wrap-result 'array-to-reversed
                     "toReversed"
                     (unsafe:js-array-to-reversed (array-unwrap arr))))

;; array-to-sorted : any/c [(or/c procedure? external?) #f] -> array?
;;   Return a sorted copy of the array.
;;   When compare-function is supplied, it is called with two elements and
;;   should return a negative, zero, or positive value.
(define (array-to-sorted arr [compare-function #f])
  (define arr* (array-unwrap arr))
  (if (eq? compare-function #f)
      (array-wrap-result 'array-to-sorted
                         "toSorted"
                         (unsafe:js-array-to-sorted arr* (unsafe:js-undefined)))
      (array-wrap-result 'array-to-sorted
                         "toSorted"
                         (unsafe:js-array-to-sorted arr* compare-function))))

;; array-to-spliced : any/c exact-integer? exact-integer? any/c ... -> array?
;;   Return the result of splicing without mutating the original array.
;;   start and delete-count are array positions.
(define (array-to-spliced arr start delete-count . items)
  (array-wrap-result
   'array-to-spliced
   "toSpliced"
   (unsafe:js-array-to-spliced
    (array-unwrap arr)
    (array-items->vector (cons start (cons delete-count items))))))

;; array-with : any/c exact-integer? any/c -> array?
;;   Return a copy of the array with one value replaced.
;;   index is an array position.
(define (array-with arr index value)
  (array-wrap-result 'array-with
                     "with"
                     (unsafe:js-array-with (array-unwrap arr) index (array-unwrap value))))
