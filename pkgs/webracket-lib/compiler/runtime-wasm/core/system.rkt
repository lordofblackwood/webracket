#lang racket

(provide system-runtime-string-constants
         system-runtime-symbol-constants
         system-core-runtime-helpers
         system-runtime-helper-forms
         system-runtime-only-helpers)

(require "../core-helper.rkt"
         "../../private/wasm-utils.rkt")

;; system-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by system/runtime information helpers.
(define system-runtime-string-constants
  `((racket-version    ,(version))
    (system-type-mode-contract
     "(or/c 'os 'os* 'arch 'word 'vm 'gc 'link 'machine 'target-machine\n                  'so-suffix 'so-mode 'fs-change 'cross)")
    (webracket-machine "WebRacket")))

;; system-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by system/runtime information helpers.
(define system-runtime-symbol-constants
  '(system-type
    os
    os*
    arch
    wasm32
    word
    vm
    chez-scheme
    gc
    link
    static
    machine
    target-machine
    so-suffix
    so-mode
    webracket
    fs-change
    supported
    file-level
    cross
    installation-name))

;; system-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for system/runtime information helpers.
(define system-runtime-only-helper-names
  '($system-big-endian?
    $system-type
    $version
    $get-installation-name))

;; system-promoted-runtime-helper-names : (listof symbol?)
;;   Name system helpers available in the standalone core runtime.
(define system-promoted-runtime-helper-names
  '($system-big-endian?))

;; system-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given system helper names from a helper index.
(define (system-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; system-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render system/runtime information helpers in runtime assembly order.
(define (system-runtime-helper-forms helper-index)
  (system-helper-forms helper-index system-runtime-only-helper-names))

;; system-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate all system/runtime information helpers used by the monolithic runtime.
(define system-all-runtime-helpers
  (function-forms->runtime-helpers
   'system-runtime-only-helpers
   `(
     (func $system-big-endian? (type $Prim0) (result (ref eq))
           ;; WebAssembly's linear memory is defined as little-endian,
           ;; so WebRacket always reports a little-endian system.
           (global.get $false))

     ;; system-type : [symbol?] -> any/c
     ;;   Bootstrap target metadata for WebRacket. This is intentionally
     ;;   target-oriented, not host-OS detection. Some valid native-library
     ;;   modes return #f until WebRacket has a browser-specific answer.
     (func $system-type (type $Prim01)
           (param $mode (ref eq)) ;; optional symbol, defaults to 'os
           (result      (ref eq))

           (if (ref.eq (local.get $mode) (global.get $missing))
               (then (return (global.get $symbol:unix))))
           (if (ref.eq (local.get $mode) (global.get $symbol:os))
               (then (return (global.get $symbol:unix))))
           (if (ref.eq (local.get $mode) (global.get $symbol:os*))
               (then (return (global.get $symbol:unix))))
           (if (ref.eq (local.get $mode) (global.get $symbol:arch))
               (then (return (global.get $symbol:wasm32))))
           (if (ref.eq (local.get $mode) (global.get $symbol:word))
               (then (return ,(Imm 32))))
           (if (ref.eq (local.get $mode) (global.get $symbol:vm))
               (then (return (global.get $symbol:chez-scheme))))
           (if (ref.eq (local.get $mode) (global.get $symbol:gc))
               (then (return (global.get $symbol:cs))))
           (if (ref.eq (local.get $mode) (global.get $symbol:link))
               (then (return (global.get $symbol:static))))
           (if (ref.eq (local.get $mode) (global.get $symbol:machine))
               (then (return (global.get $string:webracket-machine))))
           (if (ref.eq (local.get $mode) (global.get $symbol:target-machine))
               (then (return (global.get $symbol:webracket))))
           (if (ref.eq (local.get $mode) (global.get $symbol:so-suffix))
               (then (return (global.get $false))))
           (if (ref.eq (local.get $mode) (global.get $symbol:so-mode))
               (then (return (global.get $false))))
           (if (ref.eq (local.get $mode) (global.get $symbol:fs-change))
               (then
                (return
                 (struct.new $Vector
                             (i32.const 0)
                             (i32.const 1)
                             (array.new_fixed $Array 4
                                              (global.get $symbol:supported)
                                              (global.get $false)
                                              (global.get $false)
                                              (global.get $symbol:file-level))))))
           (if (ref.eq (local.get $mode) (global.get $symbol:cross))
               (then (return (global.get $false))))
           (call $raise-argument-error1
                 (global.get $symbol:system-type)
                 (global.get $string:system-type-mode-contract)
                 (local.get $mode))
           (unreachable))

     ;; version : -> string?
     ;;   Return the Racket version used to generate this WebRacket runtime.
     (func $version (type $Prim0) (result (ref eq))
           (global.get $string:racket-version))

     ;; get-installation-name : [hash? = #hash()] -> string?
     ;;   Approximate #%utils `get-installation-name` for browser module
     ;;   loading. Racket falls back to `(version)` when the installation
     ;;   config table has no `installation-name`; WebRacket currently uses
     ;;   that fallback unconditionally after validating an explicit table.
     (func $get-installation-name (type $Prim01)
           (param $config-table (ref eq)) ;; optional configuration hash, default #hash()
           (result              (ref eq))

           (if (ref.eq (local.get $config-table) (global.get $missing))
               (then (return (global.get $string:racket-version))))
           (if (i32.eqz (call $hash-leaf?/i32 (local.get $config-table)))
               (then
                (call $raise-argument-error1
                      (global.get $symbol:get-installation-name)
                      (global.get $string:hash?)
                      (local.get $config-table))
                (unreachable)))
           (call $hash-ref
                 (local.get $config-table)
                 (global.get $symbol:installation-name)
                 (global.get $string:racket-version))))))

;; system-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate system helpers available in the standalone core runtime.
(define system-core-runtime-helpers
  (select-runtime-helpers system-all-runtime-helpers
                          system-promoted-runtime-helper-names))

;; system-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate system helpers that still remain runtime-local.
(define system-runtime-only-helpers
  (remove-runtime-helpers system-all-runtime-helpers
                          system-promoted-runtime-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define system-helper-index
    (make-core-runtime-helper-index
     (append system-core-runtime-helpers
             system-runtime-only-helpers)))

  (check-equal?
   (map form-name (system-runtime-helper-forms system-helper-index))
   system-runtime-only-helper-names)

  (check-equal?
   (map core-runtime-helper-name system-core-runtime-helpers)
   system-promoted-runtime-helper-names))
