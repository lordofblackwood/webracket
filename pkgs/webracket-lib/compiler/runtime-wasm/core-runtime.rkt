#lang racket

(provide core-runtime-helpers
         core-runtime-helper-index
         core-runtime-callable-name-set
         core-runtime-global-names
         core-runtime-global-name-set
         core-runtime-import-function-names
         core-runtime-program-import-tag-names
         core-runtime-program-preinitialized-global-names
         core-runtime-program-import-constant-data-names
         core-runtime-program-import-constant-global-names
         core-runtime-program-import-global-names
         generate-core-runtime)

(require "core-helper.rkt"
         (only-in "constants.rkt"
                  make-runtime-constant-registry
                  runtime-constant-registry-declare-bytes
                  runtime-constant-registry-declare-strings
                  runtime-constant-registry-declare-symbols!
                  runtime-constant-registry-initialize-bytes
                  runtime-constant-registry-initialize-strings
                  runtime-constant-registry-initialize-symbols!
                  bytes-global-name
                  bytes-data-name
                  string-global-name
                  string-data-name
                  symbol-data-name
                  symbol-global-name)
         (only-in "js-imports.rkt"
                  js-host-import-forms
                  js-host-import-function-names)
         "core/arrays.rkt"
         "core/booleans.rkt"
         "core/bignums.rkt"
         "core/boxes.rkt"
         "core/bytes.rkt"
         "core/characters.rkt"
         "core/closures.rkt"
         "core/control-flow.rkt"
         "core/equality.rkt"
         "core/exceptions.rkt"
         "core/events.rkt"
         "core/fasl.rkt"
         "core/ffi.rkt"
         "core/filesystem.rkt"
         "core/fixnums.rkt"
         "core/flonums.rkt"
         "core/formatter-error-closure.rkt"
         "core/formatting.rkt"
         "core/growable-arrays.rkt"
         "core/growable-bytes.rkt"
         "core/growable-i32-arrays.rkt"
         "core/hashes.rkt"
         "core/i32-arrays.rkt"
         "core/i8-arrays.rkt"
         "core/io-handlers.rkt"
         "core/immediates.rkt"
         "core/immutable-hashes.rkt"
         "core/impersonators.rkt"
         "core/keywords.rkt"
         "core/lists.rkt"
         "core/linklet-instances.rkt"
         "core/linklets.rkt"
         "core/locations.rkt"
         "core/loggers.rkt"
         "core/memory-map.rkt"
         "core/mlists.rkt"
         "core/mutable-hashes.rkt"
         "core/namespaces.rkt"
         "core/numbers.rkt"
         "core/parameters.rkt"
         "core/paths.rkt"
         "core/ports.rkt"
         "core/procedures.rkt"
         "core/random.rkt"
         "core/rationals.rkt"
         "core/realms.rkt"
         "core/reflection.rkt"
         "core/regexps.rkt"
         "core/runtime-bytes-constants.rkt"
         "core/runtime-string-constants.rkt"
         "core/runtime-symbol-constants.rkt"
         "core/security.rkt"
         "core/semaphores.rkt"
         "core/stencil-vectors.rkt"
         "core/strings.rkt"
         "core/structs.rkt"
         "core/syntax.rkt"
         "core/symbols.rkt"
         "core/system.rkt"
         "core/threads.rkt"
         "core/time.rkt"
         "core/treelists.rkt"
         "core/unsafe.rkt"
         "core/vectors.rkt"
         "core/wills.rkt"
         "shared-types.rkt")

;; core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate the functions currently shared between monolithic and core runtime trees.
(define core-runtime-helpers
  (append
   array-core-runtime-helpers
   boolean-core-runtime-helpers
   bignum-core-runtime-helpers
   box-core-runtime-helpers
   bytes-core-runtime-helpers
   character-core-runtime-helpers
   control-flow-core-runtime-helpers
   equality-core-runtime-helpers
   exception-core-runtime-helpers
   event-core-runtime-helpers
   external-value-core-runtime-helpers
   fasl-core-runtime-helpers
   ffi-core-runtime-helpers
   filesystem-core-runtime-helpers
   fixnum-core-runtime-helpers
   flonum-core-runtime-helpers
   formatter-error-closure-core-runtime-helpers
   formatting-core-runtime-helpers
   growable-array-core-runtime-helpers
   growable-bytes-core-runtime-helpers
   hash-core-runtime-helpers
   i32-array-core-runtime-helpers
   growable-i32-array-core-runtime-helpers
   i8-array-core-runtime-helpers
   i8-array-byte-core-runtime-helpers
   immediate-core-runtime-helpers
   immutable-hash-core-runtime-helpers
   impersonator-core-runtime-helpers
   keyword-core-runtime-helpers
   list-core-runtime-helpers
   linklet-instance-core-runtime-helpers
   linklet-core-runtime-helpers
   source-location-core-runtime-helpers
   logger-core-runtime-helpers
   mlist-core-runtime-helpers
   mutable-hash-core-runtime-helpers
   namespace-core-runtime-helpers
   number-core-runtime-helpers
   parameter-core-runtime-helpers
   path-core-runtime-helpers
   port-core-runtime-helpers
   procedure-core-runtime-helpers
   random-core-runtime-helpers
   rational-core-runtime-helpers
   reflection-core-runtime-helpers
   regexp-core-runtime-helpers
   security-core-runtime-helpers
   semaphore-core-runtime-helpers
   stencil-vector-core-runtime-helpers
   string-core-runtime-helpers
   struct-core-runtime-helpers
   syntax-core-runtime-helpers
   symbol-core-runtime-helpers
   system-core-runtime-helpers
   thread-core-runtime-helpers
   time-core-runtime-helpers
   treelist-core-runtime-helpers
   unsafe-core-runtime-helpers
   vector-core-runtime-helpers
   will-core-runtime-helpers))

;; core-runtime-helper-index : hasheq?
;;   Index core runtime helpers by Wasm function name.
(define core-runtime-helper-index
  (make-core-runtime-helper-index core-runtime-helpers))

;; core-runtime-import-function-names : (listof symbol?)
;;   Name imported host functions that standalone core helpers may call.
(define core-runtime-import-function-names
  js-host-import-function-names)

;; core-runtime-internal-function-names : (listof symbol?)
;;   Name private core support functions emitted outside core-runtime-helpers.
(define core-runtime-internal-function-names
  (append symbol-table-runtime-only-helper-names
          symbol-table-initializer-runtime-only-helper-names
          keyword-table-initializer-runtime-only-helper-names))

;; core-runtime-callable-name-set : hasheq?
;;   Index functions callable by standalone core helpers.
(define core-runtime-callable-name-set
  (for/hasheq ([name (in-list (append (map core-runtime-helper-name
                                           core-runtime-helpers)
                                      core-runtime-internal-function-names
                                      core-runtime-import-function-names))])
    (values name #t)))

;; core-runtime-string-constant-registry : runtime-constant-registry?
;;   Register runtime string constants owned by the standalone core runtime.
(define core-runtime-string-constant-registry
  (make-runtime-constant-registry core-runtime-string-constants
                                  '()
                                  '()))

;; core-runtime-string-constant-global-names : (listof symbol?)
;;   Enumerate stable string globals declared by the standalone core runtime.
(define core-runtime-string-constant-global-names
  (for/list ([constant (in-list core-runtime-string-constants)])
    (string-global-name (first constant))))

;; core-runtime-string-constant-data-names : (listof symbol?)
;;   Enumerate stable string data segments declared by the standalone core runtime.
(define core-runtime-string-constant-data-names
  (for/list ([constant (in-list core-runtime-string-constants)])
    (string-data-name (first constant))))

;; core-runtime-string-constant-declaration-forms : (listof datum?)
;;   Declare data segments and globals for core-owned string constants.
(define core-runtime-string-constant-declaration-forms
  (runtime-constant-registry-declare-strings
   core-runtime-string-constant-registry))

;; core-runtime-string-constant-converter-name : symbol?
;;   Name the private core runtime helper used to decode compiler-authored UTF-8 constants.
(define core-runtime-string-constant-converter-name
  '$core-runtime-i8array->string)

;; core-runtime-string-constant-converter-form : datum?
;;   Decode valid UTF-8 data segments into immutable strings for core startup.
(define core-runtime-string-constant-converter-form
  `(func ,core-runtime-string-constant-converter-name
         (param $arr (ref $I8Array))
         (result (ref $String))
         (local $buf  (ref $I32GrowableArray))
         (local $end  i32)
         (local $i    i32)
         (local $byte i32)
         (local $need i32)
         (local $acc  i32)
         (local $b2   i32)
         (local $cp   i32)

         (local.set $end (array.len (local.get $arr)))
         (local.set $buf (call $make-i32growable-array (local.get $end)))
         (local.set $i (i32.const 0))
         (block $done
                (loop $loop
                      (br_if $done (i32.ge_u (local.get $i) (local.get $end)))
                      (local.set $byte (array.get_u $I8Array (local.get $arr) (local.get $i)))
                      (if (i32.lt_u (local.get $byte) (i32.const 128))
                          (then
                           (call $i32growable-array-add! (local.get $buf) (local.get $byte))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop)))
                      (call $bytes->string/utf-8:determine-utf-8-sequence (local.get $byte))
                      (local.set $acc)
                      (local.set $need)
                      (if (i32.lt_s (local.get $need) (i32.const 0))
                          (then (unreachable)))
                      (if (i32.ge_u (i32.add (local.get $i) (local.get $need))
                                     (local.get $end))
                          (then (unreachable)))
                      (local.set $cp (local.get $acc))
                      (local.set $i (i32.add (local.get $i) (i32.const 1)))
                      (block $cont-fail
                             (loop $cont-loop
                                   (br_if $cont-fail (i32.eqz (local.get $need)))
                                   (local.set $b2 (array.get_u $I8Array
                                                               (local.get $arr)
                                                               (local.get $i)))
                                   (if (i32.and (i32.ge_u (local.get $b2) (i32.const 128))
                                                (i32.lt_u (local.get $b2) (i32.const 192)))
                                       (then
                                        (local.set $cp
                                                   (i32.or
                                                    (i32.shl (local.get $cp) (i32.const 6))
                                                    (i32.and (local.get $b2) (i32.const #x3F))))
                                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                        (local.set $need (i32.sub (local.get $need) (i32.const 1)))
                                        (br $cont-loop)))))
                      (if (i32.ne (local.get $need) (i32.const 0))
                          (then (unreachable)))
                      (call $i32growable-array-add! (local.get $buf) (local.get $cp))
                      (br $loop)))
         (call $i32growable-array->immutable-string (local.get $buf))))

;; core-runtime-string-constant-initializer-forms : (listof datum?)
;;   Initialize core-owned string constants when the core runtime instantiates.
(define core-runtime-string-constant-initializer-forms
  (runtime-constant-registry-initialize-strings
   core-runtime-string-constant-registry
   #:converter core-runtime-string-constant-converter-name))

;; core-runtime-bytes-constant-registry : runtime-constant-registry?
;;   Register runtime byte-string constants owned by the standalone core runtime.
(define core-runtime-bytes-constant-registry
  (make-runtime-constant-registry '()
                                  core-runtime-bytes-constants
                                  '()))

;; core-runtime-bytes-constant-global-names : (listof symbol?)
;;   Enumerate stable byte-string globals declared by the standalone core runtime.
(define core-runtime-bytes-constant-global-names
  (for/list ([constant (in-list core-runtime-bytes-constants)])
    (bytes-global-name (first constant))))

;; core-runtime-bytes-constant-data-names : (listof symbol?)
;;   Enumerate stable byte-string data segments declared by the standalone core runtime.
(define core-runtime-bytes-constant-data-names
  (for/list ([constant (in-list core-runtime-bytes-constants)])
    (bytes-data-name (first constant))))

;; core-runtime-bytes-constant-declaration-forms : (listof datum?)
;;   Declare data segments and globals for core-owned byte-string constants.
(define core-runtime-bytes-constant-declaration-forms
  (runtime-constant-registry-declare-bytes
   core-runtime-bytes-constant-registry))

;; core-runtime-bytes-constant-initializer-forms : (listof datum?)
;;   Initialize core-owned byte-string constants when the core runtime instantiates.
(define core-runtime-bytes-constant-initializer-forms
  (runtime-constant-registry-initialize-bytes
   core-runtime-bytes-constant-registry))

;; core-runtime-symbol-constant-registry : runtime-constant-registry?
;;   Register runtime symbol constants owned by the standalone core runtime.
(define core-runtime-symbol-constant-registry
  (make-runtime-constant-registry
   '()
   '()
   (for/list ([symbol (in-list core-runtime-symbol-constants)])
     (list symbol symbol))))

;; core-runtime-symbol-constant-global-names : (listof symbol?)
;;   Enumerate stable symbol globals declared by the standalone core runtime.
(define core-runtime-symbol-constant-global-names
  (for/list ([symbol (in-list (sort (remove-duplicates core-runtime-symbol-constants eq?)
                                    symbol<?))])
    (symbol-global-name symbol)))

;; core-runtime-symbol-constant-data-names : (listof symbol?)
;;   Enumerate stable symbol data segments declared by the standalone core runtime.
(define core-runtime-symbol-constant-data-names
  (for/list ([symbol (in-list (sort (remove-duplicates core-runtime-symbol-constants eq?)
                                    symbol<?))])
    (symbol-data-name symbol)))

;; core-runtime-symbol-constant-declaration-forms : (listof datum?)
;;   Declare data segments and globals for core-owned symbol constants.
(define core-runtime-symbol-constant-declaration-forms
  (runtime-constant-registry-declare-symbols!
   core-runtime-symbol-constant-registry))

;; core-runtime-symbol-constant-initializer-forms : (listof datum?)
;;   Initialize core-owned symbol constants when the core runtime instantiates.
(define core-runtime-symbol-constant-initializer-forms
  (runtime-constant-registry-initialize-symbols!
   core-runtime-symbol-constant-registry
   #:string-converter core-runtime-string-constant-converter-name
   #:symbol-converter core-runtime-symbol-constant-converter-name))

;; core-runtime-program-import-global-names : (listof symbol?)
;;   Name mutable core globals that split-core program modules must share.
(define core-runtime-program-import-global-names
  (append
   '($the-symbol-table
     $the-keyword-table
     $prefab-struct-type-registry
     $the-racket-realm
     $the-racket/primitive-realm)
   ffi-result-global-names
   ffi-debug-global-names
   ffi-callback-global-names
   struct-property-identity-global-names
   struct-equal+hash-recur-global-names
   equality-primitive-global-names
   impersonator-primitive-global-names
   closure-core-global-names
   procedure-global-names
   list-higher-order-primitive-global-names
   syntax-global-names
   flonum-global-names
   port-current-global-names
   port-primitive-global-names
   path-current-global-names
   hash-seed-global-names
   character-general-category-global-names
   environment-parameter-global-names
   print-read-parameter-global-names
   io-handler-default-port-global-names
   namespace-current-global-names
   namespace-top-level-global-names
   logger-current-global-names
   security-current-global-names
   void-primitive-global-names
   reader-printer-policy-parameter-global-names
   reader-printer-policy-parameter-primitive-global-names
   compile-parameter-global-names
   promoted-parameter-primitive-global-names
   parameterization-global-names
   random-state-global-names
   random-current-global-names
   thread-group-current-global-names
   error-rendering-handler-global-names
   location-global-names
   exception-read-primitive-global-names
   exception-struct-type-cache-global-names
   filesystem-temporary-global-names
   symbol-gensym-global-names
   linklet-primitive-table-global-names))

;; core-runtime-program-import-tag-names : (listof symbol?)
;;   Name core tags that split-core program modules must share for catch/throw identity.
(define core-runtime-program-import-tag-names
  '($exn))

;; core-runtime-program-preinitialized-global-names : (listof symbol?)
;;   Name core-owned globals whose program-side initialization should be removed.
(define core-runtime-program-preinitialized-global-names
  (append
   '($the-racket-realm
     $the-racket/primitive-realm)
   flonum-global-names
   character-general-category-global-names
   struct-property-identity-global-names))

;; core-runtime-program-import-constant-global-names : (listof symbol?)
;;   Name immutable-by-convention core constants that split-core programs should import.
(define core-runtime-program-import-constant-global-names
  (append core-runtime-string-constant-global-names
          core-runtime-bytes-constant-global-names
          core-runtime-symbol-constant-global-names
          '($dummy-array
            $dummy-pair
            $dummy-vector
            $zero
            $one
            $two
            $three)
          memory-map-global-names
          fasl-tag-global-names
          '($treelist:BITS
            $treelist:MAX_WIDTH
            $treelist:MASK
            $dummy-treelist-node
            $empty-treelist)
          namespace-module-registry-global-names))

;; core-runtime-program-import-constant-data-names : (listof symbol?)
;;   Name core constant data segments that must stay on the runtime side.
(define core-runtime-program-import-constant-data-names
  (append core-runtime-string-constant-data-names
          core-runtime-bytes-constant-data-names
          core-runtime-symbol-constant-data-names))

;; core-runtime-global-names : (listof symbol?)
;;   Enumerate stable globals declared by the standalone core runtime.
(define core-runtime-global-names
  (append singleton-global-names
          core-runtime-program-import-constant-global-names
          core-runtime-program-import-global-names
          thread-current-core-global-names))

;; core-runtime-global-export-form : symbol? -> datum?
;;   Export a core global using the split-runtime global export namespace.
(define (core-runtime-global-export-form name)
  `(export ,(format "global:~a" (symbol->string name)) (global ,name)))

;; core-runtime-tag-export-form : symbol? -> datum?
;;   Export a core tag using the split-runtime tag export namespace.
(define (core-runtime-tag-export-form name)
  `(export ,(format "tag:~a" (symbol->string name)) (tag ,name)))

;; core-runtime-global-name-set : hasheq?
;;   Index stable core runtime globals by Wasm name.
(define core-runtime-global-name-set
  (for/hasheq ([name (in-list core-runtime-global-names)])
    (values name #t)))

;; generate-core-runtime : -> datum?
;;   Build the standalone core runtime module tree used by split-runtime experiments.
(define (generate-core-runtime)
  `(module
     ,@(generate-shared-types)
     ,@memory-import-forms
     ,@js-host-import-forms
     ,@exception-tag-forms
     ,@core-runtime-string-constant-declaration-forms
     ,@core-runtime-bytes-constant-declaration-forms
     ,@core-runtime-symbol-constant-declaration-forms
     ,@singleton-global-forms
     ,@ffi-result-global-forms
     ,@ffi-debug-global-forms
     ,@ffi-callback-global-forms
     ,@memory-map-global-forms
     ,@fixnum-global-forms
     ,@flonum-global-forms
     ,@fasl-tag-global-forms
     ,@treelist-constant-global-forms
     ,@vector-dummy-array-global-forms
     ,@pair-global-forms
     ,@vector-dummy-global-forms
     ,@treelist-empty-global-forms
     ,@realm-global-forms
     ,@struct-property-identity-global-forms
     ,@struct-equal+hash-recur-global-forms
     ,@equality-primitive-global-forms
     ,@impersonator-primitive-global-forms
     ,@closure-core-global-forms
     ,@procedure-global-forms
     ,@list-higher-order-primitive-global-forms
     ,@syntax-global-forms
     ,@port-current-global-forms
     ,@port-primitive-global-forms
     ,@path-current-global-forms
     ,@hash-seed-global-forms
     ,@character-general-category-global-forms
     ,@environment-parameter-global-forms
     ,@print-read-parameter-global-forms
     ,@io-handler-default-port-global-forms
     ,@namespace-current-global-forms
     ,@namespace-top-level-global-forms
     ,@namespace-module-registry-global-forms
     ,@logger-current-global-forms
     ,@security-current-global-forms
     ,@void-primitive-global-forms
     ,@reader-printer-policy-parameter-global-forms
     ,@reader-printer-policy-parameter-primitive-global-forms
     ,@compile-parameter-global-forms
     ,@promoted-parameter-primitive-global-forms
     ,@parameterization-global-forms
     ,@random-state-global-forms
     ,@random-current-global-forms
     ,@thread-group-current-global-forms
     ,@error-rendering-handler-global-forms
     ,@location-global-forms
     ,@exception-read-primitive-global-forms
     ,@exception-struct-type-cache-global-forms
     ,@filesystem-temporary-global-forms
     ,@symbol-gensym-global-forms
     ,@linklet-primitive-table-global-forms
     ,@symbol-table-global-forms
     ,@keyword-table-global-forms
     ,@struct-prefab-registry-global-forms
     ,@thread-current-core-global-forms
     ,core-runtime-string-constant-converter-form
     ,@(symbol-table-core-runtime-helper-forms)
     ,@(keyword-table-core-runtime-helper-forms)
     ,core-runtime-symbol-constant-converter-form
     (func $initialize-core-runtime!
           ,@core-runtime-string-constant-initializer-forms
           ,@core-runtime-bytes-constant-initializer-forms
           (call $initialize-the-symbol-table)
           (call $initialize-the-keyword-table)
           (call $initialize-prefab-struct-type-registry)
           ,@core-runtime-symbol-constant-initializer-forms
           ,@flonum-initializer-forms
           ,@character-general-category-initializer-forms
           ,@struct-property-identity-initializer-forms
           ,@random-current-initializer-forms
           ,@thread-group-current-initializer-forms
           ,@logger-current-initializer-forms
           ,@custodian-current-initializer-forms
           ,@realm-initializer-forms
           ,@namespace-initializer-forms)
     (start $initialize-core-runtime!)
     (export "global:$the-symbol-table" (global $the-symbol-table))
     (export "global:$the-keyword-table" (global $the-keyword-table))
     ,@(map core-runtime-global-export-form
            '($prefab-struct-type-registry))
     ,@(map core-runtime-global-export-form
            '($the-racket-realm
              $the-racket/primitive-realm))
     ,@(map core-runtime-global-export-form
            ffi-debug-global-names)
     ,@(map core-runtime-global-export-form
            ffi-result-global-names)
     ,@(map core-runtime-global-export-form
            ffi-callback-global-names)
     ,@(map core-runtime-global-export-form
            struct-property-identity-global-names)
     ,@(map core-runtime-global-export-form
            struct-equal+hash-recur-global-names)
     ,@(map core-runtime-global-export-form
            equality-primitive-global-names)
     ,@(map core-runtime-global-export-form
            impersonator-primitive-global-names)
     ,@(map core-runtime-global-export-form
            closure-core-global-names)
     ,@(map core-runtime-global-export-form
            procedure-global-names)
     ,@(map core-runtime-global-export-form
            list-higher-order-primitive-global-names)
     ,@(map core-runtime-global-export-form
            syntax-global-names)
     ,@(map core-runtime-global-export-form
            flonum-global-names)
     ,@(map core-runtime-global-export-form
            port-current-global-names)
     ,@(map core-runtime-global-export-form
            port-primitive-global-names)
     ,@(map core-runtime-global-export-form
            path-current-global-names)
     ,@(map core-runtime-global-export-form
            hash-seed-global-names)
     ,@(map core-runtime-global-export-form
            character-general-category-global-names)
     ,@(map core-runtime-global-export-form
            environment-parameter-global-names)
     ,@(map core-runtime-global-export-form
            print-read-parameter-global-names)
     ,@(map core-runtime-global-export-form
            io-handler-default-port-global-names)
     ,@(map core-runtime-global-export-form
            namespace-current-global-names)
     ,@(map core-runtime-global-export-form
            namespace-top-level-global-names)
     ,@(map core-runtime-global-export-form
            logger-current-global-names)
     ,@(map core-runtime-global-export-form
            security-current-global-names)
     ,@(map core-runtime-global-export-form
            void-primitive-global-names)
     ,@(map core-runtime-global-export-form
            reader-printer-policy-parameter-global-names)
     ,@(map core-runtime-global-export-form
            reader-printer-policy-parameter-primitive-global-names)
     ,@(map core-runtime-global-export-form
            compile-parameter-global-names)
     ,@(map core-runtime-global-export-form
            promoted-parameter-primitive-global-names)
     ,@(map core-runtime-global-export-form
            parameterization-global-names)
     ,@(map core-runtime-global-export-form
            random-state-global-names)
     ,@(map core-runtime-global-export-form
            random-current-global-names)
     ,@(map core-runtime-global-export-form
            thread-group-current-global-names)
     ,@(map core-runtime-global-export-form
            error-rendering-handler-global-names)
     ,@(map core-runtime-global-export-form
            location-global-names)
     ,@(map core-runtime-global-export-form
            exception-read-primitive-global-names)
     ,@(map core-runtime-global-export-form
            exception-struct-type-cache-global-names)
     ,@(map core-runtime-global-export-form
            filesystem-temporary-global-names)
     ,@(map core-runtime-global-export-form
            symbol-gensym-global-names)
     ,@(map core-runtime-global-export-form
            linklet-primitive-table-global-names)
     ,@(map core-runtime-tag-export-form
            core-runtime-program-import-tag-names)
     ,@(map core-runtime-global-export-form
            core-runtime-program-import-constant-global-names)
     ,@(core-runtime-helper-forms core-runtime-helpers #:export? #t)))

(module+ test
  (require rackunit
           racket/system
           "core-dependencies.rkt"
           (only-in "../assembler.rkt" wat->wasm))

  ;; module-body : datum? -> (or/c (listof datum?) #f)
  ;;   Return the body forms from a generated WAT module tree.
  (define (module-body module)
    (match module
      [`(module ,forms ...) forms]
      [_ #f]))

  ;; type-form-named? : symbol? datum? -> boolean?
  ;;   Check whether form is a type declaration with the given name.
  (define (type-form-named? name form)
    (match form
      [`(type ,type-name . ,_) (eq? type-name name)]
      [_ #f]))

  ;; function-form-named? : symbol? datum? -> boolean?
  ;;   Check whether form is a function declaration with the given name.
  (define (function-form-named? name form)
    (match form
      [`(func ,func-name . ,_) (eq? func-name name)]
      [_ #f]))

  ;; global-form-named? : symbol? datum? -> boolean?
  ;;   Check whether form is a global declaration with the given name.
  (define (global-form-named? name form)
    (match form
      [`(global ,global-name . ,_) (eq? global-name name)]
      [_ #f]))

  ;; tag-form-named? : symbol? datum? -> boolean?
  ;;   Check whether form is a tag declaration with the given name.
  (define (tag-form-named? name form)
    (match form
      [`(tag ,tag-name . ,_) (eq? tag-name name)]
      [_ #f]))

  ;; export-form-named? : string? symbol? datum? -> boolean?
  ;;   Check whether form exports the given global name.
  (define (global-export-form-named? export-name global-name form)
    (match form
      [`(export ,name (global ,target))
       (and (string=? name export-name)
            (eq? target global-name))]
      [_ #f]))

  ;; tag-export-form-named? : string? symbol? datum? -> boolean?
  ;;   Check whether form exports the given tag name.
  (define (tag-export-form-named? export-name tag-name form)
    (match form
      [`(export ,name (tag ,target))
       (and (string=? name export-name)
            (eq? target tag-name))]
      [_ #f]))

  ;; form-contains-global-set? : symbol? datum? -> boolean?
  ;;   Check whether a form writes to the given global.
  (define (form-contains-global-set? name form)
    (match form
      [`(global.set ,target . ,body)
       (or (eq? target name)
           (for/or ([part (in-list body)])
             (form-contains-global-set? name part)))]
      [(? list?)
       (for/or ([part (in-list form)])
         (form-contains-global-set? name part))]
      [_ #f]))

  ;; function-export-names : datum? -> (listof string?)
  ;;   Return all export names attached directly to a function form.
  (define (function-export-names form)
    (match form
      [`(func ,_ ,body ...)
       (for/list ([part (in-list body)]
                  #:when (match part
                           [`(export ,(? string?)) #t]
                           [_ #f]))
         (second part))]
      [_ '()]))

  ;; core-helper-import : symbol? symbol? -> datum?
  ;;   Build an imported core helper declaration with a shared function type.
  (define (core-helper-import name type-name)
    `(func ,name
           (import "core" ,(symbol->string name))
           (type ,type-name)))

  ;; core-raw-i32-unary-import : symbol? -> datum?
  ;;   Build an imported core helper declaration for raw unary predicates.
  (define (core-raw-i32-unary-import name)
    `(func ,name
           (import "core" ,(symbol->string name))
           (param (ref eq))
           (result i32)))

  ;; core-array-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for generic arrays.
  (define (core-array-imports)
    `((func $make-array
            (import "core" "$make-array")
            (param i32)
            (param (ref eq))
            (result (ref $Array)))
      (func $array-length
            (import "core" "$array-length")
            (param (ref $Array))
            (result i32))
      (func $array-ref
            (import "core" "$array-ref")
            (param (ref $Array))
            (param i32)
            (result (ref eq)))
      (func $array-set!
            (import "core" "$array-set!")
            (param (ref $Array))
            (param i32)
            (param (ref eq)))
      (func $array-fill!
            (import "core" "$array-fill!")
            (param (ref $Array))
            (param (ref eq)))
      (func $array-copy!
            (import "core" "$array-copy!")
            (param (ref $Array))
            (param i32)
            (param (ref $Array))
            (param i32)
            (param i32))
      (func $array-copy!/error
            (import "core" "$array-copy!/error")
            (param (ref $Array))
            (param i32)
            (param (ref $Array))
            (param i32)
            (param i32)
            (result i32))
      (func $array-append
            (import "core" "$array-append")
            (param (ref $Array))
            (param (ref $Array))
            (result (ref $Array)))
      (func $array-append-all
            (import "core" "$array-append-all")
            (param (ref $Array))
            (result (ref $Array)))
      (func $array-take
            (import "core" "$array-take")
            (param (ref $Array))
            (param i32)
            (result (ref $Array)))
      (func $array-take-right
            (import "core" "$array-take-right")
            (param (ref $Array))
            (param i32)
            (result (ref $Array)))
      (func $array-drop
            (import "core" "$array-drop")
            (param (ref $Array))
            (param i32)
            (result (ref $Array)))
      (func $array-drop-right
            (import "core" "$array-drop-right")
            (param (ref $Array))
            (param i32)
            (result (ref $Array)))
      (func $array-split-at
            (import "core" "$array-split-at")
            (param (ref $Array))
            (param i32)
            (result (ref $Array)))
      (func $array-copy
            (import "core" "$array-copy")
            (param (ref $Array))
            (param i32)
            (param i32)
            (result (ref $Array)))
      (func $array-set/copy
            (import "core" "$array-set/copy")
            (param (ref $Array))
            (param i32)
            (param (ref eq))
            (result (ref $Array)))
      (func $array-extend
            (import "core" "$array-extend")
            (param (ref $Array))
            (param i32)
            (param (ref eq))
            (result (ref $Array)))))

  ;; core-growable-array-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for generic growable arrays.
  (define (core-growable-array-imports)
    `((func $make-growable-array
            (import "core" "$make-growable-array")
            (param i32)
            (result (ref $GrowableArray)))
      (func $growable-array??
            (import "core" "$growable-array??")
            (param (ref eq))
            (result i32))
      (func $growable-array?
            (import "core" "$growable-array?")
            (param (ref eq))
            (result (ref eq)))
      (func $growable-array-ref
            (import "core" "$growable-array-ref")
            (param (ref $GrowableArray))
            (param i32)
            (result (ref eq)))
      (func $growable-array-ref/default
            (import "core" "$growable-array-ref/default")
            (param (ref $GrowableArray))
            (param i32)
            (param (ref eq))
            (result (ref eq)))
      (func $growable-array-add!
            (import "core" "$growable-array-add!")
            (param (ref $GrowableArray))
            (param (ref eq)))
      (func $growable-array-insert!
            (import "core" "$growable-array-insert!")
            (param (ref $GrowableArray))
            (param i32)
            (param (ref eq)))
      (func $growable-array-set!
            (import "core" "$growable-array-set!")
            (param (ref $GrowableArray))
            (param i32)
            (param (ref eq)))
      (func $growable-array-remove!
            (import "core" "$growable-array-remove!")
            (param (ref $GrowableArray))
            (param i32))
      (func $growable-array-remove-last!
            (import "core" "$growable-array-remove-last!")
            (param (ref $GrowableArray))
            (result (ref eq)))
      (func $growable-array-count
            (import "core" "$growable-array-count")
            (param (ref $GrowableArray))
            (result i32))
      (func $growable-array->array
            (import "core" "$growable-array->array")
            (param (ref $GrowableArray))
            (result (ref $Array)))
      (func $array->growable-array
            (import "core" "$array->growable-array")
            (param (ref $Array))
            (result (ref $GrowableArray)))))

  ;; core-i32-array-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for I32 arrays.
  (define (core-i32-array-imports)
    `((func $i32array-make
            (import "core" "$i32array-make")
            (param i32)
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-length
            (import "core" "$i32array-length")
            (param (ref $I32Array))
            (result i32))
      (func $i32array-ref
            (import "core" "$i32array-ref")
            (param (ref $I32Array))
            (param i32)
            (result i32))
      (func $i32array-set!
            (import "core" "$i32array-set!")
            (param (ref $I32Array))
            (param i32)
            (param i32))
      (func $i32array-equal?
            (import "core" "$i32array-equal?")
            (param (ref $I32Array))
            (param (ref $I32Array))
            (result i32))
      (func $i32array-fill!
            (import "core" "$i32array-fill!")
            (param (ref $I32Array))
            (param i32))
      (func $i32array-copy!
            (import "core" "$i32array-copy!")
            (param (ref $I32Array))
            (param i32)
            (param (ref $I32Array))
            (param i32)
            (param i32))
      (func $i32array-copy!/error
            (import "core" "$i32array-copy!/error")
            (param (ref $I32Array))
            (param i32)
            (param (ref $I32Array))
            (param i32)
            (param i32)
            (result i32))
      (func $i32array-copy
            (import "core" "$i32array-copy")
            (param (ref $I32Array))
            (param i32)
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-append
            (import "core" "$i32array-append")
            (param (ref $I32Array))
            (param (ref $I32Array))
            (result (ref $I32Array)))
      (func $i32array-take
            (import "core" "$i32array-take")
            (param (ref $I32Array))
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-take-right
            (import "core" "$i32array-take-right")
            (param (ref $I32Array))
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-drop
            (import "core" "$i32array-drop")
            (param (ref $I32Array))
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-drop-right
            (import "core" "$i32array-drop-right")
            (param (ref $I32Array))
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-set/copy
            (import "core" "$i32array-set/copy")
            (param (ref $I32Array))
            (param i32)
            (param i32)
            (result (ref $I32Array)))
      (func $i32array-extend
            (import "core" "$i32array-extend")
            (param (ref $I32Array))
            (param i32)
            (param i32)
            (result (ref $I32Array)))))

  ;; core-i8-array-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for I8 arrays.
  (define (core-i8-array-imports)
    `((func $i8make-array
            (import "core" "$i8make-array")
            (param i32)
            (param i32)
            (result (ref $I8Array)))
      (func $i8array-length
            (import "core" "$i8array-length")
            (param (ref $I8Array))
            (result i32))
      (func $i8array-ref
            (import "core" "$i8array-ref")
            (param (ref $I8Array))
            (param i32)
            (result i32))
      (func $i8array-set!
            (import "core" "$i8array-set!")
            (param (ref $I8Array))
            (param i32)
            (param i32))
      (func $i8array-fill!
            (import "core" "$i8array-fill!")
            (param (ref $I8Array))
            (param i32))
      (func $i8array-copy!
            (import "core" "$i8array-copy!")
            (param (ref $I8Array))
            (param i32)
            (param (ref $I8Array))
            (param i32)
            (param i32))
      (func $i8array-copy!/error
            (import "core" "$i8array-copy!/error")
            (param (ref $I8Array))
            (param i32)
            (param (ref $I8Array))
            (param i32)
            (param i32)
            (result i32))
      (func $i8array-copy
            (import "core" "$i8array-copy")
            (param (ref $I8Array))
            (param i32)
            (param i32)
            (result (ref $I8Array)))
      (func $i8array-set/copy
            (import "core" "$i8array-set/copy")
            (param (ref $I8Array))
            (param i32)
            (param i32)
            (result (ref $I8Array)))
      (func $i8array-extend
            (import "core" "$i8array-extend")
            (param (ref $I8Array))
            (param i32)
            (param i32)
            (result (ref $I8Array)))
      (func $i8array-append
            (import "core" "$i8array-append")
            (param (ref $I8Array))
            (param (ref $I8Array))
            (result (ref $I8Array)))))

  ;; core-growable-i32-array-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for I32 growable arrays.
  (define (core-growable-i32-array-imports)
    `((func $make-i32growable-array
            (import "core" "$make-i32growable-array")
            (param i32)
            (result (ref $I32GrowableArray)))
      (func $i32growable-array-add!
            (import "core" "$i32growable-array-add!")
            (param (ref $I32GrowableArray))
            (param i32))
      (func $i32growable-array-add-string!
            (import "core" "$i32growable-array-add-string!")
            (param (ref $I32GrowableArray))
            (param (ref $String)))
      (func $i32growable-array-ref
            (import "core" "$i32growable-array-ref")
            (param (ref $I32GrowableArray))
            (param i32)
            (result i32))
      (func $i32growable-array-count
            (import "core" "$i32growable-array-count")
            (param (ref $I32GrowableArray))
            (result i32))
      (func $i32growable-array->array
            (import "core" "$i32growable-array->array")
            (param (ref $I32GrowableArray))
            (result (ref $I32Array)))
      (func $i32array->growable-array
            (import "core" "$i32array->growable-array")
            (param (ref $I32Array))
            (result (ref $I32GrowableArray)))))

  ;; core-growable-bytes-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for growable bytes.
  (define (core-growable-bytes-imports)
    `((func $make-growable-bytes
            (import "core" "$make-growable-bytes")
            (param i32)
            (result (ref $GrowableBytes)))
      (func $growable-bytes-add!
            (import "core" "$growable-bytes-add!")
            (param (ref $GrowableBytes))
            (param i32))
      (func $growable-bytes->bytes
            (import "core" "$growable-bytes->bytes")
            (param (ref $GrowableBytes))
            (result (ref $Bytes)))))

  ;; core-i8-array-byte-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for I8Array-to-bytes wrappers.
  (define (core-i8-array-byte-imports)
    `((func $i8array->bytes
            (import "core" "$i8array->bytes")
            (param (ref $I8Array))
            (result (ref $Bytes)))
      (func $i8array->immutable-bytes
            (import "core" "$i8array->immutable-bytes")
            (param (ref $I8Array))
            (result (ref $Bytes)))))

  ;; core-string-imports : -> (listof datum?)
  ;;   Build imported core helper declarations for string constructors.
  (define (core-string-imports)
    `((func $i32array->string
            (import "core" "$i32array->string")
            (param (ref $I32Array))
            (result (ref $String)))
      (func $i32array->immutable-string
            (import "core" "$i32array->immutable-string")
            (param (ref $I32Array))
            (result (ref $String)))
      (func $i32growable-array->string
            (import "core" "$i32growable-array->string")
            (param (ref $I32GrowableArray))
            (result (ref $String)))
      (func $i32growable-array->immutable-string
            (import "core" "$i32growable-array->immutable-string")
            (param (ref $I32GrowableArray))
            (result (ref $String)))))

  ;; tagged-call1-export : string? symbol? integer? -> datum?
  ;;   Build an exported test function that returns a raw tagged unary result.
  (define (tagged-call1-export export-name helper-name arg)
    `(func (export ,export-name) (result i32)
           (i31.get_s
            (ref.cast (ref i31)
                      (call ,helper-name
                            (ref.i31 (i32.const ,arg)))))))

  ;; tagged-call2-export : string? symbol? integer? integer? -> datum?
  ;;   Build an exported test function that returns a raw tagged binary result.
  (define (tagged-call2-export export-name helper-name arg1 arg2)
    `(func (export ,export-name) (result i32)
           (i31.get_s
            (ref.cast (ref i31)
                      (call ,helper-name
                            (ref.i31 (i32.const ,arg1))
                            (ref.i31 (i32.const ,arg2)))))))

  (define core-prim1-test-imports
    '($fxnot
      $fxpopcount
      $fxpopcount32
      $fxpopcount16
      $unsafe-fxnot
      $unsafe-fxpopcount
      $unsafe-fxpopcount32
      $unsafe-fxpopcount16))

  (define core-prim2-test-imports
    '($fxand/2
      $fxior/2
      $fxxor/2
      $fxlshift
      $fxrshift
      $fx+/wraparound
      $fx*/wraparound
      $fxlshift/wraparound
      $fxrshift/logical
      $unsafe-fxlshift
      $unsafe-fx+/wraparound
      $unsafe-fx*/wraparound
      $unsafe-fxlshift/wraparound
      $unsafe-fxrshift
      $unsafe-fxrshift/logical))

  (define core-raw-i32-unary-test-imports
    '($fl?/i32
      $keyword?/i32
      $vector?/i32
      $struct?/i32
      $struct-type?/i32))

  (define shared-types (generate-shared-types))
  (define shared-type-names (shared-type-name-set shared-types))
  (define core-helper-names core-runtime-helper-index)
  (check-pred list? shared-types)
  (check-true (hash-has-key? shared-type-names '$Array))
  (check-true (hash-has-key? shared-type-names '$Pair))
  (check-true (hash-has-key? shared-type-names '$SymbolTable))
  (check-true (hash-has-key? core-runtime-global-name-set '$string:empty))
  (check-true (hash-has-key? core-runtime-global-name-set '$bytes:empty))
  (check-true (hash-has-key? core-runtime-global-name-set '$symbol:racket))
  (check-true (hash-has-key? core-runtime-global-name-set '$the-symbol-table))
  (check-true (hash-has-key? core-runtime-global-name-set '$the-keyword-table))
  (check-true (hash-has-key? core-runtime-global-name-set '$the-racket-realm))
  (check-true (hash-has-key? core-runtime-global-name-set '$the-racket/primitive-realm))
  (check-true (hash-has-key? core-runtime-global-name-set '$prefab-struct-type-registry))
  (check-true (hash-has-key? core-runtime-global-name-set '$debug-allocation-budget))
  (check-true (hash-has-key? core-runtime-global-name-set '$debug-invoke-budget))
  (check-true (hash-has-key? core-runtime-global-name-set '$result-bytes))
  (check-true (hash-has-key? core-runtime-global-name-set '$callback-registry))
  (check-true (hash-has-key? core-runtime-global-name-set '$exn-type))
  (check-true (hash-has-key? core-runtime-global-name-set '$dummy-array))
  (check-true (hash-has-key? core-runtime-global-name-set '$dummy-pair))
  (check-true (hash-has-key? core-runtime-global-name-set '$dummy-vector))
  (check-true (hash-has-key? core-runtime-global-name-set '$flzero))
  (check-true (hash-has-key? core-runtime-global-name-set '$flone))
  (check-true (hash-has-key? core-runtime-global-name-set '$fltwo))
  (check-true (hash-has-key? core-runtime-global-name-set '$flthree))
  (check-true (hash-has-key? core-runtime-global-name-set '$zero))
  (check-true (hash-has-key? core-runtime-global-name-set '$one))
  (check-true (hash-has-key? core-runtime-global-name-set '$two))
  (check-true (hash-has-key? core-runtime-global-name-set '$three))
  (check-true (hash-has-key? core-runtime-global-name-set '$fasl-fixnum))
  (check-true (hash-has-key? core-runtime-global-name-set '$fasl-keyword))
  (check-true (hash-has-key? core-runtime-global-name-set '$memory-map:callback-buffer-base))
  (check-true (hash-has-key? core-runtime-global-name-set '$memory-map:callback-buffer-length))
  (check-true (hash-has-key? core-runtime-global-name-set '$prop:procedure))
  (check-true (hash-has-key? core-runtime-global-name-set '$prop:checked-procedure))
  (check-true (hash-has-key? core-runtime-global-name-set '$equal+hash-recur/equal))
  (check-true (hash-has-key? core-runtime-global-name-set '$equal+hash-recur/hash-always))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:eq?))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:eqv?))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:equal?))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:equal-always?))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:webracket-impersonator-property-predicate))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:webracket-impersonator-property-accessor))
  (check-true (hash-has-key? core-runtime-global-name-set '$dummy-closure))
  (check-true (hash-has-key? core-runtime-global-name-set '$placeholder-linklet-closure))
  (check-true (hash-has-key? core-runtime-global-name-set '$escape-continuation-closure))
  (check-true (hash-has-key? core-runtime-global-name-set '$closedapp-clos))
  (check-true (hash-has-key? core-runtime-global-name-set '$arity-at-least-type))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:map))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:andmap))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:ormap))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:for-each))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:append-map))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:count))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:foldl))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:foldr))
  (check-true (hash-has-key? core-runtime-global-name-set '$syntax-type))
  (check-true (hash-has-key? core-runtime-global-name-set '$current-output-port-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$current-input-port-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$current-error-port-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:current-input-port))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:current-output-port))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:current-error-port))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:js-log))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:current-print))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:current-read-interaction))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:error-value->string-handler))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:error-syntax->string-handler))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:error-module-path->string-handler))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:make-input-port))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:make-output-port))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:peek-bytes-avail!))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:peek-bytes-avail!*))
  (check-true (hash-has-key? core-runtime-global-name-set '$system-path-convention))
  (check-true (hash-has-key? core-runtime-global-name-set '$next-hash-state))
  (check-true (hash-has-key? core-runtime-global-name-set '$char-general-category-symbols))
  (check-true (hash-has-key? core-runtime-global-name-set '$current-environment-variables-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$current-print-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$current-logger-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$top-level-namespace))
  (check-true (hash-has-key? core-runtime-global-name-set '$empty-module-registry))
  (check-true (hash-has-key? core-runtime-global-name-set '$current-security-guard-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$current-custodian-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:void))
  (check-true (hash-has-key? core-runtime-global-name-set '$print-as-expression-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$print-mpair-curly-braces-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$default-port-read-handler-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$default-port-write-handler-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$default-port-display-handler-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$default-port-print-handler-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:print-as-expression))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:print-mpair-curly-braces))
  (check-true (hash-has-key? core-runtime-global-name-set '$current-compile-realm-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:current-logger))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:current-thread-group))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:current-security-guard))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:current-custodian))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:current-compile-realm))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:current-readtable))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:print-syntax-width))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:error-print-width))
  (check-true (hash-has-key? core-runtime-global-name-set '$current-parameterization-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$random-state))
  (check-true (hash-has-key? core-runtime-global-name-set '$current-pseudo-random-generator-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$current-thread-group-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$cache-configuration-values))
  (check-true (hash-has-key? core-runtime-global-name-set '$error-value->string-handler-value))
  (check-true (hash-has-key? core-runtime-global-name-set '$srcloc-type))
  (check-true (hash-has-key? core-runtime-global-name-set '$prim:exn:fail:read-srclocs))
  (check-true (hash-has-key? core-runtime-global-name-set '$temporary-file-counter))
  (check-true (hash-has-key? core-runtime-global-name-set '$gensym-counter))
  (check-true (hash-has-key? core-runtime-global-name-set '$primitive-table-user-installed))
  (check-true (hash-has-key? core-runtime-global-name-set '$dummy-treelist-node))
  (check-true (hash-has-key? core-runtime-global-name-set '$empty-treelist))
  (check-true (hash-has-key? core-runtime-global-name-set '$treelist:BITS))
  (check-true (hash-has-key? core-runtime-global-name-set '$treelist:MAX_WIDTH))
  (check-equal? core-runtime-program-import-tag-names '($exn))
  (check-true (for/or ([form (in-list shared-types)])
                (type-form-named? '$Array form)))
  (check-true (for/or ([form (in-list shared-types)])
                (match form
                  [`(rec . ,_) #t]
                  [_ #f])))

  (for ([helper (in-list core-runtime-helpers)])
    (define name (core-runtime-helper-name helper))
    (define export-name (core-runtime-helper-export-name helper))
    (define raw-export-names
      (function-export-names
       (core-runtime-helper-form core-runtime-helper-index name)))
    (check-equal? (core-runtime-helper-ref core-runtime-helper-index name)
                  helper)
    (check-equal? (remove export-name raw-export-names string=?)
                  raw-export-names)
    (check-equal? (remove export-name
                          (function-export-names
                           (core-runtime-helper-form core-runtime-helper-index
                                                     name
                                                     #:export? #t))
                          string=?)
                  raw-export-names))
  (check-exn exn:fail?
             (lambda ()
               (core-runtime-helper-ref core-runtime-helper-index '$not-a-helper)))
  (check-exn exn:fail?
             (lambda ()
               (make-core-runtime-helper-index
                (list (first core-runtime-helpers)
                      (first core-runtime-helpers)))))

  (for ([helper (in-list core-runtime-helpers)])
    (define name (core-runtime-helper-name helper))
    (check-equal? (core-runtime-helper-dependency-problems
                   (core-runtime-helper-form core-runtime-helper-index name)
                   core-runtime-callable-name-set
                   shared-type-names
                   core-runtime-global-name-set)
                  '()))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (param (ref eq)) (result i32)
                        (call $fx?/i32 (local.get $v)))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result i32)
                        (call $js-flonum->string (f64.const 0.0)))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (result i32)
                        (global.get $false))
                 core-runtime-callable-name-set
                 shared-type-names)
                (list (helper-dependency-problem
                       'runtime-global
                       '$false)))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result (ref eq))
                        (global.get $false))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result (ref eq))
                        (global.get $string:empty))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result (ref eq))
                        (global.get $bytes:empty))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result (ref eq))
                        (global.get $symbol:racket))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result i32)
                        (global.get $memory-map:callback-buffer-base))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result (ref eq))
                        (global.get $prop:procedure))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result (ref null $StructType))
                        (global.get $arity-at-least-type))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (param $v (ref $StructType))
                        (global.set $syntax-type (local.get $v)))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result (ref eq))
                        (global.get $current-output-port-value))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result i32)
                        (global.get $next-hash-state))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result (ref eq))
                        (global.get $current-parameterization-value))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result (ref eq))
                        (global.get $print-as-expression-value))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (result (ref eq))
                        (global.get $prim:print-as-expression))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (param (ref eq)) (result i32)
                        (call $other (local.get $v)))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                (list (helper-dependency-problem
                       'runtime-call
                       '$other)))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (param (ref eq)) (result i32)
                        (return_call $other (local.get $v)))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                (list (helper-dependency-problem
                       'runtime-call
                       '$other)))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (param (ref $NotShared)) (result i32)
                        (i32.const 0))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                (list (helper-dependency-problem
                       'unshared-type
                       '$NotShared)))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (type $NotShared)
                        (i32.const 0))
                 core-runtime-callable-name-set
                 shared-type-names
                 core-runtime-global-name-set)
                (list (helper-dependency-problem
                       'unshared-type
                       '$NotShared)))

  (define core-module (generate-core-runtime))
  (define core-forms (module-body core-module))
  (check-pred list? core-forms)
  (check-true (for/or ([form (in-list core-forms)])
                (type-form-named? '$Array form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$string:empty form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$bytes:empty form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$symbol:racket form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$flzero form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$symbol:append form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$the-racket-realm form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$the-racket/primitive-realm form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$exn-type form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$memory-map:callback-buffer-base form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$memory-map:callback-buffer-length form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$result-bytes form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$callback-registry form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prop:procedure form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prop:checked-procedure form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$equal+hash-recur/equal form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$equal+hash-recur/hash-always form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:eq? form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:eqv? form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:equal? form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:equal-always? form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$arity-at-least-type form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$syntax-type form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$current-output-port-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:js-log form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$system-path-convention form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$next-hash-state form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$char-general-category-symbols form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$current-environment-variables-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$current-print-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$current-namespace-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$top-level-namespace form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$empty-module-registry form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$current-logger-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$current-security-guard-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$current-custodian-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:void form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$print-as-expression-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:print-as-expression form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:print-mpair-curly-braces form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$current-compile-realm-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:current-logger form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:current-thread-group form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:current-security-guard form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:current-custodian form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:current-compile-realm form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:current-readtable form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:current-namespace form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:print-syntax-width form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:error-print-width form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$current-parameterization-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$random-state form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$current-pseudo-random-generator-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$current-thread-group-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$cache-configuration-values form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$error-value->string-handler-value form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$srcloc-type form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$prim:exn:fail:read-srclocs form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$temporary-file-counter form)))
  (check-true (for/or ([form (in-list core-forms)])
                (tag-form-named? '$exn form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$the-symbol-table form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-form-named? '$the-keyword-table form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$the-symbol-table"
                                           '$the-symbol-table
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$the-keyword-table"
                                           '$the-keyword-table
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$string:empty"
                                           '$string:empty
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$bytes:empty"
                                           '$bytes:empty
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$symbol:racket"
                                           '$symbol:racket
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$symbol:append"
                                           '$symbol:append
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$the-racket-realm"
                                           '$the-racket-realm
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$the-racket/primitive-realm"
                                           '$the-racket/primitive-realm
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$exn-type"
                                           '$exn-type
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$memory-map:callback-buffer-base"
                                           '$memory-map:callback-buffer-base
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$memory-map:callback-buffer-length"
                                           '$memory-map:callback-buffer-length
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$result-bytes"
                                           '$result-bytes
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$callback-registry"
                                           '$callback-registry
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prop:procedure"
                                           '$prop:procedure
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prop:checked-procedure"
                                           '$prop:checked-procedure
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$equal+hash-recur/equal"
                                           '$equal+hash-recur/equal
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$equal+hash-recur/hash-always"
                                           '$equal+hash-recur/hash-always
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:eq?"
                                           '$prim:eq?
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:eqv?"
                                           '$prim:eqv?
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:equal?"
                                           '$prim:equal?
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:equal-always?"
                                           '$prim:equal-always?
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:webracket-impersonator-property-predicate"
                                           '$prim:webracket-impersonator-property-predicate
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:webracket-impersonator-property-accessor"
                                           '$prim:webracket-impersonator-property-accessor
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$arity-at-least-type"
                                           '$arity-at-least-type
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$syntax-type"
                                           '$syntax-type
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$current-output-port-value"
                                           '$current-output-port-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$system-path-convention"
                                           '$system-path-convention
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$next-hash-state"
                                           '$next-hash-state
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$char-general-category-symbols"
                                           '$char-general-category-symbols
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$current-environment-variables-value"
                                           '$current-environment-variables-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$current-print-value"
                                           '$current-print-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:js-log"
                                           '$prim:js-log
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$current-namespace-value"
                                           '$current-namespace-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$top-level-namespace"
                                           '$top-level-namespace
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$current-logger-value"
                                           '$current-logger-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$current-security-guard-value"
                                           '$current-security-guard-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$current-custodian-value"
                                           '$current-custodian-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:void"
                                           '$prim:void
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$print-as-expression-value"
                                           '$print-as-expression-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:print-as-expression"
                                           '$prim:print-as-expression
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:print-mpair-curly-braces"
                                           '$prim:print-mpair-curly-braces
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$current-compile-realm-value"
                                           '$current-compile-realm-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:current-logger"
                                           '$prim:current-logger
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:current-thread-group"
                                           '$prim:current-thread-group
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:current-security-guard"
                                           '$prim:current-security-guard
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:current-custodian"
                                           '$prim:current-custodian
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:current-compile-realm"
                                           '$prim:current-compile-realm
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:current-readtable"
                                           '$prim:current-readtable
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:current-namespace"
                                           '$prim:current-namespace
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:print-syntax-width"
                                           '$prim:print-syntax-width
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:error-print-width"
                                           '$prim:error-print-width
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$current-parameterization-value"
                                           '$current-parameterization-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$random-state"
                                           '$random-state
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$current-pseudo-random-generator-value"
                                           '$current-pseudo-random-generator-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$current-thread-group-value"
                                           '$current-thread-group-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$cache-configuration-values"
                                           '$cache-configuration-values
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$srcloc-type"
                                           '$srcloc-type
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$prim:exn:fail:read-srclocs"
                                           '$prim:exn:fail:read-srclocs
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$error-value->string-handler-value"
                                           '$error-value->string-handler-value
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$gensym-counter"
                                           '$gensym-counter
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$primitive-table-user-installed"
                                           '$primitive-table-user-installed
                                           form)))
  (check-true (for/or ([form (in-list core-forms)])
                (global-export-form-named? "global:$empty-module-registry"
                                           '$empty-module-registry
                                           form)))
  (for ([name (in-list closure-core-global-names)])
    (check-true (for/or ([form (in-list core-forms)])
                  (global-export-form-named?
                   (format "global:~a" name)
                   name
                   form))))
  (for ([name (in-list list-higher-order-primitive-global-names)])
    (check-true (for/or ([form (in-list core-forms)])
                  (global-export-form-named?
                   (format "global:~a" name)
                   name
                   form))))
  (for ([name (in-list port-primitive-global-names)])
    (check-true (for/or ([form (in-list core-forms)])
                  (global-export-form-named?
                   (format "global:~a" name)
                   name
                   form))))
  (for ([name (in-list io-handler-default-port-global-names)])
    (check-true (for/or ([form (in-list core-forms)])
                  (global-export-form-named?
                   (format "global:~a" name)
                   name
                   form))))
  (check-true (for/or ([form (in-list core-forms)])
                (tag-export-form-named? "tag:$exn" '$exn form)))
  (check-not-false
   (for/or ([form (in-list core-forms)])
     (match form
       [`(func $initialize-core-runtime! ,body ...)
        (for/or ([part (in-list body)])
          (form-contains-global-set? '$prop:procedure part))]
       [_ #f])))
  (check-not-false
   (for/or ([form (in-list core-forms)])
     (match form
       [`(func $initialize-core-runtime! ,body ...)
        (for/or ([part (in-list body)])
          (form-contains-global-set? '$char-general-category-symbols part))]
       [_ #f])))
  (check-not-false
   (for/or ([form (in-list core-forms)])
     (match form
       [`(func $initialize-core-runtime! ,body ...)
        (for/or ([part (in-list body)])
          (form-contains-global-set? '$top-level-namespace part))]
       [_ #f])))
  (check-not-false
   (for/or ([form (in-list core-forms)])
     (match form
       [`(func $initialize-core-runtime! ,body ...)
        (for/or ([part (in-list body)])
          (form-contains-global-set? '$current-namespace-value part))]
       [_ #f])))
  (check-not-false (member '(start $initialize-core-runtime!) core-forms))
  (define string-converter-functions
    (for/list ([form (in-list core-forms)]
               #:when (function-form-named? core-runtime-string-constant-converter-name form))
      form))
  (check-equal? (length string-converter-functions) 1)
  (check-equal? (function-export-names (first string-converter-functions))
                '())
  (check-true
   (for/or ([form (in-list core-runtime-string-constant-initializer-forms)])
     (match form
       [`(global.set ,_ (call ,name . ,_))
        (eq? name core-runtime-string-constant-converter-name)]
       [_ #f])))
  (for ([helper (in-list core-runtime-helpers)])
    (define name (core-runtime-helper-name helper))
    (define export-name (core-runtime-helper-export-name helper))
    (define matching-functions
      (for/list ([form (in-list core-forms)]
                 #:when (function-form-named? name form))
        form))
    (check-equal? (length matching-functions) 1)
    (check-not-false
     (member export-name (function-export-names (first matching-functions)))))

  (when (find-executable-path "wasm-tools")
    (define core-wat-path
      (make-temporary-file "webracket-core-runtime-test-~a.wat"))
    (define core-wasm-path
      (path-replace-extension core-wat-path ".wasm"))
    (check-true (wat->wasm core-module
                           #:wat core-wat-path
                           #:wasm core-wasm-path))
    (check-true (file-exists? core-wasm-path))

    (define split-consumer-module
      `(module
         ,@(generate-shared-types)

         (func $fx?/i32
               (import "core" "$fx?/i32")
               (param (ref eq))
               (result i32))
         (func $fixnum?/i32
               (import "core" "$fixnum?/i32")
         (param (ref eq))
         (result i32))
         ,@(for/list ([name (in-list core-raw-i32-unary-test-imports)])
             (core-raw-i32-unary-import name))
         ,@(core-array-imports)
         ,@(core-growable-array-imports)
         ,@(core-i32-array-imports)
         ,@(core-i8-array-imports)
         ,@(core-i8-array-byte-imports)
         ,@(core-growable-i32-array-imports)
         ,@(core-growable-bytes-imports)
         ,@(core-string-imports)
         ,@(for/list ([name (in-list core-prim1-test-imports)])
             (core-helper-import name '$Prim1))
         ,@(for/list ([name (in-list core-prim2-test-imports)])
             (core-helper-import name '$Prim2))

         (func (export "fx_fixnum_true") (result i32)
               (call $fx?/i32 (ref.i31 (i32.const 84))))
         (func (export "fx_immediate_false") (result i32)
               (call $fx?/i32 (ref.i31 (i32.const 85))))
         (func (export "fx_heap_false") (result i32)
               (call $fx?/i32
                     (struct.new $Pair
                                 (i32.const 0)
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0)))))
         (func (export "fixnum_fixnum_true") (result i32)
               (call $fixnum?/i32 (ref.i31 (i32.const 84))))
         (func (export "fixnum_immediate_false") (result i32)
               (call $fixnum?/i32 (ref.i31 (i32.const 85))))
         (func (export "fl_flonum_true") (result i32)
               (call $fl?/i32
                     (struct.new $Flonum
                                 (i32.const 0)
                                 (f64.const 1.5))))
         (func (export "fl_fixnum_false") (result i32)
               (call $fl?/i32 (ref.i31 (i32.const 84))))
         (func (export "keyword_keyword_true") (result i32)
               (call $keyword?/i32
                     (struct.new $Keyword
                                 (i32.const 0)
                                 (struct.new $String
                                             (i32.const 0)
                                             (i32.const 1)
                                             (array.new $I32Array
                                                        (i32.const 107)
                                                        (i32.const 1))))))
         (func (export "keyword_fixnum_false") (result i32)
               (call $keyword?/i32 (ref.i31 (i32.const 84))))
         (func (export "vector_vector_true") (result i32)
               (call $vector?/i32
                     (struct.new $Vector
                                 (i32.const 0)
                                 (i32.const 0)
                                 (array.new $Array
                                            (ref.i31 (i32.const 0))
                                            (i32.const 3)))))
         (func (export "vector_fixnum_false") (result i32)
               (call $vector?/i32 (ref.i31 (i32.const 84))))
         (func (export "struct_type_true") (result i32)
               (call $struct-type?/i32
                     (struct.new $StructType
                                 (i32.const 0)
                                 (struct.new $Symbol
                                             (i32.const 0)
                                             (struct.new $String
                                                         (i32.const 0)
                                                         (i32.const 1)
                                                         (array.new $I32Array
                                                                    (i32.const 115)
                                                                    (i32.const 1)))
                                             (i32.const 0)
                                             (ref.i31 (i32.const 0)))
                                 (ref.i31 (i32.const 0))
                                 (i32.const 0)
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0)))))
         (func (export "struct_type_fixnum_false") (result i32)
               (call $struct-type?/i32 (ref.i31 (i32.const 84))))
         (func (export "struct_struct_type_false") (result i32)
               (call $struct?/i32
                     (struct.new $StructType
                                 (i32.const 0)
                                 (struct.new $Symbol
                                             (i32.const 0)
                                             (struct.new $String
                                                         (i32.const 0)
                                                         (i32.const 1)
                                                         (array.new $I32Array
                                                                    (i32.const 115)
                                                                    (i32.const 1)))
                                             (i32.const 0)
                                             (ref.i31 (i32.const 0)))
                                 (ref.i31 (i32.const 0))
                                 (i32.const 0)
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0))
                                 (ref.i31 (i32.const 0)))))
         (func (export "struct_fixnum_false") (result i32)
               (call $struct?/i32 (ref.i31 (i32.const 84))))
         (func (export "array_length") (result i32)
               (call $array-length
                     (call $make-array (i32.const 3) (ref.i31 (i32.const 20)))))
         (func (export "array_ref_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref
                                (array.new_fixed $Array 2
                                                 (ref.i31 (i32.const 20))
                                                 (ref.i31 (i32.const 40)))
                                (i32.const 1)))))
         (func (export "array_set_ref_tagged") (result i32)
               (local $arr (ref $Array))
               (local.set $arr (call $make-array (i32.const 2) (ref.i31 (i32.const 20))))
               (call $array-set! (local.get $arr) (i32.const 1) (ref.i31 (i32.const 60)))
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref (local.get $arr) (i32.const 1)))))
         (func (export "array_fill_ref_tagged") (result i32)
               (local $arr (ref $Array))
               (local.set $arr (call $make-array (i32.const 3) (ref.i31 (i32.const 20))))
               (call $array-fill! (local.get $arr) (ref.i31 (i32.const 80)))
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref (local.get $arr) (i32.const 2)))))
         (func (export "array_copy_bang_tagged") (result i32)
               (local $dest (ref $Array))
               (local $src (ref $Array))
               (local.set $dest (call $make-array (i32.const 3) (ref.i31 (i32.const 0))))
               (local.set $src (array.new_fixed $Array 2
                                                 (ref.i31 (i32.const 20))
                                                 (ref.i31 (i32.const 40))))
               (call $array-copy! (local.get $dest) (i32.const 1) (local.get $src) (i32.const 0) (i32.const 2))
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref (local.get $dest) (i32.const 2)))))
         (func (export "array_copy_error_success") (result i32)
               (call $array-copy!/error
                     (call $make-array (i32.const 2) (ref.i31 (i32.const 0)))
                     (i32.const 0)
                     (array.new_fixed $Array 2
                                      (ref.i31 (i32.const 20))
                                      (ref.i31 (i32.const 40)))
                     (i32.const 0)
                     (i32.const 2)))
         (func (export "array_copy_error_failure") (result i32)
               (call $array-copy!/error
                     (call $make-array (i32.const 1) (ref.i31 (i32.const 0)))
                     (i32.const 1)
                     (array.new_fixed $Array 2
                                      (ref.i31 (i32.const 20))
                                      (ref.i31 (i32.const 40)))
                     (i32.const 0)
                     (i32.const 2)))
         (func (export "array_append_ref_tagged") (result i32)
               (local $arr (ref $Array))
               (local.set $arr
                          (call $array-append
                                (array.new_fixed $Array 1
                                                 (ref.i31 (i32.const 20)))
                                (array.new_fixed $Array 2
                                                 (ref.i31 (i32.const 40))
                                                 (ref.i31 (i32.const 60)))))
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref (local.get $arr) (i32.const 2)))))
         (func (export "array_append_all_ref_tagged") (result i32)
               (local $arr (ref $Array))
               (local.set $arr
                          (call $array-append-all
                                (array.new_fixed $Array 2
                                                 (array.new_fixed $Array 1
                                                                  (ref.i31 (i32.const 20)))
                                                 (array.new_fixed $Array 2
                                                                  (ref.i31 (i32.const 40))
                                                                  (ref.i31 (i32.const 60))))))
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref (local.get $arr) (i32.const 2)))))
         (func (export "array_take_length") (result i32)
               (call $array-length
                     (call $array-take
                           (array.new_fixed $Array 3
                                            (ref.i31 (i32.const 20))
                                            (ref.i31 (i32.const 40))
                                            (ref.i31 (i32.const 60)))
                           (i32.const 2))))
         (func (export "array_take_right_ref_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref
                                (call $array-take-right
                                      (array.new_fixed $Array 3
                                                       (ref.i31 (i32.const 20))
                                                       (ref.i31 (i32.const 40))
                                                       (ref.i31 (i32.const 60)))
                                      (i32.const 2))
                                (i32.const 0)))))
         (func (export "array_drop_ref_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref
                                (call $array-drop
                                      (array.new_fixed $Array 3
                                                       (ref.i31 (i32.const 20))
                                                       (ref.i31 (i32.const 40))
                                                       (ref.i31 (i32.const 60)))
                                      (i32.const 1))
                                (i32.const 0)))))
         (func (export "array_drop_right_length") (result i32)
               (call $array-length
                     (call $array-drop-right
                           (array.new_fixed $Array 3
                                            (ref.i31 (i32.const 20))
                                            (ref.i31 (i32.const 40))
                                            (ref.i31 (i32.const 60)))
                           (i32.const 1))))
         (func (export "array_split_at_second_length") (result i32)
               (local $split (ref $Array))
               (local.set $split
                          (call $array-split-at
                                (array.new_fixed $Array 3
                                                 (ref.i31 (i32.const 20))
                                                 (ref.i31 (i32.const 40))
                                                 (ref.i31 (i32.const 60)))
                                (i32.const 1)))
               (call $array-length
                     (ref.cast (ref $Array)
                               (call $array-ref (local.get $split) (i32.const 1)))))
         (func (export "array_copy_ref_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref
                                (call $array-copy
                                      (array.new_fixed $Array 3
                                                       (ref.i31 (i32.const 20))
                                                       (ref.i31 (i32.const 40))
                                                       (ref.i31 (i32.const 60)))
                                      (i32.const 1)
                                      (i32.const 3))
                                (i32.const 0)))))
         (func (export "array_set_copy_ref_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $array-ref
                                (call $array-set/copy
                                      (array.new_fixed $Array 2
                                                       (ref.i31 (i32.const 20))
                                                       (ref.i31 (i32.const 40)))
                                      (i32.const 1)
                                      (ref.i31 (i32.const 80)))
                                (i32.const 1)))))
         (func (export "array_extend_length") (result i32)
               (call $array-length
                     (call $array-extend
                           (array.new_fixed $Array 2
                                            (ref.i31 (i32.const 20))
                                            (ref.i31 (i32.const 40)))
                           (i32.const 5)
                           (ref.i31 (i32.const 0)))))
         (func (export "growable_array_predicate_true") (result i32)
               (call $growable-array??
                     (call $make-growable-array (i32.const 1))))
         (func (export "growable_array_predicate_false") (result i32)
               (call $growable-array?? (ref.i31 (i32.const 84))))
         (func (export "growable_array_boolean_true_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $growable-array?
                                (call $make-growable-array (i32.const 1))))))
         (func (export "growable_array_ref_default_tagged") (result i32)
               (i31.get_s
                (ref.cast (ref i31)
                          (call $growable-array-ref/default
                                (call $make-growable-array (i32.const 1))
                                (i32.const 4)
                                (ref.i31 (i32.const 222))))))
         (func (export "growable_array_count_after_ops") (result i32)
               (local $g (ref $GrowableArray))
               (local.set $g (call $make-growable-array (i32.const 1)))
               (call $growable-array-add! (local.get $g) (ref.i31 (i32.const 20)))
               (call $growable-array-add! (local.get $g) (ref.i31 (i32.const 40)))
               (call $growable-array-insert! (local.get $g) (i32.const 1) (ref.i31 (i32.const 30)))
               (call $growable-array-set! (local.get $g) (i32.const 3) (ref.i31 (i32.const 50)))
               (call $growable-array-remove! (local.get $g) (i32.const 2))
               (drop (call $growable-array-remove-last! (local.get $g)))
               (call $growable-array-count (local.get $g)))
         (func (export "growable_array_ref_after_ops_tagged") (result i32)
               (local $g (ref $GrowableArray))
               (local.set $g (call $make-growable-array (i32.const 1)))
               (call $growable-array-add! (local.get $g) (ref.i31 (i32.const 20)))
               (call $growable-array-add! (local.get $g) (ref.i31 (i32.const 40)))
               (call $growable-array-insert! (local.get $g) (i32.const 1) (ref.i31 (i32.const 30)))
               (i31.get_s
                (ref.cast (ref i31)
                          (call $growable-array-ref (local.get $g) (i32.const 1)))))
         (func (export "growable_array_copy_tagged") (result i32)
               (local $g (ref $GrowableArray))
               (local $arr (ref $Array))
               (local.set $g (call $make-growable-array (i32.const 1)))
               (call $growable-array-add! (local.get $g) (ref.i31 (i32.const 20)))
               (call $growable-array-add! (local.get $g) (ref.i31 (i32.const 40)))
               (local.set $arr (call $growable-array->array (local.get $g)))
               (i31.get_s
                (ref.cast (ref i31)
                          (array.get $Array (local.get $arr) (i32.const 1)))))
         (func (export "array_to_growable_count") (result i32)
               (call $growable-array-count
                     (call $array->growable-array
                           (array.new_fixed $Array 2
                                            (ref.i31 (i32.const 20))
                                            (ref.i31 (i32.const 40))))))
         (func (export "i32array_length") (result i32)
               (call $i32array-length
                     (call $i32array-make (i32.const 3) (i32.const 7))))
         (func (export "i32array_ref") (result i32)
               (call $i32array-ref
                     (array.new_fixed $I32Array 2
                                      (i32.const 11)
                                      (i32.const 22))
                     (i32.const 1)))
         (func (export "i32array_set") (result i32)
               (local $arr (ref $I32Array))
               (local.set $arr (call $i32array-make (i32.const 2) (i32.const 0)))
               (call $i32array-set! (local.get $arr) (i32.const 1) (i32.const 33))
               (call $i32array-ref (local.get $arr) (i32.const 1)))
         (func (export "i32array_equal_true") (result i32)
               (call $i32array-equal?
                     (array.new_fixed $I32Array 2
                                      (i32.const 1)
                                      (i32.const 2))
                     (array.new_fixed $I32Array 2
                                      (i32.const 1)
                                      (i32.const 2))))
         (func (export "i32array_equal_false") (result i32)
               (call $i32array-equal?
                     (array.new_fixed $I32Array 2
                                      (i32.const 1)
                                      (i32.const 2))
                     (array.new_fixed $I32Array 2
                                      (i32.const 1)
                                      (i32.const 3))))
         (func (export "i32array_fill") (result i32)
               (local $arr (ref $I32Array))
               (local.set $arr (call $i32array-make (i32.const 3) (i32.const 0)))
               (call $i32array-fill! (local.get $arr) (i32.const 44))
               (call $i32array-ref (local.get $arr) (i32.const 2)))
         (func (export "i32array_copy_bang") (result i32)
               (local $dest (ref $I32Array))
               (local.set $dest (call $i32array-make (i32.const 3) (i32.const 0)))
               (call $i32array-copy!
                     (local.get $dest)
                     (i32.const 1)
                     (array.new_fixed $I32Array 2
                                      (i32.const 55)
                                      (i32.const 66))
                     (i32.const 0)
                     (i32.const 2))
               (call $i32array-ref (local.get $dest) (i32.const 2)))
         (func (export "i32array_copy_error_success") (result i32)
               (call $i32array-copy!/error
                     (call $i32array-make (i32.const 2) (i32.const 0))
                     (i32.const 0)
                     (array.new_fixed $I32Array 2
                                      (i32.const 55)
                                      (i32.const 66))
                     (i32.const 0)
                     (i32.const 2)))
         (func (export "i32array_copy_error_failure") (result i32)
               (call $i32array-copy!/error
                     (call $i32array-make (i32.const 1) (i32.const 0))
                     (i32.const 1)
                     (array.new_fixed $I32Array 2
                                      (i32.const 55)
                                      (i32.const 66))
                     (i32.const 0)
                     (i32.const 2)))
         (func (export "i32array_append_ref") (result i32)
               (call $i32array-ref
                     (call $i32array-append
                           (array.new_fixed $I32Array 1
                                            (i32.const 11))
                           (array.new_fixed $I32Array 2
                                            (i32.const 22)
                                            (i32.const 33)))
                     (i32.const 2)))
         (func (export "i32array_take_length") (result i32)
               (call $i32array-length
                     (call $i32array-take
                           (array.new_fixed $I32Array 3
                                            (i32.const 11)
                                            (i32.const 22)
                                            (i32.const 33))
                           (i32.const 2))))
         (func (export "i32array_take_right_ref") (result i32)
               (call $i32array-ref
                     (call $i32array-take-right
                           (array.new_fixed $I32Array 3
                                            (i32.const 11)
                                            (i32.const 22)
                                            (i32.const 33))
                           (i32.const 2))
                     (i32.const 0)))
         (func (export "i32array_drop_ref") (result i32)
               (call $i32array-ref
                     (call $i32array-drop
                           (array.new_fixed $I32Array 3
                                            (i32.const 11)
                                            (i32.const 22)
                                            (i32.const 33))
                           (i32.const 1))
                     (i32.const 0)))
         (func (export "i32array_drop_right_length") (result i32)
               (call $i32array-length
                     (call $i32array-drop-right
                           (array.new_fixed $I32Array 3
                                            (i32.const 11)
                                            (i32.const 22)
                                            (i32.const 33))
                           (i32.const 1))))
         (func (export "i32array_set_copy_ref") (result i32)
               (call $i32array-ref
                     (call $i32array-set/copy
                           (array.new_fixed $I32Array 2
                                            (i32.const 11)
                                            (i32.const 22))
                           (i32.const 1)
                           (i32.const 99))
                     (i32.const 1)))
         (func (export "i32array_extend_length") (result i32)
               (call $i32array-length
                     (call $i32array-extend
                           (array.new_fixed $I32Array 2
                                            (i32.const 11)
                                            (i32.const 22))
                           (i32.const 5)
                           (i32.const 0))))
         (func (export "i8array_length") (result i32)
               (call $i8array-length
                     (call $i8make-array (i32.const 3) (i32.const 7))))
         (func (export "i8array_ref_unsigned") (result i32)
               (call $i8array-ref
                     (array.new_fixed $I8Array 2
                                      (i32.const 11)
                                      (i32.const 255))
                     (i32.const 1)))
         (func (export "i8array_set") (result i32)
               (local $arr (ref $I8Array))
               (local.set $arr (call $i8make-array (i32.const 2) (i32.const 0)))
               (call $i8array-set! (local.get $arr) (i32.const 1) (i32.const 33))
               (call $i8array-ref (local.get $arr) (i32.const 1)))
         (func (export "i8array_fill") (result i32)
               (local $arr (ref $I8Array))
               (local.set $arr (call $i8make-array (i32.const 3) (i32.const 0)))
               (call $i8array-fill! (local.get $arr) (i32.const 44))
               (call $i8array-ref (local.get $arr) (i32.const 2)))
         (func (export "i8array_copy_bang") (result i32)
               (local $dest (ref $I8Array))
               (local.set $dest (call $i8make-array (i32.const 3) (i32.const 0)))
               (call $i8array-copy!
                     (local.get $dest)
                     (i32.const 1)
                     (array.new_fixed $I8Array 2
                                      (i32.const 55)
                                      (i32.const 66))
                     (i32.const 0)
                     (i32.const 2))
               (call $i8array-ref (local.get $dest) (i32.const 2)))
         (func (export "i8array_copy_error_success") (result i32)
               (call $i8array-copy!/error
                     (call $i8make-array (i32.const 2) (i32.const 0))
                     (i32.const 0)
                     (array.new_fixed $I8Array 2
                                      (i32.const 55)
                                      (i32.const 66))
                     (i32.const 0)
                     (i32.const 2)))
         (func (export "i8array_copy_error_failure") (result i32)
               (call $i8array-copy!/error
                     (call $i8make-array (i32.const 1) (i32.const 0))
                     (i32.const 1)
                     (array.new_fixed $I8Array 2
                                      (i32.const 55)
                                      (i32.const 66))
                     (i32.const 0)
                     (i32.const 2)))
         (func (export "i8array_copy_ref") (result i32)
               (call $i8array-ref
                     (call $i8array-copy
                           (array.new_fixed $I8Array 3
                                            (i32.const 11)
                                            (i32.const 22)
                                            (i32.const 33))
                           (i32.const 1)
                           (i32.const 3))
                     (i32.const 0)))
         (func (export "i8array_set_copy_ref") (result i32)
               (call $i8array-ref
                     (call $i8array-set/copy
                           (array.new_fixed $I8Array 2
                                            (i32.const 11)
                                            (i32.const 22))
                           (i32.const 1)
                           (i32.const 99))
                     (i32.const 1)))
         (func (export "i8array_extend_length") (result i32)
               (call $i8array-length
                     (call $i8array-extend
                           (array.new_fixed $I8Array 2
                                            (i32.const 11)
                                            (i32.const 22))
                           (i32.const 5)
                           (i32.const 0))))
         (func (export "i8array_append_ref") (result i32)
               (call $i8array-ref
                     (call $i8array-append
                           (array.new_fixed $I8Array 1
                                            (i32.const 11))
                           (array.new_fixed $I8Array 2
                                            (i32.const 22)
                                            (i32.const 33)))
                     (i32.const 2)))
         (func (export "i8array_to_bytes_immutable_field") (result i32)
               (struct.get $Bytes $immutable
                           (call $i8array->bytes
                                 (array.new_fixed $I8Array 2
                                                  (i32.const 11)
                                                  (i32.const 22)))))
         (func (export "i8array_to_immutable_bytes_field") (result i32)
               (struct.get $Bytes $immutable
                           (call $i8array->immutable-bytes
                                 (array.new_fixed $I8Array 2
                                                  (i32.const 11)
                                                  (i32.const 22)))))
         (func (export "i8array_to_bytes_ref") (result i32)
               (local $b (ref $Bytes))
               (local.set $b
                          (call $i8array->bytes
                                (array.new_fixed $I8Array 2
                                                 (i32.const 11)
                                                 (i32.const 22))))
               (array.get_u $I8Array
                            (struct.get $Bytes $bs (local.get $b))
                            (i32.const 1)))
         (func (export "i32growable_count_after_growth") (result i32)
               (local $g (ref $I32GrowableArray))
               (local.set $g (call $make-i32growable-array (i32.const 1)))
               (call $i32growable-array-add! (local.get $g) (i32.const 11))
               (call $i32growable-array-add! (local.get $g) (i32.const 22))
               (call $i32growable-array-add! (local.get $g) (i32.const 33))
               (call $i32growable-array-count (local.get $g)))
         (func (export "i32growable_ref_after_growth") (result i32)
               (local $g (ref $I32GrowableArray))
               (local.set $g (call $make-i32growable-array (i32.const 1)))
               (call $i32growable-array-add! (local.get $g) (i32.const 11))
               (call $i32growable-array-add! (local.get $g) (i32.const 22))
               (call $i32growable-array-add! (local.get $g) (i32.const 33))
               (call $i32growable-array-ref (local.get $g) (i32.const 2)))
         (func (export "i32growable_copy_ref") (result i32)
               (local $g (ref $I32GrowableArray))
               (local $arr (ref $I32Array))
               (local.set $g (call $make-i32growable-array (i32.const 1)))
               (call $i32growable-array-add! (local.get $g) (i32.const 11))
               (call $i32growable-array-add! (local.get $g) (i32.const 22))
               (local.set $arr (call $i32growable-array->array (local.get $g)))
               (call $i32array-ref (local.get $arr) (i32.const 1)))
         (func (export "i32array_to_growable_count") (result i32)
               (call $i32growable-array-count
                     (call $i32array->growable-array
                           (array.new_fixed $I32Array 2
                                            (i32.const 11)
                                            (i32.const 22)))))
         (func (export "i32growable_add_string_ref") (result i32)
               (local $g (ref $I32GrowableArray))
               (local.set $g (call $make-i32growable-array (i32.const 1)))
               (call $i32growable-array-add! (local.get $g) (i32.const 65))
               (call $i32growable-array-add-string!
                     (local.get $g)
                     (struct.new $String
                                 (i32.const 0)
                                 (i32.const 1)
                                 (array.new_fixed $I32Array 2
                                                  (i32.const 66)
                                                  (i32.const 67))))
               (call $i32growable-array-ref (local.get $g) (i32.const 2)))
         (func (export "growable_bytes_count_after_growth") (result i32)
               (local $g (ref $GrowableBytes))
               (local.set $g (call $make-growable-bytes (i32.const 1)))
               (call $growable-bytes-add! (local.get $g) (i32.const 11))
               (call $growable-bytes-add! (local.get $g) (i32.const 22))
               (call $growable-bytes-add! (local.get $g) (i32.const 33))
               (struct.get $GrowableBytes $i (local.get $g)))
         (func (export "growable_bytes_to_bytes_length") (result i32)
               (local $g (ref $GrowableBytes))
               (local $b (ref $Bytes))
               (local.set $g (call $make-growable-bytes (i32.const 1)))
               (call $growable-bytes-add! (local.get $g) (i32.const 11))
               (call $growable-bytes-add! (local.get $g) (i32.const 22))
               (call $growable-bytes-add! (local.get $g) (i32.const 33))
               (local.set $b (call $growable-bytes->bytes (local.get $g)))
               (array.len (struct.get $Bytes $bs (local.get $b))))
         (func (export "growable_bytes_to_bytes_ref") (result i32)
               (local $g (ref $GrowableBytes))
               (local $b (ref $Bytes))
               (local.set $g (call $make-growable-bytes (i32.const 1)))
               (call $growable-bytes-add! (local.get $g) (i32.const 11))
               (call $growable-bytes-add! (local.get $g) (i32.const 22))
               (call $growable-bytes-add! (local.get $g) (i32.const 33))
               (local.set $b (call $growable-bytes->bytes (local.get $g)))
               (array.get_u $I8Array
                            (struct.get $Bytes $bs (local.get $b))
                            (i32.const 2)))
         (func (export "growable_bytes_to_bytes_immutable_field") (result i32)
               (local $g (ref $GrowableBytes))
               (local.set $g (call $make-growable-bytes (i32.const 1)))
               (call $growable-bytes-add! (local.get $g) (i32.const 11))
               (call $growable-bytes-add! (local.get $g) (i32.const 22))
               (call $growable-bytes-add! (local.get $g) (i32.const 33))
               (struct.get $Bytes $immutable
                           (call $growable-bytes->bytes (local.get $g))))
         (func (export "i32array_to_string_immutable_field") (result i32)
               (struct.get $String $immutable
                           (call $i32array->string
                                 (array.new_fixed $I32Array 2
                                                  (i32.const 65)
                                                  (i32.const 66)))))
         (func (export "i32array_to_immutable_string_field") (result i32)
               (struct.get $String $immutable
                           (call $i32array->immutable-string
                                 (array.new_fixed $I32Array 2
                                                  (i32.const 65)
                                                  (i32.const 66)))))
         (func (export "i32array_to_string_ref") (result i32)
               (local $s (ref $String))
               (local.set $s
                          (call $i32array->string
                                (array.new_fixed $I32Array 2
                                                 (i32.const 65)
                                                 (i32.const 66))))
               (array.get $I32Array
                          (struct.get $String $codepoints (local.get $s))
                          (i32.const 1)))
         (func (export "i32growable_to_string_ref") (result i32)
               (local $g (ref $I32GrowableArray))
               (local $s (ref $String))
               (local.set $g (call $make-i32growable-array (i32.const 1)))
               (call $i32growable-array-add! (local.get $g) (i32.const 65))
               (call $i32growable-array-add! (local.get $g) (i32.const 66))
               (local.set $s (call $i32growable-array->string (local.get $g)))
               (array.get $I32Array
                          (struct.get $String $codepoints (local.get $s))
                          (i32.const 1)))
         (func (export "i32growable_to_immutable_string_field") (result i32)
               (local $g (ref $I32GrowableArray))
               (local.set $g (call $make-i32growable-array (i32.const 1)))
               (call $i32growable-array-add! (local.get $g) (i32.const 65))
               (call $i32growable-array-add! (local.get $g) (i32.const 66))
               (struct.get $String $immutable
                           (call $i32growable-array->immutable-string
                                 (local.get $g))))
         ,(tagged-call2-export "fxand_tagged" '$fxand/2 84 20)
         ,(tagged-call2-export "fxior_tagged" '$fxior/2 84 20)
         ,(tagged-call2-export "fxxor_tagged" '$fxxor/2 84 20)
         ,(tagged-call1-export "fxnot_tagged" '$fxnot 84)
         ,(tagged-call2-export "fxlshift_tagged" '$fxlshift 84 4)
         ,(tagged-call2-export "fxrshift_tagged" '$fxrshift 84 4)
         ,(tagged-call2-export "fxrshift_negative_tagged" '$fxrshift -84 4)
         ,(tagged-call1-export "fxpopcount_tagged" '$fxpopcount 14)
         ,(tagged-call1-export "fxpopcount32_tagged" '$fxpopcount32 14)
         ,(tagged-call1-export "fxpopcount16_tagged" '$fxpopcount16 14)
         ,(tagged-call2-export "fx_plus_wraparound_tagged" '$fx+/wraparound 84 20)
         ,(tagged-call2-export "fx_times_wraparound_tagged" '$fx*/wraparound 84 20)
         ,(tagged-call2-export "fxlshift_wraparound_tagged" '$fxlshift/wraparound 84 4)
         ,(tagged-call2-export "fxrshift_logical_tagged" '$fxrshift/logical 84 4)
         ,(tagged-call1-export "unsafe_fxnot_tagged" '$unsafe-fxnot 84)
         ,(tagged-call1-export "unsafe_fxpopcount_tagged" '$unsafe-fxpopcount 14)
         ,(tagged-call1-export "unsafe_fxpopcount32_tagged" '$unsafe-fxpopcount32 14)
         ,(tagged-call1-export "unsafe_fxpopcount16_tagged" '$unsafe-fxpopcount16 14)
         ,(tagged-call2-export "unsafe_fxlshift_tagged" '$unsafe-fxlshift 84 4)
         ,(tagged-call2-export "unsafe_fx_plus_wraparound_tagged" '$unsafe-fx+/wraparound 84 20)
         ,(tagged-call2-export "unsafe_fx_times_wraparound_tagged" '$unsafe-fx*/wraparound 84 20)
         ,(tagged-call2-export "unsafe_fxlshift_wraparound_tagged" '$unsafe-fxlshift/wraparound 84 4)
         ,(tagged-call2-export "unsafe_fxrshift_tagged" '$unsafe-fxrshift 84 4)
         ,(tagged-call2-export "unsafe_fxrshift_negative_tagged" '$unsafe-fxrshift -84 4)
         ,(tagged-call2-export "unsafe_fxrshift_logical_tagged" '$unsafe-fxrshift/logical 84 4)))

    (define consumer-wat-path
      (make-temporary-file "webracket-core-runtime-consumer-test-~a.wat"))
    (define consumer-wasm-path
      (path-replace-extension consumer-wat-path ".wasm"))
    (check-true (wat->wasm split-consumer-module
                           #:wat consumer-wat-path
                           #:wasm consumer-wasm-path))
    (check-true (file-exists? consumer-wasm-path))

    (define node-path (find-executable-path "node"))
    (when node-path
      (define node-script-path
        (make-temporary-file "webracket-core-runtime-link-test-~a.mjs"))
      (with-output-to-file node-script-path
        (lambda ()
          (display
           #<<JS
import fs from "node:fs/promises";

const [corePath, consumerPath] = process.argv.slice(2);
const coreBytes = await fs.readFile(corePath);
const consumerBytes = await fs.readFile(consumerPath);
const coreModule = await WebAssembly.compile(coreBytes);
const imports = {};
for (const spec of WebAssembly.Module.imports(coreModule)) {
  imports[spec.module] ??= {};
  if (spec.kind === "memory") {
    imports[spec.module][spec.name] = new WebAssembly.Memory({ initial: 1024 });
  } else if (spec.kind === "tag") {
    imports[spec.module][spec.name] = new WebAssembly.Tag({ parameters: ["externref"] });
  } else if (spec.kind === "function") {
    imports[spec.module][spec.name] = (..._args) => {
      if (spec.module === "math" && typeof Math[spec.name] === "function") {
        return Math[spec.name](..._args);
      }
      return 0;
    };
  }
}
const core = await WebAssembly.instantiate(coreModule, imports);
const consumer = await WebAssembly.instantiate(
  consumerBytes,
  { ...imports, core: core.exports },
);

const expected = new Map([
  ["fx_fixnum_true", 1],
  ["fx_immediate_false", 0],
  ["fx_heap_false", 0],
  ["fixnum_fixnum_true", 1],
  ["fixnum_immediate_false", 0],
  ["fl_flonum_true", 1],
  ["fl_fixnum_false", 0],
  ["keyword_keyword_true", 1],
  ["keyword_fixnum_false", 0],
  ["vector_vector_true", 1],
  ["vector_fixnum_false", 0],
  ["struct_type_true", 1],
  ["struct_type_fixnum_false", 0],
  ["struct_struct_type_false", 0],
  ["struct_fixnum_false", 0],
  ["array_length", 3],
  ["array_ref_tagged", 40],
  ["array_set_ref_tagged", 60],
  ["array_fill_ref_tagged", 80],
  ["array_copy_bang_tagged", 40],
  ["array_copy_error_success", 1],
  ["array_copy_error_failure", 0],
  ["array_append_ref_tagged", 60],
  ["array_append_all_ref_tagged", 60],
  ["array_take_length", 2],
  ["array_take_right_ref_tagged", 40],
  ["array_drop_ref_tagged", 40],
  ["array_drop_right_length", 2],
  ["array_split_at_second_length", 2],
  ["array_copy_ref_tagged", 40],
  ["array_set_copy_ref_tagged", 80],
  ["array_extend_length", 5],
  ["growable_array_predicate_true", 1],
  ["growable_array_predicate_false", 0],
  ["growable_array_boolean_true_tagged", 159],
  ["growable_array_ref_default_tagged", 222],
  ["growable_array_count_after_ops", 2],
  ["growable_array_ref_after_ops_tagged", 30],
  ["growable_array_copy_tagged", 40],
  ["array_to_growable_count", 2],
  ["i32array_length", 3],
  ["i32array_ref", 22],
  ["i32array_set", 33],
  ["i32array_equal_true", 1],
  ["i32array_equal_false", 0],
  ["i32array_fill", 44],
  ["i32array_copy_bang", 66],
  ["i32array_copy_error_success", 1],
  ["i32array_copy_error_failure", 0],
  ["i32array_append_ref", 33],
  ["i32array_take_length", 2],
  ["i32array_take_right_ref", 22],
  ["i32array_drop_ref", 22],
  ["i32array_drop_right_length", 2],
  ["i32array_set_copy_ref", 99],
  ["i32array_extend_length", 5],
  ["i8array_length", 3],
  ["i8array_ref_unsigned", 255],
  ["i8array_set", 33],
  ["i8array_fill", 44],
  ["i8array_copy_bang", 66],
  ["i8array_copy_error_success", 1],
  ["i8array_copy_error_failure", 0],
  ["i8array_copy_ref", 22],
  ["i8array_set_copy_ref", 99],
  ["i8array_extend_length", 5],
  ["i8array_append_ref", 33],
  ["i8array_to_bytes_immutable_field", 0],
  ["i8array_to_immutable_bytes_field", 1],
  ["i8array_to_bytes_ref", 22],
  ["i32growable_count_after_growth", 3],
  ["i32growable_ref_after_growth", 33],
  ["i32growable_copy_ref", 22],
  ["i32array_to_growable_count", 2],
  ["i32growable_add_string_ref", 67],
  ["growable_bytes_count_after_growth", 3],
  ["growable_bytes_to_bytes_length", 3],
  ["growable_bytes_to_bytes_ref", 33],
  ["growable_bytes_to_bytes_immutable_field", 3],
  ["i32array_to_string_immutable_field", 0],
  ["i32array_to_immutable_string_field", 1],
  ["i32array_to_string_ref", 66],
  ["i32growable_to_string_ref", 66],
  ["i32growable_to_immutable_string_field", 1],
  ["fxand_tagged", 20],
  ["fxior_tagged", 84],
  ["fxxor_tagged", 64],
  ["fxnot_tagged", -86],
  ["fxlshift_tagged", 336],
  ["fxrshift_tagged", 20],
  ["fxrshift_negative_tagged", -22],
  ["fxpopcount_tagged", 6],
  ["fxpopcount32_tagged", 6],
  ["fxpopcount16_tagged", 6],
  ["fx_plus_wraparound_tagged", 104],
  ["fx_times_wraparound_tagged", 840],
  ["fxlshift_wraparound_tagged", 336],
  ["fxrshift_logical_tagged", 20],
  ["unsafe_fxnot_tagged", -86],
  ["unsafe_fxpopcount_tagged", 6],
  ["unsafe_fxpopcount32_tagged", 6],
  ["unsafe_fxpopcount16_tagged", 6],
  ["unsafe_fxlshift_tagged", 336],
  ["unsafe_fx_plus_wraparound_tagged", 104],
  ["unsafe_fx_times_wraparound_tagged", 840],
  ["unsafe_fxlshift_wraparound_tagged", 336],
  ["unsafe_fxrshift_tagged", 20],
  ["unsafe_fxrshift_negative_tagged", -22],
  ["unsafe_fxrshift_logical_tagged", 20],
]);

for (const [name, value] of expected) {
  const actual = consumer.instance.exports[name]();
  if (actual !== value) {
    throw new Error(`${name}: expected ${value}, got ${actual}`);
  }
}
JS
           ))
        #:exists 'replace)
      (check-equal?
       (system*/exit-code node-path
                          (path->string node-script-path)
                          (path->string core-wasm-path)
                          (path->string consumer-wasm-path))
       0))))
