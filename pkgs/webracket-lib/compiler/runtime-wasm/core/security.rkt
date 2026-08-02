#lang racket

(provide security-pre-parameter-runtime-only-helper-names
         security-pre-parameter-runtime-helper-forms
         security-runtime-string-constants
         security-runtime-symbol-constants
         security-post-parameter-runtime-only-helper-names
         security-post-parameter-runtime-helper-forms
         custodian-current-initializer-forms
         custodian-runtime-only-helper-names
         custodian-runtime-helper-forms
         inspector-runtime-only-helper-names
         inspector-runtime-helper-forms
         security-core-runtime-helpers
         security-core-runtime-helper-forms
         security-current-global-forms
         security-current-global-names
         security-guard-current-initializer-forms
         security-runtime-only-helpers)

(require "../core-helper.rkt")

;; security-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by security guard and custodian helpers.
(define security-runtime-string-constants
  '((security-guard? "security-guard?")
    (custodian?      "custodian?")
    (custodian-box?  "custodian-box?")
    (inspector?      "inspector?")
    (security-guard-file-hook "(procedure-arity-includes/c 3)")
    (security-guard-network-hook "(procedure-arity-includes/c 4)")
    (security-guard-link-hook "(or/c #f (procedure-arity-includes/c 3))")))

;; security-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by security guard and custodian helpers.
(define security-runtime-symbol-constants
  '(current-security-guard
    security-guard?
    make-security-guard
    current-custodian
    custodian?
    make-custodian
    custodian-shutdown-all
    custodian-shut-down?
    make-custodian-box
    custodian-box?
    custodian-box-value
    make-inspector
    inspector-superior?))

;; security-current-global-forms : (listof datum?)
;;   Declare current security guard and custodian globals.
(define security-current-global-forms
  '(
               (global $current-security-guard-value (mut (ref eq)) (global.get $false))
               (global $current-custodian-value   (mut (ref eq)) (global.get $false))))

;; security-global-form-name : datum? -> symbol?
;;   Return the Wasm global name declared by a security global form.
(define (security-global-form-name form)
  (match form
    [`(global ,name . ,_) name]
    [_ (error 'security-global-form-name
              "expected global form, got: ~s"
              form)]))

;; security-current-global-names : (listof symbol?)
;;   Enumerate security and custodian current globals shared by split modules.
(define security-current-global-names
  (map security-global-form-name security-current-global-forms))

;; custodian-current-initializer-forms : (listof datum?)
;;   Initialize the root custodian.
(define custodian-current-initializer-forms
  '(
                     (global.set $current-custodian-value
                                 (struct.new $Custodian
                                             (i32.const 0)
                                             (i32.const 0)))))

;; security-guard-current-initializer-forms : (listof datum?)
;;   Initialize the root security guard after primitive globals are ready.
(define security-guard-current-initializer-forms
  '(
                    (global.set $current-security-guard-value
                                (struct.new $SecurityGuard
                                            (i32.const 0)
                                            (global.get $false)
                                            (ref.cast (ref $Procedure) (global.get $prim:void))
                                            (ref.cast (ref $Procedure) (global.get $prim:void))
                                            (ref.cast (ref $Procedure) (global.get $prim:void))))))

;; make-predicate-body : symbol? -> (listof datum?)
;;   Generate a standard WebRacket predicate body for ref-type.
(define (make-predicate-body ref-type)
  `((param $v (ref eq))
    (result   (ref eq))
    (if (result (ref eq))
        (ref.test (ref ,ref-type) (local.get $v))
        (then (global.get $true))
        (else (global.get $false)))))

;; security-promoted-runtime-helper-names : (listof symbol?)
;;   Name security helpers that are available in the standalone core runtime.
(define security-promoted-runtime-helper-names
  '($subprocess?
    $security-guard?
    $security-guard-procedure/arity
    $make-security-guard
    $custodian?
    $make-custodian
    $custodian-shutdown-all
    $custodian-shut-down?
    $make-custodian-box
    $custodian-box?
    $custodian-box-value
    $inspector?
    $current-inspector
    $current-code-inspector
    $object-name))

;; security-pre-parameter-helper-names : (listof symbol?)
;;   Preserve helpers emitted before current-security-guard.
(define security-pre-parameter-helper-names
  '($security-guard-procedure/arity))

;; security-pre-parameter-runtime-only-helper-names : (listof symbol?)
;;   Preserve runtime-only helpers emitted before current-security-guard.
(define security-pre-parameter-runtime-only-helper-names
  (remove* security-promoted-runtime-helper-names
           security-pre-parameter-helper-names
           eq?))

;; security-post-parameter-helper-names : (listof symbol?)
;;   Preserve helpers emitted between current-security-guard and current-custodian.
(define security-post-parameter-helper-names
  '($make-security-guard))

;; security-post-parameter-runtime-only-helper-names : (listof symbol?)
;;   Preserve runtime-only helpers emitted between current-security-guard and current-custodian.
(define security-post-parameter-runtime-only-helper-names
  (remove* security-promoted-runtime-helper-names
           security-post-parameter-helper-names
           eq?))

;; custodian-helper-names : (listof symbol?)
;;   Preserve custodian helper emission order.
(define custodian-helper-names
  '($make-custodian
    $custodian-shutdown-all
    $custodian-shut-down?
    $make-custodian-box
    $custodian-box-value))

;; custodian-runtime-only-helper-names : (listof symbol?)
;;   Preserve runtime-only custodian helper emission order.
(define custodian-runtime-only-helper-names
  (remove* security-promoted-runtime-helper-names
           custodian-helper-names
           eq?))

;; inspector-runtime-only-helper-names : (listof symbol?)
;;   Preserve inspector and object-name helper emission order.
(define inspector-runtime-only-helper-names
  '($make-inspector
    $inspector-superior?))

;; security-runtime-only-forms : (listof datum?)
;;   Enumerate security guard, custodian, inspector, and object-name helpers.
(define security-runtime-only-forms
  `(
         ;; subprocess? : any/c -> boolean?
         ;;   Browsers cannot expose OS subprocess handles. Until WebRacket has
         ;;   an explicit host-process abstraction, no value is a subprocess.
         (func $subprocess? (type $Prim1)
               (param $v (ref eq)) ;; any/c
               (result   (ref eq))
               (global.get $false))

         ;; security-guard? : any/c -> boolean?
         ;;   Predicate for WebRacket's minimal security guard records.
         (func $security-guard? (type $Prim1)
               ,@(make-predicate-body '$SecurityGuard))

         ;; $security-guard-procedure/arity : symbol? string? any/c exact-nonnegative-integer? -> procedure?
         ;;   Validate one access-check hook. WebRacket stores hooks for future
         ;;   VFS/network checks, but does not consult them yet.
         (func $security-guard-procedure/arity
               (param $who      (ref eq)) ;; symbol?
               (param $expected (ref eq)) ;; contract string
               (param $proc-raw (ref eq)) ;; procedure?
               (param $argc     i32) ;; required argument count
               (result          (ref $Procedure))
               (local $proc (ref $Procedure))

               (if (ref.eq (call $procedure? (local.get $proc-raw))
                           (global.get $false))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (local.get $expected)
                               (local.get $proc-raw))
                         (unreachable)))
               (local.set $proc (ref.cast (ref $Procedure) (local.get $proc-raw)))
               (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                  (local.get $proc)
                                  (local.get $argc)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (local.get $expected)
                               (local.get $proc-raw))
                         (unreachable)))
               (local.get $proc))
         ;; make-security-guard : security-guard? (procedure-arity-includes/c 3) (procedure-arity-includes/c 4) [(or/c #f (procedure-arity-includes/c 3))] -> security-guard?
         ;;   Create a minimal security guard. The file guard must accept 3
         ;;   arguments, the network guard must accept 4, and the optional
         ;;   link guard defaults to void and must accept 3 when provided.
         (func $make-security-guard (type $Prim34)
               (param $parent-raw (ref eq)) ;; security-guard?
               (param $file-raw   (ref eq)) ;; procedure accepting 3 args
               (param $network-raw (ref eq)) ;; procedure accepting 4 args
               (param $link-raw   (ref eq)) ;; optional procedure accepting 3 args or #f
               (result            (ref eq))
               (local $file    (ref $Procedure))
               (local $network (ref $Procedure))
               (local $link    (ref $Procedure))

               (if (i32.eqz (ref.test (ref $SecurityGuard) (local.get $parent-raw)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:make-security-guard)
                               (global.get $string:security-guard?)
                               (local.get $parent-raw))
                         (unreachable)))
               (local.set $file
                          (call $security-guard-procedure/arity
                                (global.get $symbol:make-security-guard)
                                (global.get $string:security-guard-file-hook)
                                (local.get $file-raw)
                                (i32.const 3)))
               (local.set $network
                          (call $security-guard-procedure/arity
                                (global.get $symbol:make-security-guard)
                                (global.get $string:security-guard-network-hook)
                                (local.get $network-raw)
                                (i32.const 4)))
               (if (ref.eq (local.get $link-raw) (global.get $missing))
                   (then (local.set $link-raw (global.get $prim:void))))
               (if (ref.eq (local.get $link-raw) (global.get $false))
                   (then (local.set $link-raw (global.get $prim:void))))
               (local.set $link
                          (call $security-guard-procedure/arity
                                (global.get $symbol:make-security-guard)
                                (global.get $string:security-guard-link-hook)
                                (local.get $link-raw)
                                (i32.const 3)))
               (struct.new $SecurityGuard
                           (i32.const 0)
                           (local.get $parent-raw)
                           (local.get $file)
                           (local.get $network)
                           (local.get $link)))

         ;; custodian? : any/c -> boolean?
         ;;   Predicate for WebRacket's minimal custodian records.
         (func $custodian? (type $Prim1)
               ,@(make-predicate-body '$Custodian))
         ;; make-custodian : [custodian?] -> custodian?
         ;;   Create a minimal custodian. The optional parent is validated but
         ;;   not retained yet, so parent shutdown does not cascade.
         (func $make-custodian (type $Prim01)
               (param $parent-raw (ref eq)) ;; optional parent custodian
               (result            (ref eq))
               (if (ref.eq (local.get $parent-raw) (global.get $missing))
                   (then (local.set $parent-raw
                                    (call $current-custodian
                                          (global.get $missing)))))
               (if (i32.eqz (ref.test (ref $Custodian) (local.get $parent-raw)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:make-custodian)
                               (global.get $string:custodian?)
                               (local.get $parent-raw))
                         (unreachable)))
               (struct.new $Custodian (i32.const 0) (i32.const 0)))

         ;; custodian-shutdown-all : custodian? -> void?
         ;;   Mark a minimal custodian as shut down. WebRacket does not yet
         ;;   close managed resources or cascade to children.
         (func $custodian-shutdown-all (type $Prim1)
               (param $cust-raw (ref eq)) ;; custodian?
               (result          (ref eq))
               (if (i32.eqz (ref.test (ref $Custodian) (local.get $cust-raw)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:custodian-shutdown-all)
                               (global.get $string:custodian?)
                               (local.get $cust-raw))
                         (unreachable)))
               (struct.set $Custodian $shutdown?
                           (ref.cast (ref $Custodian) (local.get $cust-raw))
                           (i32.const 1))
               (global.get $void))

         ;; custodian-shut-down? : custodian? -> boolean?
         ;;   Report the shutdown bit on a minimal custodian.
         (func $custodian-shut-down? (type $Prim1)
               (param $cust-raw (ref eq)) ;; custodian?
               (result          (ref eq))
               (if (i32.eqz (ref.test (ref $Custodian) (local.get $cust-raw)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:custodian-shut-down?)
                               (global.get $string:custodian?)
                               (local.get $cust-raw))
                         (unreachable)))
               (if (result (ref eq))
                   (struct.get $Custodian $shutdown?
                               (ref.cast (ref $Custodian) (local.get $cust-raw)))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; make-custodian-box : custodian? any/c -> custodian-box?
         ;;   Attach a value to a minimal custodian. If the custodian is already
         ;;   shut down, store #f as Racket specifies.
         (func $make-custodian-box (type $Prim2)
               (param $cust-raw (ref eq)) ;; custodian?
               (param $v        (ref eq)) ;; any/c
               (result          (ref eq))
               (local $cust (ref $Custodian))
               (if (i32.eqz (ref.test (ref $Custodian) (local.get $cust-raw)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:make-custodian-box)
                               (global.get $string:custodian?)
                               (local.get $cust-raw))
                         (unreachable)))
               (local.set $cust (ref.cast (ref $Custodian) (local.get $cust-raw)))
               (if (struct.get $Custodian $shutdown? (local.get $cust))
                   (then (local.set $v (global.get $false))))
               (struct.new $CustodianBox
                           (i32.const 0)
                           (local.get $cust)
                           (local.get $v)))

         ;; custodian-box? : any/c -> boolean?
         ;;   Predicate for WebRacket's minimal custodian boxes.
         (func $custodian-box? (type $Prim1)
               ,@(make-predicate-body '$CustodianBox))

         ;; custodian-box-value : custodian-box? -> any/c
         ;;   Return the box value, or #f after the attached custodian shuts down.
         (func $custodian-box-value (type $Prim1)
               (param $box-raw (ref eq)) ;; custodian-box?
               (result         (ref eq))
               (local $box  (ref $CustodianBox))
               (local $cust (ref $Custodian))
               (if (i32.eqz (ref.test (ref $CustodianBox) (local.get $box-raw)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:custodian-box-value)
                               (global.get $string:custodian-box?)
                               (local.get $box-raw))
                         (unreachable)))
               (local.set $box (ref.cast (ref $CustodianBox) (local.get $box-raw)))
               (local.set $cust (struct.get $CustodianBox $cust (local.get $box)))
               (if (struct.get $Custodian $shutdown? (local.get $cust))
                   (then (return (global.get $false))))
               (struct.get $CustodianBox $v (local.get $box)))
         ;; inspector? : any/c -> boolean?
         ;;   Permissive placeholder. The inspector value itself is represented
         ;;   as #f until WebRacket grows a real inspector hierarchy.
         (func $inspector? (type $Prim1)
               (param $v (ref eq)) ;; any/c
               (result   (ref eq))
               (if (result (ref eq))
                   (ref.eq (local.get $v) (global.get $false))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; current-inspector : -> inspector?
         ;;   Permissive placeholder. WebRacket does not yet enforce inspector
         ;;   access control, so the current inspector is represented as #f.
         (func $current-inspector (type $Prim0)
               (result (ref eq))
               (global.get $false))

         ;; current-code-inspector : -> inspector?
         ;;   Code inspectors matter for protected module access in full Racket.
         ;;   The expander bootstrap asks for the parameter, but WebRacket does
         ;;   not yet model protected module access, so use the same permissive
         ;;   #f placeholder as `current-inspector`.
         (func $current-code-inspector (type $Prim0)
               (result (ref eq))
               (global.get $false))

         ;; make-inspector : inspector? -> inspector?
         ;;   Placeholder constructor paired with the permissive inspector
         ;;   model above. Returning #f keeps structure creation transparent
         ;;   until WebRacket grows real inspector objects and hierarchy checks.
         (func $make-inspector (type $Prim1)
               (param $parent (ref eq)) ;; parent inspector
               (result (ref eq))
               (if (i32.eqz (ref.eq (local.get $parent) (global.get $false)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:make-inspector)
                               (global.get $string:inspector?)
                               (local.get $parent))
                         (unreachable)))
               (global.get $false))

         ;; inspector-superior? : inspector? inspector? -> boolean?
         ;;   Permissive placeholder for module/body namespace recovery. Since
         ;;   all inspectors collapse to #f in the current model, treat #f as
         ;;   controlling #f; real hierarchy checks should replace this stub
         ;;   when protected module/struct access is implemented.
         (func $inspector-superior? (type $Prim2)
               (param $inspector (ref eq)) ;; inspector?
               (param $maybe-subinspector (ref eq)) ;; inspector?
               (result (ref eq))
               (if (i32.eqz (ref.eq (local.get $inspector) (global.get $false)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:inspector-superior?)
                               (global.get $string:inspector?)
                               (local.get $inspector))
                         (unreachable)))
               (if (i32.eqz (ref.eq (local.get $maybe-subinspector) (global.get $false)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:inspector-superior?)
                               (global.get $string:inspector?)
                               (local.get $maybe-subinspector))
                         (unreachable)))
               (if (result (ref eq))
                   (i32.and (ref.eq (local.get $inspector) (global.get $false))
                            (ref.eq (local.get $maybe-subinspector) (global.get $false)))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; Racket's object-name recognizes additional values such as regexp objects,
         ;; loggers, prompt tags, and structures with the prop:object-name property.
         ;; WebRacket currently supports procedures, structure instances, structure
         ;; type descriptors, and string ports.
         (func $object-name (type $Prim1)
               (param $v (ref eq)) ;; any/c
               (result   (ref eq))

               (local $proc        (ref $Procedure))
               (local $struct      (ref $Struct))
               (local $type        (ref $StructType))
               (local $name        (ref eq))
               (local $prop-val    (ref eq))
               (local $sentinel    (ref eq))
               (local $fields      (ref $Array))
               (local $rx          (ref $Regexp))
               (local $idx         i32)
               (local $super       (ref eq))
               (local $super-type  (ref null $StructType))
               (local $super-count i32)
               (local $abs-index   i32)
               (local $prop-proc   (ref $Procedure))
               (local $prop-inv    (ref $ProcedureInvoker))
               (local $prop-args   (ref $Args))
               (local $prop-name   (ref $Symbol))

               ;; Structure instances report the associated struct type name.
               (if (ref.test (ref $Struct) (local.get $v))
                   (then (local.set $struct    (ref.cast (ref $Struct) (local.get $v)))
                         (local.set $type      (struct.get $Struct $type (local.get $struct)))
                         (local.set $sentinel  (call $cons (global.get $false) (global.get $false)))
                         (local.set $prop-name (ref.cast (ref $Symbol)
                                                         (global.get $symbol:object-name)))
                         (local.set $prop-val  (call $struct-type-property-lookup-by-name
                                                     (local.get $type)
                                                     (local.get $prop-name)
                                                     (local.get $sentinel)))
                         (if (i32.eqz (ref.eq (local.get $prop-val) (local.get $sentinel)))
                             (then (if (ref.test (ref i31) (local.get $prop-val))
                                       (then (local.set $idx (i32.shr_u
                                                              (i31.get_u (ref.cast (ref i31) (local.get $prop-val)))
                                                              (i32.const 1)))
                                             (local.set $super (struct.get $StructType $super (local.get $type)))
                                             (local.set $super-type (ref.null $StructType))
                                             (local.set $super-count (i32.const 0))
                                             (if (i32.eqz (ref.eq (local.get $super) (global.get $false)))
                                                 (then
                                                  (local.set $super-type
                                                             (ref.cast (ref $StructType) (local.get $super)))
                                                  (local.set $super-count
                                                             (struct.get $StructType $field-count
                                                                         (local.get $super-type)))))
                                             (local.set $fields (struct.get $Struct $fields (local.get $struct)))
                                             (local.set $abs-index (i32.add (local.get $super-count) (local.get $idx)))
                                             (return (array.get $Array (local.get $fields) (local.get $abs-index))))
                                       (else (if (ref.eq (call $procedure? (local.get $prop-val))
                                                        (global.get $true))
                                                 (then
                                                  (local.set $prop-proc
                                                             (ref.cast (ref $Procedure) (local.get $prop-val)))
                                                  (local.set $prop-inv
                                                             (struct.get $Procedure $invoke (local.get $prop-proc)))
                                                  (local.set $prop-args
                                                             (array.new $Args (global.get $null) (i32.const 1)))
                                                  (array.set $Args (local.get $prop-args)
                                                             (i32.const 0)
                                                             (local.get $struct))
                                                  (return_call_ref $ProcedureInvoker
                                                                   (local.get $prop-proc)
                                                                   (local.get $prop-args)
                                                                   (local.get $prop-inv)))
                                                 (else (return (local.get $prop-val)))))))
                             (else (return (struct.get $StructType $name (local.get $type)))))))

               ;; Structure type descriptors return their recorded name symbol.
               (if (ref.test (ref $StructType) (local.get $v))
                   (then
                    (return (struct.get $StructType $name
                                        (ref.cast (ref $StructType) (local.get $v))))))

               ;; Ports expose the stored port name.
               (if (ref.test (ref $Port) (local.get $v))
                   (then
                    (return (struct.get $Port $name
                                        (ref.cast (ref $Port) (local.get $v))))))
               ;; Regexp values expose the source string or bytes.
               (if (ref.test (ref $Regexp) (local.get $v))
                   (then
                    (local.set $rx (ref.cast (ref $Regexp) (local.get $v)))
                    (return (struct.get $Regexp $source (local.get $rx)))))
               ;; Procedures use the cached name field when available.
               (if (ref.eq (call $procedure? (local.get $v))
                           (global.get $true))
                   (then
                    (local.set $proc (ref.cast (ref $Procedure) (local.get $v)))
                    (local.set $name (struct.get $Procedure $name (local.get $proc)))
                    (return (if (result (ref eq))
                                (ref.eq (local.get $name) (global.get $false))
                                (then (global.get $false))
                                (else (local.get $name))))))

               ;; Unnamed objects fall back to #f.
               (global.get $false))
     ))

;; security-all-runtime-helpers : (listof core-runtime-helper?)
;;   Register security guard, custodian, inspector, and object-name helpers.
(define security-all-runtime-helpers
  (function-forms->runtime-helpers
   'security-runtime-only-helpers
   security-runtime-only-forms))

;; security-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate security helpers available in the standalone core runtime.
(define security-core-runtime-helpers
  (select-runtime-helpers security-all-runtime-helpers
                          security-promoted-runtime-helper-names))

;; security-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate security helpers that still depend on monolithic runtime globals.
(define security-runtime-only-helpers
  (remove-runtime-helpers security-all-runtime-helpers
                          security-promoted-runtime-helper-names))

;; security-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given security helper names from the runtime helper index.
(define (security-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; security-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted security helpers in runtime assembly order.
(define (security-core-runtime-helper-forms helper-index)
  (security-helper-forms helper-index security-promoted-runtime-helper-names))

;; security-pre-parameter-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render helpers emitted before current-security-guard.
(define (security-pre-parameter-runtime-helper-forms helper-index)
  (security-helper-forms helper-index security-pre-parameter-runtime-only-helper-names))

;; security-post-parameter-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render helpers emitted between current-security-guard and current-custodian.
(define (security-post-parameter-runtime-helper-forms helper-index)
  (security-helper-forms helper-index security-post-parameter-runtime-only-helper-names))

;; custodian-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render custodian helpers in runtime assembly order.
(define (custodian-runtime-helper-forms helper-index)
  (security-helper-forms helper-index custodian-runtime-only-helper-names))

;; inspector-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render inspector and object-name helpers in runtime assembly order.
(define (inspector-runtime-helper-forms helper-index)
  (security-helper-forms helper-index inspector-runtime-only-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define security-core-helper-index
    (make-core-runtime-helper-index security-core-runtime-helpers))

  (define security-helper-index
    (make-core-runtime-helper-index
     (append security-core-runtime-helpers
             security-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name security-core-runtime-helpers)
   security-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (security-core-runtime-helper-forms security-core-helper-index))
   security-promoted-runtime-helper-names)

  (check-equal?
   (map form-name
        (security-pre-parameter-runtime-helper-forms security-helper-index))
   security-pre-parameter-runtime-only-helper-names)

  (check-equal?
   (map form-name
        (security-post-parameter-runtime-helper-forms security-helper-index))
   security-post-parameter-runtime-only-helper-names)

  (check-equal?
   (map form-name (custodian-runtime-helper-forms security-helper-index))
   custodian-runtime-only-helper-names)

  (check-equal?
   (map form-name (inspector-runtime-helper-forms security-helper-index))
   inspector-runtime-only-helper-names))
