#lang racket

(provide flonum-core-runtime-helpers
         flonum-minmax-runtime-only-helper-names
         flonum-runtime-only-helpers)

(require "../core-helper.rkt")

;; flonum-minmax-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for flonum min/max helpers.
(define flonum-minmax-runtime-only-helper-names
  '($flmin/2
    $flmax/2
    $unsafe-flmin/2
    $unsafe-flmax/2
    $flmin
    $flmax
    $unsafe-flmin
    $unsafe-flmax))

;; flonum-binary-minmax-runtime-helper : symbol? datum? boolean? -> core-runtime-helper?
;;   Build a binary flonum min/max helper, optionally assuming validated arguments.
(define (flonum-binary-minmax-runtime-helper name expr unsafe?)
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name
            (type $Prim2)
            (param $a (ref eq))
            (param $b (ref eq))
            (result (ref eq))
            (local $a/fl (ref $Flonum))
            (local $b/fl (ref $Flonum))
            (local $a/f64 f64)
            (local $b/f64 f64)
            ,@(if unsafe?
                  '()
                  `((if (i32.eqz (ref.test (ref $Flonum) (local.get $a)))
                        (then (call $raise-argument-error:flonum-expected (local.get $a))
                              (unreachable)))
                    (if (i32.eqz (ref.test (ref $Flonum) (local.get $b)))
                        (then (call $raise-argument-error:flonum-expected (local.get $b))
                              (unreachable)))))
            (local.set $a/fl (ref.cast (ref $Flonum) (local.get $a)))
            (local.set $b/fl (ref.cast (ref $Flonum) (local.get $b)))
            (local.set $a/f64 (struct.get $Flonum $v (local.get $a/fl)))
            (local.set $b/f64 (struct.get $Flonum $v (local.get $b/fl)))
            (struct.new $Flonum
                        (i32.const 0)
                        ,expr)))))

;; flonum-minmax-runtime-helper : symbol? symbol? boolean? -> core-runtime-helper?
;;   Build a variadic flonum min/max helper, optionally assuming validated arguments.
(define (flonum-minmax-runtime-helper name cmp unsafe?)
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name (param $x0 (ref eq)) (param $xs (ref eq)) (result (ref eq))
            (local $node (ref $Pair))
            (local $fx   (ref eq))
            (local $best (ref eq))
            ,@(if unsafe?
                  '()
                  `((if (i32.eqz (ref.test (ref $Flonum) (local.get $x0)))
                        (then (call $raise-argument-error:flonum-expected (local.get $x0))
                              (unreachable)))))
            (local.set $best (local.get $x0))
            (block $done
                   (loop $loop
                         (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                         (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                         (local.set $fx   (struct.get $Pair $a (local.get $node)))
                         ,@(if unsafe?
                               '()
                               `((if (i32.eqz (ref.test (ref $Flonum) (local.get $fx)))
                                     (then (call $raise-argument-error:flonum-expected (local.get $fx))
                                           (unreachable)))))
                         (local.set $best (call ,cmp (local.get $best) (local.get $fx)))
                         (local.set $xs (struct.get $Pair $d (local.get $node)))
                         (br $loop)))
            (local.get $best)))))

;; flonum-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum helpers that depend on monolithic runtime errors.
(define flonum-runtime-only-helpers
  (append
   (for/list ([name '( $flmin/2 $flmax/2 )]
              [expr '((f64.min (local.get $a/f64) (local.get $b/f64))
                      (f64.max (local.get $a/f64) (local.get $b/f64)))])
     (flonum-binary-minmax-runtime-helper name expr #f))
   (for/list ([name '( $unsafe-flmin/2 $unsafe-flmax/2 )]
              [expr '((f64.min (local.get $a/f64) (local.get $b/f64))
                      (f64.max (local.get $a/f64) (local.get $b/f64)))])
     (flonum-binary-minmax-runtime-helper name expr #t))
   (for/list ([name '( $flmin $flmax )]
              [cmp  '( $flmin/2 $flmax/2 )])
     (flonum-minmax-runtime-helper name cmp #f))
   (for/list ([name '( $unsafe-flmin $unsafe-flmax )]
              [cmp  '( $unsafe-flmin/2 $unsafe-flmax/2 )])
     (flonum-minmax-runtime-helper name cmp #t))))

;; flonum-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum helpers that can be emitted in core runtime.
(define flonum-core-runtime-helpers
  (list
   ;; fl?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a flonum, 0 otherwise.
   (core-runtime-helper
    '$fl?/i32
    "$fl?/i32"
    (lambda ()
      `(func $fl?/i32 (param $a (ref eq)) (result i32)
             (ref.test (ref $Flonum) (local.get $a)))))))
