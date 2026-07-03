#lang racket

(provide closure-empty-free-global-forms
         closure-global-forms
         closure-runtime-global-forms)

;; closure-empty-free-global-forms : (listof datum?)
;;   Declare the shared empty closure free-variable array.
(define closure-empty-free-global-forms
  '(
         ;; Closures

         ; Closures with no free variables can share an empty array
         (global $empty-free (ref $Free)
                 (array.new $Free (global.get $null) (i32.const 0)))

         ;; Closure invocation - invoke
         #;(type $ProcedureInvoker
                 (func (param $proc (ref $Procedure))
                       (param $args (ref $Args))      ; an array of (ref eq)
                       (result (ref eq))))))

;; closure-runtime-global-forms : (listof datum?)
;;   Declare runtime closure values that depend on procedure/linklet helpers.
(define closure-runtime-global-forms
  '(
         (global $dummy-closure (ref $Closure)
                 (struct.new $Closure
                             (i32.const 0)               ; hash
                             (global.get $false)         ; name:  #f or $String
                             (global.get $zero)          ; arity: todo
                             (global.get $false)         ; realm: #f or $Symbol
                             (ref.func $invoke-closure) ; invoke (used by apply, map, etc.)
                             (global.get $false)         ; debug-id
                             (ref.func $placeholder-linklet-code)
                             (array.new_fixed $Free 0)))
         (global $placeholder-linklet-closure (ref $Closure)
                 (struct.new $Closure
                             (i32.const 0)               ; hash
                             (global.get $false)         ; name:  #f or $String
                             (ref.i31 (i32.const -1))    ; arity-at-least 0
                             (global.get $false)         ; realm: #f or $Symbol
                             (ref.func $invoke-closure) ; invoke (used by apply, map, etc.)
                             (global.get $false)         ; debug-id
                             (ref.func $dummy-code)
                             (array.new_fixed $Free 0)))
         (global $interpreted-linklet-retainer (ref $Closure)
                 (struct.new $Closure
                             (i32.const 0)
                             (global.get $false)
                             (ref.i31 (i32.const -1))
                             (global.get $false)
                             (ref.func $invoke-closure)
                             (global.get $false)
                             (ref.func $interpreted-linklet-code)
                             (array.new_fixed $Free 2
                                              (global.get $false)
                                              (global.get $null))))
         (global $escape-continuation-closure (ref $Closure)
                 (struct.new $Closure
                             (i32.const 0)
                             (global.get $false)
                             (ref.i31 (i32.const -1)) ; arity-at-least 0
                             (global.get $false)
                             (ref.func $invoke-escape-continuation)
                             (global.get $false)
                             (ref.func $dummy-code)
                             (array.new_fixed $Free 0)))
         (global $closedapp-clos (mut (ref $Closure)) (global.get $dummy-closure))))

;; closure-global-forms : (listof datum?)
;;   Declare all closure-related globals used by the runtime.
(define closure-global-forms
  (append closure-empty-free-global-forms
          closure-runtime-global-forms))
