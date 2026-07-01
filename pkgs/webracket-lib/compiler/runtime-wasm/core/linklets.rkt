#lang racket

(provide linklet-runtime-only-helper-names
         linklet-runtime-only-helper-forms)

(require "../../private/wasm-utils.rkt")

;; make-predicate-body : symbol? -> (listof datum?)
;;   Generate a standard WebRacket predicate body for ref-type.
(define (make-predicate-body ref-type)
  `((param $v (ref eq))
    (result   (ref eq))
    (if (result (ref eq))
        (ref.test (ref ,ref-type) (local.get $v))
        (then (global.get $true))
        (else (global.get $false)))))

;; linklet-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for linklet helpers.
(define linklet-runtime-only-helper-names
  '($linklet?
    $linklet-body-reserved-symbol?
    $linklet-bundle?
    $hash->linklet-bundle
    $linklet-bundle->hash
    $linklet-directory?
    $hash->linklet-directory
    $linklet-directory->hash
    $make-compiled-linklet
    $linklet-name
    $linklet-import-variables
    $linklet-export-variables
    $instantiate-linklet))

;; linklet-runtime-only-helper-forms : (listof symbol?) -> (listof datum?)
;;   Generate linklet helpers that depend on the active primitive set.
(define (linklet-runtime-only-helper-forms linklet-body-reserved-symbols)
  `(
         ;; Linklets

         (func $linklet? (type $Prim1)
               (param $v (ref eq))  ;; value to check
               (result   (ref eq))

               (if (result (ref eq))
                   (ref.test (ref $Linklet) (local.get $v))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $linklet-body-reserved-symbol? (type $Prim1)
               (param $sym (ref eq))
               (result     (ref eq))

               (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:linklet-body-reserved-symbol?)
                               (global.get $string:symbol?)
                               (local.get $sym))
                         (unreachable)))
               ,@(for/list ([sym (in-list linklet-body-reserved-symbols)])
                   `(if (ref.eq (local.get $sym)
                                (global.get ,($ (string->symbol (~a "symbol:" sym)))))
                        (then (return (global.get $true)))))
               (global.get $false))

         (func $linklet-bundle? (type $Prim1)
               ,@(make-predicate-body '$LinkletBundle))

         (func $hash->linklet-bundle (type $Prim1)
               (param $content (ref eq))
               (result         (ref eq))

               (local $ht    (ref $HashEqMutable))
               (local $pairs (ref eq))
               (local $node  (ref eq))
               (local $pair  (ref $Pair))
               (local $entry (ref $Pair))
               (local $key   (ref eq))

               (if (i32.eqz (ref.test (ref $HashEqMutable) (local.get $content)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:hash->linklet-bundle)
                               (global.get $string:mutable-hasheq?)
                               (local.get $content))
                         (unreachable)))
               (local.set $ht (ref.cast (ref $HashEqMutable) (local.get $content)))

               (local.set $pairs (call $hash->list (local.get $content) (global.get $false)))
               (local.set $node (local.get $pairs))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $node) (global.get $null)))
                            (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                            (local.set $entry (ref.cast (ref $Pair)
                                                        (struct.get $Pair $a (local.get $pair))))
                            (local.set $key (struct.get $Pair $a (local.get $entry)))
                            (if (i32.eqz
                                 (i32.or (ref.test (ref $Symbol) (local.get $key))
                                         (ref.eq (call $fixnum? (local.get $key))
                                                 (global.get $true))))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:hash->linklet-bundle)
                                            (global.get $string:linklet-bundle-key?)
                                            (local.get $key))
                                      (unreachable)))
                            (local.set $node (struct.get $Pair $d (local.get $pair)))
                            (br $loop)))

               (ref.cast (ref eq)
                         (struct.new $LinkletBundle
                                     (i32.const 0)
                                     (local.get $ht))))

         (func $linklet-bundle->hash (type $Prim1)
               (param $bundle (ref eq))
               (result        (ref eq))

               (if (i32.eqz (ref.test (ref $LinkletBundle) (local.get $bundle)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:linklet-bundle->hash)
                               (global.get $string:linklet-bundle?)
                               (local.get $bundle))
                         (unreachable)))
               (ref.cast (ref eq)
                         (struct.get $LinkletBundle $content
                                     (ref.cast (ref $LinkletBundle) (local.get $bundle)))))

         (func $linklet-directory? (type $Prim1)
               ,@(make-predicate-body '$LinkletDirectory))

         (func $hash->linklet-directory (type $Prim1)
               (param $content (ref eq))
               (result         (ref eq))

               (local $ht    (ref $HashEqMutable))
               (local $pairs (ref eq))
               (local $node  (ref eq))
               (local $pair  (ref $Pair))
               (local $entry (ref $Pair))
               (local $key   (ref eq))
               (local $val   (ref eq))

               (if (i32.eqz (ref.test (ref $HashEqMutable) (local.get $content)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:hash->linklet-directory)
                               (global.get $string:mutable-hasheq?)
                               (local.get $content))
                         (unreachable)))
               (local.set $ht (ref.cast (ref $HashEqMutable) (local.get $content)))

               (local.set $pairs (call $hash->list (local.get $content) (global.get $false)))
               (local.set $node (local.get $pairs))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $node) (global.get $null)))
                            (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                            (local.set $entry (ref.cast (ref $Pair)
                                                        (struct.get $Pair $a (local.get $pair))))
                            (local.set $key (struct.get $Pair $a (local.get $entry)))
                            (local.set $val (struct.get $Pair $d (local.get $entry)))
                            (if (i32.eqz
                                 (i32.or (ref.test (ref $Symbol) (local.get $key))
                                         (ref.eq (local.get $key) (global.get $false))))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:hash->linklet-directory)
                                            (global.get $string:linklet-directory-key?)
                                            (local.get $key))
                                      (unreachable)))
                            (if (ref.eq (local.get $key) (global.get $false))
                                (then
                                 (if (i32.eqz (ref.test (ref $LinkletBundle) (local.get $val)))
                                     (then (call $raise-argument-error1
                                                 (global.get $symbol:hash->linklet-directory)
                                                 (global.get $string:linklet-bundle?)
                                                 (local.get $val))
                                           (unreachable))))
                                (else
                                 (if (i32.eqz (ref.test (ref $LinkletDirectory) (local.get $val)))
                                     (then (call $raise-argument-error1
                                                 (global.get $symbol:hash->linklet-directory)
                                                 (global.get $string:linklet-directory?)
                                                 (local.get $val))
                                           (unreachable)))))
                            (local.set $node (struct.get $Pair $d (local.get $pair)))
                            (br $loop)))

               (ref.cast (ref eq)
                         (struct.new $LinkletDirectory
                                     (i32.const 0)
                                     (local.get $ht))))

         (func $linklet-directory->hash (type $Prim1)
               (param $directory (ref eq))
               (result           (ref eq))

               (if (i32.eqz (ref.test (ref $LinkletDirectory) (local.get $directory)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:linklet-directory->hash)
                               (global.get $string:linklet-directory?)
                               (local.get $directory))
                         (unreachable)))
               (ref.cast (ref eq)
                         (struct.get $LinkletDirectory $content
                                     (ref.cast (ref $LinkletDirectory) (local.get $directory)))))

         (func $make-compiled-linklet (type $Prim4)
               (param $name     (ref eq)) ;; #f or symbol
               (param $importss (ref eq)) ;; (listof (listof symbol?))
               (param $exports  (ref eq)) ;; (listof symbol?)
               (param $proc     (ref eq)) ;; procedure
               (result (ref eq))

               (local $imports-node       (ref eq))
               (local $imports-pair       (ref $Pair))
               (local $single-imports     (ref eq))
               (local $inner-node         (ref eq))
               (local $inner-pair         (ref $Pair))
               (local $sym                (ref eq))
               (local $exports-node       (ref eq))
               (local $exports-pair       (ref $Pair))
               (local $seen-exports       (ref $HashEqMutable))
               (local $seen?              (ref eq))
               (local $compiled-linklet   (ref $CompiledLinklet))

               ;; Validate name (allow #f for anonymous linklets).
               (if (i32.eqz (ref.eq (local.get $name) (global.get $false)))
                   (then
                    (if (i32.eqz (ref.test (ref $Symbol) (local.get $name)))
                        (then (call $raise-argument-error1
                                    (global.get $symbol:make-compiled-linklet)
                                    (global.get $string:symbol-or-false)
                                    (local.get $name))
                              (unreachable)))))

               ;; Validate imports: listof listof symbol?
               (local.set $imports-node (local.get $importss))
               (block $imports-done
                      (loop $imports-loop
                            (br_if $imports-done
                                   (ref.eq (local.get $imports-node)
                                           (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $imports-node)))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:make-compiled-linklet)
                                            (global.get $string:listof-listof-symbol?)
                                            (local.get $importss))
                                      (unreachable)))
                            (local.set $imports-pair
                                       (ref.cast (ref $Pair) (local.get $imports-node)))
                            (local.set $single-imports
                                       (struct.get $Pair $a (local.get $imports-pair)))
                            (local.set $inner-node (local.get $single-imports))
                            (block $inner-done
                                   (loop $inner-loop
                                         (br_if $inner-done
                                                (ref.eq (local.get $inner-node)
                                                        (global.get $null)))
                                         (if (i32.eqz (ref.test (ref $Pair) (local.get $inner-node)))
                                             (then (call $raise-argument-error1
                                                         (global.get $symbol:make-compiled-linklet)
                                                         (global.get $string:listof-symbol?)
                                                         (local.get $single-imports))
                                                   (unreachable)))
                                         (local.set $inner-pair
                                                    (ref.cast (ref $Pair) (local.get $inner-node)))
                                         (local.set $sym
                                                    (struct.get $Pair $a (local.get $inner-pair)))
                                         (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
                                             (then (call $raise-argument-error1
                                                         (global.get $symbol:make-compiled-linklet)
                                                         (global.get $string:symbol?)
                                                         (local.get $sym))
                                                   (unreachable)))
                                         (local.set $inner-node
                                                    (struct.get $Pair $d (local.get $inner-pair)))
                                         (br $inner-loop)))
                            (local.set $imports-node
                                       (struct.get $Pair $d (local.get $imports-pair)))
                            (br $imports-loop)))

               ;; Validate exports: listof symbol? with no duplicate names.
               (local.set $seen-exports (ref.cast (ref $HashEqMutable) (call $make-empty-hasheq)))
               (local.set $exports-node (local.get $exports))
               (block $exports-done
                      (loop $exports-loop
                            (br_if $exports-done
                                   (ref.eq (local.get $exports-node)
                                           (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $exports-node)))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:make-compiled-linklet)
                                            (global.get $string:listof-symbol?)
                                            (local.get $exports))
                                      (unreachable)))
                            (local.set $exports-pair
                                       (ref.cast (ref $Pair) (local.get $exports-node)))
                            (local.set $sym
                                       (struct.get $Pair $a (local.get $exports-pair)))
                            (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:make-compiled-linklet)
                                            (global.get $string:symbol?)
                                            (local.get $sym))
                                      (unreachable)))
                            (local.set $seen?
                                       (call $hasheq-ref
                                             (ref.cast (ref eq) (local.get $seen-exports))
                                             (local.get $sym)
                                             (global.get $false)))
                            (if (i32.eqz (ref.eq (local.get $seen?) (global.get $false)))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:make-compiled-linklet)
                                            (global.get $string:distinct-listof-symbol?)
                                            (local.get $exports))
                                      (unreachable)))
                            (call $hasheq-set!/mutable/checked
                                  (local.get $seen-exports)
                                  (local.get $sym)
                                  (global.get $true))
                            (local.set $exports-node
                                       (struct.get $Pair $d (local.get $exports-pair)))
                            (br $exports-loop)))

               ;; Validate procedure argument.
               (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                   (then (call $raise-argument-error:procedure-expected (local.get $proc))
                         (unreachable)))

               (local.set $compiled-linklet
                          (struct.new $CompiledLinklet
                                      (i32.const 0)
                                      (local.get $name)
                                      (local.get $importss)
                                      (local.get $exports)
                                      (local.get $proc)))
               (ref.cast (ref eq) (local.get $compiled-linklet)))

         (func $linklet-name (type $Prim1)
               (param $linklet (ref eq))
               (result         (ref eq))

               (local $plain     (ref $Linklet))

               (if (i32.eqz (ref.test (ref $Linklet) (local.get $linklet)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:linklet-name)
                               (global.get $string:linklet?)
                               (local.get $linklet))
                         (unreachable)))

               (local.set $plain (ref.cast (ref $Linklet) (local.get $linklet)))
               (struct.get $Linklet $name (local.get $plain)))


         (func $linklet-import-variables (type $Prim1)
               (param $linklet (ref eq))
               (result (ref eq))

               (local $plain    (ref $Linklet))
               (local $compiled (ref $CompiledLinklet))

               (if (i32.eqz (ref.test (ref $Linklet) (local.get $linklet)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:linklet-import-variables)
                               (global.get $string:linklet?)
                               (local.get $linklet))
                         (unreachable)))

               (local.set $plain (ref.cast (ref $Linklet) (local.get $linklet)))
               (struct.get $Linklet $importss (local.get $plain)))

         (func $linklet-export-variables (type $Prim1)
               (param $linklet (ref eq))
               (result (ref eq))

               (local $plain    (ref $Linklet))
               (local $compiled (ref $CompiledLinklet))

               (if (i32.eqz (ref.test (ref $Linklet) (local.get $linklet)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:linklet-export-variables)
                               (global.get $string:linklet?)
                               (local.get $linklet))
                         (unreachable)))

               (local.set $plain (ref.cast (ref $Linklet) (local.get $linklet)))
               (struct.get $Linklet $exports (local.get $plain)))

         ; version 1
         #;(func $instantiate-linklet (type $Prim24)
               ;; WebRacket currently ignores use-prompt?.
               (param $linklet          (ref eq)) ;; compiled linklet
               (param $import-instances (ref eq)) ;; (listof instance?)
               (param $target-instance  (ref eq)) ;; optional instance, defaults to #f
               (param $use-prompt?      (ref eq)) ;; optional any/c, defaults to #f (ignored)
               (result                  (ref eq))

               (local $compiled         (ref $CompiledLinklet))
               (local $imports-node     (ref eq))
               (local $imports-node2    (ref eq))
               (local $pair             (ref $Pair))
               (local $value            (ref eq))
               (local $imports-expected (ref eq))
               (local $target           (ref $Instance))
               (local $proc             (ref $Procedure))
               (local $invoke           (ref $ProcedureInvoker))
               (local $args             (ref $Args))
               (local $result           (ref eq))
               (local $name             (ref eq))
               (local $import-count     i32)
               (local $expected-count   i32)
               (local $i                i32)
               (local $new?             i32)

               ;; Optional parameters default to #f.
               (if (ref.eq (local.get $target-instance) (global.get $missing))
                   (then (local.set $target-instance (global.get $false))))
               (if (ref.eq (local.get $use-prompt?) (global.get $missing))
                   (then (local.set $use-prompt? (global.get $false))))

               ;; Validate linklet argument.
               (if (i32.eqz (ref.test (ref $Linklet) (local.get $linklet)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:instantiate-linklet)
                               (global.get $string:linklet?)
                               (local.get $linklet))
                         (unreachable)))

               (if (i32.eqz (ref.test (ref $CompiledLinklet) (local.get $linklet)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:instantiate-linklet)
                               (global.get $string:compiled-linklet?)
                               (local.get $linklet))
                         (unreachable)))

               (local.set $compiled (ref.cast (ref $CompiledLinklet) (local.get $linklet)))

               ;; Validate import-instances list and count elements.
               (local.set $import-count (i32.const 0))
               (local.set $imports-node (local.get $import-instances))
               (block $imports-done
                      (loop $imports-loop
                            (br_if $imports-done
                                   (ref.eq (local.get $imports-node) (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $imports-node)))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:instantiate-linklet)
                                            (global.get $string:listof-instance?)
                                            (local.get $import-instances))
                                      (unreachable)))
                            (local.set $pair
                                       (ref.cast (ref $Pair) (local.get $imports-node)))
                            (local.set $value (struct.get $Pair $a (local.get $pair)))
                            (if (i32.eqz (ref.test (ref $Instance) (local.get $value)))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:instantiate-linklet)
                                            (global.get $string:listof-instance?)
                                            (local.get $import-instances))
                                      (unreachable)))
                            (local.set $imports-node (struct.get $Pair $d (local.get $pair)))
                            (local.set $import-count
                                       (i32.add (local.get $import-count) (i32.const 1)))
                            (br $imports-loop)))

               ;; Determine expected number of import instances from the compiled linklet.
               (local.set $expected-count   (i32.const 0))
               (local.set $imports-expected (struct.get $CompiledLinklet $importss (local.get $compiled)))
               (local.set $imports-node2    (local.get $imports-expected))
               (block $expected-done
                      (loop $expected-loop
                            (br_if $expected-done
                                   (ref.eq (local.get $imports-node2) (global.get $null)))
                            (local.set $pair
                                       (ref.cast (ref $Pair) (local.get $imports-node2)))
                            (local.set $imports-node2 (struct.get $Pair $d (local.get $pair)))
                            (local.set $expected-count
                                       (i32.add (local.get $expected-count) (i32.const 1)))
                            (br $expected-loop)))

               (if (i32.ne (local.get $expected-count) (local.get $import-count))
                   (then (call $raise-argument-error1
                               (global.get $symbol:instantiate-linklet)
                               (global.get $string:instantiate-linklet:import-count)
                               (local.get $import-instances))
                         (unreachable)))

               ;; Determine or create the target instance.
               #;(local.set $target (ref.null $Instance))
               (local.set $new?   (i32.const 0))
               (if (i32.eqz (ref.eq (local.get $target-instance) (global.get $false)))
                   (then
                    (if (i32.eqz (ref.test (ref $Instance) (local.get $target-instance)))
                        (then (call $raise-argument-error1
                                    (global.get $symbol:instantiate-linklet)
                                    (global.get $string:instance-or-false)
                                    (local.get $target-instance))
                              (unreachable)))
                    (local.set $target
                               (ref.cast (ref $Instance) (local.get $target-instance))))
                   (else
                    (local.set $name   (struct.get $CompiledLinklet $name (local.get $compiled)))
                    (local.set $target (ref.cast (ref $Instance)
                                                 (call $make-instance (local.get $name) (global.get $null))))
                    (local.set $new? (i32.const 1))))

               ;; Prepare arguments for the compiled linklet procedure.
               (local.set $proc
                          (ref.cast (ref $Procedure)
                                    (struct.get $CompiledLinklet $proc (local.get $compiled))))
               (local.set $invoke (struct.get $Procedure $invoke (local.get $proc)))
               (local.set $args
                          (array.new $Args
                                     (global.get $null)
                                     (i32.add (local.get $import-count) (i32.const 1))))
               (array.set $Args
                          (local.get $args)
                          (i32.const 0)
                          (ref.cast (ref eq) (local.get $target)))

               (local.set $imports-node (local.get $import-instances))
               (local.set $i (i32.const 0))
               (block $fill-done
                      (loop $fill
                            (br_if $fill-done
                                   (ref.eq (local.get $imports-node) (global.get $null)))
                            (local.set $pair
                                       (ref.cast (ref $Pair) (local.get $imports-node)))
                            (local.set $value (struct.get $Pair $a (local.get $pair)))
                            (array.set $Args
                                       (local.get $args)
                                       (i32.add (local.get $i) (i32.const 1))
                                       (local.get $value))
                            (local.set $imports-node (struct.get $Pair $d (local.get $pair)))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $fill)))

               (local.set $result
                          (call_ref $ProcedureInvoker
                                    (local.get $proc)
                                    (local.get $args)
                                    (local.get $invoke)))

               (if (i32.eqz (local.get $new?))
                   (then (return (local.get $result)))
                   (else (drop (local.get $result))
                         (return (ref.cast (ref eq) (local.get $target))))))

         ; version 2
         (func $instantiate-linklet (type $Prim24)
               (param $linklet          (ref eq))  ;; linklet
               (param $import-instances (ref eq))  ;; (listof instance)
               (param $target           (ref eq))  ;; optional instance, defaults to #f
               (param $use-prompt       (ref eq))  ;; optional any/c, defaults to #f (ignored)
               (result                  (ref eq))

               (local $compiled          (ref $CompiledLinklet))
               (local $imports-node      (ref eq))
               (local $imports-pair      (ref $Pair))
               (local $import-value      (ref eq))
               (local $expected-node     (ref eq))
               (local $expected-pair     (ref $Pair))
               (local $expected-imports  (ref eq))
               (local $expected-import   (ref $Pair))
               (local $import-symbol     (ref eq))
               (local $exports-node      (ref eq))
               (local $exports-pair      (ref $Pair))
               (local $export-symbol     (ref eq))
               (local $export-box        (ref $Box))
               (local $export-val        (ref eq))
               (local $target-plain      (ref $Instance))
               (local $target-constants  (ref $HashEqMutable))
               (local $proc              (ref $Procedure))
               (local $inv               (ref $ProcedureInvoker))
               (local $args              (ref $Args))
               (local $result            (ref eq))
               (local $target-instance   (ref eq))
               (local $name              (ref eq))
               (local $actual-count      i32)
               (local $expected-count    i32)
               (local $index             i32)
               (local $return-instance   i32)

               (local.set $actual-count    (i32.const 0))
               (local.set $expected-count  (i32.const 0))
               (local.set $target-instance (global.get $false))
               (local.set $return-instance (i32.const 0))

               (if (i32.eqz (ref.test (ref $Linklet) (local.get $linklet)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:instantiate-linklet)
                               (global.get $string:linklet?)
                               (local.get $linklet))
                         (unreachable)))
               (if (i32.eqz (ref.test (ref $CompiledLinklet) (local.get $linklet)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:instantiate-linklet)
                               (global.get $string:compiled-linklet?)
                               (local.get $linklet))
                         (unreachable)))

               (local.set $compiled (ref.cast (ref $CompiledLinklet) (local.get $linklet)))

               (local.set $imports-node (local.get $import-instances))
               (block $imports-done
                      (loop $imports-loop
                            (br_if $imports-done
                                   (ref.eq (local.get $imports-node) (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $imports-node)))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:instantiate-linklet)
                                            (global.get $string:listof-instance?)
                                            (local.get $import-instances))
                                      (unreachable)))
                            (local.set $imports-pair
                                       (ref.cast (ref $Pair) (local.get $imports-node)))
                            (local.set $import-value
                                       (struct.get $Pair $a (local.get $imports-pair)))
                            (if (i32.eqz (ref.test (ref $Instance) (local.get $import-value)))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:instantiate-linklet)
                                            (global.get $string:listof-instance?)
                                            (local.get $import-instances))
                                      (unreachable)))
                            (local.set $actual-count
                                       (i32.add (local.get $actual-count) (i32.const 1)))
                            (local.set $imports-node
                                       (struct.get $Pair $d (local.get $imports-pair)))
                            (br $imports-loop)))

               (if (ref.eq (local.get $target) (global.get $missing))
                   (then (nop))
                   (else (local.set $target-instance (local.get $target))))

               (if (i32.eqz (ref.eq (local.get $target-instance) (global.get $false)))
                   (then (if (i32.eqz (ref.test (ref $Instance) (local.get $target-instance)))
                             (then (call $raise-argument-error1
                                         (global.get $symbol:instantiate-linklet)
                                         (global.get $string:instance-or-false)
                                         (local.get $target-instance))
                                   (unreachable))))
                   (else (local.set $return-instance (i32.const 1))))

               (local.set $expected-node
                          (struct.get $Linklet $importss (local.get $compiled)))
               (block $expected-done
                      (loop $expected-loop
                            (br_if $expected-done
                                   (ref.eq (local.get $expected-node) (global.get $null)))
                            (local.set $imports-pair
                                       (ref.cast (ref $Pair) (local.get $expected-node)))
                            (local.set $expected-count
                                       (i32.add (local.get $expected-count) (i32.const 1)))
                            (local.set $expected-node
                                       (struct.get $Pair $d (local.get $imports-pair)))
                            (br $expected-loop)))

               (if (i32.ne (local.get $expected-count) (local.get $actual-count))
                   (then (call $raise-argument-error1
                               (global.get $symbol:instantiate-linklet)
                               (global.get $string:instantiate-linklet:import-count)
                               (local.get $import-instances))
                         (unreachable)))

               ;; Validate declared imports before running the linklet body.
               (local.set $expected-node
                          (struct.get $Linklet $importss (local.get $compiled)))
               (local.set $imports-node (local.get $import-instances))
               (block $validate-done
                      (loop $validate-loop
                            (br_if $validate-done
                                   (ref.eq (local.get $expected-node) (global.get $null)))
                            (local.set $expected-pair
                                       (ref.cast (ref $Pair) (local.get $expected-node)))
                            (local.set $imports-pair
                                       (ref.cast (ref $Pair) (local.get $imports-node)))
                            (local.set $expected-imports
                                       (struct.get $Pair $a (local.get $expected-pair)))
                            (local.set $import-value
                                       (struct.get $Pair $a (local.get $imports-pair)))
                            (block $symbols-done
                                   (loop $symbols-loop
                                         (br_if $symbols-done
                                                (ref.eq (local.get $expected-imports)
                                                        (global.get $null)))
                                         (local.set $expected-import
                                                    (ref.cast (ref $Pair)
                                                              (local.get $expected-imports)))
                                         (local.set $import-symbol
                                                    (struct.get $Pair $a
                                                                (local.get $expected-import)))
                                         (drop (call $instance-variable-box
                                                     (local.get $import-value)
                                                     (local.get $import-symbol)
                                                     (global.get $false)))
                                         (local.set $expected-imports
                                                    (struct.get $Pair $d
                                                                (local.get $expected-import)))
                                         (br $symbols-loop)))
                            (local.set $expected-node
                                       (struct.get $Pair $d (local.get $expected-pair)))
                            (local.set $imports-node
                                       (struct.get $Pair $d (local.get $imports-pair)))
                            (br $validate-loop)))

               (if (i32.eq (local.get $return-instance) (i32.const 1))
                   (then
                    (local.set $name (struct.get $Linklet $name (local.get $compiled)))
                    (local.set $target-instance
                               (call $make-instance
                                     (local.get $name)
                                     (global.get $null)))))

               (local.set $proc
                          (ref.cast (ref $Procedure)
                                    (struct.get $CompiledLinklet $proc (local.get $compiled))))
               (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))

               (local.set $args
                          (array.new $Args
                                     (global.get $null)
                                     (i32.add (local.get $actual-count) (i32.const 1))))
               (array.set $Args (local.get $args) (i32.const 0) (local.get $target-instance))
               (local.set $index (i32.const 1))
               (local.set $imports-node (local.get $import-instances))
               (block $fill-done
                      (loop $fill-loop
                            (br_if $fill-done
                                   (ref.eq (local.get $imports-node) (global.get $null)))
                            (local.set $imports-pair
                                       (ref.cast (ref $Pair) (local.get $imports-node)))
                            (array.set $Args
                                       (local.get $args)
                                       (local.get $index)
                                       (struct.get $Pair $a (local.get $imports-pair)))
                            (local.set $index
                                       (i32.add (local.get $index) (i32.const 1)))
                            (local.set $imports-node
                                       (struct.get $Pair $d (local.get $imports-pair)))
                            (br $fill-loop)))

               (local.set $result
                          (call_ref $ProcedureInvoker
                                    (local.get $proc)
                                    (local.get $args)
                                    (local.get $inv)))

               ;; Exported bindings are constant from the instance API after
               ;; instantiation, even though the linklet body initializes them.
               (local.set $target-plain (ref.cast (ref $Instance) (local.get $target-instance)))
               (local.set $target-constants
                          (struct.get $Instance $constants (local.get $target-plain)))
               (local.set $exports-node
                          (struct.get $Linklet $exports (local.get $compiled)))
               (block $exports-done
                      (loop $exports-loop
                            (br_if $exports-done
                                   (ref.eq (local.get $exports-node) (global.get $null)))
                            (local.set $exports-pair
                                       (ref.cast (ref $Pair) (local.get $exports-node)))
                            (local.set $export-symbol
                                       (struct.get $Pair $a (local.get $exports-pair)))
                            (local.set $export-box
                                       (ref.cast (ref $Box)
                                                 (call $instance-variable-box
                                                       (local.get $target-instance)
                                                       (local.get $export-symbol)
                                                       (global.get $true))))
                            (local.set $export-val
                                       (struct.get $Box $v (local.get $export-box)))
                            (if (ref.eq (local.get $export-val) (global.get $undefined))
                                (then (drop (call $set-box!
                                                  (ref.cast (ref eq) (local.get $export-box))
                                                  (global.get $unsafe-undefined)))))
                            (call $hasheq-set!/mutable/checked
                                  (local.get $target-constants)
                                  (local.get $export-symbol)
                                  (global.get $true))
                            (local.set $exports-node
                                       (struct.get $Pair $d (local.get $exports-pair)))
                            (br $exports-loop)))

               (if (result (ref eq))
                   (i32.eq (local.get $return-instance) (i32.const 1))
                   (then (drop (local.get $result))
                         (local.get $target-instance))
                   (else (local.get $result))))

     ))
