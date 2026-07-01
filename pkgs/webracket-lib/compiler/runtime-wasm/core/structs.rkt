#lang racket

(provide struct-core-runtime-helpers
         struct-runtime-only-helpers)

(require "../core-helper.rkt")

;; struct-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate struct helpers that can be emitted in core runtime.
(define struct-core-runtime-helpers
  (list
   ;; struct?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a struct, 0 otherwise.
   (core-runtime-helper
    '$struct?/i32
    "$struct?/i32"
    (lambda ()
      `(func $struct?/i32 (param $v (ref eq)) (result i32)
             (ref.test (ref $Struct) (local.get $v)))))
   ;; struct-type?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a struct type descriptor, 0 otherwise.
   (core-runtime-helper
    '$struct-type?/i32
    "$struct-type?/i32"
    (lambda ()
      `(func $struct-type?/i32 (param $v (ref eq)) (result i32)
             (ref.test (ref $StructType) (local.get $v)))))))

;; struct-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate struct helpers that depend on monolithic runtime globals.
(define struct-runtime-only-helpers
  (list
   ;; initialize-prefab-struct-type-registry : -> void
   ;;   Lazily allocate the global prefab struct type registry.
   (core-runtime-helper
    '$initialize-prefab-struct-type-registry
    "$initialize-prefab-struct-type-registry"
    (lambda ()
      `(func $initialize-prefab-struct-type-registry
             (if (ref.is_null (global.get $prefab-struct-type-registry))
                 (then
                  (global.set $prefab-struct-type-registry
                              (ref.cast (ref $HashEqMutable)
                                        (call $make-empty-hasheq))))))))))
