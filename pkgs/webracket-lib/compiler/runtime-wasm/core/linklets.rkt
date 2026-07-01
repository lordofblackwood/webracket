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
    $linklet-export-variables))

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

     ))
