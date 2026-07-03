#lang racket

(provide box-runtime-string-constants
         box-mutability-runtime-only-helper-names
         box-runtime-only-helpers)

(require "../core-helper.rkt")

;; box-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by box helpers and box errors.
(define box-runtime-string-constants
  '((box? "box?")))

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
             ; 1. Cast $b into a (ref $Box)
             (local $B (ref $Boxed))
             (local.set $B
                        (block $ok (result (ref $Boxed))
                               (br_on_cast $ok (ref eq) (ref $Boxed) (local.get $b))
                               (return (global.get $error))))
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
                               (return (global.get $error))))
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
                           (return (global.get $error)))))))


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
             (call $unbox (local.get $b)))))


   (core-runtime-helper
    '$raise-immutable-box
    "$raise-immutable-box"
    (lambda ()
      `(func $raise-immutable-box (param $x (ref eq)) (unreachable))))


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
                               (return (global.get $error))))
             ; 2. Check mutability
             (if (i32.ne (struct.get $Box $immutable (local.get $B)) (i32.const 0))
                 (then (call $raise-immutable-box (local.get $B)) (unreachable)))
             ; 3. Set the contents
             (struct.set $Box $v (local.get $B) (local.get $v))
             ; 4. Return `void`
             (global.get $void))))


   ;; set-box*! : (and/c box? (not/c immutable?) (not/c impersonator?)) any/c -> void?
   ;;   WebRacket has no box impersonators yet, so this follows set-box!.
   (core-runtime-helper
    '$set-box*!
    "$set-box*!"
    (lambda ()
      `(func $set-box*! (type $Prim2)
             (param $b (ref eq)) ;; mutable non-impersonator box
             (param $v (ref eq)) ;; replacement value
             (result (ref eq))
             (call $set-box! (local.get $b) (local.get $v)))))


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
                               (return (global.get $error))))
             (if (i32.ne (struct.get $Box $immutable (local.get $B)) (i32.const 0))
                 (then (call $raise-immutable-box (local.get $B)) (unreachable)))
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
                           (return (global.get $error)))))))
))

;; box-mutability-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for box mutability predicates.
(define box-mutability-runtime-only-helper-names
  '($mutable-box?
    $immutable-box?))

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
