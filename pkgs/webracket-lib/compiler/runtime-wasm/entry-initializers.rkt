#lang racket

(provide entry-struct-property-initializer-forms)

;; entry-struct-property-initializer-forms : (listof datum?)
;;   Initialize runtime struct-type properties and equal+hash recursion closures.
(define entry-struct-property-initializer-forms
  '(
                     ;; Initialize struct-type properties provided by the runtime
                     (global.set $prop:sealed
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:sealed))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:evt
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:evt))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:object-name
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:object-name))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:procedure
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:procedure))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:exn:srclocs
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:exn:srclocs))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     ;; Reference: prop:input-port and prop:output-port identify
                     ;; structure types whose instances can stand in for ports.
                     ;; This initializes the property identities needed by
                     ;; racket/pretty; port coercion through the properties is
                     ;; implemented when a primitive actually consumes the struct
                     ;; as a port.
                     (global.set $prop:input-port
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:input-port))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:output-port
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:output-port))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     ;; Reference: impersonator-prop:application-mark is an
                     ;; impersonator property recognized by procedure
                     ;; impersonators. WebRacket has no impersonators yet, but
                     ;; contracts expect the property identity to exist.
                     (global.set $impersonator-prop:application-mark
                                 (ref.cast (ref eq)
                                           (struct.new $ImpersonatorProperty
                                                       (i32.const 0)
                                                       (global.get $symbol:impersonator-prop:application-mark))))
                     (global.set $prop:checked-procedure
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:checked-procedure))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:impersonator-of
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:impersonator-of))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:method-arity-error
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:method-arity-error))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:arity-string
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:arity-string))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:incomplete-arity
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:incomplete-arity))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:authentic
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:authentic))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:custom-write
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:custom-write))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:custom-print-quotable
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:custom-print-quotable))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $prop:equal+hash
                                 (ref.cast (ref eq)
                                           (call $make-struct-type-property-descriptor/checked
                                                 (ref.cast (ref $Symbol)
                                                           (global.get $symbol:prop:equal+hash))
                                                 (global.get $false)
                                                 (global.get $null)
                                                 (global.get $false)
                                                 (global.get $false))))
                     (global.set $equal+hash-recur/equal
                                 (struct.new $Closure
                                             (i32.const 0)
                                             (global.get $false)
                                             (ref.i31 (i32.const 4))
                                             (global.get $false)
                                             (ref.func $invoke-closure)
                                             (global.get $false)
                                             (ref.func $equal+hash-recur/equal)
                                             (array.new_fixed $Free 0)))
                     (global.set $equal+hash-recur/equal-always
                                 (struct.new $Closure
                                             (i32.const 0)
                                             (global.get $false)
                                             (ref.i31 (i32.const 4))
                                             (global.get $false)
                                             (ref.func $invoke-closure)
                                             (global.get $false)
                                             (ref.func $equal+hash-recur/equal-always)
                                             (array.new_fixed $Free 0)))
                     (global.set $equal+hash-recur/hash
                                 (struct.new $Closure
                                             (i32.const 0)
                                             (global.get $false)
                                             (ref.i31 (i32.const 2))
                                             (global.get $false)
                                             (ref.func $invoke-closure)
                                             (global.get $false)
                                             (ref.func $equal+hash-recur/hash)
                                             (array.new_fixed $Free 0)))
                     (global.set $equal+hash-recur/hash-always
                                 (struct.new $Closure
                                             (i32.const 0)
                                             (global.get $false)
                                             (ref.i31 (i32.const 2))
                                             (global.get $false)
                                             (ref.func $invoke-closure)
                                             (global.get $false)
                                             (ref.func $equal+hash-recur/hash-always)
                                             (array.new_fixed $Free 0)))))
