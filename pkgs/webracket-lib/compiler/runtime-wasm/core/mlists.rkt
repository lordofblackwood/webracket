#lang racket

(provide mlist-runtime-string-constants
         mlist-core-runtime-helper-forms
         mlist-core-runtime-helpers
         mlist-runtime-helper-forms
         mlist-runtime-only-helpers
         mlist-runtime-only-helper-names)

(require "../core-helper.rkt"
         "../../private/wasm-utils.rkt")

;; mlist-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by mutable-list contract errors.
(define mlist-runtime-string-constants
  '((mpair? "mpair?")
    (mpair-or-null "(or/c mpair? null?)")))

;; mlist-base-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable-pair helpers that originated in core runtime.
(define mlist-base-core-runtime-helpers
  (list
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
                         (local.get $d)))))))

;; mlist-runtime-only-forms : (listof datum?)
;;   Enumerate mutable-pair helpers that depend on full runtime error support.
(define mlist-runtime-only-forms
  `(
    ;; raise-mpair-expected/who : symbol? any/c -> none
    ;;   Raise a mutable-pair contract error for who.
    (func $raise-mpair-expected/who
          (param $who (ref eq))
          (param $x   (ref eq))
          (call $raise-argument-error1
                (local.get $who)
                (global.get $string:mpair?)
                (local.get $x)))

    ;; mcar : mpair? -> any/c
    ;;   Return the car field of a mutable pair.
    (func $mcar (type $Prim1)
          (param $v (ref eq))
          (result (ref eq))
          (if (result (ref eq))
              (ref.test (ref $MPair) (local.get $v))
              (then (struct.get $MPair $a
                                (ref.cast (ref $MPair) (local.get $v))))
              (else (call $raise-mpair-expected/who
                          (global.get $symbol:mcar)
                          (local.get $v))
                    (unreachable))))

    ;; mcdr : mpair? -> any/c
    ;;   Return the cdr field of a mutable pair.
    (func $mcdr (type $Prim1)
          (param $v (ref eq))
          (result (ref eq))
          (if (result (ref eq))
              (ref.test (ref $MPair) (local.get $v))
              (then (struct.get $MPair $d
                                (ref.cast (ref $MPair) (local.get $v))))
              (else (call $raise-mpair-expected/who
                          (global.get $symbol:mcdr)
                          (local.get $v))
                    (unreachable))))

    ;; set-mcar! : mpair? any/c -> void?
    ;;   Mutate the car field of a mutable pair.
    (func $set-mcar! (type $Prim2)
          (param $p (ref eq))   ;; mpair to mutate
          (param $v (ref eq))   ;; new car value
          (result (ref eq))
          (if (result (ref eq))
              (ref.test (ref $MPair) (local.get $p))
              (then (struct.set $MPair $a
                                (ref.cast (ref $MPair) (local.get $p))
                                (local.get $v))
                    ,(Imm (void)))
              (else (call $raise-mpair-expected/who
                          (global.get $symbol:set-mcar!)
                          (local.get $p))
                    (unreachable))))

    ;; set-mcdr! : mpair? any/c -> void?
    ;;   Mutate the cdr field of a mutable pair.
    (func $set-mcdr! (type $Prim2)
          (param $p (ref eq))   ;; mpair to mutate
          (param $v (ref eq))   ;; new cdr value
          (result (ref eq))
          (if (result (ref eq))
              (ref.test (ref $MPair) (local.get $p))
              (then (struct.set $MPair $d
                                (ref.cast (ref $MPair) (local.get $p))
                                (local.get $v))
                    ,(Imm (void)))
              (else (call $raise-mpair-expected/who
                          (global.get $symbol:set-mcdr!)
                          (local.get $p))
                    (unreachable))))))

;; mlist-runtime-only-helpers : (listof core-runtime-helper?)
;;   Register mutable-pair helpers that need monolithic runtime support.
(define mlist-runtime-only-helpers
  (function-forms->runtime-helpers
   'mlist-runtime-only-helpers
   mlist-runtime-only-forms))

;; mlist-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for mutable-pair runtime helpers.
(define mlist-runtime-only-helper-names
  (map core-runtime-helper-name mlist-runtime-only-helpers))

;; mlist-core-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for mutable-list core helpers.
(define mlist-core-runtime-helper-names
  '($mpair?
    $mcons
    $raise-mpair-expected/who))

;; select-mlist-helpers : (listof core-runtime-helper?) (listof symbol?) -> (listof core-runtime-helper?)
;;   Select helpers by name while preserving the order of the source list.
(define (select-mlist-helpers helpers names)
  (define name-set
    (for/hasheq ([name (in-list names)])
      (values name #t)))
  (for/list ([helper (in-list helpers)]
             #:when (hash-ref name-set (core-runtime-helper-name helper) #f))
    helper))

;; mlist-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable-pair helpers that can be emitted in core runtime.
(define mlist-core-runtime-helpers
  (append mlist-base-core-runtime-helpers
          (select-mlist-helpers mlist-runtime-only-helpers
                                mlist-core-runtime-helper-names)))

;; mlist-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render mutable-list core helpers in runtime assembly order.
(define (mlist-core-runtime-helper-forms helper-index)
  (for/list ([name (in-list mlist-core-runtime-helper-names)])
    (core-runtime-helper-form helper-index name)))

;; mlist-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render mutable-pair runtime helpers in runtime assembly order.
(define (mlist-runtime-helper-forms helper-index)
  (for/list ([name (in-list (remove* mlist-core-runtime-helper-names
                                      mlist-runtime-only-helper-names))])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define mlist-core-helper-index
    (make-core-runtime-helper-index mlist-core-runtime-helpers))

  (check-equal?
   (map form-name (mlist-core-runtime-helper-forms mlist-core-helper-index))
   mlist-core-runtime-helper-names)

  (define mlist-runtime-helper-index
    (make-core-runtime-helper-index mlist-runtime-only-helpers))

  (check-equal?
   (map form-name (mlist-runtime-helper-forms mlist-runtime-helper-index))
   (remove* mlist-core-runtime-helper-names
            mlist-runtime-only-helper-names)))
