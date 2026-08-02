#lang racket

(provide impersonator-runtime-string-constants
         impersonator-runtime-symbol-constants
         impersonator-primitive-global-forms
         impersonator-primitive-global-names
         impersonator-core-runtime-helpers
         impersonator-core-runtime-helper-forms
         impersonator-basic-runtime-only-helper-names
         impersonator-basic-runtime-helper-forms
         chaperone-procedure-runtime-only-helper-names
         chaperone-procedure-runtime-helper-forms
         impersonator-runtime-only-helpers)

(require "../core-helper.rkt")

;; impersonator-global-form-name : datum? -> symbol?
;;   Return the Wasm global name declared by an impersonator support global form.
(define (impersonator-global-form-name form)
  (match form
    [`(global ,name . ,_) name]
    [_ (error 'impersonator-global-form-name
              "expected global form, got: ~s"
              form)]))

;; impersonator-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by impersonator and chaperone helpers.
(define impersonator-runtime-string-constants
  '((impersonator-property? "impersonator-property?")
    (impersonators-unsupported "impersonators are not supported by WebRacket")
    (procedure-arity-2 "(procedure-arity-includes/c 2)")
    (procedure-arity-3 "(procedure-arity-includes/c 3)")
    (procedure-arity-3-or-false "(or/c (procedure-arity-includes/c 3) #f)")))

;; impersonator-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by impersonator and chaperone helpers.
(define impersonator-runtime-symbol-constants
  '(chaperone?))

;; impersonator-primitive-global-forms : (listof datum?)
;;   Declare primitive procedure globals used by inert impersonator-property helpers.
(define impersonator-primitive-global-forms
  '(
    (global $prim:webracket-impersonator-property-predicate (mut (ref eq)) (global.get $undefined))
    (global $prim:webracket-impersonator-property-accessor  (mut (ref eq)) (global.get $undefined))))

;; impersonator-primitive-global-names : (listof symbol?)
;;   Enumerate impersonator primitive procedure globals shared by split modules.
(define impersonator-primitive-global-names
  (map impersonator-global-form-name impersonator-primitive-global-forms))

;; impersonator-basic-all-runtime-helper-names : (listof symbol?)
;;   Preserve the full runtime emission order for basic impersonator helpers.
(define impersonator-basic-all-runtime-helper-names
  '($impersonator?
    $procedure-impersonator*?
    $chaperone?
    $impersonator-val
    $make-impersonator-property
    $impersonator-property?
    $impersonator-property-accessor-procedure?
    $webracket-impersonator-property-predicate
    $webracket-impersonator-property-accessor))

;; chaperone-procedure-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for chaperone procedure helpers.
(define chaperone-procedure-runtime-only-helper-names
  '($check-procedure-arity-or-false
    $check-chaperone-hash-required-callbacks
    $chaperone-procedure
    $chaperone-struct
    $chaperone-vector
    $chaperone-box
    $chaperone-hash
    $unsafe-chaperone-procedure
    $unsafe-impersonate-procedure))

;; impersonator-core-runtime-helper-names : (listof symbol?)
;;   Name inert impersonator helpers available in the standalone core runtime.
(define impersonator-core-runtime-helper-names
  '($impersonator?
    $procedure-impersonator*?
    $chaperone?
    $make-impersonator-property
    $impersonator-property?
    $impersonator-property-accessor-procedure?
    $webracket-impersonator-property-predicate
    $check-procedure-arity))

;; impersonator-basic-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime-only emission order for basic impersonator helpers.
(define impersonator-basic-runtime-only-helper-names
  (remove* impersonator-core-runtime-helper-names
           impersonator-basic-all-runtime-helper-names))

;; impersonator-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate all inert impersonator and chaperone support helpers.
(define impersonator-all-runtime-helpers
  (function-forms->runtime-helpers
   'impersonator-all-runtime-helpers
   '(
     (func $impersonator? (type $Prim1)
           (param $v (ref eq)) ;; any value
           (result   (ref eq)) ;; always #f; WebRacket has no impersonators
           (global.get $false))

     ;; procedure-impersonator*? : any/c -> boolean?
     ;;   Recognize procedure impersonators, including those created through
     ;;   prop:impersonator-of. WebRacket has no impersonators yet, so the
     ;;   conservative result is always #f.
     (func $procedure-impersonator*? (type $Prim1)
           (param $v (ref eq)) ;; any value
           (result   (ref eq))
           (global.get $false))

     (func $chaperone? (type $Prim1)
           (param $v (ref eq)) ;; any value
           (result   (ref eq)) ;; always #f; WebRacket has no chaperones
           (global.get $false))

     (func $impersonator-val (type $Prim1)
           (param $v (ref eq)) ;; unsupported impersonator value
           (result   (ref eq))
           (drop (call $raise
                       (call $exn:fail:unsupported/make
                             (global.get $string:impersonators-unsupported)
                             (call $current-continuation-marks
                                   (global.get $missing)))
                       (global.get $true)))
           (unreachable))

     ;; make-impersonator-property : symbol? -> values impersonator-property? procedure? procedure?
     ;;   Allocate a property descriptor and return inert predicate/accessor
     ;;   procedures. WebRacket has no impersonators yet, so the predicate
     ;;   always returns #f and the accessor only supports the documented
     ;;   fallback path.
     (func $make-impersonator-property (type $Prim1)
           (param $name (ref eq)) ;; symbol?
           (result      (ref eq)) ;; three values

           (if (ref.eq (call $symbol? (local.get $name)) (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:make-impersonator-property)
                           (global.get $string:symbol?)
                           (local.get $name))
                     (unreachable)))
           (array.new_fixed $Values 3
                            (struct.new $ImpersonatorProperty
                                        (i32.const 0)
                                        (local.get $name))
                            (global.get $prim:webracket-impersonator-property-predicate)
                            (global.get $prim:webracket-impersonator-property-accessor)))

     ;; impersonator-property? : any/c -> boolean?
     ;;   Recognize WebRacket's inert impersonator-property descriptors.
     (func $impersonator-property? (type $Prim1)
           (param $v (ref eq)) ;; candidate value
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $ImpersonatorProperty) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     ;; impersonator-property-accessor-procedure? : any/c -> boolean?
     ;;   The only accessor procedure WebRacket can currently produce is
     ;;   the inert fallback accessor returned by make-impersonator-property.
     (func $impersonator-property-accessor-procedure? (type $Prim1)
           (param $v (ref eq)) ;; candidate value
           (result   (ref eq))
           (if (result (ref eq))
               (ref.eq (local.get $v)
                       (global.get $prim:webracket-impersonator-property-accessor))
               (then (global.get $true))
               (else (global.get $false))))

     ;; webracket-impersonator-property-predicate : any/c -> boolean?
     ;;   Inert predicate for the no-impersonator runtime.
     (func $webracket-impersonator-property-predicate (type $Prim1)
           (param $v (ref eq)) ;; any value
           (result   (ref eq))
           (global.get $false))

     ;; webracket-impersonator-property-accessor : any/c [any/c] -> any/c
     ;;   Inert accessor. With no fallback, Racket raises; with a fallback
     ;;   procedure it tail-calls the procedure with zero arguments,
     ;;   otherwise it returns the fallback value.
     (func $webracket-impersonator-property-accessor (type $Prim12)
           (param $v        (ref eq)) ;; any value
           (param $fallback (ref eq)) ;; optional fallback, default = raise
           (result          (ref eq))

           (local $proc (ref $Procedure))
           (local $inv  (ref $ProcedureInvoker))

           (if (ref.eq (local.get $fallback) (global.get $missing))
               (then (call $raise-argument-error1
                           (global.get $symbol:webracket-impersonator-property-accessor)
                           (global.get $string:impersonator-property?)
                           (local.get $v))
                     (unreachable)))
           (if (ref.eq (call $procedure? (local.get $fallback)) (global.get $true))
               (then
                (local.set $proc (ref.cast (ref $Procedure) (local.get $fallback)))
                (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))
                (return_call_ref $ProcedureInvoker
                                 (local.get $proc)
                                 (array.new_fixed $Args 0)
                                 (local.get $inv))))
           (local.get $fallback))

     ;; check-procedure-arity : symbol? string? any/c exact-nonnegative-integer? -> void?
     ;;   Validate that a callback is a procedure accepting argc arguments.
     (func $check-procedure-arity
           (param $who      (ref eq)) ;; primitive name for errors
           (param $expected (ref eq)) ;; expected contract text
           (param $v        (ref eq)) ;; candidate procedure
           (param $argc     i32)      ;; required arity

           (local $proc (ref $Procedure))

          (if (ref.eq (call $procedure? (local.get $v)) (global.get $false))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (local.get $expected)
                           (local.get $v))
                     (unreachable)))
           (local.set $proc (ref.cast (ref $Procedure) (local.get $v)))
           (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                              (local.get $proc)
                              (local.get $argc)))
               (then (call $raise-argument-error1
                           (local.get $who)
                           (local.get $expected)
                           (local.get $v))
                     (unreachable))))

     ;; check-procedure-arity-or-false : symbol? string? any/c exact-nonnegative-integer? -> void?
     ;;   Validate a callback that can also be #f.
     (func $check-procedure-arity-or-false
           (param $who      (ref eq)) ;; primitive name for errors
           (param $expected (ref eq)) ;; expected contract text
           (param $v        (ref eq)) ;; candidate procedure or #f
           (param $argc     i32)      ;; required arity

           (if (ref.eq (local.get $v) (global.get $false))
               (then (return)))
           (call $check-procedure-arity
                 (local.get $who)
                 (local.get $expected)
                 (local.get $v)
                 (local.get $argc)))

     ;; check-chaperone-hash-required-callbacks : list? -> void?
     ;;   Validate the remove and key callbacks carried in the variadic tail.
     (func $check-chaperone-hash-required-callbacks
           (param $rest (ref eq)) ;; remove/key/optional/property arguments

           (local $cell        (ref $Pair))
           (local $remove-proc (ref eq))
           (local $key-proc    (ref eq))

           (if (i32.eqz (ref.test (ref $Pair) (local.get $rest)))
               (then (call $raise-argument-error1
                           (global.get $symbol:chaperone-hash)
                           (global.get $string:procedure-arity-2)
                           (local.get $rest))
                     (unreachable)))
           (local.set $cell (ref.cast (ref $Pair) (local.get $rest)))
           (local.set $remove-proc (struct.get $Pair $a (local.get $cell)))
           (local.set $rest (struct.get $Pair $d (local.get $cell)))

           (call $check-procedure-arity
                 (global.get $symbol:chaperone-hash)
                 (global.get $string:procedure-arity-2)
                 (local.get $remove-proc)
                 (i32.const 2))

           (if (i32.eqz (ref.test (ref $Pair) (local.get $rest)))
               (then (call $raise-argument-error1
                           (global.get $symbol:chaperone-hash)
                           (global.get $string:procedure-arity-2)
                           (local.get $rest))
                     (unreachable)))
           (local.set $cell (ref.cast (ref $Pair) (local.get $rest)))
           (local.set $key-proc (struct.get $Pair $a (local.get $cell)))
           (call $check-procedure-arity
                 (global.get $symbol:chaperone-hash)
                 (global.get $string:procedure-arity-2)
                 (local.get $key-proc)
                 (i32.const 2)))

     ;; chaperone-procedure : procedure? (or/c procedure? #f) any/c ... -> procedure?
     ;;   Reference chaperones interpose on calls while preserving
     ;;   chaperone-of? constraints. WebRacket does not implement real
     ;;   chaperones yet, so use the same Goal-1 bridge as the unsafe
     ;;   variant: a wrapper procedure becomes the callable result, and
     ;;   #f means "no interposition", so the original procedure is kept.
     (func $chaperone-procedure (type $Prim>=2)
           (param $proc    (ref eq)) ;; original procedure
           (param $wrapper (ref eq)) ;; wrapper procedure or #f
           (param $props   (ref eq)) ;; ignored property/value list
           (result         (ref eq))

           (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
               (then (call $raise-argument-error:procedure-expected/who
                           (global.get $symbol:chaperone-procedure)
                           (local.get $proc))
                     (unreachable)))
           (if (ref.eq (local.get $wrapper) (global.get $false))
               (then (return (local.get $proc))))
           (if (ref.eq (call $procedure? (local.get $wrapper)) (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:chaperone-procedure)
                           (global.get $string:procedure-or-false?)
                           (local.get $wrapper))
                     (unreachable)))
           (local.get $wrapper))

     ;; chaperone-struct : any/c any/c ... -> any/c
     ;;   Full Racket interposes on struct accessors, mutators, property
     ;;   accessors, and struct-info. WebRacket has no chaperone wrappers
     ;;   yet; for Goal 1, preserve identity and ignore interposition so
     ;;   contract-heavy libraries can instantiate their helper structs.
     (func $chaperone-struct (type $Prim>=1)
           (param $v    (ref eq)) ;; value to chaperone
           (param $args (ref eq)) ;; ignored struct/type/proc/property args
           (result      (ref eq))

           (local.get $v))

     ;; chaperone-vector : vector? (or/c procedure? #f) (or/c procedure? #f) any/c ... -> vector?
     ;;   Goal-1 identity bridge. Full Racket interposes on vector ref/set;
     ;;   WebRacket currently has no chaperone wrapper representation.
     (func $chaperone-vector (type $Prim>=3)
           (param $vec      (ref eq)) ;; vector?
           (param $ref-proc (ref eq)) ;; ignored ref interposer
           (param $set-proc (ref eq)) ;; ignored set interposer
           (param $props    (ref eq)) ;; ignored property/value list
           (result          (ref eq))

           (if (i32.eqz (ref.test (ref $Vector) (local.get $vec)))
               (then (call $raise-argument-error1
                           (global.get $symbol:chaperone-vector)
                           (global.get $string:vector?)
                           (local.get $vec))
                     (unreachable)))
           (call $check-procedure-arity-or-false
                 (global.get $symbol:chaperone-vector)
                 (global.get $string:procedure-arity-3-or-false)
                 (local.get $ref-proc)
                 (i32.const 3))
           (call $check-procedure-arity-or-false
                 (global.get $symbol:chaperone-vector)
                 (global.get $string:procedure-arity-3-or-false)
                 (local.get $set-proc)
                 (i32.const 3))
           (local.get $vec))

     ;; chaperone-box : box? procedure? procedure? any/c ... -> box?
     ;;   Goal-1 identity bridge. Full Racket interposes on unbox/set-box!;
     ;;   WebRacket currently has no chaperone wrapper representation.
     (func $chaperone-box (type $Prim>=3)
           (param $box        (ref eq)) ;; box?
           (param $unbox-proc (ref eq)) ;; ignored unbox interposer
           (param $set-proc   (ref eq)) ;; ignored set interposer
           (param $props      (ref eq)) ;; ignored property/value list
           (result            (ref eq))

           (if (i32.eqz (ref.test (ref $Box) (local.get $box)))
               (then (call $raise-argument-error1
                           (global.get $symbol:chaperone-box)
                           (global.get $string:box?)
                           (local.get $box))
                     (unreachable)))
           (call $check-procedure-arity
                 (global.get $symbol:chaperone-box)
                 (global.get $string:procedure-arity-2)
                 (local.get $unbox-proc)
                 (i32.const 2))
           (call $check-procedure-arity
                 (global.get $symbol:chaperone-box)
                 (global.get $string:procedure-arity-2)
                 (local.get $set-proc)
                 (i32.const 2))
           (local.get $box))

     ;; chaperone-hash : hash? procedure? procedure? procedure? procedure? any/c ... -> hash?
     ;;   Goal-1 identity bridge. Full Racket interposes on hash access,
     ;;   update, remove, key extraction, and optional clear/equal-key
     ;;   operations; WebRacket currently keeps the original hash.
     (func $chaperone-hash (type $Prim>=3)
           (param $hash     (ref eq)) ;; hash?
           (param $ref-proc (ref eq)) ;; ignored ref interposer
           (param $set-proc (ref eq)) ;; ignored set interposer
           (param $rest     (ref eq)) ;; remove/key/optional/properties
           (result          (ref eq))

           (if (ref.eq (call $hash? (local.get $hash)) (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:chaperone-hash)
                           (global.get $string:hash?)
                           (local.get $hash))
                     (unreachable)))
           (call $check-procedure-arity
                 (global.get $symbol:chaperone-hash)
                 (global.get $string:procedure-arity-2)
                 (local.get $ref-proc)
                 (i32.const 2))
           (call $check-procedure-arity
                 (global.get $symbol:chaperone-hash)
                 (global.get $string:procedure-arity-3)
                 (local.get $set-proc)
                 (i32.const 3))
           (call $check-chaperone-hash-required-callbacks
                 (local.get $rest))
           (local.get $hash))

     ;; unsafe-chaperone-procedure : procedure? procedure? any/c ... -> procedure?
     ;;   WebRacket does not implement chaperones yet. Preserve the useful
     ;;   contract-wrapper behavior by returning the wrapper procedure,
     ;;   which is responsible for delegating to the original procedure.
     (func $unsafe-chaperone-procedure (type $Prim>=2)
           (param $proc    (ref eq)) ;; original procedure
           (param $wrapper (ref eq)) ;; replacement/wrapper procedure
           (param $props   (ref eq)) ;; ignored property/value list
           (result         (ref eq))

           (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
               (then (call $raise-argument-error:procedure-expected/who
                           (global.get $symbol:unsafe-chaperone-procedure)
                           (local.get $proc))
                     (unreachable)))
           (if (ref.eq (call $procedure? (local.get $wrapper)) (global.get $false))
               (then (call $raise-argument-error:procedure-expected/who
                           (global.get $symbol:unsafe-chaperone-procedure)
                           (local.get $wrapper))
                     (unreachable)))
           (local.get $wrapper))

     ;; unsafe-impersonate-procedure : procedure? procedure? any/c ... -> procedure?
     ;;   Same temporary representation as unsafe-chaperone-procedure.
     (func $unsafe-impersonate-procedure (type $Prim>=2)
           (param $proc    (ref eq)) ;; original procedure
           (param $wrapper (ref eq)) ;; replacement procedure
           (param $props   (ref eq)) ;; ignored property/value list
           (result         (ref eq))

           (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
               (then (call $raise-argument-error:procedure-expected/who
                           (global.get $symbol:unsafe-impersonate-procedure)
                           (local.get $proc))
                     (unreachable)))
           (if (ref.eq (call $procedure? (local.get $wrapper)) (global.get $false))
               (then (call $raise-argument-error:procedure-expected/who
                           (global.get $symbol:unsafe-impersonate-procedure)
                           (local.get $wrapper))
                     (unreachable)))
           (local.get $wrapper)))))

;; impersonator-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate inert impersonator helpers available in the standalone core runtime.
(define impersonator-core-runtime-helpers
  (select-runtime-helpers impersonator-all-runtime-helpers
                          impersonator-core-runtime-helper-names))

;; impersonator-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate inert impersonator and chaperone support helpers that still depend on monolithic runtime definitions.
(define impersonator-runtime-only-helpers
  (remove-runtime-helpers impersonator-all-runtime-helpers
                          impersonator-core-runtime-helper-names))

;; impersonator-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given impersonator helper names from the runtime helper index.
(define (impersonator-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; impersonator-basic-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render basic impersonator helpers in runtime assembly order.
(define (impersonator-basic-runtime-helper-forms helper-index)
  (impersonator-helper-forms helper-index impersonator-basic-runtime-only-helper-names))

;; impersonator-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted impersonator helpers in runtime assembly order.
(define (impersonator-core-runtime-helper-forms helper-index)
  (impersonator-helper-forms helper-index impersonator-core-runtime-helper-names))

;; chaperone-procedure-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render chaperone procedure helpers in runtime assembly order.
(define (chaperone-procedure-runtime-helper-forms helper-index)
  (impersonator-helper-forms helper-index chaperone-procedure-runtime-only-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define impersonator-helper-index
    (make-core-runtime-helper-index
     (append impersonator-core-runtime-helpers
             impersonator-runtime-only-helpers)))

  (define impersonator-core-helper-index
    (make-core-runtime-helper-index impersonator-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name impersonator-core-runtime-helpers)
   impersonator-core-runtime-helper-names)

  (check-equal?
   impersonator-primitive-global-names
   '($prim:webracket-impersonator-property-predicate
     $prim:webracket-impersonator-property-accessor))

  (check-equal?
   (map form-name
        (impersonator-core-runtime-helper-forms impersonator-core-helper-index))
   impersonator-core-runtime-helper-names)

  (check-equal?
   (map form-name
        (impersonator-basic-runtime-helper-forms impersonator-helper-index))
   impersonator-basic-runtime-only-helper-names)

  (check-equal?
   (map form-name
        (chaperone-procedure-runtime-helper-forms impersonator-helper-index))
   chaperone-procedure-runtime-only-helper-names))
