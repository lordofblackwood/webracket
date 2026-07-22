#lang racket/base

(require (only-in webracket/primitives
                  external?
                  procedure->external)
         (only-in webracket/unsafe/array
                  js-undefined
                  js-nullish?
                  js-ref/extern
                  js-ref
                  js-send
                  js-send/extern
                  js-send/extern/nullish
                  js-send/value
                  js-typeof
                  js-object
                  js-array/extern
                  js-Iterator
                  js-Object))

(provide (except-out (struct-out iterator) iterator?)
         (struct-out iterator-zip-options)
         (rename-out [iterator/surface? iterator?])
         Iterator
         iterable?
         iterator->vector
         iterator-call/callback
         iterator-collect-list
         iterator-concat
         iterator-dispose!
         iterator-drop
         iterator-entry-key
         iterator-entry-value
         iterator-every
         iterator-filter
         iterator-find
         iterator-flat-map
         iterator-for-each
         iterator-from
         iterator-make
         iterator-map
         iterator-next
         iterator-prefix
         iterator-prototype
         iterator-prototype-constructor
         iterator-prototype-to-string-tag
         iterator-reduce
         iterator-resolve-optional
         iterator-resolve-this-arg
         iterator-result
         iterator-return
         iterator-some
         iterator-symbol-iterator
         iterator-take
         iterator-unwrap
         iterator-zip
         iterator-zip-keyed)

;; This is the canonical module version of the old `include-lib iterator` safe
;; wrapper. Raw bindings remain in `webracket/unsafe/array`.

;;;
;;; Iterator
;;;


;; EXPERIMENTAL

;; zip and zipKeyed
;;   Only FireFox supports zip and zipKeyed for the moment.
;;   So iterator-zip and iterator-zip-keyed reimplements the
;;   functions from scratch.

;; BASELINE 2025 / 2026
;; - Most  methods are newly available from 2025.
;; - A few methods are newly available from 2026.

;; TODO
;; - iterator-zip and iterator-zip-keyed are ignoring the `options` argument


;; iterator : external/raw -> iterator?
;;   Wrap a browser Iterator object in a checked structure.
(struct iterator (raw) #:transparent #:constructor-name make-iterator)

;; iterator-zip-options : symbol? any/c -> iterator-zip-options?
;;   Describe how Iterator.zip and Iterator.zipKeyed should combine lengths.
(struct iterator-zip-options (mode padding)
  #:transparent
  #:constructor-name make-iterator-zip-options
  #:guard (lambda (mode padding name)
            (unless (memq mode '(shortest longest strict))
              (raise-argument-error name
                                    "(or/c 'shortest 'longest 'strict)"
                                    mode))
            (values mode padding)))

;; iterator-unwrap : any/c -> any/c
;;   Unwrap an iterator struct to its raw browser object.
(define (iterator-unwrap value)
  (if (iterator? value)
      (iterator-raw value)
      value))

;; iterator-resolve-this-arg : any/c -> any/c
;;   Use #f as the omission marker, and force thunks when a literal value is needed.
(define (iterator-resolve-this-arg this-arg)
  (cond
    [(eq? this-arg #f) (js-undefined)]
    [(procedure? this-arg) (this-arg)]
    [else this-arg]))

;; iterator-resolve-optional : any/c -> any/c
;;   Use #f as the omission marker, and force thunks when a literal value is needed.
(define (iterator-resolve-optional value)
  (cond
    [(eq? value #f) #f]
    [(procedure? value) (value)]
    [else value]))

;; iterator-host-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable method named method-name.
(define (iterator-host-method-present? raw method-name)
  (and (iterator-raw-host-value? raw)
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; iterator-raw-host-value? : any/c -> boolean?
;;   Report whether raw is a non-nullish external host value.
(define (iterator-raw-host-value? raw)
  (and (external? raw)
       (not (js-nullish? raw))))

;; iterator-host-value? : any/c -> boolean?
;;   Report whether v wraps an external Iterator-like host value.
(define (iterator-host-value? v)
  (and (iterator? v)
       (iterator-host-method-present? (iterator-raw v) "next")))

;; iterator/surface? : any/c -> boolean?
;;   Report whether v is a wrapped Iterator-like host value.
(define (iterator/surface? v)
  (iterator-host-value? v))

;; check-iterator-host-method : symbol? external/raw string? string? -> void?
;;   Ensure a required Iterator host method is available.
(define (check-iterator-host-method who raw receiver-name method-name)
  (unless (iterator-host-method-present? raw method-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          method-name
                                          " is not available"))))

;; check-iterator-host-property : symbol? external/raw string? string? -> external/raw
;;   Return a required Iterator host property after checking it is available.
(define (check-iterator-host-property who raw receiver-name property-name)
  (define value (and (external? raw)
                     (not (js-nullish? raw))
                     (js-ref/extern raw property-name)))
  (unless (and (external? value)
               (not (js-nullish? value)))
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          property-name
                                          " is not available")))
  value)

;; check-iterator-global : symbol? -> external/raw
;;   Return the Iterator constructor after checking the host global is available.
(define (check-iterator-global who)
  (define iterator-ctor (Iterator))
  (unless (and (external? iterator-ctor)
               (not (js-nullish? iterator-ctor))
               (string=? (js-typeof iterator-ctor) "function"))
    (raise-arguments-error who "Iterator is not available"))
  iterator-ctor)

;; check-iterator-global-method : symbol? string? -> external/raw
;;   Return the Iterator constructor after checking a required static method.
(define (check-iterator-global-method who method-name)
  (define iterator-ctor (check-iterator-global who))
  (check-iterator-host-method who iterator-ctor "Iterator" method-name)
  iterator-ctor)

;; check-object-global-method : symbol? string? -> external/raw
;;   Return the Object constructor after checking a required static method.
(define (check-object-global-method who method-name)
  (define object-ctor (js-Object))
  (unless (and (external? object-ctor)
               (not (js-nullish? object-ctor))
               (string=? (js-typeof object-ctor) "function"))
    (raise-arguments-error who "Object is not available"))
  (check-iterator-host-method who object-ctor "Object" method-name)
  object-ctor)

;; iterable? : any/c -> boolean?
;;   Check whether a value has a callable [Symbol.iterator] method.
(define (iterable? value)
  (or (iterator-host-value? value)
      (let ([ctor (Iterator)])
        (and (not (js-nullish? ctor))
             (iterator-host-method-present? ctor "from")
             (with-handlers ([exn:fail? (lambda (_) #f)])
               (define probe
                 (js-send/extern/nullish ctor "from"
                                         (vector (iterator-unwrap value))))
               (and probe #t))))))

;; iterator-prefix : (listof any/c) exact-nonnegative-integer? -> (listof any/c)
;;   Keep the first n values from a list.
(define (iterator-prefix values n)
  (let loop ([values values] [n n] [acc '()])
    (cond
      [(or (zero? n) (null? values)) (reverse acc)]
      [else (loop (cdr values) (sub1 n) (cons (car values) acc))])))

;; iterator-call/callback : (or/c procedure? external?) (listof any/c) any/c -> any/c
;;   Call a callback, truncating extra arguments for Racket procedures.
(define (iterator-call/callback callback values [this-arg #f])
  (cond
    [(external? callback)
     (js-send/value callback "call"
                    (apply vector (list (iterator-unwrap (iterator-resolve-this-arg this-arg)))
                           (map iterator-unwrap values)))]
    [else
     (let loop ([n (length values)])
       (cond
         [(negative? n) (apply callback values)]
         [(procedure-arity-includes? callback n)
          (apply callback (iterator-prefix values n))]
         [else (loop (sub1 n))]))]))

;; iterator-result : any/c boolean? -> external/raw
;;   Build a JS iterator result record.
(define (iterator-result value done?)
  (js-object (vector (vector "value" value)
                     (vector "done" done?))))

;; iterator-collect-list : iterator? -> (listof any/c)
;;   Consume an iterator into a Racket list.
(define (iterator-collect-list iter)
  (let loop ([acc '()])
    (define step (iterator-next iter))
    (if (js-ref step "done")
        (reverse acc)
        (loop (cons (js-ref step "value") acc)))))

;; iterator-entry-key : (or/c vector? list?) -> any/c
;;   Read the key from an Object.entries entry.
(define (iterator-entry-key entry)
  (cond
    [(vector? entry) (vector-ref entry 0)]
    [(pair? entry) (car entry)]
    [else (error 'iterator-zip-keyed "expected entry pair, got: ~s" entry)]))

;; iterator-entry-value : (or/c vector? list?) -> any/c
;;   Read the value from an Object.entries entry.
(define (iterator-entry-value entry)
  (cond
    [(vector? entry) (vector-ref entry 1)]
    [(pair? entry) (cadr entry)]
    [else (error 'iterator-zip-keyed "expected entry pair, got: ~s" entry)]))

;; iterator-make : (-> external/raw) [-> external/raw] -> iterator?
;;   Build a lightweight JS iterator object from Racket closures.
(define (iterator-make next-proc [return-proc #f])
  (define fields
    (if return-proc
        (vector (vector "next" (procedure->external next-proc))
                (vector "return" (procedure->external return-proc)))
        (vector (vector "next" (procedure->external next-proc)))))
  (make-iterator (js-object fields)))

;; Iterator : -> external/raw
;;   Read the JavaScript Iterator global constructor.
(define (Iterator)
  (js-Iterator))

;; iterator-prototype : -> external/raw
;;   Read Iterator.prototype.
(define (iterator-prototype)
  (check-iterator-host-property 'iterator-prototype
                                (check-iterator-global 'iterator-prototype)
                                "Iterator"
                                "prototype"))

;; iterator-prototype-constructor : -> external/raw
;;   Read the constructor stored on Iterator.prototype.
(define (iterator-prototype-constructor)
  (define prototype
    (check-iterator-host-property 'iterator-prototype-constructor
                                  (check-iterator-global
                                   'iterator-prototype-constructor)
                                  "Iterator"
                                  "prototype"))
  (check-iterator-host-method 'iterator-prototype-constructor
                              prototype
                              "Iterator.prototype"
                              "constructor")
  (js-ref/extern prototype "constructor"))

;; iterator-prototype-to-string-tag : -> string?
;;   Read the default Symbol.toStringTag value for Iterator.prototype.
(define (iterator-prototype-to-string-tag)
  "Iterator")

;; iterator-from : iterable? -> iterator?
;;   Convert an iterator or iterable into a standard Iterator object.
(define (iterator-from object)
  (define iterator-ctor (check-iterator-global-method 'iterator-from "from"))
  (unless (iterable? object)
    (raise-argument-error 'iterator-from "iterable?" object))
  (make-iterator (js-send iterator-ctor "from" (vector (iterator-unwrap object)))))

;; iterator-concat : iterable? ... -> iterator?
;;   Concatenate multiple iterables into one Iterator.
(define (iterator-concat . iterables)
  (define sources (map iterator-from iterables))
  (define current 0)
  (define done? #f)
  (iterator-make
   (lambda ()
     (let loop ()
       (cond
         [done?
          (iterator-result (js-undefined) #t)]
         [(>= current (length sources))
          (set! done? #t)
          (iterator-result (js-undefined) #t)]
         [else
          (define step (iterator-next (list-ref sources current)))
          (if (js-ref step "done")
              (begin
                (set! current (add1 current))
                (loop))
              (iterator-result (js-ref step "value") #f))])))))

;; iterator-zip : iterable? [or/c #f iterator-zip-options?] -> iterator?
;;   Zip a collection of iterables into a new Iterator.
(define (iterator-zip iterables [options #f])
  (when options
    (unless (iterator-zip-options? options)
      (raise-argument-error 'iterator-zip
                            "(or/c #f iterator-zip-options?)"
                            options)))
  (define sources
    (map iterator-from
         (iterator-collect-list (iterator-from iterables))))
  (define done? #f)
  (iterator-make
   (lambda ()
     (cond
       [done?
        (iterator-result (js-undefined) #t)]
       [else
        (define steps (map iterator-next sources))
        (if (ormap (lambda (step) (js-ref step "done")) steps)
            (begin
              (set! done? #t)
              (iterator-result (js-undefined) #t))
            (iterator-result
             (js-array/extern (list->vector (map (lambda (step)
                                                   (js-ref step "value"))
                                                 steps)))
             #f))]))))

;; iterator-zip-keyed : iterable? [or/c #f iterator-zip-options?] -> iterator?
;;   Zip a keyed collection of iterables into a new Iterator.
(define (iterator-zip-keyed iterables [options #f])
  (when options
    (unless (iterator-zip-options? options)
      (raise-argument-error 'iterator-zip-keyed
                            "(or/c #f iterator-zip-options?)"
                            options)))
  (define object-ctor (check-object-global-method 'iterator-zip-keyed
                                                  "entries"))
  (define entries
    (map (lambda (entry)
           (cons (iterator-entry-key entry)
                 (iterator-from (iterator-entry-value entry))))
         (iterator-collect-list
          (iterator-from (js-send/value object-ctor
                                        "entries"
                                        (vector iterables))))))
  (define done? #f)
  (iterator-make
   (lambda ()
     (cond
       [done?
        (iterator-result (js-undefined) #t)]
       [else
        (define steps
          (map (lambda (entry)
                 (cons (car entry) (iterator-next (cdr entry))))
               entries))
        (if (ormap (lambda (entry) (js-ref (cdr entry) "done")) steps)
            (begin
              (set! done? #t)
              (iterator-result (js-undefined) #t))
            (iterator-result
             (js-object (list->vector
                         (map (lambda (entry)
                                (vector (car entry)
                                        (js-ref (cdr entry) "value")))
                              steps)))
             #f))]))))

;; iterator-next : iterator? -> external/raw
;;   Pull the next iteration result from an Iterator object.
(define (iterator-next iter)
  (unless (iterator? iter)
    (raise-argument-error 'iterator-next "iterator?" iter))
  (check-iterator-host-method 'iterator-next (iterator-raw iter) "Iterator" "next")
  (js-send (iterator-raw iter) "next" (vector)))

;; iterator-return : iterator? [any/c] -> external/raw
;;   Ask an Iterator to finish early and return a final result.
(define (iterator-return iter [value (void)])
  (unless (iterator? iter)
    (raise-argument-error 'iterator-return "iterator?" iter))
  (if (iterator-host-method-present? (iterator-raw iter) "return")
      (js-send/extern (iterator-raw iter) "return" (vector value))
      (iterator-result value #t)))

;; iterator-dispose! : iterator? -> void?
;;   Dispose an Iterator by calling return() when available.
(define (iterator-dispose! iter)
  (unless (iterator? iter)
    (raise-argument-error 'iterator-dispose! "iterator?" iter))
  (when (iterator-host-method-present? (iterator-raw iter) "return")
    (js-send/value (iterator-raw iter) "return" (vector)))
  (void))

;; iterator-symbol-iterator : iterator? -> iterator?
;;   Return the iterator itself, matching [Symbol.iterator].
(define (iterator-symbol-iterator iter)
  (unless (iterator? iter)
    (raise-argument-error 'iterator-symbol-iterator "iterator?" iter))
  iter)

;; iterator-drop : iterator? exact-nonnegative-integer? -> iterator?
;;   Skip a prefix of values from an Iterator.
(define (iterator-drop iter count)
  (unless (iterator? iter)
    (raise-argument-error 'iterator-drop "iterator?" iter))
  (unless (exact-nonnegative-integer? count)
    (raise-argument-error 'iterator-drop "exact-nonnegative-integer?" count))
  (define source (iterator-from iter))
  (define skipped 0)
  (iterator-make
   (lambda ()
     (let loop ()
       (cond
         [(< skipped count)
          (define step (iterator-next source))
          (if (js-ref step "done")
              (iterator-result (js-undefined) #t)
              (begin
                (set! skipped (add1 skipped))
                (loop)))]
         [else
          (define step (iterator-next source))
          (if (js-ref step "done")
              (iterator-result (js-undefined) #t)
              (iterator-result (js-ref step "value") #f))])))))

;; iterator-every : iterator? (or/c procedure? external?) [any/c] -> boolean?
;;   Check whether every iterated value satisfies a predicate.
(define (iterator-every iter callback [this-arg #f])
  (unless (iterator? iter)
    (raise-argument-error 'iterator-every "iterator?" iter))
  (define source (iterator-from iter))
  (let loop ([index 0])
    (define step (iterator-next source))
    (if (js-ref step "done")
        #t
        (and (iterator-call/callback callback
                                     (list (js-ref step "value")
                                           index
                                           source)
                                     this-arg)
             (loop (add1 index))))))

;; iterator-filter : iterator? (or/c procedure? external?) [any/c] -> iterator?
;;   Keep only the values accepted by a predicate.
(define (iterator-filter iter callback [this-arg #f])
  (unless (iterator? iter)
    (raise-argument-error 'iterator-filter "iterator?" iter))
  (define source (iterator-from iter))
  (iterator-make
   (lambda ()
     (let loop ([index 0])
       (define step (iterator-next source))
       (cond
         [(js-ref step "done") (iterator-result (js-undefined) #t)]
         [(iterator-call/callback callback
                                  (list (js-ref step "value")
                                        index
                                        source)
                                  this-arg)
          (iterator-result (js-ref step "value") #f)]
         [else (loop (add1 index))])))))

;; iterator-find : iterator? (or/c procedure? external?) [any/c] -> any/c
;;   Return the first value accepted by a predicate.
(define (iterator-find iter callback [this-arg #f])
  (unless (iterator? iter)
    (raise-argument-error 'iterator-find "iterator?" iter))
  (define source (iterator-from iter))
  (let loop ([index 0])
    (define step (iterator-next source))
    (cond
      [(js-ref step "done") #f]
      [(iterator-call/callback callback
                               (list (js-ref step "value")
                                     index
                                     source)
                               this-arg)
       (js-ref step "value")]
      [else (loop (add1 index))])))

;; iterator-flat-map : iterator? (or/c procedure? external?) [any/c] -> iterator?
;;   Map each value to an iterable and flatten the results one level.
(define (iterator-flat-map iter callback [this-arg #f])
  (unless (iterator? iter)
    (raise-argument-error 'iterator-flat-map "iterator?" iter))
  (define source (iterator-from iter))
  (define inner #f)
  (iterator-make
   (lambda ()
     (let loop ([index 0])
       (cond
         [inner
          (define inner-step (iterator-next inner))
          (if (js-ref inner-step "done")
              (begin
                (set! inner #f)
                (loop index))
              (iterator-result (js-ref inner-step "value") #f))]
         [else
          (define step (iterator-next source))
          (cond
            [(js-ref step "done")
             (iterator-result (js-undefined) #t)]
            [else
             (define mapped (iterator-call/callback callback
                                                    (list (js-ref step "value")
                                                          index
                                                          source)
                                                    this-arg))
             (set! inner (iterator-from mapped))
             (loop (add1 index))])])))))

;; iterator-for-each : iterator? (or/c procedure? external?) [any/c] -> void?
;;   Visit each value in an Iterator for side effects.
(define (iterator-for-each iter callback [this-arg #f])
  (unless (iterator? iter)
    (raise-argument-error 'iterator-for-each "iterator?" iter))
  (define source (iterator-from iter))
  (let loop ([index 0])
    (define step (iterator-next source))
    (unless (js-ref step "done")
      (void (iterator-call/callback callback
                                    (list (js-ref step "value")
                                          index
                                          source)
                                    this-arg))
      (loop (add1 index))))
  (void))

;; iterator-map : iterator? (or/c procedure? external?) [any/c] -> iterator?
;;   Transform each iterated value.
(define (iterator-map iter callback [this-arg #f])
  (unless (iterator? iter)
    (raise-argument-error 'iterator-map "iterator?" iter))
  (define source (iterator-from iter))
  (define index 0)
  (iterator-make
   (lambda ()
     (define step (iterator-next source))
     (if (js-ref step "done")
         (iterator-result (js-undefined) #t)
         (let ([mapped (iterator-call/callback callback
                                                (list (js-ref step "value")
                                                      index
                                                      source)
                                                this-arg)])
           (set! index (add1 index))
           (iterator-result mapped #f))))))

;; iterator-reduce : iterator? (or/c procedure? external?) [any/c] -> any/c
;;   Collapse an Iterator to a single value.
(define (iterator-reduce iter callback [initial-value #f])
  (unless (iterator? iter)
    (raise-argument-error 'iterator-reduce "iterator?" iter))
  (define source (iterator-from iter))
  (define started? (not (eq? initial-value #f)))
  (define acc (iterator-resolve-optional initial-value))
  (define index 0)
  (let loop ()
    (define step (iterator-next source))
    (cond
      [(js-ref step "done")
       (if started?
           acc
           (raise-arguments-error 'iterator-reduce
                                  "empty iterator with no initial value"))]
      [started?
       (set! acc (iterator-call/callback callback
                                         (list acc
                                               (js-ref step "value")
                                               index
                                               source)))
       (set! index (add1 index))
       (loop)]
      [else
       (set! acc (js-ref step "value"))
       (set! started? #t)
       (set! index (add1 index))
       (loop)])))

;; iterator-some : iterator? (or/c procedure? external?) [any/c] -> boolean?
;;   Check whether any iterated value satisfies a predicate.
(define (iterator-some iter callback [this-arg #f])
  (unless (iterator? iter)
    (raise-argument-error 'iterator-some "iterator?" iter))
  (define source (iterator-from iter))
  (let loop ([index 0])
    (define step (iterator-next source))
    (cond
      [(js-ref step "done") #f]
      [(iterator-call/callback callback
                               (list (js-ref step "value")
                                     index
                                     source)
                               this-arg)
       #t]
      [else (loop (add1 index))])))

;; iterator-take : iterator? exact-nonnegative-integer? -> iterator?
;;   Keep only the first count values from an Iterator.
(define (iterator-take iter count)
  (unless (iterator? iter)
    (raise-argument-error 'iterator-take "iterator?" iter))
  (unless (exact-nonnegative-integer? count)
    (raise-argument-error 'iterator-take "exact-nonnegative-integer?" count))
  (define source (iterator-from iter))
  (define taken 0)
  (iterator-make
   (lambda ()
     (cond
       [(>= taken count)
        (iterator-result (js-undefined) #t)]
       [else
        (define step (iterator-next source))
        (if (js-ref step "done")
            (iterator-result (js-undefined) #t)
            (begin
              (set! taken (add1 taken))
              (iterator-result (js-ref step "value") #f)))]))))

;; iterator->vector : iterator? -> vector?
;;   Collect an Iterator into a WebRacket vector.
(define (iterator->vector iter)
  (unless (iterator? iter)
    (raise-argument-error 'iterator->vector "iterator?" iter))
  (list->vector
   (let loop ([acc '()] [source (iterator-from iter)])
     (define step (iterator-next source))
     (if (js-ref step "done")
         (reverse acc)
         (loop (cons (js-ref step "value") acc) source)))))
