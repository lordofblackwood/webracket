#lang racket

(provide core-runtime-helpers
         core-runtime-helper-index
         core-runtime-global-names
         core-runtime-global-name-set
         generate-core-runtime)

(require "core-helper.rkt"
         "core/arrays.rkt"
         "core/booleans.rkt"
         "core/boxes.rkt"
         "core/fixnums.rkt"
         "core/flonums.rkt"
         "core/growable-arrays.rkt"
         "core/growable-bytes.rkt"
         "core/growable-i32-arrays.rkt"
         "core/i32-arrays.rkt"
         "core/i8-arrays.rkt"
         "core/immediates.rkt"
         "core/keywords.rkt"
         "core/lists.rkt"
         "core/mlists.rkt"
         "core/procedures.rkt"
         "core/strings.rkt"
         "core/structs.rkt"
         "core/unsafe.rkt"
         "core/vectors.rkt"
         "shared-types.rkt")

;; core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate the functions currently shared between monolithic and core runtime trees.
(define core-runtime-helpers
  (append
   array-core-runtime-helpers
   boolean-core-runtime-helpers
   box-core-runtime-helpers
   fixnum-core-runtime-helpers
   flonum-core-runtime-helpers
   growable-array-core-runtime-helpers
   growable-bytes-core-runtime-helpers
   i32-array-core-runtime-helpers
   growable-i32-array-core-runtime-helpers
   i8-array-core-runtime-helpers
   i8-array-byte-core-runtime-helpers
   immediate-core-runtime-helpers
   keyword-core-runtime-helpers
   list-core-runtime-helpers
   mlist-core-runtime-helpers
   procedure-core-runtime-helpers
   string-core-runtime-helpers
   struct-core-runtime-helpers
   unsafe-core-runtime-helpers
   vector-core-runtime-helpers))

;; core-runtime-helper-index : hasheq?
;;   Index core runtime helpers by Wasm function name.
(define core-runtime-helper-index
  (make-core-runtime-helper-index core-runtime-helpers))

;; core-runtime-global-names : (listof symbol?)
;;   Enumerate stable globals declared by the standalone core runtime.
(define core-runtime-global-names
  singleton-global-names)

;; core-runtime-global-name-set : hasheq?
;;   Index stable core runtime globals by Wasm name.
(define core-runtime-global-name-set
  (for/hasheq ([name (in-list core-runtime-global-names)])
    (values name #t)))

;; generate-core-runtime : -> datum?
;;   Build the standalone core runtime module tree used by split-runtime experiments.
(define (generate-core-runtime)
  `(module
     ,@(generate-shared-types)
     ,@singleton-global-forms
     ,@(core-runtime-helper-forms core-runtime-helpers #:export? #t)))

(module+ test
  (require rackunit
           racket/system
           "core-dependencies.rkt"
           (only-in "../assembler.rkt" wat->wasm))

  ;; module-body : datum? -> (or/c (listof datum?) #f)
  ;;   Return the body forms from a generated WAT module tree.
  (define (module-body module)
    (match module
      [`(module ,forms ...) forms]
      [_ #f]))

  ;; type-form-named? : symbol? datum? -> boolean?
  ;;   Check whether form is a type declaration with the given name.
  (define (type-form-named? name form)
    (match form
      [`(type ,type-name . ,_) (eq? type-name name)]
      [_ #f]))

  ;; function-form-named? : symbol? datum? -> boolean?
  ;;   Check whether form is a function declaration with the given name.
  (define (function-form-named? name form)
    (match form
      [`(func ,func-name . ,_) (eq? func-name name)]
      [_ #f]))

  ;; function-export-names : datum? -> (listof string?)
  ;;   Return all export names attached directly to a function form.
  (define (function-export-names form)
    (match form
      [`(func ,_ ,body ...)
       (for/list ([part (in-list body)]
                  #:when (match part
                           [`(export ,(? string?)) #t]
                           [_ #f]))
         (second part))]
      [_ '()]))

  ;; core-helper-import : symbol? symbol? -> datum?
  ;;   Build an imported core helper declaration with a shared function type.
  (define (core-helper-import name type-name)
    `(func ,name
           (import "core" ,(symbol->string name))
           (type ,type-name)))

  ;; core-raw-i32-unary-import : symbol? -> datum?
  ;;   Build an imported core helper declaration for raw unary predicates.
  (define (core-raw-i32-unary-import name)
    `(func ,name
           (import "core" ,(symbol->string name))
           (param (ref eq))
           (result i32)))

  ;; core-array-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for generic arrays.
  (define (core-array-imports)
    `((func $make-array
            (import "core" "$make-array")
            (param i32)
            (param (ref eq))
            (result (ref $Array)))
      (func $array-length
            (import "core" "$array-length")
            (param (ref $Array))
            (result i32))
      (func $array-ref
            (import "core" "$array-ref")
            (param (ref $Array))
            (param i32)
            (result (ref eq)))
      (func $array-set!
            (import "core" "$array-set!")
            (param (ref $Array))
            (param i32)
            (param (ref eq)))
      (func $array-fill!
            (import "core" "$array-fill!")
            (param (ref $Array))
            (param (ref eq)))
      (func $array-copy!
            (import "core" "$array-copy!")
            (param (ref $Array))
            (param i32)
            (param (ref $Array))
            (param i32)
            (param i32))
      (func $array-copy!/error
            (import "core" "$array-copy!/error")
            (param (ref $Array))
            (param i32)
            (param (ref $Array))
            (param i32)
            (param i32)
            (result i32))
      (func $array-append
            (import "core" "$array-append")
            (param (ref $Array))
            (param (ref $Array))
            (result (ref $Array)))
      (func $array-append-all
            (import "core" "$array-append-all")
            (param (ref $Array))
            (result (ref $Array)))
      (func $array-take
            (import "core" "$array-take")
            (param (ref $Array))
            (param i32)
            (result (ref $Array)))
      (func $array-take-right
            (import "core" "$array-take-right")
            (param (ref $Array))
            (param i32)
            (result (ref $Array)))
      (func $array-drop
            (import "core" "$array-drop")
            (param (ref $Array))
            (param i32)
            (result (ref $Array)))
      (func $array-drop-right
            (import "core" "$array-drop-right")
            (param (ref $Array))
            (param i32)
            (result (ref $Array)))
      (func $array-split-at
            (import "core" "$array-split-at")
            (param (ref $Array))
            (param i32)
            (result (ref $Array)))
      (func $array-copy
            (import "core" "$array-copy")
            (param (ref $Array))
            (param i32)
            (param i32)
            (result (ref $Array)))
      (func $array-set/copy
            (import "core" "$array-set/copy")
            (param (ref $Array))
            (param i32)
            (param (ref eq))
            (result (ref $Array)))
      (func $array-extend
            (import "core" "$array-extend")
            (param (ref $Array))
            (param i32)
            (param (ref eq))
            (result (ref $Array)))))

  ;; core-growable-array-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for generic growable arrays.
  (define (core-growable-array-imports)
    `((func $make-growable-array
            (import "core" "$make-growable-array")
            (param i32)
            (result (ref $GrowableArray)))
      (func $growable-array??
            (import "core" "$growable-array??")
            (param (ref eq))
            (result i32))
      (func $growable-array?
            (import "core" "$growable-array?")
            (param (ref eq))
            (result (ref eq)))
      (func $growable-array-ref
            (import "core" "$growable-array-ref")
            (param (ref $GrowableArray))
            (param i32)
            (result (ref eq)))
      (func $growable-array-ref/default
            (import "core" "$growable-array-ref/default")
            (param (ref $GrowableArray))
            (param i32)
            (param (ref eq))
            (result (ref eq)))
      (func $growable-array-add!
            (import "core" "$growable-array-add!")
            (param (ref $GrowableArray))
            (param (ref eq)))
      (func $growable-array-insert!
            (import "core" "$growable-array-insert!")
            (param (ref $GrowableArray))
            (param i32)
            (param (ref eq)))
      (func $growable-array-set!
            (import "core" "$growable-array-set!")
            (param (ref $GrowableArray))
            (param i32)
            (param (ref eq)))
      (func $growable-array-remove!
            (import "core" "$growable-array-remove!")
            (param (ref $GrowableArray))
            (param i32))
      (func $growable-array-remove-last!
            (import "core" "$growable-array-remove-last!")
            (param (ref $GrowableArray))
            (result (ref eq)))
      (func $growable-array-count
            (import "core" "$growable-array-count")
            (param (ref $GrowableArray))
            (result i32))
      (func $growable-array->array
            (import "core" "$growable-array->array")
            (param (ref $GrowableArray))
            (result (ref $Array)))
      (func $array->growable-array
            (import "core" "$array->growable-array")
            (param (ref $Array))
            (result (ref $GrowableArray)))))

  ;; core-i32-array-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for I32 arrays.
  (define (core-i32-array-imports)
    `((func $i32array-make
            (import "core" "$i32array-make")
            (param i32)
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-length
            (import "core" "$i32array-length")
            (param (ref $I32Array))
            (result i32))
      (func $i32array-ref
            (import "core" "$i32array-ref")
            (param (ref $I32Array))
            (param i32)
            (result i32))
      (func $i32array-set!
            (import "core" "$i32array-set!")
            (param (ref $I32Array))
            (param i32)
            (param i32))
      (func $i32array-equal?
            (import "core" "$i32array-equal?")
            (param (ref $I32Array))
            (param (ref $I32Array))
            (result i32))
      (func $i32array-fill!
            (import "core" "$i32array-fill!")
            (param (ref $I32Array))
            (param i32))
      (func $i32array-copy!
            (import "core" "$i32array-copy!")
            (param (ref $I32Array))
            (param i32)
            (param (ref $I32Array))
            (param i32)
            (param i32))
      (func $i32array-copy!/error
            (import "core" "$i32array-copy!/error")
            (param (ref $I32Array))
            (param i32)
            (param (ref $I32Array))
            (param i32)
            (param i32)
            (result i32))
      (func $i32array-copy
            (import "core" "$i32array-copy")
            (param (ref $I32Array))
            (param i32)
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-append
            (import "core" "$i32array-append")
            (param (ref $I32Array))
            (param (ref $I32Array))
            (result (ref $I32Array)))
      (func $i32array-take
            (import "core" "$i32array-take")
            (param (ref $I32Array))
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-take-right
            (import "core" "$i32array-take-right")
            (param (ref $I32Array))
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-drop
            (import "core" "$i32array-drop")
            (param (ref $I32Array))
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-drop-right
            (import "core" "$i32array-drop-right")
            (param (ref $I32Array))
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-set/copy
            (import "core" "$i32array-set/copy")
            (param (ref $I32Array))
            (param i32)
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-extend
            (import "core" "$i32array-extend")
            (param (ref $I32Array))
            (param i32)
            (param i32)
            (result (ref $I32Array)))))

  ;; core-i8-array-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for I8 arrays.
  (define (core-i8-array-imports)
    `((func $i8make-array
            (import "core" "$i8make-array")
            (param i32)
            (param i32)
            (result (ref $I8Array)))
      (func $i8array-length
            (import "core" "$i8array-length")
            (param (ref $I8Array))
            (result i32))
      (func $i8array-ref
            (import "core" "$i8array-ref")
            (param (ref $I8Array))
            (param i32)
            (result i32))
      (func $i8array-set!
            (import "core" "$i8array-set!")
            (param (ref $I8Array))
            (param i32)
            (param i32))
      (func $i8array-fill!
            (import "core" "$i8array-fill!")
            (param (ref $I8Array))
            (param i32))
      (func $i8array-copy!
            (import "core" "$i8array-copy!")
            (param (ref $I8Array))
            (param i32)
            (param (ref $I8Array))
            (param i32)
            (param i32))
      (func $i8array-copy!/error
            (import "core" "$i8array-copy!/error")
            (param (ref $I8Array))
            (param i32)
            (param (ref $I8Array))
            (param i32)
            (param i32)
            (result i32))
      (func $i8array-copy
            (import "core" "$i8array-copy")
            (param (ref $I8Array))
            (param i32)
            (param i32)
            (result (ref $I8Array)))
      (func $i8array-set/copy
            (import "core" "$i8array-set/copy")
            (param (ref $I8Array))
            (param i32)
            (param i32)
            (result (ref $I8Array)))
      (func $i8array-extend
            (import "core" "$i8array-extend")
            (param (ref $I8Array))
            (param i32)
            (param i32)
            (result (ref $I8Array)))
      (func $i8array-append
            (import "core" "$i8array-append")
            (param (ref $I8Array))
            (param (ref $I8Array))
            (result (ref $I8Array)))))

  ;; core-growable-i32-array-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for I32 growable arrays.
  (define (core-growable-i32-array-imports)
    `((func $make-i32growable-array
            (import "core" "$make-i32growable-array")
            (param i32)
            (result (ref $I32GrowableArray)))
      (func $i32growable-array-add!
            (import "core" "$i32growable-array-add!")
            (param (ref $I32GrowableArray))
            (param i32))
      (func $i32growable-array-add-string!
            (import "core" "$i32growable-array-add-string!")
            (param (ref $I32GrowableArray))
            (param (ref $String)))
      (func $i32growable-array-ref
            (import "core" "$i32growable-array-ref")
            (param (ref $I32GrowableArray))
            (param i32)
            (result i32))
      (func $i32growable-array-count
            (import "core" "$i32growable-array-count")
            (param (ref $I32GrowableArray))
            (result i32))
      (func $i32growable-array->array
            (import "core" "$i32growable-array->array")
            (param (ref $I32GrowableArray))
            (result (ref $I32Array)))
      (func $i32array->growable-array
            (import "core" "$i32array->growable-array")
            (param (ref $I32Array))
            (result (ref $I32GrowableArray)))))

  ;; core-growable-bytes-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for growable bytes.
  (define (core-growable-bytes-imports)
    `((func $make-growable-bytes
            (import "core" "$make-growable-bytes")
            (param i32)
            (result (ref $GrowableBytes)))
      (func $growable-bytes-add!
            (import "core" "$growable-bytes-add!")
            (param (ref $GrowableBytes))
            (param i32))
      (func $growable-bytes->bytes
            (import "core" "$growable-bytes->bytes")
            (param (ref $GrowableBytes))
            (result (ref $Bytes)))))

  ;; core-i8-array-byte-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for I8Array-to-bytes wrappers.
  (define (core-i8-array-byte-imports)
    `((func $i8array->bytes
            (import "core" "$i8array->bytes")
            (param (ref $I8Array))
            (result (ref $Bytes)))
      (func $i8array->immutable-bytes
            (import "core" "$i8array->immutable-bytes")
            (param (ref $I8Array))
            (result (ref $Bytes)))))

  ;; core-string-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for string constructors.
  (define (core-string-imports)
    `((func $i32array->string
            (import "core" "$i32array->string")
            (param (ref $I32Array))
            (result (ref $String)))
      (func $i32array->immutable-string
            (import "core" "$i32array->immutable-string")
            (param (ref $I32Array))
            (result (ref $String)))
      (func $i32growable-array->string
            (import "core" "$i32growable-array->string")
            (param (ref $I32GrowableArray))
            (result (ref $String)))
      (func $i32growable-array->immutable-string
            (import "core" "$i32growable-array->immutable-string")
            (param (ref $I32GrowableArray))
            (result (ref $String)))))

  ;; tagged-call1-export : string? symbol? integer? -> datum?
  ;;   Build an exported test function that returns a raw tagged unary result.
  (define (tagged-call1-export export-name helper-name arg)
    `(func (export ,export-name) (result i32)
           (i31.get_s
            (ref.cast (ref i31)
                      (call ,helper-name
                            (ref.i31 (i32.const ,arg)))))))

  ;; tagged-call2-export : string? symbol? integer? integer? -> datum?
  ;;   Build an exported test function that returns a raw tagged binary result.
  (define (tagged-call2-export export-name helper-name arg1 arg2)
    `(func (export ,export-name) (result i32)
           (i31.get_s
            (ref.cast (ref i31)
                      (call ,helper-name
                            (ref.i31 (i32.const ,arg1))
                            (ref.i31 (i32.const ,arg2)))))))

  (define core-prim1-test-imports
    '($fxnot
      $fxpopcount
      $fxpopcount32
      $fxpopcount16
      $unsafe-fxnot
      $unsafe-fxpopcount
      $unsafe-fxpopcount32
      $unsafe-fxpopcount16))

  (define core-prim2-test-imports
    '($fxand/2
      $fxior/2
      $fxxor/2
      $fxlshift
      $fxrshift
      $fx+/wraparound
      $fx*/wraparound
      $fxlshift/wraparound
      $fxrshift/logical
      $unsafe-fxlshift
      $unsafe-fx+/wraparound
      $unsafe-fx*/wraparound
      $unsafe-fxlshift/wraparound
      $unsafe-fxrshift
      $unsafe-fxrshift/logical))

  (define core-raw-i32-unary-test-imports
    '($fl?/i32
      $keyword?/i32
      $vector?/i32
      $struct?/i32
      $struct-type?/i32))

  (define shared-types (generate-shared-types))
  (define shared-type-names (shared-type-name-set shared-types))
  (define core-helper-names core-runtime-helper-index)
  (check-pred list? shared-types)
  (check-true (hash-has-key? shared-type-names '$Array))
  (check-true (hash-has-key? shared-type-names '$Pair))
  (check-true (for/or ([form (in-list shared-types)])
                (type-form-named? '$Array form)))
  (check-true (for/or ([form (in-list shared-types)])
                (match form
                  [`(rec . ,_) #t]
                  [_ #f])))

  (for ([helper (in-list core-runtime-helpers)])
    (define name (core-runtime-helper-name helper))
    (define export-name (core-runtime-helper-export-name helper))
    (check-equal? (core-runtime-helper-ref core-runtime-helper-index name)
                  helper)
    (check-equal? (function-export-names
                   (core-runtime-helper-form core-runtime-helper-index name))
                  '())
    (check-equal? (function-export-names
                   (core-runtime-helper-form core-runtime-helper-index name #:export? #t))
                  (list export-name)))
  (check-exn exn:fail?
             (lambda ()
               (core-runtime-helper-ref core-runtime-helper-index '$not-a-helper)))
  (check-exn exn:fail?
             (lambda ()
               (make-core-runtime-helper-index
                (list (first core-runtime-helpers)
                      (first core-runtime-helpers)))))

  (for ([helper (in-list core-runtime-helpers)])
    (define name (core-runtime-helper-name helper))
    (check-equal? (core-runtime-helper-dependency-problems
                   (core-runtime-helper-form core-runtime-helper-index name)
                   core-helper-names
                   shared-type-names
                   core-runtime-global-name-set)
                  '()))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (param (ref eq)) (result i32)
                        (call $fx?/i32 (local.get $v)))
                 core-helper-names
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (result i32)
                        (global.get $false))
                 core-helper-names
                 shared-type-names)
                (list (helper-dependency-problem
                       'runtime-global
                       '$false)))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result (ref eq))
                        (global.get $false))
                 core-helper-names
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (param (ref eq)) (result i32)
                        (call $other (local.get $v)))
                 core-helper-names
                 shared-type-names
                 core-runtime-global-name-set)
                (list (helper-dependency-problem
                       'runtime-call
                       '$other)))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (param (ref eq)) (result i32)
                        (return_call $other (local.get $v)))
                 core-helper-names
                 shared-type-names
                 core-runtime-global-name-set)
                (list (helper-dependency-problem
                       'runtime-call
                       '$other)))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (param (ref $NotShared)) (result i32)
                        (i32.const 0))
                 core-helper-names
                 shared-type-names
                 core-runtime-global-name-set)
                (list (helper-dependency-problem
                       'unshared-type
                       '$NotShared)))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (type $NotShared)
                        (i32.const 0))
                 core-helper-names
                 shared-type-names
                 core-runtime-global-name-set)
                (list (helper-dependency-problem
                       'unshared-type
                       '$NotShared)))

  (define core-module (generate-core-runtime))
  (define core-forms (module-body core-module))
  (check-pred list? core-forms)
  (check-true (for/or ([form (in-list core-forms)])
                (type-form-named? '$Array form)))
  (for ([helper (in-list core-runtime-helpers)])
    (define name (core-runtime-helper-name helper))
    (define export-name (core-runtime-helper-export-name helper))
    (define matching-functions
      (for/list ([form (in-list core-forms)]
                 #:when (function-form-named? name form))
        form))
    (check-equal? (length matching-functions) 1)
    (check-equal? (function-export-names (first matching-functions))
                  (list export-name)))

  (when (find-executable-path "wasm-tools")
    (define core-wat-path
      (make-temporary-file "webracket-core-runtime-test-~a.wat"))
    (define core-wasm-path
      (path-replace-extension core-wat-path ".wasm"))
    (check-true (wat->wasm core-module
                           #:wat core-wat-path
                           #:wasm core-wasm-path))
    (check-true (file-exists? core-wasm-path))

    (define split-consumer-module
      `(module
         ,@(generate-shared-types)

         (func $fx?/i32
               (import "core" "$fx?/i32")
               (param (ref eq))
               (result i32))
         (func $fixnum?/i32
               (import "core" "$fixnum?/i32")
         (param (ref eq))
         (result i32))
         ,@(for/list ([name (in-list core-raw-i32-unary-test-imports)])
             (core-raw-i32-unary-import name))
         ,@(core-array-imports)
         ,@(core-growable-array-imports)
         ,@(core-i32-array-imports)
         ,@(core-i8-array-imports)
         ,@(core-i8-array-byte-imports)
         ,@(core-growable-i32-array-imports)
         ,@(core-growable-bytes-imports)
         ,@(core-string-imports)
         ,@(for/list ([name (in-list core-prim1-test-imports)])
             (core-helper-import name '$Prim1))
         ,@(for/list ([name (in-list core-prim2-test-imports)])
             (core-helper-import name '$Prim2))

         (func (export "fx_fixnum_true") (result i32)
               (call $fx?/i32 (ref.i31 (i32.const 84))))
         (func (export "fx_immediate_false") (result i32)
               (call $fx?/i32 (ref.i31 (i32.const 85))))
         (func (export "fx_heap_false") (result i32)
               (call $fx?/i32
                     (struct.new $Pair
                                 (i32.const 0)
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0)))))
         (func (export "fixnum_fixnum_true") (result i32)
               (call $fixnum?/i32 (ref.i31 (i32.const 84))))
         (func (export "fixnum_immediate_false") (result i32)
               (call $fixnum?/i32 (ref.i31 (i32.const 85))))
         (func (export "fl_flonum_true") (result i32)
               (call $fl?/i32
                     (struct.new $Flonum
                                 (i32.const 0)
                                 (f64.const 1.5))))
         (func (export "fl_fixnum_false") (result i32)
               (call $fl?/i32 (ref.i31 (i32.const 84))))
         (func (export "keyword_keyword_true") (result i32)
               (call $keyword?/i32
                     (struct.new $Keyword
                                 (i32.const 0)
                                 (struct.new $String
                                             (i32.const 0)
                                             (i32.const 1)
                                             (array.new $I32Array
                                                        (i32.const 107)
                                                        (i32.const 1))))))
         (func (export "keyword_fixnum_false") (result i32)
               (call $keyword?/i32 (ref.i31 (i32.const 84))))
         (func (export "vector_vector_true") (result i32)
               (call $vector?/i32
                     (struct.new $Vector
                                 (i32.const 0)
                                 (i32.const 0)
                                 (array.new $Array
                                            (ref.i31 (i32.const 0))
                                            (i32.const 3)))))
         (func (export "vector_fixnum_false") (result i32)
               (call $vector?/i32 (ref.i31 (i32.const 84))))
         (func (export "struct_type_true") (result i32)
               (call $struct-type?/i32
                     (struct.new $StructType
                                 (i32.const 0)
                                 (struct.new $Symbol
                                             (i32.const 0)
                                             (struct.new $String
                                                         (i32.const 0)
                                                         (i32.const 1)
                                                         (array.new $I32Array
                                                                    (i32.const 115)
                                                                    (i32.const 1)))
                                             (i32.const 0)
                                             (ref.i31 (i32.const 0)))
                                 (ref.i31 (i32.const 0))
                                 (i32.const 0)
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0)))))
         (func (export "struct_type_fixnum_false") (result i32)
               (call $struct-type?/i32 (ref.i31 (i32.const 84))))
         (func (export "struct_struct_type_false") (result i32)
               (call $struct?/i32
                     (struct.new $StructType
                                 (i32.const 0)
                                 (struct.new $Symbol
                                             (i32.const 0)
                                             (struct.new $String
                                                         (i32.const 0)
                                                         (i32.const 1)
                                                         (array.new $I32Array
                                                                    (i32.const 115)
                                                                    (i32.const 1)))
                                             (i32.const 0)
                                             (ref.i31 (i32.const 0)))
                                 (ref.i31 (i32.const 0))
                                 (i32.const 0)
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0)))))
         (func (export "struct_fixnum_false") (result i32)
               (call $struct?/i32 (ref.i31 (i32.const 84))))
         (func (export "array_length") (result i32)
               (call $array-length
                     (call $make-array (i32.const 3) (ref.i31 (i32.const 20)))))
         (func (export "array_ref_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref
                                (array.new_fixed $Array 2
                                                 (ref.i31 (i32.const 20))
                                                 (ref.i31 (i32.const 40)))
                                (i32.const 1)))))
         (func (export "array_set_ref_tagged") (result i32)
               (local $arr (ref $Array))
               (local.set $arr (call $make-array (i32.const 2) (ref.i31 (i32.const 20))))
               (call $array-set! (local.get $arr) (i32.const 1) (ref.i31 (i32.const 60)))
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref (local.get $arr) (i32.const 1)))))
         (func (export "array_fill_ref_tagged") (result i32)
               (local $arr (ref $Array))
               (local.set $arr (call $make-array (i32.const 3) (ref.i31 (i32.const 20))))
               (call $array-fill! (local.get $arr) (ref.i31 (i32.const 80)))
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref (local.get $arr) (i32.const 2)))))
         (func (export "array_copy_bang_tagged") (result i32)
               (local $dest (ref $Array))
               (local $src (ref $Array))
               (local.set $dest (call $make-array (i32.const 3) (ref.i31 (i32.const 0))))
               (local.set $src (array.new_fixed $Array 2
                                                 (ref.i31 (i32.const 20))
                                                 (ref.i31 (i32.const 40))))
               (call $array-copy! (local.get $dest) (i32.const 1) (local.get $src) (i32.const 0) (i32.const 2))
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref (local.get $dest) (i32.const 2)))))
         (func (export "array_copy_error_success") (result i32)
               (call $array-copy!/error
                     (call $make-array (i32.const 2) (ref.i31 (i32.const 0)))
                     (i32.const 0)
                     (array.new_fixed $Array 2
                                      (ref.i31 (i32.const 20))
                                      (ref.i31 (i32.const 40)))
                     (i32.const 0)
                     (i32.const 2)))
         (func (export "array_copy_error_failure") (result i32)
               (call $array-copy!/error
                     (call $make-array (i32.const 1) (ref.i31 (i32.const 0)))
                     (i32.const 1)
                     (array.new_fixed $Array 2
                                      (ref.i31 (i32.const 20))
                                      (ref.i31 (i32.const 40)))
                     (i32.const 0)
                     (i32.const 2)))
         (func (export "array_append_ref_tagged") (result i32)
               (local $arr (ref $Array))
               (local.set $arr
                          (call $array-append
                                (array.new_fixed $Array 1
                                                 (ref.i31 (i32.const 20)))
                                (array.new_fixed $Array 2
                                                 (ref.i31 (i32.const 40))
                                                 (ref.i31 (i32.const 60)))))
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref (local.get $arr) (i32.const 2)))))
         (func (export "array_append_all_ref_tagged") (result i32)
               (local $arr (ref $Array))
               (local.set $arr
                          (call $array-append-all
                                (array.new_fixed $Array 2
                                                 (array.new_fixed $Array 1
                                                                  (ref.i31 (i32.const 20)))
                                                 (array.new_fixed $Array 2
                                                                  (ref.i31 (i32.const 40))
                                                                  (ref.i31 (i32.const 60))))))
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref (local.get $arr) (i32.const 2)))))
         (func (export "array_take_length") (result i32)
               (call $array-length
                     (call $array-take
                           (array.new_fixed $Array 3
                                            (ref.i31 (i32.const 20))
                                            (ref.i31 (i32.const 40))
                                            (ref.i31 (i32.const 60)))
                           (i32.const 2))))
         (func (export "array_take_right_ref_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref
                                (call $array-take-right
                                      (array.new_fixed $Array 3
                                                       (ref.i31 (i32.const 20))
                                                       (ref.i31 (i32.const 40))
                                                       (ref.i31 (i32.const 60)))
                                      (i32.const 2))
                                (i32.const 0)))))
         (func (export "array_drop_ref_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref
                                (call $array-drop
                                      (array.new_fixed $Array 3
                                                       (ref.i31 (i32.const 20))
                                                       (ref.i31 (i32.const 40))
                                                       (ref.i31 (i32.const 60)))
                                      (i32.const 1))
                                (i32.const 0)))))
         (func (export "array_drop_right_length") (result i32)
               (call $array-length
                     (call $array-drop-right
                           (array.new_fixed $Array 3
                                            (ref.i31 (i32.const 20))
                                            (ref.i31 (i32.const 40))
                                            (ref.i31 (i32.const 60)))
                           (i32.const 1))))
         (func (export "array_split_at_second_length") (result i32)
               (local $split (ref $Array))
               (local.set $split
                          (call $array-split-at
                                (array.new_fixed $Array 3
                                                 (ref.i31 (i32.const 20))
                                                 (ref.i31 (i32.const 40))
                                                 (ref.i31 (i32.const 60)))
                                (i32.const 1)))
               (call $array-length
                     (ref.cast (ref $Array)
                               (call $array-ref (local.get $split) (i32.const 1)))))
         (func (export "array_copy_ref_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref
                                (call $array-copy
                                      (array.new_fixed $Array 3
                                                       (ref.i31 (i32.const 20))
                                                       (ref.i31 (i32.const 40))
                                                       (ref.i31 (i32.const 60)))
                                      (i32.const 1)
                                      (i32.const 3))
                                (i32.const 0)))))
         (func (export "array_set_copy_ref_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref
                                (call $array-set/copy
                                      (array.new_fixed $Array 2
                                                       (ref.i31 (i32.const 20))
                                                       (ref.i31 (i32.const 40)))
                                      (i32.const 1)
                                      (ref.i31 (i32.const 80)))
                                (i32.const 1)))))
         (func (export "array_extend_length") (result i32)
               (call $array-length
                     (call $array-extend
                           (array.new_fixed $Array 2
                                            (ref.i31 (i32.const 20))
                                            (ref.i31 (i32.const 40)))
                           (i32.const 5)
                           (ref.i31 (i32.const 0)))))
         (func (export "growable_array_predicate_true") (result i32)
               (call $growable-array??
                     (call $make-growable-array (i32.const 1))))
         (func (export "growable_array_predicate_false") (result i32)
               (call $growable-array?? (ref.i31 (i32.const 84))))
         (func (export "growable_array_boolean_true_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $growable-array?
                                (call $make-growable-array (i32.const 1))))))
         (func (export "growable_array_ref_default_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $growable-array-ref/default
                                (call $make-growable-array (i32.const 1))
                                (i32.const 4)
                                (ref.i31 (i32.const 222))))))
         (func (export "growable_array_count_after_ops") (result i32)
               (local $g (ref $GrowableArray))
               (local.set $g (call $make-growable-array (i32.const 1)))
               (call $growable-array-add! (local.get $g) (ref.i31 (i32.const 20)))
               (call $growable-array-add! (local.get $g) (ref.i31 (i32.const 40)))
               (call $growable-array-insert! (local.get $g) (i32.const 1) (ref.i31 (i32.const 30)))
               (call $growable-array-set! (local.get $g) (i32.const 3) (ref.i31 (i32.const 50)))
               (call $growable-array-remove! (local.get $g) (i32.const 2))
               (drop (call $growable-array-remove-last! (local.get $g)))
               (call $growable-array-count (local.get $g)))
         (func (export "growable_array_ref_after_ops_tagged") (result i32)
               (local $g (ref $GrowableArray))
               (local.set $g (call $make-growable-array (i32.const 1)))
               (call $growable-array-add! (local.get $g) (ref.i31 (i32.const 20)))
               (call $growable-array-add! (local.get $g) (ref.i31 (i32.const 40)))
               (call $growable-array-insert! (local.get $g) (i32.const 1) (ref.i31 (i32.const 30)))
               (i31.get_s
                (ref.cast (ref i31)
                          (call $growable-array-ref (local.get $g) (i32.const 1)))))
         (func (export "growable_array_copy_tagged") (result i32)
               (local $g (ref $GrowableArray))
               (local $arr (ref $Array))
               (local.set $g (call $make-growable-array (i32.const 1)))
               (call $growable-array-add! (local.get $g) (ref.i31 (i32.const 20)))
               (call $growable-array-add! (local.get $g) (ref.i31 (i32.const 40)))
               (local.set $arr (call $growable-array->array (local.get $g)))
               (i31.get_s
                (ref.cast (ref i31)
                          (array.get $Array (local.get $arr) (i32.const 1)))))
         (func (export "array_to_growable_count") (result i32)
               (call $growable-array-count
                     (call $array->growable-array
                           (array.new_fixed $Array 2
                                            (ref.i31 (i32.const 20))
                                            (ref.i31 (i32.const 40))))))
         (func (export "i32array_length") (result i32)
               (call $i32array-length
                     (call $i32array-make (i32.const 3) (i32.const 7))))
         (func (export "i32array_ref") (result i32)
               (call $i32array-ref
                     (array.new_fixed $I32Array 2
                                      (i32.const 11)
                                      (i32.const 22))
                     (i32.const 1)))
         (func (export "i32array_set") (result i32)
               (local $arr (ref $I32Array))
               (local.set $arr (call $i32array-make (i32.const 2) (i32.const 0)))
               (call $i32array-set! (local.get $arr) (i32.const 1) (i32.const 33))
               (call $i32array-ref (local.get $arr) (i32.const 1)))
         (func (export "i32array_equal_true") (result i32)
               (call $i32array-equal?
                     (array.new_fixed $I32Array 2
                                      (i32.const 1)
                                      (i32.const 2))
                     (array.new_fixed $I32Array 2
                                      (i32.const 1)
                                      (i32.const 2))))
         (func (export "i32array_equal_false") (result i32)
               (call $i32array-equal?
                     (array.new_fixed $I32Array 2
                                      (i32.const 1)
                                      (i32.const 2))
                     (array.new_fixed $I32Array 2
                                      (i32.const 1)
                                      (i32.const 3))))
         (func (export "i32array_fill") (result i32)
               (local $arr (ref $I32Array))
               (local.set $arr (call $i32array-make (i32.const 3) (i32.const 0)))
               (call $i32array-fill! (local.get $arr) (i32.const 44))
               (call $i32array-ref (local.get $arr) (i32.const 2)))
         (func (export "i32array_copy_bang") (result i32)
               (local $dest (ref $I32Array))
               (local.set $dest (call $i32array-make (i32.const 3) (i32.const 0)))
               (call $i32array-copy!
                     (local.get $dest)
                     (i32.const 1)
                     (array.new_fixed $I32Array 2
                                      (i32.const 55)
                                      (i32.const 66))
                     (i32.const 0)
                     (i32.const 2))
               (call $i32array-ref (local.get $dest) (i32.const 2)))
         (func (export "i32array_copy_error_success") (result i32)
               (call $i32array-copy!/error
                     (call $i32array-make (i32.const 2) (i32.const 0))
                     (i32.const 0)
                     (array.new_fixed $I32Array 2
                                      (i32.const 55)
                                      (i32.const 66))
                     (i32.const 0)
                     (i32.const 2)))
         (func (export "i32array_copy_error_failure") (result i32)
               (call $i32array-copy!/error
                     (call $i32array-make (i32.const 1) (i32.const 0))
                     (i32.const 1)
                     (array.new_fixed $I32Array 2
                                      (i32.const 55)
                                      (i32.const 66))
                     (i32.const 0)
                     (i32.const 2)))
         (func (export "i32array_append_ref") (result i32)
               (call $i32array-ref
                     (call $i32array-append
                           (array.new_fixed $I32Array 1
                                            (i32.const 11))
                           (array.new_fixed $I32Array 2
                                            (i32.const 22)
                                            (i32.const 33)))
                     (i32.const 2)))
         (func (export "i32array_take_length") (result i32)
               (call $i32array-length
                     (call $i32array-take
                           (array.new_fixed $I32Array 3
                                            (i32.const 11)
                                            (i32.const 22)
                                            (i32.const 33))
                           (i32.const 2))))
         (func (export "i32array_take_right_ref") (result i32)
               (call $i32array-ref
                     (call $i32array-take-right
                           (array.new_fixed $I32Array 3
                                            (i32.const 11)
                                            (i32.const 22)
                                            (i32.const 33))
                           (i32.const 2))
                     (i32.const 0)))
         (func (export "i32array_drop_ref") (result i32)
               (call $i32array-ref
                     (call $i32array-drop
                           (array.new_fixed $I32Array 3
                                            (i32.const 11)
                                            (i32.const 22)
                                            (i32.const 33))
                           (i32.const 1))
                     (i32.const 0)))
         (func (export "i32array_drop_right_length") (result i32)
               (call $i32array-length
                     (call $i32array-drop-right
                           (array.new_fixed $I32Array 3
                                            (i32.const 11)
                                            (i32.const 22)
                                            (i32.const 33))
                           (i32.const 1))))
         (func (export "i32array_set_copy_ref") (result i32)
               (call $i32array-ref
                     (call $i32array-set/copy
                           (array.new_fixed $I32Array 2
                                            (i32.const 11)
                                            (i32.const 22))
                           (i32.const 1)
                           (i32.const 99))
                     (i32.const 1)))
         (func (export "i32array_extend_length") (result i32)
               (call $i32array-length
                     (call $i32array-extend
                           (array.new_fixed $I32Array 2
                                            (i32.const 11)
                                            (i32.const 22))
                           (i32.const 5)
                           (i32.const 0))))
         (func (export "i8array_length") (result i32)
               (call $i8array-length
                     (call $i8make-array (i32.const 3) (i32.const 7))))
         (func (export "i8array_ref_unsigned") (result i32)
               (call $i8array-ref
                     (array.new_fixed $I8Array 2
                                      (i32.const 11)
                                      (i32.const 255))
                     (i32.const 1)))
         (func (export "i8array_set") (result i32)
               (local $arr (ref $I8Array))
               (local.set $arr (call $i8make-array (i32.const 2) (i32.const 0)))
               (call $i8array-set! (local.get $arr) (i32.const 1) (i32.const 33))
               (call $i8array-ref (local.get $arr) (i32.const 1)))
         (func (export "i8array_fill") (result i32)
               (local $arr (ref $I8Array))
               (local.set $arr (call $i8make-array (i32.const 3) (i32.const 0)))
               (call $i8array-fill! (local.get $arr) (i32.const 44))
               (call $i8array-ref (local.get $arr) (i32.const 2)))
         (func (export "i8array_copy_bang") (result i32)
               (local $dest (ref $I8Array))
               (local.set $dest (call $i8make-array (i32.const 3) (i32.const 0)))
               (call $i8array-copy!
                     (local.get $dest)
                     (i32.const 1)
                     (array.new_fixed $I8Array 2
                                      (i32.const 55)
                                      (i32.const 66))
                     (i32.const 0)
                     (i32.const 2))
               (call $i8array-ref (local.get $dest) (i32.const 2)))
         (func (export "i8array_copy_error_success") (result i32)
               (call $i8array-copy!/error
                     (call $i8make-array (i32.const 2) (i32.const 0))
                     (i32.const 0)
                     (array.new_fixed $I8Array 2
                                      (i32.const 55)
                                      (i32.const 66))
                     (i32.const 0)
                     (i32.const 2)))
         (func (export "i8array_copy_error_failure") (result i32)
               (call $i8array-copy!/error
                     (call $i8make-array (i32.const 1) (i32.const 0))
                     (i32.const 1)
                     (array.new_fixed $I8Array 2
                                      (i32.const 55)
                                      (i32.const 66))
                     (i32.const 0)
                     (i32.const 2)))
         (func (export "i8array_copy_ref") (result i32)
               (call $i8array-ref
                     (call $i8array-copy
                           (array.new_fixed $I8Array 3
                                            (i32.const 11)
                                            (i32.const 22)
                                            (i32.const 33))
                           (i32.const 1)
                           (i32.const 3))
                     (i32.const 0)))
         (func (export "i8array_set_copy_ref") (result i32)
               (call $i8array-ref
                     (call $i8array-set/copy
                           (array.new_fixed $I8Array 2
                                            (i32.const 11)
                                            (i32.const 22))
                           (i32.const 1)
                           (i32.const 99))
                     (i32.const 1)))
         (func (export "i8array_extend_length") (result i32)
               (call $i8array-length
                     (call $i8array-extend
                           (array.new_fixed $I8Array 2
                                            (i32.const 11)
                                            (i32.const 22))
                           (i32.const 5)
                           (i32.const 0))))
         (func (export "i8array_append_ref") (result i32)
               (call $i8array-ref
                     (call $i8array-append
                           (array.new_fixed $I8Array 1
                                            (i32.const 11))
                           (array.new_fixed $I8Array 2
                                            (i32.const 22)
                                            (i32.const 33)))
                     (i32.const 2)))
         (func (export "i8array_to_bytes_immutable_field") (result i32)
               (struct.get $Bytes $immutable
                           (call $i8array->bytes
                                 (array.new_fixed $I8Array 2
                                                  (i32.const 11)
                                                  (i32.const 22)))))
         (func (export "i8array_to_immutable_bytes_field") (result i32)
               (struct.get $Bytes $immutable
                           (call $i8array->immutable-bytes
                                 (array.new_fixed $I8Array 2
                                                  (i32.const 11)
                                                  (i32.const 22)))))
         (func (export "i8array_to_bytes_ref") (result i32)
               (local $b (ref $Bytes))
               (local.set $b
                          (call $i8array->bytes
                                (array.new_fixed $I8Array 2
                                                 (i32.const 11)
                                                 (i32.const 22))))
               (array.get_u $I8Array
                            (struct.get $Bytes $bs (local.get $b))
                            (i32.const 1)))
         (func (export "i32growable_count_after_growth") (result i32)
               (local $g (ref $I32GrowableArray))
               (local.set $g (call $make-i32growable-array (i32.const 1)))
               (call $i32growable-array-add! (local.get $g) (i32.const 11))
               (call $i32growable-array-add! (local.get $g) (i32.const 22))
               (call $i32growable-array-add! (local.get $g) (i32.const 33))
               (call $i32growable-array-count (local.get $g)))
         (func (export "i32growable_ref_after_growth") (result i32)
               (local $g (ref $I32GrowableArray))
               (local.set $g (call $make-i32growable-array (i32.const 1)))
               (call $i32growable-array-add! (local.get $g) (i32.const 11))
               (call $i32growable-array-add! (local.get $g) (i32.const 22))
               (call $i32growable-array-add! (local.get $g) (i32.const 33))
               (call $i32growable-array-ref (local.get $g) (i32.const 2)))
         (func (export "i32growable_copy_ref") (result i32)
               (local $g (ref $I32GrowableArray))
               (local $arr (ref $I32Array))
               (local.set $g (call $make-i32growable-array (i32.const 1)))
               (call $i32growable-array-add! (local.get $g) (i32.const 11))
               (call $i32growable-array-add! (local.get $g) (i32.const 22))
               (local.set $arr (call $i32growable-array->array (local.get $g)))
               (call $i32array-ref (local.get $arr) (i32.const 1)))
         (func (export "i32array_to_growable_count") (result i32)
               (call $i32growable-array-count
                     (call $i32array->growable-array
                           (array.new_fixed $I32Array 2
                                            (i32.const 11)
                                            (i32.const 22)))))
         (func (export "i32growable_add_string_ref") (result i32)
               (local $g (ref $I32GrowableArray))
               (local.set $g (call $make-i32growable-array (i32.const 1)))
               (call $i32growable-array-add! (local.get $g) (i32.const 65))
               (call $i32growable-array-add-string!
                     (local.get $g)
                     (struct.new $String
                                 (i32.const 0)
                                 (i32.const 1)
                                 (array.new_fixed $I32Array 2
                                                  (i32.const 66)
                                                  (i32.const 67))))
               (call $i32growable-array-ref (local.get $g) (i32.const 2)))
         (func (export "growable_bytes_count_after_growth") (result i32)
               (local $g (ref $GrowableBytes))
               (local.set $g (call $make-growable-bytes (i32.const 1)))
               (call $growable-bytes-add! (local.get $g) (i32.const 11))
               (call $growable-bytes-add! (local.get $g) (i32.const 22))
               (call $growable-bytes-add! (local.get $g) (i32.const 33))
               (struct.get $GrowableBytes $i (local.get $g)))
         (func (export "growable_bytes_to_bytes_length") (result i32)
               (local $g (ref $GrowableBytes))
               (local $b (ref $Bytes))
               (local.set $g (call $make-growable-bytes (i32.const 1)))
               (call $growable-bytes-add! (local.get $g) (i32.const 11))
               (call $growable-bytes-add! (local.get $g) (i32.const 22))
               (call $growable-bytes-add! (local.get $g) (i32.const 33))
               (local.set $b (call $growable-bytes->bytes (local.get $g)))
               (array.len (struct.get $Bytes $bs (local.get $b))))
         (func (export "growable_bytes_to_bytes_ref") (result i32)
               (local $g (ref $GrowableBytes))
               (local $b (ref $Bytes))
               (local.set $g (call $make-growable-bytes (i32.const 1)))
               (call $growable-bytes-add! (local.get $g) (i32.const 11))
               (call $growable-bytes-add! (local.get $g) (i32.const 22))
               (call $growable-bytes-add! (local.get $g) (i32.const 33))
               (local.set $b (call $growable-bytes->bytes (local.get $g)))
               (array.get_u $I8Array
                            (struct.get $Bytes $bs (local.get $b))
                            (i32.const 2)))
         (func (export "growable_bytes_to_bytes_immutable_field") (result i32)
               (local $g (ref $GrowableBytes))
               (local.set $g (call $make-growable-bytes (i32.const 1)))
               (call $growable-bytes-add! (local.get $g) (i32.const 11))
               (call $growable-bytes-add! (local.get $g) (i32.const 22))
               (call $growable-bytes-add! (local.get $g) (i32.const 33))
               (struct.get $Bytes $immutable
                           (call $growable-bytes->bytes (local.get $g))))
         (func (export "i32array_to_string_immutable_field") (result i32)
               (struct.get $String $immutable
                           (call $i32array->string
                                 (array.new_fixed $I32Array 2
                                                  (i32.const 65)
                                                  (i32.const 66)))))
         (func (export "i32array_to_immutable_string_field") (result i32)
               (struct.get $String $immutable
                           (call $i32array->immutable-string
                                 (array.new_fixed $I32Array 2
                                                  (i32.const 65)
                                                  (i32.const 66)))))
         (func (export "i32array_to_string_ref") (result i32)
               (local $s (ref $String))
               (local.set $s
                          (call $i32array->string
                                (array.new_fixed $I32Array 2
                                                 (i32.const 65)
                                                 (i32.const 66))))
               (array.get $I32Array
                          (struct.get $String $codepoints (local.get $s))
                          (i32.const 1)))
         (func (export "i32growable_to_string_ref") (result i32)
               (local $g (ref $I32GrowableArray))
               (local $s (ref $String))
               (local.set $g (call $make-i32growable-array (i32.const 1)))
               (call $i32growable-array-add! (local.get $g) (i32.const 65))
               (call $i32growable-array-add! (local.get $g) (i32.const 66))
               (local.set $s (call $i32growable-array->string (local.get $g)))
               (array.get $I32Array
                          (struct.get $String $codepoints (local.get $s))
                          (i32.const 1)))
         (func (export "i32growable_to_immutable_string_field") (result i32)
               (local $g (ref $I32GrowableArray))
               (local.set $g (call $make-i32growable-array (i32.const 1)))
               (call $i32growable-array-add! (local.get $g) (i32.const 65))
               (call $i32growable-array-add! (local.get $g) (i32.const 66))
               (struct.get $String $immutable
                           (call $i32growable-array->immutable-string
                                 (local.get $g))))
         ,(tagged-call2-export "fxand_tagged" '$fxand/2 84 20)
         ,(tagged-call2-export "fxior_tagged" '$fxior/2 84 20)
         ,(tagged-call2-export "fxxor_tagged" '$fxxor/2 84 20)
         ,(tagged-call1-export "fxnot_tagged" '$fxnot 84)
         ,(tagged-call2-export "fxlshift_tagged" '$fxlshift 84 4)
         ,(tagged-call2-export "fxrshift_tagged" '$fxrshift 84 4)
         ,(tagged-call2-export "fxrshift_negative_tagged" '$fxrshift -84 4)
         ,(tagged-call1-export "fxpopcount_tagged" '$fxpopcount 14)
         ,(tagged-call1-export "fxpopcount32_tagged" '$fxpopcount32 14)
         ,(tagged-call1-export "fxpopcount16_tagged" '$fxpopcount16 14)
         ,(tagged-call2-export "fx_plus_wraparound_tagged" '$fx+/wraparound 84 20)
         ,(tagged-call2-export "fx_times_wraparound_tagged" '$fx*/wraparound 84 20)
         ,(tagged-call2-export "fxlshift_wraparound_tagged" '$fxlshift/wraparound 84 4)
         ,(tagged-call2-export "fxrshift_logical_tagged" '$fxrshift/logical 84 4)
         ,(tagged-call1-export "unsafe_fxnot_tagged" '$unsafe-fxnot 84)
         ,(tagged-call1-export "unsafe_fxpopcount_tagged" '$unsafe-fxpopcount 14)
         ,(tagged-call1-export "unsafe_fxpopcount32_tagged" '$unsafe-fxpopcount32 14)
         ,(tagged-call1-export "unsafe_fxpopcount16_tagged" '$unsafe-fxpopcount16 14)
         ,(tagged-call2-export "unsafe_fxlshift_tagged" '$unsafe-fxlshift 84 4)
         ,(tagged-call2-export "unsafe_fx_plus_wraparound_tagged" '$unsafe-fx+/wraparound 84 20)
         ,(tagged-call2-export "unsafe_fx_times_wraparound_tagged" '$unsafe-fx*/wraparound 84 20)
         ,(tagged-call2-export "unsafe_fxlshift_wraparound_tagged" '$unsafe-fxlshift/wraparound 84 4)
         ,(tagged-call2-export "unsafe_fxrshift_tagged" '$unsafe-fxrshift 84 4)
         ,(tagged-call2-export "unsafe_fxrshift_negative_tagged" '$unsafe-fxrshift -84 4)
         ,(tagged-call2-export "unsafe_fxrshift_logical_tagged" '$unsafe-fxrshift/logical 84 4)))

    (define consumer-wat-path
      (make-temporary-file "webracket-core-runtime-consumer-test-~a.wat"))
    (define consumer-wasm-path
      (path-replace-extension consumer-wat-path ".wasm"))
    (check-true (wat->wasm split-consumer-module
                           #:wat consumer-wat-path
                           #:wasm consumer-wasm-path))
    (check-true (file-exists? consumer-wasm-path))

    (define node-path (find-executable-path "node"))
    (when node-path
      (define node-script-path
        (make-temporary-file "webracket-core-runtime-link-test-~a.mjs"))
      (with-output-to-file node-script-path
        (lambda ()
          (display
           #<<JS
import fs from "node:fs/promises";

const [corePath, consumerPath] = process.argv.slice(2);
const coreBytes = await fs.readFile(corePath);
const consumerBytes = await fs.readFile(consumerPath);
const core = await WebAssembly.instantiate(coreBytes, {});
const consumer = await WebAssembly.instantiate(
  consumerBytes,
  { core: core.instance.exports },
);

const expected = new Map([
  ["fx_fixnum_true", 1],
  ["fx_immediate_false", 0],
  ["fx_heap_false", 0],
  ["fixnum_fixnum_true", 1],
  ["fixnum_immediate_false", 0],
  ["fl_flonum_true", 1],
  ["fl_fixnum_false", 0],
  ["keyword_keyword_true", 1],
  ["keyword_fixnum_false", 0],
  ["vector_vector_true", 1],
  ["vector_fixnum_false", 0],
  ["struct_type_true", 1],
  ["struct_type_fixnum_false", 0],
  ["struct_struct_type_false", 0],
  ["struct_fixnum_false", 0],
  ["array_length", 3],
  ["array_ref_tagged", 40],
  ["array_set_ref_tagged", 60],
  ["array_fill_ref_tagged", 80],
  ["array_copy_bang_tagged", 40],
  ["array_copy_error_success", 1],
  ["array_copy_error_failure", 0],
  ["array_append_ref_tagged", 60],
  ["array_append_all_ref_tagged", 60],
  ["array_take_length", 2],
  ["array_take_right_ref_tagged", 40],
  ["array_drop_ref_tagged", 40],
  ["array_drop_right_length", 2],
  ["array_split_at_second_length", 2],
  ["array_copy_ref_tagged", 40],
  ["array_set_copy_ref_tagged", 80],
  ["array_extend_length", 5],
  ["growable_array_predicate_true", 1],
  ["growable_array_predicate_false", 0],
  ["growable_array_boolean_true_tagged", 159],
  ["growable_array_ref_default_tagged", 222],
  ["growable_array_count_after_ops", 2],
  ["growable_array_ref_after_ops_tagged", 30],
  ["growable_array_copy_tagged", 40],
  ["array_to_growable_count", 2],
  ["i32array_length", 3],
  ["i32array_ref", 22],
  ["i32array_set", 33],
  ["i32array_equal_true", 1],
  ["i32array_equal_false", 0],
  ["i32array_fill", 44],
  ["i32array_copy_bang", 66],
  ["i32array_copy_error_success", 1],
  ["i32array_copy_error_failure", 0],
  ["i32array_append_ref", 33],
  ["i32array_take_length", 2],
  ["i32array_take_right_ref", 22],
  ["i32array_drop_ref", 22],
  ["i32array_drop_right_length", 2],
  ["i32array_set_copy_ref", 99],
  ["i32array_extend_length", 5],
  ["i8array_length", 3],
  ["i8array_ref_unsigned", 255],
  ["i8array_set", 33],
  ["i8array_fill", 44],
  ["i8array_copy_bang", 66],
  ["i8array_copy_error_success", 1],
  ["i8array_copy_error_failure", 0],
  ["i8array_copy_ref", 22],
  ["i8array_set_copy_ref", 99],
  ["i8array_extend_length", 5],
  ["i8array_append_ref", 33],
  ["i8array_to_bytes_immutable_field", 0],
  ["i8array_to_immutable_bytes_field", 1],
  ["i8array_to_bytes_ref", 22],
  ["i32growable_count_after_growth", 3],
  ["i32growable_ref_after_growth", 33],
  ["i32growable_copy_ref", 22],
  ["i32array_to_growable_count", 2],
  ["i32growable_add_string_ref", 67],
  ["growable_bytes_count_after_growth", 3],
  ["growable_bytes_to_bytes_length", 3],
  ["growable_bytes_to_bytes_ref", 33],
  ["growable_bytes_to_bytes_immutable_field", 3],
  ["i32array_to_string_immutable_field", 0],
  ["i32array_to_immutable_string_field", 1],
  ["i32array_to_string_ref", 66],
  ["i32growable_to_string_ref", 66],
  ["i32growable_to_immutable_string_field", 1],
  ["fxand_tagged", 20],
  ["fxior_tagged", 84],
  ["fxxor_tagged", 64],
  ["fxnot_tagged", -86],
  ["fxlshift_tagged", 336],
  ["fxrshift_tagged", 20],
  ["fxrshift_negative_tagged", -22],
  ["fxpopcount_tagged", 6],
  ["fxpopcount32_tagged", 6],
  ["fxpopcount16_tagged", 6],
  ["fx_plus_wraparound_tagged", 104],
  ["fx_times_wraparound_tagged", 840],
  ["fxlshift_wraparound_tagged", 336],
  ["fxrshift_logical_tagged", 20],
  ["unsafe_fxnot_tagged", -86],
  ["unsafe_fxpopcount_tagged", 6],
  ["unsafe_fxpopcount32_tagged", 6],
  ["unsafe_fxpopcount16_tagged", 6],
  ["unsafe_fxlshift_tagged", 336],
  ["unsafe_fx_plus_wraparound_tagged", 104],
  ["unsafe_fx_times_wraparound_tagged", 840],
  ["unsafe_fxlshift_wraparound_tagged", 336],
  ["unsafe_fxrshift_tagged", 20],
  ["unsafe_fxrshift_negative_tagged", -22],
  ["unsafe_fxrshift_logical_tagged", 20],
]);

for (const [name, value] of expected) {
  const actual = consumer.instance.exports[name]();
  if (actual !== value) {
    throw new Error(`${name}: expected ${value}, got ${actual}`);
  }
}
JS
           ))
        #:exists 'replace)
      (check-equal?
       (system*/exit-code node-path
                          (path->string node-script-path)
                          (path->string core-wasm-path)
                          (path->string consumer-wasm-path))
       0))))
