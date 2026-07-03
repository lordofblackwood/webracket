#lang racket

(provide mlist-runtime-string-constants
         mlist-core-runtime-helpers)

(require "../core-helper.rkt"
         "../../private/wasm-utils.rkt")

;; mlist-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by mutable-list contract errors.
(define mlist-runtime-string-constants
  '((mpair-or-null "(or/c mpair? null?)")))

;; mlist-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable-pair helpers that can be emitted in core runtime.
(define mlist-core-runtime-helpers
  (list
   ;; raise-mpair-expected : any/c -> none
   ;;   Placeholder mutable-pair contract error.
   (core-runtime-helper
    '$raise-mpair-expected
    "$raise-mpair-expected"
    (lambda ()
      `(func $raise-mpair-expected
             (param $x (ref eq))
             (unreachable))))

   ;; mpair? : any/c -> boolean?
   ;;   Return #t if the value is a mutable pair, #f otherwise.
   (core-runtime-helper
    '$mpair?
    "$mpair?"
    (lambda ()
      `(func $mpair? (type $Prim1)
             (param $v (ref eq))
             (result (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $MPair) (local.get $v))
                 (then ,(Imm #t))
                 (else ,(Imm #f))))))

   ;; mcons : any/c any/c -> mpair?
   ;;   Allocate a mutable pair.
   (core-runtime-helper
    '$mcons
    "$mcons"
    (lambda ()
      `(func $mcons (type $Prim2)
             (param $a (ref eq))  ;; car value
             (param $d (ref eq))  ;; cdr value
             (result (ref eq))
             (struct.new $MPair
                         (i32.const 0)
                         (local.get $a)
                         (local.get $d)))))

   ;; mcar : mpair? -> any/c
   ;;   Return the car field of a mutable pair.
   (core-runtime-helper
    '$mcar
    "$mcar"
    (lambda ()
      `(func $mcar (type $Prim1)
             (param $v (ref eq))
             (result (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $MPair) (local.get $v))
                 (then (struct.get $MPair $a
                                   (ref.cast (ref $MPair) (local.get $v))))
                 (else (call $raise-mpair-expected (local.get $v))
                       (unreachable))))))

   ;; mcdr : mpair? -> any/c
   ;;   Return the cdr field of a mutable pair.
   (core-runtime-helper
    '$mcdr
    "$mcdr"
    (lambda ()
      `(func $mcdr (type $Prim1)
             (param $v (ref eq))
             (result (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $MPair) (local.get $v))
                 (then (struct.get $MPair $d
                                   (ref.cast (ref $MPair) (local.get $v))))
                 (else (call $raise-mpair-expected (local.get $v))
                       (unreachable))))))

   ;; set-mcar! : mpair? any/c -> void?
   ;;   Mutate the car field of a mutable pair.
   (core-runtime-helper
    '$set-mcar!
    "$set-mcar!"
    (lambda ()
      `(func $set-mcar! (type $Prim2)
             (param $p (ref eq))   ;; mpair to mutate
             (param $v (ref eq))   ;; new car value
             (result (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $MPair) (local.get $p))
                 (then (struct.set $MPair $a
                                   (ref.cast (ref $MPair) (local.get $p))
                                   (local.get $v))
                       ,(Imm (void)))
                 (else (call $raise-mpair-expected (local.get $p))
                       (unreachable))))))

   ;; set-mcdr! : mpair? any/c -> void?
   ;;   Mutate the cdr field of a mutable pair.
   (core-runtime-helper
    '$set-mcdr!
    "$set-mcdr!"
    (lambda ()
      `(func $set-mcdr! (type $Prim2)
             (param $p (ref eq))   ;; mpair to mutate
             (param $v (ref eq))   ;; new cdr value
             (result (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $MPair) (local.get $p))
                 (then (struct.set $MPair $d
                                   (ref.cast (ref $MPair) (local.get $p))
                                   (local.get $v))
                       ,(Imm (void)))
                 (else (call $raise-mpair-expected (local.get $p))
                       (unreachable))))))))
