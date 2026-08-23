#lang racket

(provide generate-shared-types)

;; generate-shared-types : -> (listof datum?)
;;   Build type declarations shared by the core and program runtime modules.
(define (generate-shared-types)
  `(
         ;;;
         ;;; Internal Types
         ;;;

         ; The following internal types are used to implement the various Racket data types.
         (type $Array    (array (mut (ref eq))))
         (type $I32Array (array (mut i32)))
         (type $I8Array  (array (mut i8)))

         (type $GrowableArray
               (struct
                 (field $arr (mut (ref $Array)))  ;; underlying array
                 (field $cap (mut i32))           ;; capacity (the size of the array)
                 (field $i   (mut i32))))         ;; the index of the next free slot in $arr

         (type $GrowableBytes
               (struct
                 (field $arr (mut (ref $I8Array))) ;; underlying byte array
                 (field $cap (mut i32))            ;; capacity of the array
                 (field $i   (mut i32))))          ;; next free index

         (type $I32GrowableArray
               (struct
                 (field $arr (mut (ref $I32Array))) ;; underlying array
                 (field $cap (mut i32))             ;; capacity
                 (field $i   (mut i32))))           ;; current size

         (type $SymbolTable
               (struct
                 (field $entries (mut (ref $Array))) ;; flat array: key0, val0, key1, val1, ...
                 (field $count   (mut i32))))        ;; number of symbols currently stored

         ; The type $Boxed is used for assignable variables.
         ; They are not exposed, so they do not need to carry a hash code.
         (type $Boxed (struct (field $v (mut (ref eq)))))

         ;;;
         ;;; Support
         ;;;

         (type $Values    (array (mut (ref eq))))  ; for multiple values return
         (type $Args      (array (mut (ref eq))))  ; holds arguments passed to a closure
         (type $Free      (array (mut (ref eq))))  ; holds captured free variables

       ;;;
       ;;; Types: Heap allocated objects
       ;;;

       ; All heap allocated values carry a hash code.
       ; If the hash code is 0 it hash hasn't been computed yet.
         (rec
          (type $Heap (sub (struct (field $hash (mut i32)))))
          (type $Pair (sub $Heap
                           (struct
                             (field $hash (mut i32))
                             (field $a    (mut (ref eq)))
                             (field $d    (mut (ref eq))))))
          (type $MPair (sub $Heap
                            (struct
                              (field $hash (mut i32))
                              (field $a    (mut (ref eq)))
                              (field $d    (mut (ref eq))))))
          (type $Box  (sub $Heap
                           (struct
                             (field $hash      (mut i32))
                             (field $immutable i32)
                             (field $v         (mut (ref eq))))))
          ;; Weak boxes normally allow their contents to disappear after GC.
          ;; WebRacket does not expose GC weakness yet, so this first slice
          ;; keeps a strong reference. That is enough for expander caches, where
          ;; retaining cached values is semantically conservative.
          (type $WeakBox (sub $Heap
                              (struct
                                (field $hash (mut i32))
                                (field $v    (mut (ref eq))))))
          ;; Thread cells are per-thread in Racket. WebRacket is currently
          ;; single-threaded, so the current value is stored directly here.
          (type $ThreadCell (sub $Heap
                                 (struct
                                   (field $hash      (mut i32))
                                   (field $default   (mut (ref eq)))
                                   (field $current   (mut (ref eq)))
                                   (field $preserved i32))))
          ;; WebRacket is single-threaded for now, but the expander's
          ;; namespace registry expects stable thread identity and simple
          ;; synchronizable semaphores/events.
          (type $Thread (sub $Heap
                             (struct
                               (field $hash (mut i32)))))
          ;; Minimal thread groups for single-threaded WebRacket. They retain
          ;; parent links for API compatibility, but scheduling is unaffected.
          (type $ThreadGroup (sub $Heap
                                  (struct
                                    (field $hash   (mut i32))
                                    (field $parent (ref eq)))))
          ;; Minimal logger objects. They are enough for racket/base modules
          ;; that test logging levels before emitting; receivers/events can be
          ;; layered on later if browser logging becomes a goal.
          (type $Logger (sub $Heap
                             (struct
                               (field $hash (mut i32))
                               (field $name (ref eq)))))
          (type $LogReceiver (sub $Heap
                                  (struct
                                    (field $hash   (mut i32))
                                    (field $logger (ref $Logger))
                                    (field $level  (ref eq))
                                    (field $topics (ref eq)))))
          ;; Minimal byte converters. For now they represent the guaranteed
          ;; UTF-8/locale-as-UTF-8 identity conversions used while booting
          ;; module libraries; full transcoding belongs with richer I/O/rktio.
          (type $BytesConverter (sub $Heap
                                     (struct
                                       (field $hash   (mut i32))
                                       (field $closed (mut i32)))))
          (type $Channel (sub $Heap
                              (struct
                                (field $hash  (mut i32))
                                (field $ready (mut i32))
                                (field $value (mut (ref eq))))))
          (type $ChannelPutEvt (sub $Heap
                                    (struct
                                      (field $hash (mut i32))
                                      (field $ch   (ref $Channel))
                                      (field $v    (ref eq)))))
          (type $HandleEvt (sub $Heap
                                (struct
                                  (field $hash (mut i32))
                                  (field $evt  (ref eq))
                                  (field $proc (ref $Procedure)))))
          ;; Minimal will executors. WebRacket does not expose GC-driven
          ;; finalization yet, so registrations are retained to preserve
          ;; references, but no wills become ready for execution.
          (type $WillExecutor (sub $Heap
                                   (struct
                                     (field $hash          (mut i32))
                                     (field $registrations (mut (ref eq))))))
          ;; Opaque continuation-mark keys. Full continuation marks are still
          ;; stubbed, but libraries use fresh key allocation as opaque identity
          ;; tokens during startup.
          (type $ContinuationMarkKey (sub $Heap
                                          (struct
                                            (field $hash (mut i32))
                                            (field $name (ref eq)))))
          (type $ContinuationMarkSet (sub $Heap
                                          (struct
                                            (field $hash (mut i32)))))
          ;; Minimal custodians for browser/module bootstrap. They track a
          ;; shutdown bit so custodian boxes can report #f after shutdown, but
          ;; WebRacket does not yet manage ports, threads, or memory by
          ;; custodian.
          (type $Custodian (sub $Heap
                                (struct
                                  (field $hash      (mut i32))
                                  (field $shutdown? (mut i32)))))
          ;; Minimal security guards. They preserve the value graph and
          ;; current-security-guard parameter protocol used by racket/base
          ;; modules. The access-checking hooks are not consulted yet; they
          ;; belong with the VFS/network layer.
          (type $SecurityGuard (sub $Heap
                                    (struct
                                      (field $hash          (mut i32))
                                      (field $parent        (ref eq))
                                      (field $file-guard    (ref $Procedure))
                                      (field $network-guard (ref $Procedure))
                                      (field $link-guard    (ref $Procedure)))))
          (type $CustodianBox (sub $Heap
                                   (struct
                                     (field $hash (mut i32))
                                     (field $cust (ref $Custodian))
                                     (field $v    (mut (ref eq))))))
          (type $Date (sub $Heap
                           (struct
                             (field $hash             (mut i32))
                             (field $second           (ref eq))
                             (field $minute           (ref eq))
                             (field $hour             (ref eq))
                             (field $day              (ref eq))
                             (field $month            (ref eq))
                             (field $year             (ref eq))
                             (field $week-day         (ref eq))
                             (field $year-day         (ref eq))
                             (field $dst?             (ref eq))
                             (field $time-zone-offset (ref eq)))))
          (type $DateStar (sub $Date
                               (struct
                                 (field $hash             (mut i32))
                                 (field $second           (ref eq))
                                 (field $minute           (ref eq))
                                 (field $hour             (ref eq))
                                 (field $day              (ref eq))
                                 (field $month            (ref eq))
                                 (field $year             (ref eq))
                                 (field $week-day         (ref eq))
                                 (field $year-day         (ref eq))
                                 (field $dst?             (ref eq))
                                 (field $time-zone-offset (ref eq))
                                 (field $nanosecond       (ref eq))
                                 (field $time-zone-name   (ref $String)))))
          (type $Semaphore (sub $Heap
                                (struct
                                  (field $hash  (mut i32))
                                  (field $count (mut i32)))))
          (type $SemaphorePeekEvt (sub $Heap
                                       (struct
                                         (field $hash (mut i32))
                                         (field $sema (ref $Semaphore)))))
          (type $AlwaysEvt (sub $Heap
                                (struct
                                  (field $hash (mut i32)))))
          (type $NeverEvt (sub $Heap
                               (struct
                                 (field $hash (mut i32)))))
          ;; Racket CS uses uninterruptible locks around mutable runtime
          ;; tables. WebRacket is currently single-threaded, so the lock value
          ;; is opaque and acquire/release are no-ops. If WebRacket grows
          ;; threads/places later, this is where real lock state belongs.
          (type $UninterruptibleLock (sub $Heap
                                          (struct
                                            (field $hash (mut i32)))))
          ;; Environment variables are currently modeled as an empty set. This
          ;; is enough for expander probes that merely ask whether flags exist.
          (type $EnvironmentVariables (sub $Heap
                                           (struct
                                             (field $hash (mut i32)))))
          ;; Lightweight pseudo-random generators. Racket specifies MRG32k3a;
          ;; WebRacket currently uses SplitMix32 state while preserving the
          ;; generator object/parameter protocol needed by racket/base modules.
          (type $PseudoRandomGenerator (sub $Heap
                                            (struct
                                              (field $hash  (mut i32))
                                              (field $state (mut i32)))))
          ;; Private payload thrown by WebRacket's bootstrap
          ;; call-with-escape-continuation implementation.
          (type $EscapeContinuationJump (sub $Heap
                                             (struct
                                               (field $hash  (mut i32))
                                               (field $value (ref eq)))))

          ;; Poor-man parameterizations. This is an overlay chain over a base
          ;; parameterization plus a list of parameter/value pairs. It is not a
          ;; full continuation-mark model, but it preserves dynamic parameter
          ;; lookup for the bootstrap parameters that WebRacket implements as
          ;; primitives.
          (type $Parameterization (sub $Heap
                                       (struct
                                         (field $hash     (mut i32))
                                         (field $base     (ref eq))
                                         (field $bindings (ref eq)))))

          ;; WebRacket does not implement impersonators yet, but Racket
          ;; libraries allocate impersonator-property descriptors at module
          ;; initialization time. Keep a first-class descriptor so the public
          ;; predicates work without pretending that impersonation is active.
          (type $ImpersonatorProperty (sub $Heap
                                           (struct
                                             (field $hash (mut i32))
                                             (field $name (ref eq)))))

          (type $Procedure
                (sub $Heap
                     (struct
                       (field $hash   (mut i32))
                       (field $name   (ref eq))   ;; $false or a $Symbol
                       (field $arity  (ref eq))   ;; fixnum (i31 with lsb=0)
                       ;                              +n means precisely n
                       ;                               0 means precisely 0
                       ;                              -1 means at least  0
                       ;                              -2 means at least  1
                       ;                              -n means at least n-1
                       (field $realm  (ref eq))   ;; $false or $Symbol
                       (field $invoke (ref $ProcedureInvoker)))))

          (type $ProcedureInvoker
                (func (param $proc (ref $Procedure))
                      (param $args (ref $Args))      ; an array of (ref eq)
                      (result (ref eq))))

          ;; Raw primitive function types
          (type $Prim0    (func                                   (result (ref eq))))
          (type $Prim1    (func (param (ref eq))                  (result (ref eq))))
          (type $Prim2    (func (param (ref eq)) (param (ref eq)) (result (ref eq))))
          (type $Prim3    (func (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (result (ref eq))))
          (type $Prim4    (func (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (result (ref eq))))
          (type $Prim5    (func (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (result (ref eq))))

          (type $Prim>=0  (func (param (ref eq))      ;; list of args
                                (result (ref eq))))
          (type $Prim>=1  (func (param (ref eq))      ;; first arg
                                (param (ref eq))      ;; rest list
                                (result (ref eq))))
          (type $Prim>=2  (func (param (ref eq)) (param (ref eq))
                                (param (ref eq))      ;; rest list
                                (result (ref eq))))
          (type $Prim>=3  (func (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (param (ref eq))      ;; rest list
                                (result (ref eq))))
          (type $Prim>=4  (func (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (param (ref eq))      ;; rest list
                                (result (ref eq))))

          (type $Prim01   (func (param (ref eq)) (result (ref eq))))
          (type $Prim02   (func (param (ref eq)) (param (ref eq)) (result (ref eq))))
          (type $Prim03   (func (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (result (ref eq))))

          (type $Prim12   (func (param (ref eq)) (param (ref eq)) (result (ref eq))))
          (type $Prim13   (func (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (result (ref eq))))
          (type $Prim14   (func (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (result (ref eq))))
          (type $Prim15   (func (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (result (ref eq))))
          ; Instead of introducing an $Prim16 use $Prim>=1 to reduce the number of shapes.
          (type $Prim23   (func (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (result (ref eq))))
          (type $Prim24   (func (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (result (ref eq))))
          (type $Prim25   (func (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (result (ref eq))))

          (type $Prim34   (func (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (result (ref eq))))
          (type $Prim35   (func (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (result (ref eq))))
          (type $Prim67   (func (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq))
                                 (param (ref eq)) (param (ref eq)) (param (ref eq))
                                 (result (ref eq))))
          (type $Prim6    (func (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq)) (param (ref eq))
                                (param (ref eq))
                                (result (ref eq))))

          (type $ClosureCode  (func (param $clos (ref $Closure))
                                    (param $args (ref $Args))
                                    (result (ref eq))))
          (type $KnownCode0   (func (param $args (ref $Args))
                                    (result (ref eq))))
          (type $KnownCode1   (func (param $env0 (ref eq))
                                    (param $args (ref $Args))
                                    (result (ref eq))))
          (type $Closure
                (sub $Procedure
                     (struct
                       ; from $Procedure
                       (field $hash   (mut i32))
                       (field $name   (ref eq))   ;; $false or a $Symbol
                       (field $arity  (ref eq))   ;; fixnum (i31 with lsb=0) or (arity-at-least n)
                       (field $realm  (ref eq))   ;; $false or $Symbol
                       (field $invoke (ref $ProcedureInvoker))
                       ; from $Closure
                       (field $debug-id (ref eq)) ;; $false or a $Symbol used for debug lookup
                       (field $code   (ref $ClosureCode))
                       (field $free   (ref $Free)))))

          (type $Closure1
                (sub $Closure
                     (struct
                       ;; inherited $Procedure fields
                       (field $hash   (mut i32))
                       (field $name   (ref eq))
                       (field $arity  (ref eq))
                       (field $realm  (ref eq))
                       (field $invoke (ref $ProcedureInvoker))
                       ;; inherited $Closure fields
                       (field $debug-id (ref eq))
                       (field $code   (ref $ClosureCode))
                       (field $free   (ref $Free))
                       ;; inline payload for the single captured value
                       (field $free0  (mut (ref eq))))))

          (type $Closure2
                (sub $Closure
                     (struct
                       ;; inherited $Procedure fields
                       (field $hash   (mut i32))
                       (field $name   (ref eq))
                       (field $arity  (ref eq))
                       (field $realm  (ref eq))
                       (field $invoke (ref $ProcedureInvoker))
                       ;; inherited $Closure fields
                       (field $debug-id (ref eq))
                       (field $code   (ref $ClosureCode))
                       (field $free   (ref $Free))
                       ;; inline payload for the two captured values
                       (field $free0  (mut (ref eq)))
                       (field $free1  (mut (ref eq))))))

          (type $Closure3
                (sub $Closure
                     (struct
                       ;; inherited $Procedure fields
                       (field $hash   (mut i32))
                       (field $name   (ref eq))
                       (field $arity  (ref eq))
                       (field $realm  (ref eq))
                       (field $invoke (ref $ProcedureInvoker))
                       ;; inherited $Closure fields
                       (field $debug-id (ref eq))
                       (field $code   (ref $ClosureCode))
                       (field $free   (ref $Free))
                       ;; inline payload for the three captured values
                       (field $free0  (mut (ref eq)))
                       (field $free1  (mut (ref eq)))
                       (field $free2  (mut (ref eq))))))

          (type $CaseClosure  ; for case-lambda
                (sub $Closure
                     (struct
                       ;; inherited $Procedure fields
                       (field $hash   (mut i32))
                       (field $name   (ref eq))
                       (field $arity  (ref eq))        ;; store (ref $I32Array) here for Racket-style arity
                       (field $realm  (ref eq))
                       (field $invoke (ref $ProcedureInvoker))
                       ;; inherited $Closure fields
                       (field $debug-id (ref eq))
                       (field $code   (ref $ClosureCode))  ;; dispatcher
                       (field $free   (ref $Free))         ;; can be an empty array
                       ;; new, typed payload
                       (field $arities (ref $I32Array))    ;; markers: m>=0 exact m; m<0 at least (-m-1)
                       (field $arms    (ref $Array)))))    ;; (ref eq) array of arm closures


          (type $PrimitiveProcedure
                (sub $Procedure
                     (struct
                       ; From $Procedure
                       (field $hash   (mut i32))
                       (field $name   (ref eq))
                       (field $arity  (ref eq))
                       (field $realm  (ref eq))
                       (field $invoke (ref $ProcedureInvoker))
                       ; Function pointer for primitive implementation
                       (field $code (ref null func))
                       ; other fields
                       (field $result-arity (ref eq))))) ;; fixnum like 1 for most

          (type $PrimitiveClosure
                (sub $PrimitiveProcedure
                     (struct
                       ;; Inherits all fields from $PrimitiveProcedure:
                       (field $hash         (mut i32))
                       (field $name         (ref eq))
                       (field $arity        (ref eq))
                       (field $realm        (ref eq))
                       (field $invoke       (ref $ProcedureInvoker))
                       (field $code         (ref null func))
                       (field $result-arity (ref eq))  ; fixnum
                       ;; Own fields
                       ; ...
                       )))


          ; Some structs are applicable.
          ; In order to make function calls fast, we make structs a subtype of $Procedure.
          ; Non-applicable structs gets an $invoke function that signals an error.
          ; The down side is that we add 4 (four!) extra fields.
          (type $Struct
                (sub $Procedure
                     (struct
                       ; from the procedure super-type
                       (field $hash   (mut i32))  ;; Computed lazily, starts at 0
                       (field $name   (ref eq))   ;; $false or a $Symbol
                       (field $arity  (ref eq))   ;; fixnum (i31 with lsb=0) or (arity-at-least n)
                       (field $realm  (ref eq))   ;; $false or $Symbol
                       (field $invoke (ref $ProcedureInvoker))
                       ; fields for structs
                       (field $type   (ref $StructType))      ;; Pointer to struct type descriptor
                       (field $fields (ref $Array)))))        ;; Array of (ref eq), holds field values

          (type $StructType
                (sub $Heap
                     (struct
                       (field $hash             (mut i32))            ;; Computed lazily, starts at 0
                       (field $name             (ref $Symbol))        ;; Struct name
                       (field $super            (ref eq))             ;; Supertype or #f (use global $false)
                       (field $field-count      i32)                  ;; Total number of fields
                       (field $init-indices     (ref eq))             ;; List of init field indices ($Pair or $null)
                       (field $auto-indices     (ref eq))             ;; List of auto field indices
                       (field $auto-values      (ref eq))             ;; List of values for auto fields
                       (field $properties       (ref eq))             ;; Property table: hash table
                       (field $inspector        (ref eq))             ;; Inspector object or #f
                       (field $immutables       (ref eq))             ;; Immutables descriptor or #f
                       (field $guard            (ref eq))             ;; Guard procedure or #f
                       (field $constructor-name (ref eq)))))          ;; For error reporting / printing ($Symbol or #f)

          (type $StructConstructorProcedure
                ; current representation is a plain closure
                (sub $Closure
                     (struct
                       (field $hash   (mut i32))
                       (field $name   (ref eq))   ;; $false or a $Symbol
                       (field $arity  (ref eq))   ;; fixnum (i31 with lsb=0) or (arity-at-least n)
                       (field $realm  (ref eq))   ;; $false or $Symbol
                       (field $invoke (ref $ProcedureInvoker))
                       (field $debug-id (ref eq))
                       (field $code   (ref $ClosureCode))
                       (field $free   (ref $Free)))))


          (type $StructPredicateProcedure
                ; current representation is a plain closure
                (sub $Closure
                     (struct
                       (field $hash   (mut i32))
                       (field $name   (ref eq))   ;; $false or a $Symbol
                       (field $arity  (ref eq))   ;; fixnum (i31 with lsb=0) or (arity-at-least n)
                       (field $realm  (ref eq))   ;; $false or $Symbol
                       (field $invoke (ref $ProcedureInvoker))
                       (field $debug-id (ref eq))
                       (field $code   (ref $ClosureCode))
                       (field $free   (ref $Free)))))

          (type $StructAccessorProcedure
                ; current representation is a plain closure
                (sub $Closure
                     (struct
                       (field $hash   (mut i32))
                       (field $name   (ref eq))   ;; $false or a $Symbol
                       (field $arity  (ref eq))   ;; fixnum (i31 with lsb=0) or (arity-at-least n)
                       (field $realm  (ref eq))   ;; $false or $Symbol
                       (field $invoke (ref $ProcedureInvoker))
                       (field $debug-id (ref eq))
                       (field $code   (ref $ClosureCode))
                       (field $free   (ref $Free)))))

          (type $StructMutatorProcedure
                ; current representation is a plain closure
                (sub $Closure
                     (struct
                       (field $hash   (mut i32))
                       (field $name   (ref eq))   ;; $false or a $Symbol
                       (field $arity  (ref eq))   ;; fixnum (i31 with lsb=0) or (arity-at-least n)
                       (field $realm  (ref eq))   ;; $false or $Symbol
                       (field $invoke (ref $ProcedureInvoker))
                       (field $debug-id (ref eq))
                       (field $code   (ref $ClosureCode))
                       (field $free   (ref $Free)))))

          (type $StructTypeProperty
                (sub $Heap
                     (struct
                       (field $hash               (mut i32))          ;; Cached hash, lazily computed
                       (field $name               (ref $Symbol))      ;; Property name
                       (field $guard-info         (ref eq))           ;; Guard metadata or #f
                       (field $supers             (ref eq))           ;; List of super property descriptors
                       (field $can-impersonate    (ref eq))           ;; Boolean indicating impersonation support
                       (field $accessor-name-info (ref eq))           ;; Accessor naming hints or #f
                       (field $predicate-cache    (mut (ref eq)))     ;; Cached predicate procedure or #f
                       (field $accessor-cache     (mut (ref eq))))))  ;; Cached accessor procedure or #f

          (type $Number (sub $Heap    ; abstract super type for boxed numbers
                             (struct
                               (field $hash (mut i32)))))
          (type $Real (sub $Number
                           (struct
                             (field $hash (mut i32)))))
          ;; Exact integers outside the i31 fixnum range. Limbs are unsigned
          ;; base-2^32 words in little-endian order, and zero is represented
          ;; only as the fixnum 0.
          (type $Bignum (sub $Real
                             (struct
                               (field $hash  (mut i32))
                               (field $sign  i32)
                               (field $limbs (ref $I32Array)))))
          ;; Exact non-integer rationals. Numerators and denominators are
          ;; canonical exact integers; denominators are positive and not 1.
          (type $Rational (sub $Real
                               (struct
                                 (field $hash (mut i32))
                                 (field $num  (ref eq))
                                 (field $den  (ref eq)))))
          (type $Flonum (sub $Real  ; double precision
                             (struct
                               (field $hash (mut i32))
                               (field $v f64))))
          (type $Complex (sub $Number
                              (struct
                                (field $hash (mut i32))
                                (field $real (ref eq))
                                (field $imag (ref eq)))))

	          (type $Vector    (sub $Heap
                                (struct
                                  (field $hash      (mut i32))
                                  (field $immutable i32)                        ;; 0 or 1
                                  (field $arr       (ref $Array)))))
          (type $TreelistNode (sub $Heap
                                   (struct
                                     (field $hash     (mut i32))
                                     (field $children (ref $Array))
                                     (field $sizes    (ref null $I32Array)))))
          (type $Treelist (sub $Heap
                               (struct
                                 (field $hash   (mut i32))
                                 (field $root   (ref $TreelistNode))
                                 (field $size   i32)
                                 (field $height i32))))
          (type $String    (sub $Heap
                                (struct
                                  (field $hash      (mut i32))
                                  (field $immutable i32)                        ;; 0 or 1
                                  (field $codepoints (mut (ref $I32Array))))))  ;; An array of Unicode code points
          (type $Bytes      (sub $Heap
                                 (struct
                                   (field $hash      (mut i32))
                                   (field $immutable i32)                      ;; 0 or 1
                                   (field $bs        (mut (ref $I8Array)))))) ;; An array of bytes
          (type $Regexp     (sub $Heap
                                 (struct
                                   (field $hash   (mut i32))
                                   (field $kind   i32)       ;; 0 rx, 1 px, 2 byte-rx, 3 byte-px
                                   (field $source (ref eq))))) ;; string or bytes object-name
          (type $Symbol (sub $Heap
                             (struct
                               (field $hash          (mut i32))          ;; cached hash
                               (field $name          (ref $String))      ;; symbol name (string)
                               (field $unreadable?   i32)                ;; non-zero for unreadable symbols
                               (field $property-list (mut (ref eq))))))  ;; user-defined properties
          (type $Ephemeron (sub $Heap
                                (struct
                                  (field $hash  (mut i32))
                                  (field $key   (ref eq))
                                  (field $value (mut (ref eq))))))
          (type $Keyword (sub $Heap
                              (struct
                                (field $hash  (mut i32))
                                (field $str   (ref $String)))))  ; string without #:

          (type $Location   (sub $Heap
                                 ; If line counting is not enabled, the first two are #f
                                 (struct
                                   (field $hash  (mut i32))
                                   (field $line  (mut (ref eq)))    ; #f or line number (fixnum)
                                   (field $col   (mut (ref eq)))    ; #f or column number
                                   (field $pos   (mut (ref eq)))))) ; #f or position

          (type $Path      (sub $Heap
                                (struct
                                  (field $hash       (mut i32))          ;; cached hash
                                  (field $bytes      (ref $Bytes))       ;; raw byte representation (bytes)
                                  (field $convention (ref eq)))))        ;; 'unix or 'windows symbol


          (type $Port
                (sub $Heap
                     (struct
                       (field $hash  (mut i32))
                       (field $name  (mut (ref eq))) ; the port name (string) [the object-name]
                       (field $closed (mut i32))      ; 0 = open, 1 = closed
                       ; buffer (if used):
                       (field $bytes (mut (ref $Bytes)))        ; the byte string (bytes)
                       (field $len   (mut i32))                 ; the length of the string
                       (field $idx   (mut i32))                 ; the current index into the byte string
                       ; location
                       (field $loc   (mut (ref $Location))))))  ; the current location

          (type $InputPort
                (sub $Port
                     (struct
                       (field $hash  (mut i32))
                       (field $name  (mut (ref eq)))            ; the port name (string) [the object-name]
                       (field $closed (mut i32))                 ; 0 = open, 1 = closed
                       (field $bytes (mut (ref $Bytes)))        ; the byte string (bytes)
                       (field $len   (mut i32))                 ; the length of the string
                       (field $idx   (mut i32))                 ; the current index into the byte string
                       (field $loc   (mut (ref $Location)))     ; the current location
                       (field $read-handler (mut (ref eq))))))  ; #f means use the default reader

          (type $OutputPort
                (sub $Port
                     (struct
                       (field $hash  (mut i32))
                       (field $name  (mut (ref eq)))            ; the port name (string) [the object-name]
                       (field $closed (mut i32))                 ; 0 = open, 1 = closed
                       (field $bytes (mut (ref $Bytes)))        ; the byte string (bytes)
                       (field $len   (mut i32))                 ; the length of the string
                       (field $idx   (mut i32))                 ; the current index into the byte string
                       (field $loc   (mut (ref $Location))))))  ; the current location

          (type $InputStringPort
                (sub $InputPort
                     (struct
                       (field $hash  (mut i32))
                       (field $name  (mut (ref eq)))            ; the port name   (string)
                       (field $closed (mut i32))                 ; 0 = open, 1 = closed
                       (field $bytes (mut (ref $Bytes)))        ; the byte string (bytes)
                       (field $len   (mut i32))                 ; the length of the string
                       (field $idx   (mut i32))                 ; the current index into the byte string
                       (field $loc   (mut (ref $Location)))     ; the current location
                       (field $read-handler (mut (ref eq)))      ; port-read-handler override or #f
                       ;; UTF-8 decoder state:
                       (field $utf8-len    (mut i32))     ;; 0 = idle, 1-4 = number of bytes expected
                       (field $utf8-left   (mut i32))     ;; number of continuation bytes still needed
                       (field $utf8-bytes  (mut i32)))))  ;; current byte count seen (for column fix)

          (type $OutputStringPort
                (sub $OutputPort
                     (struct
                       (field $hash  (mut i32))
                       (field $name  (mut (ref eq)))         ; the port name   (string)
                       (field $closed (mut i32))              ; 0 = open, 1 = closed
                       (field $bytes (mut (ref $Bytes)))     ; the byte string (bytes)
                       (field $len   (mut i32))              ; the length of the string
                       (field $idx   (mut i32))              ; the current index into the string
                       (field $loc   (mut (ref $Location)))  ; the current location
                       ;; UTF-8 decoder state:
                       (field $utf8-len    (mut i32))     ;; 0 = idle, 1-4 = number of bytes expected
                       (field $utf8-left   (mut i32))     ;; number of continuation bytes still needed
                       (field $utf8-bytes  (mut i32)))))  ;; current byte count seen (for column fix)

          (type $OutputFilePort
                (sub $OutputStringPort
                     (struct
                       (field $hash  (mut i32))
                       (field $name  (mut (ref eq)))
                       (field $closed (mut i32))
                       (field $bytes (mut (ref $Bytes)))
                       (field $len   (mut i32))
                       (field $idx   (mut i32))
                       (field $loc   (mut (ref $Location)))
                       (field $utf8-len    (mut i32))
                       (field $utf8-left   (mut i32))
                       (field $utf8-bytes  (mut i32))
                       (field $path        (ref $Path)))))

          (type $CustomInputPort
                (sub $InputPort
                     (struct
                       (field $hash  (mut i32))
                       (field $name  (mut (ref eq)))                 ; the port name   (any/c)
                       (field $closed (mut i32))                      ; 0 = open, 1 = closed
                       (field $bytes (mut (ref $Bytes)))             ; scratch buffer  (bytes)
                       (field $len   (mut i32))                      ; unused length placeholder
                       (field $idx   (mut i32))                      ; unused index placeholder
                       (field $loc   (mut (ref $Location)))          ; the current location
                       (field $read-handler (mut (ref eq)))           ; port-read-handler override or #f
                       (field $read-proc          (mut (ref eq)))    ; required read-in argument
                       (field $peek-proc          (mut (ref eq)))    ; required peek argument
                       (field $close-proc         (mut (ref eq)))    ; required close argument
                       (field $get-progress-evt   (mut (ref eq)))    ; optional, default = #f
                       (field $commit-proc        (mut (ref eq)))    ; optional, default = #f
                       (field $get-location-proc  (mut (ref eq)))    ; optional, default = #f
                       (field $count-lines-proc   (mut (ref eq)))    ; optional, default = void
                       (field $init-position-arg  (mut (ref eq)))    ; optional, default = 1
                       (field $buffer-mode-arg    (mut (ref eq)))))) ; optional, default = #f

          (type $CustomOutputPort
                (sub $OutputPort
                     (struct
                       (field $hash  (mut i32))
                       (field $name  (mut (ref eq)))                 ; the port name   (any/c)
                       (field $closed (mut i32))                      ; 0 = open, 1 = closed
                       (field $bytes (mut (ref $Bytes)))             ; unused scratch bytes
                       (field $len   (mut i32))                      ; unused length placeholder
                       (field $idx   (mut i32))                      ; known byte position
                       (field $loc   (mut (ref $Location)))          ; current location
                       (field $write-proc             (mut (ref eq))) ; output-port? or procedure?
                       (field $close-proc             (mut (ref eq))) ; procedure?
                       (field $write-special-proc     (mut (ref eq))) ; optional
                       (field $get-write-evt-proc     (mut (ref eq))) ; optional
                       (field $get-write-special-proc (mut (ref eq))) ; optional
                       (field $get-location-proc      (mut (ref eq))) ; optional
                       (field $count-lines-proc       (mut (ref eq))) ; optional, default = void
                       (field $init-position-arg      (mut (ref eq))) ; optional, default = 1
                       (field $buffer-mode-arg        (mut (ref eq)))))) ; optional, default = #f


          (type $Hash   ; abstract super type for hashtables
                (sub $Heap
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq)))))  ; boolean (immediate, i31 tagged)

          (type $HashEq
                (sub $Hash
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq)))))

          (type $HashEqv
                (sub $Hash
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq)))))

          (type $HashEqual
                (sub $Hash
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq)))))

          (type $HashEqualAlways
                (sub $Hash
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq)))))

          ;; Stencil vectors are Chez/Racket CS's compact masked vectors. The
          ;; system variant is used as the node representation for immutable
          ;; hash HAMTs in `rumble/hamt-stencil.ss`.
          (type $StencilVector
                (sub $Heap
                     (struct
                       (field $hash    (mut i32))
                       (field $system? i32)
                       (field $mask    (mut i32))
                       (field $slots   (ref $Array)))))


          (type $HashEqMutable
                ; Mutable hash tables are implemented as an open-addressing hash table
                ; with linear probing.
                (sub $HashEq
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq))
                       (field $entries  (mut (ref $Array)))  ;; flat array: key0, val0, key1, val1, ...
                       (field $count    (mut i32)))))        ;; number of key/value pairs currently stored

          (type $HashEqvMutable
                ; Mutable hash tables are implemented as an open-addressing hash table
                ; with linear probing.
                (sub $HashEqv
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq))
                       (field $entries  (mut (ref $Array)))  ;; flat array: key0, val0, key1, val1, ...
                       (field $count    (mut i32)))))        ;; number of key/value pairs currently stored

          (type $HashEqualMutable
                ; Mutable hash tables are implemented as an open-addressing hash table
                ; with linear probing.
                (sub $HashEqual
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq))
                       (field $entries  (mut (ref $Array)))  ;; flat array: key0, val0, key1, val1, ...
                       (field $count    (mut i32)))))        ;; number of key/value pairs currently stored

          (type $HashEqualAlwaysMutable
                ; Mutable hash tables are implemented as an open-addressing hash table
                ; with linear probing.
                (sub $HashEqualAlways
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq))
                       (field $entries  (mut (ref $Array)))  ;; flat array: key0, val0, key1, val1, ...
                       (field $count    (mut i32)))))        ;; number of key/value pairs currently stored

          ;; Private immutable hash support. Racket CS represents immutable
          ;; hashes as HAMTs over system stencil vectors. WebRacket mirrors
          ;; the same split at the runtime boundary: stencil vectors are
          ;; bnodes, while terminal full-hash collisions use explicit cnodes.
          (type $ImmutableHashEntry
                (sub $Heap
                     (struct
                       (field $hash      (mut i32))
                       (field $key-hash  i32)
                       (field $key       (ref eq))
                       (field $value     (ref eq)))))

          ;; Private packed-inline key wrapper. Equal?/equal-always? HAMTs use
          ;; this only in physical bnode key slots so promotion can reuse the
          ;; cached hash while public APIs still expose the original key.
          (type $ImmutableHashWrappedKey
                (sub $Heap
                     (struct
                       (field $hash     (mut i32))
                       (field $kind     i32)
                       (field $key-hash i32)
                       (field $key      (ref eq)))))

          (type $ImmutableHashCNode
                (sub $Heap
                     (struct
                       (field $hash     (mut i32))
                       (field $key-hash i32)
                       (field $content  (ref eq)))))

          (type $HashEqImmutable
                (sub $HashEq
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq))
                       (field $root     (ref eq))
                       (field $count    i32))))

          (type $HashEqvImmutable
                (sub $HashEqv
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq))
                       (field $root     (ref eq))
                       (field $count    i32))))

          (type $HashEqualImmutable
                (sub $HashEqual
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq))
                       (field $root     (ref eq))
                       (field $count    i32))))

          (type $HashEqualAlwaysImmutable
                (sub $HashEqualAlways
                     (struct
                       (field $hash     (mut i32))
                       (field $mutable? (ref eq))
                       (field $root     (ref eq))
                       (field $count    i32))))

          ;; Reader-graph hash placeholders. Full graph resolution belongs with
          ;; make-reader-graph/read; for now retain the association list and
          ;; comparison kind so installed libraries can recognize placeholders.
          (type $HashPlaceholder
                (sub $Heap
                     (struct
                       (field $hash   (mut i32))
                       (field $kind   i32)      ;; 0 equal?, 1 eq?, 2 eqv?, 3 equal-always?
                       (field $assocs (ref eq)))))

          ;; Reader-graph placeholders created by make-placeholder.
          (type $Placeholder
                (sub $Heap
                     (struct
                       (field $hash  (mut i32))
                       (field $value (mut (ref eq))))))

	          (type $VariableReference ; opaque value returned by #%variable-reference
	                ; Minimal payload needed by variable-reference predicates.
	                (sub $Heap
	                     (struct
	                       (field $hash (mut i32))
	                       (field $constant?   (ref eq))
	                       (field $from-unsafe? (ref eq))
	                       )))
          (type $ResolvedModulePath
                (sub $Heap
                     (struct
                       (field $hash (mut i32))
                       (field $name (ref eq)))))
          (type $ModulePathIndex
                (sub $Heap
                     (struct
                       (field $hash     (mut i32))
                       (field $path     (ref eq))
                       (field $base     (ref eq))
                       (field $submod   (ref eq))
                       (field $resolved (mut (ref eq))))))
	          (type $ModuleVariable ; lowered module/linklet variable cell
	                (sub $Heap
	                     (struct
	                       (field $hash (mut i32))
	                       (field $name      (ref eq))
	                       (field $value     (mut (ref eq)))
	                       (field $constance (mut (ref eq))))))
	          (type $ModuleVariableReference
	                (sub $Heap
	                     (struct
	                       (field $hash (mut i32))
	                       (field $instance (ref eq))
	                       (field $variable (ref eq)))))
	          (type $External
	            (sub $Heap
	              (struct
                (field $hash (mut i32))
                (field $v    (ref null extern)))))

          ;; (Placeholder) module registry
          (type $ModuleRegistry
                (sub $Heap
                     (struct
                       (field $hash  (mut i32))
                       (field $table (mut (ref $Array))))))

          ; A namespace has a module registry.
          ; The registry maps a module names to module declarations.
          ; The registry is shared by all phases.
          ; The namespace holds a distinct set of top-level variables for each phase.
          ; Module instances are (can be) distinct for each phase.
          ; Each namespace has a base phase.
          ; The base phase is used by `eval` and `dynamic-require`.


          ; The first step in evaluating any compiled expression is to
          ; link its top-level variable and module-level variable references to
          ; specific variables in the namespace.

          ; At all times during evaluation, some namespace is designated as the current namespace.

          ; How does provide and require work?

          ; A module body is executed only when the module is
          ; explicitly instantiated via require or dynamic-require.

          ; On invocation, imported modules are instantiated in the order in which
          ; they are required into the module (although earlier instantiations or
          ; transitive requires can trigger the instantiation of a module before
          ; its order within a given module).

          ; Then, expressions and definitions
          ; are evaluated in order as they appear within the module.

          ; - for each module we need an $module:<module-name>:instantiate
          ;    - allocate a $ModuleInstance
          ;    - require modules
          ;    - setup module level variables
          ;    - evaluate expressions and definitions


          ;; Namespace now maps Symbol -> Boxed via a single hasheq/mutable table
          (type $Namespace
                (sub $Heap
                     (struct
                       (field $hash       (mut i32))
                       (field $name       (ref eq))                   ;; #f or $String
                       (field $base-phase i32)
                       (field $table      (mut (ref $HashEqMutable))) ;; hasheq: Symbol → Boxed
                       (field $modules    (mut (ref $ModuleRegistry)))
                       (field $protect    (mut i32)))))

          ;; A builder that accumulates arguments to be serialized for the host.
          (type $FaslBuilder
                (sub $Heap
                     (struct
                       (field $hash     (mut i32))               ;; lazy, start at 0
                       (field $strings  (ref $GrowableArray))    ;; growable of (ref $String)
                       (field $values   (ref $GrowableArray))))) ;; growable of (ref eq)

          ;; Linklet instance structure
          (type $Instance
                (sub $Heap
                     (struct
                       (field $hash      (mut i32))
                       (field $name      (ref eq))                      ;; any value for debugging
                       (field $data      (ref eq))                      ;; any value (e.g., namespace)
                       (field $variables (mut (ref $HashEqMutable)))    ;; hasheq: Symbol → Box
                       (field $constants (mut (ref $HashEqMutable)))))) ;; hasheq: Symbol → #t

          (type $Linklet
                (sub $Heap
                     (struct
                       (field $hash        (mut i32))
                       (field $name        (ref eq))    ; #f or a symbol
                       (field $importss    (ref eq))    ; (listof (listof symbol?))
                       (field $exports     (ref eq))    ; (listof symbol?)
                       )))

          ; A compiled linklet is a procedure `proc` that as arguments
          ; take an self-instance and the import instances.
          ; The arity is the same as the length of `importss` plus one (due to the self-instance).
          ; Each sublist of `importss` is a list of symbols imported from that instance.
          ; The field `exports` is a list of symbols to be exported.
          ; Calling `proc` will run the body of the linklet.
          (type $CompiledLinklet
                (sub $Linklet
                     (struct
                       (field $hash        (mut i32))
                       (field $name        (ref eq))    ; #f or a symbol
                       (field $importss    (ref eq))    ; (listof (listof symbol?))
                       (field $exports     (ref eq))    ; (listof symbol?)
                       (field $proc        (ref eq))    ; takes self instance plus instance arguments
                       )))

          ;; WebRacket currently stores mutable hasheq tables directly in
          ;; linklet bundle/directory wrappers.
          (type $LinkletBundle
                (sub $Heap
                     (struct
                       (field $hash    (mut i32))
                       (field $content (ref $HashEqMutable)))))

          (type $LinkletDirectory
                (sub $Heap
                     (struct
                       (field $hash    (mut i32))
                       (field $content (ref $HashEqMutable)))))

          (type $UnquotedPrintingString
                (sub $Heap
                     (struct
                       (field $hash  (mut i32))
                       (field $value (ref eq)))))

          ) ; rec
    ))
