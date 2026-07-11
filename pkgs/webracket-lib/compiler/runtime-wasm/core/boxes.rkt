#lang racket

(provide box-runtime-string-constants
         box-runtime-helper-forms
         box-mutability-runtime-helper-forms
         box-runtime-only-helpers)

(require "../core-helper.rkt")

;; box-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by box helpers and box errors.
(define box-runtime-string-constants
  '((boxed?                    "boxed?")
    (box?                      "box?")
    (mutable-box?              "(and/c box? (not/c immutable?))")
    (box-not-impersonator?     "(and/c box? (not impersonator?))")
    (mutable-box-not-impersonator?
     "(and/c box? (not immutable?) (not impersonator?))")
    (weak-box?                 "weak-box?")
    (use-before-initialization "undefined; cannot use before initialization")))

;; box-base-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate box helpers that still depend on monolithic runtime globals.
(define box-base-runtime-only-helpers
  (list
   (core-runtime-helper
    '$raise-letrec-placeholder-access
    "$raise-letrec-placeholder-access"
    (lambda ()
      `(func $raise-letrec-placeholder-access
             (drop (call $raise
                         (call $exn:fail:contract:variable
                               (global.get $string:use-before-initialization)
                               (call $current-continuation-marks
                                     (global.get $missing))
                               (global.get $symbol:exn:fail:contract:variable))
                         (global.get $true)))
             (unreachable))))


   (core-runtime-helper
    '$boxed
    "$boxed"
    (lambda ()
      `(func $boxed (type $Prim1) (param $v (ref eq))  (result (ref eq))
             (struct.new $Boxed (local.get $v)))))


   (core-runtime-helper
    '$unboxed
    "$unboxed"
    (lambda ()
      `(func $unboxed (type $Prim1) (param $b (ref eq))  (result (ref eq))
             (local $B (ref $Boxed))
             (local $v (ref eq))
             (local.set $B
                        (block $ok (result (ref $Boxed))
                          (br_on_cast $ok (ref eq) (ref $Boxed) (local.get $b))
                          (call $raise-argument-error1
                                (global.get $symbol:unboxed)
                                (global.get $string:boxed?)
                                (local.get $b))
                          (unreachable)))
             (local.set $v (struct.get $Boxed $v (local.get $B)))
             ;; Compiler boxes use `unsafe-undefined` as an ordinary
             ;; sentinel value. The compiler inserts explicit
             ;; `check-not-unsafe-undefined` guards where early reads must
             ;; fail, so internal box reads must expose the sentinel rather
             ;; than raising here.
             (local.get $v))))


   (core-runtime-helper
    '$set-boxed!
    "$set-boxed!"
    (lambda ()
      `(func $set-boxed! (type $Prim2)
             ; todo: make this return no values
             ;       problem: set-boxed! is currently wrapped by drop in
             ;                the code generator. Add an rule that avoids
             ;                the drop for set-boxed!.
             ;; Internal compiler boxes use unsafe-undefined as a placeholder.
             ;; Reads through $unboxed are guarded above; writes must be able
             ;; to fill the placeholder for Schemify/Webify lowered modules.
             (param $b (ref eq)) (param $v (ref eq))
             (result (ref eq))
             ; 1. Cast $b into a (ref $Boxed)
             (local $B (ref $Boxed))
             (local.set $B
                        (block $ok (result (ref $Boxed))
                               (br_on_cast $ok (ref eq) (ref $Boxed) (local.get $b))
                               (call $raise-argument-error1
                                     (global.get $symbol:set-boxed!)
                                     (global.get $string:boxed?)
                                     (local.get $b))
                               (unreachable)))
             ; 2. Set the contents
             (struct.set $Boxed $v (local.get $B) (local.get $v))
             ; 3. Return `void`
             (global.get $void))))


   (core-runtime-helper
    '$initialize-boxed!
    "$initialize-boxed!"
    (lambda ()
      `(func $initialize-boxed! (type $Prim2)
             (param $b (ref eq)) (param $v (ref eq))
             (result (ref eq))
             (local $B (ref $Boxed))
             (local.set $B
                        (block $ok (result (ref $Boxed))
                               (br_on_cast $ok (ref eq) (ref $Boxed) (local.get $b))
                               (call $raise-argument-error1
                                     (global.get $symbol:initialize-boxed!)
                                     (global.get $string:boxed?)
                                     (local.get $b))
                               (unreachable)))
             (struct.set $Boxed $v (local.get $B) (local.get $v))
             (global.get $void))))



   (core-runtime-helper
    '$boxed?
    "$boxed?"
    (lambda ()
      `(func $boxed? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $Boxed) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;;;
   ;;; 4.14 Boxes
   ;;;

   ;; https://docs.racket-lang.org/reference/boxes.html

   (core-runtime-helper
    '$raise-box-expected/who
    "$raise-box-expected/who"
    (lambda ()
      `(func $raise-box-expected/who
             (param $who (ref eq))
             (param $x   (ref eq))
             (call $raise-argument-error1
                   (local.get $who)
                   (global.get $string:box?)
                   (local.get $x)))))


   (core-runtime-helper
    '$raise-unbox*:box-expected
    "$raise-unbox*:box-expected"
    (lambda ()
      `(func $raise-unbox*:box-expected
             (param $x (ref eq))
             (call $raise-argument-error1
                   (global.get $symbol:unbox*)
                   (global.get $string:box-not-impersonator?)
                   (local.get $x)))))


   (core-runtime-helper
    '$raise-mutable-box-expected/who
    "$raise-mutable-box-expected/who"
    (lambda ()
      `(func $raise-mutable-box-expected/who
             (param $who (ref eq))
             (param $x   (ref eq))
             (call $raise-argument-error1
                   (local.get $who)
                   (global.get $string:mutable-box?)
                   (local.get $x)))))


   (core-runtime-helper
    '$raise-set-box*!:mutable-box-expected
    "$raise-set-box*!:mutable-box-expected"
    (lambda ()
      `(func $raise-set-box*!:mutable-box-expected
             (param $x (ref eq))
             (call $raise-argument-error1
                   (global.get $symbol:set-box*!)
                   (global.get $string:mutable-box-not-impersonator?)
                   (local.get $x)))))


   (core-runtime-helper
    '$raise-weak-box-expected/who
    "$raise-weak-box-expected/who"
    (lambda ()
      `(func $raise-weak-box-expected/who
             (param $who (ref eq))
             (param $x   (ref eq))
             (call $raise-argument-error1
                   (local.get $who)
                   (global.get $string:weak-box?)
                   (local.get $x)))))


   (core-runtime-helper
    '$box?
    "$box?"
    (lambda ()
      `(func $box? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $Box) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   (core-runtime-helper
    '$box
    "$box"
    (lambda ()
      `(func $box (type $Prim1) (param $v (ref eq))  (result (ref eq))
             (struct.new $Box
                         (i32.const 0)       ;; $hash
                         (i32.const 0)       ;; $immutable (mutable = not immmutable)
                         (local.get $v)))))


   (core-runtime-helper
    '$box-immutable
    "$box-immutable"
    (lambda ()
      `(func $box-immutable (type $Prim1) (param $v (ref eq))  (result (ref eq))
             (struct.new $Box
                         (i32.const 0)       ;; $hash
                         (i32.const 1)       ;; $immutable
                         (local.get $v)))))


   (core-runtime-helper
    '$unbox
    "$unbox"
    (lambda ()
      `(func $unbox (type $Prim1) (param $b (ref eq))  (result (ref eq))
             (struct.get $Box $v
                         (block $ok (result (ref $Box))
                           (br_on_cast $ok (ref eq) (ref $Box) (local.get $b))
                           (call $raise-box-expected/who
                                 (global.get $symbol:unbox)
                                 (local.get $b))
                           (unreachable))))))


   ;; unbox* : (and/c box? (not/c impersonator?)) -> any/c
   ;;   WebRacket has no box impersonators yet, so this is equivalent
   ;;   to unbox after the same box representation check.
   (core-runtime-helper
    '$unbox*
    "$unbox*"
    (lambda ()
      `(func $unbox* (type $Prim1)
             (param $b (ref eq)) ;; non-impersonator box
             (result (ref eq))
             (struct.get $Box $v
                         (block $ok (result (ref $Box))
                           (br_on_cast $ok (ref eq) (ref $Box) (local.get $b))
                           (call $raise-unbox*:box-expected (local.get $b))
                           (unreachable))))))


   (core-runtime-helper
    '$set-box!
    "$set-box!"
    (lambda ()
      `(func $set-box! (type $Prim2) ; todo: should this invalidate the hash code?
             (param $b (ref eq)) (param $v (ref eq))
             (result (ref eq))
             ; 1. Cast $b into a (ref $Box)
             (local $B (ref $Box))
             (local.set $B
                        (block $ok (result (ref $Box))
                               (br_on_cast $ok (ref eq) (ref $Box) (local.get $b))
                               (call $raise-mutable-box-expected/who
                                     (global.get $symbol:set-box!)
                                     (local.get $b))
                               (unreachable)))
             ; 2. Check mutability
             (if (i32.ne (struct.get $Box $immutable (local.get $B)) (i32.const 0))
                 (then (call $raise-mutable-box-expected/who
                             (global.get $symbol:set-box!)
                             (local.get $B))
                       (unreachable)))
             ; 3. Set the contents
             (struct.set $Box $v (local.get $B) (local.get $v))
             ; 4. Return `void`
             (global.get $void))))


   ;; set-box*! : (and/c box? (not/c immutable?) (not/c impersonator?)) any/c -> void?
   ;;   WebRacket has no box impersonators yet, so this follows set-box!
   ;;   behavior while preserving set-box*! in contract errors.
   (core-runtime-helper
    '$set-box*!
    "$set-box*!"
    (lambda ()
      `(func $set-box*! (type $Prim2)
             (param $b (ref eq)) ;; mutable non-impersonator box
             (param $v (ref eq)) ;; replacement value
             (result (ref eq))
             (local $B (ref $Box))
             (local.set $B
                        (block $ok (result (ref $Box))
                               (br_on_cast $ok (ref eq) (ref $Box) (local.get $b))
                               (call $raise-set-box*!:mutable-box-expected
                                     (local.get $b))
                               (unreachable)))
             (if (i32.ne (struct.get $Box $immutable (local.get $B)) (i32.const 0))
                 (then (call $raise-set-box*!:mutable-box-expected
                             (local.get $B))
                       (unreachable)))
             (struct.set $Box $v (local.get $B) (local.get $v))
             (global.get $void))))


   ;; box-cas! : (and/c box? mutable?) any/c any/c -> boolean?
   ;;   Single-threaded compare-and-set using Racket's eq? comparison.
   (core-runtime-helper
    '$box-cas!
    "$box-cas!"
    (lambda ()
      `(func $box-cas! (type $Prim3)
             (param $b   (ref eq)) ;; box
             (param $old (ref eq)) ;; expected value
             (param $new (ref eq)) ;; replacement value
             (result     (ref eq))
             (local $B (ref $Box))
             (local.set $B
                        (block $ok (result (ref $Box))
                               (br_on_cast $ok (ref eq) (ref $Box) (local.get $b))
                               (call $raise-mutable-box-expected/who
                                     (global.get $symbol:box-cas!)
                                     (local.get $b))
                               (unreachable)))
             (if (i32.ne (struct.get $Box $immutable (local.get $B)) (i32.const 0))
                 (then (call $raise-mutable-box-expected/who
                             (global.get $symbol:box-cas!)
                             (local.get $B))
                       (unreachable)))
             (if (result (ref eq))
                 (ref.eq (call $eq? (struct.get $Box $v (local.get $B)) (local.get $old))
                         (global.get $true))
                 (then
                  (struct.set $Box $v (local.get $B) (local.get $new))
                  (global.get $true))
                 (else (global.get $false))))))


   ;; unsafe-box*-cas! : box? any/c any/c -> boolean?
   ;;   Conservative first slice for expander caches; WebRacket is single-threaded
   ;;   and currently reuses the checked box-cas! path.
   (core-runtime-helper
    '$unsafe-box*-cas!
    "$unsafe-box*-cas!"
    (lambda ()
      `(func $unsafe-box*-cas! (type $Prim3)
             (param $b   (ref eq)) ;; box
             (param $old (ref eq)) ;; expected value
             (param $new (ref eq)) ;; replacement value
             (result     (ref eq))
             (return_call $box-cas! (local.get $b) (local.get $old) (local.get $new)))))


   ;; make-weak-box : any/c -> weak-box?
   ;;   Create a weak-box-shaped value. This is currently strong because
   ;;   Wasm-GC does not give WebRacket weak-reference hooks yet.
   (core-runtime-helper
    '$make-weak-box
    "$make-weak-box"
    (lambda ()
      `(func $make-weak-box (type $Prim1)
             (param $v (ref eq)) ;; value
             (result   (ref eq))
             (struct.new $WeakBox (i32.const 0) (local.get $v)))))


   ;; weak-box? : any/c -> boolean?
   ;;   Check whether a value is a WebRacket weak box.
   (core-runtime-helper
    '$weak-box?
    "$weak-box?"
    (lambda ()
      `(func $weak-box? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $WeakBox) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; weak-box-value : weak-box? [any/c = #f] -> any/c
   ;;   Return the value. Since this first slice is strong, the optional
   ;;   failure value is accepted but never selected.
   (core-runtime-helper
    '$weak-box-value
    "$weak-box-value"
    (lambda ()
      `(func $weak-box-value (type $Prim12)
             (param $wb      (ref eq)) ;; weak box
             (param $failure (ref eq)) ;; optional default, unused for strong fallback
             (result         (ref eq))
             (struct.get $WeakBox $v
                         (block $ok (result (ref $WeakBox))
                           (br_on_cast $ok (ref eq) (ref $WeakBox) (local.get $wb))
                           (call $raise-weak-box-expected/who
                                 (global.get $symbol:weak-box-value)
                                 (local.get $wb))
                           (unreachable))))))
))

;; box-base-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for compiler-box and box helpers.
;;   We use `boxed`, `set-boxed!`, and `unboxed` for assignable variables.
;;   These boxes are not the same as the Racket datatype `box`.
(define box-base-runtime-only-helper-names
  '($raise-letrec-placeholder-access
    $boxed
    $unboxed
    $set-boxed!
    $initialize-boxed!
    $boxed?
    $raise-box-expected/who
    $raise-unbox*:box-expected
    $raise-mutable-box-expected/who
    $raise-set-box*!:mutable-box-expected
    $raise-weak-box-expected/who
    $box?
    $box
    $box-immutable
    $unbox
    $unbox*
    $set-box!
    $set-box*!
    $box-cas!
    $unsafe-box*-cas!
    $make-weak-box
    $weak-box?
    $weak-box-value))

;; box-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render compiler-box and box helpers in runtime assembly order.
(define (box-runtime-helper-forms helper-index)
  (for/list ([name (in-list box-base-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

;; box-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given box helper names from a helper index.
(define (box-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; box-mutability-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for box mutability predicates.
(define box-mutability-runtime-only-helper-names
  '($mutable-box?
    $immutable-box?))

;; box-mutability-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render box mutability predicates in runtime assembly order.
(define (box-mutability-runtime-helper-forms helper-index)
  (box-helper-forms helper-index box-mutability-runtime-only-helper-names))

;; box-mutability-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate box mutability predicates.
(define box-mutability-runtime-only-helpers
  (function-forms->runtime-helpers
   'box-mutability-runtime-only-helpers
   '(
         (func $mutable-box? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Box) (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (struct.get $Box $immutable
                                                 (ref.cast (ref $Box) (local.get $v)))
                                     (i32.const 0))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))

         (func $immutable-box? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Box) (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (struct.get $Box $immutable
                                                 (ref.cast (ref $Box) (local.get $v)))
                                     (i32.const 1))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))


     )))

;; box-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate box helpers that still depend on monolithic runtime globals.
(define box-runtime-only-helpers
  (append box-base-runtime-only-helpers
          box-mutability-runtime-only-helpers))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define box-helper-index
    (make-core-runtime-helper-index box-runtime-only-helpers))

  (check-equal?
   (map form-name (box-runtime-helper-forms box-helper-index))
   box-base-runtime-only-helper-names)

  (check-equal?
   (map form-name (box-mutability-runtime-helper-forms box-helper-index))
   box-mutability-runtime-only-helper-names))
