#lang racket

(provide core-runtime-string-constants
         core-runtime-bytes-constants
         core-runtime-symbol-constants
         runtime-linklet-body-reserved-symbols/registration
         runtime-linklet-body-reserved-symbols
         make-program-runtime-constant-registry
         make-core-populated-runtime-constant-registry
         runtime-constant-declaration-forms
         runtime-constant-initializer-forms)

(require (only-in "../constants.rkt"
                  make-populated-runtime-constant-registry
                  runtime-constant-declaration-forms
                  runtime-constant-initializer-forms)
         (only-in "runtime-bytes-constants.rkt"
                  core-runtime-bytes-constants)
         (only-in "runtime-string-constants.rkt"
                  core-runtime-string-constants)
         (only-in "runtime-symbol-constants.rkt"
                  core-runtime-symbol-constants
                  runtime-linklet-body-reserved-symbols/registration
                  runtime-linklet-body-reserved-symbols))

;; make-program-runtime-constant-registry : list? list? list? list? list? list? -> runtime-constant-registry?
;;   Create a registry populated with program, active primitive, and runtime constants.
(define (make-program-runtime-constant-registry string-constants
                                                bytes-constants
                                                symbol-constants
                                                primitive-symbols
                                                ffi-primitive-symbols
                                                all-primitives)
  (make-core-populated-runtime-constant-registry
   string-constants
   bytes-constants
   symbol-constants
   primitive-symbols
   ffi-primitive-symbols
   (runtime-linklet-body-reserved-symbols/registration all-primitives)))

;; make-core-populated-runtime-constant-registry : list? list? list? list? list? list? -> runtime-constant-registry?
;;   Create and populate the registry with program, active, reserved, and core constants.
(define (make-core-populated-runtime-constant-registry string-constants
                                                       bytes-constants
                                                       symbol-constants
                                                       primitive-symbols
                                                       ffi-primitive-symbols
                                                       reserved-symbols)
  (make-populated-runtime-constant-registry
   string-constants
   bytes-constants
   symbol-constants
   primitive-symbols
   ffi-primitive-symbols
   reserved-symbols
   core-runtime-string-constants
   core-runtime-bytes-constants
   core-runtime-symbol-constants))

(module+ test
  (require rackunit
           (only-in "../constants.rkt"
                    runtime-constant-registry-declare-strings
                    runtime-constant-registry-declare-bytes
                    runtime-constant-registry-declare-symbols!)
           (only-in "linklets.rkt"
                    linklet-body-core-reserved-symbols))

  ;; form-names : (listof datum?) -> (listof symbol?)
  ;;   Extract data/global names from declaration forms.
  (define (form-names forms)
    (for/list ([form (in-list forms)])
      (second form)))

  (define registry
    (make-core-populated-runtime-constant-registry
     '((program-string "program"))
     '((program-bytes #"program"))
     '((program-symbol program-symbol))
     '(primitive)
     '(ffi)
     '(reserved primitive)))

  (define string-declaration-names
    (form-names (runtime-constant-registry-declare-strings registry)))

  (define bytes-declaration-names
    (form-names (runtime-constant-registry-declare-bytes registry)))

  (define symbol-declaration-names
    (form-names (runtime-constant-registry-declare-symbols! registry)))

  (check-not-false (memq '$string:program-string string-declaration-names))
  (check-not-false (memq '$string:empty string-declaration-names))
  (check-not-false (memq '$bytes:program-bytes bytes-declaration-names))
  (check-not-false (memq '$bytes:empty bytes-declaration-names))
  (check-not-false (memq '$symbol:program-symbol symbol-declaration-names))
  (check-not-false (memq '$symbol:primitive symbol-declaration-names))
  (check-not-false (memq '$symbol:ffi symbol-declaration-names))
  (check-not-false (memq '$symbol:reserved symbol-declaration-names))
  (check-not-false (memq '$symbol:racket symbol-declaration-names))

  (check-equal?
   (runtime-linklet-body-reserved-symbols/registration '(lambda custom))
   (append linklet-body-core-reserved-symbols '(custom)))
  (check-equal?
   (runtime-linklet-body-reserved-symbols '(custom lambda))
   (sort (append linklet-body-core-reserved-symbols '(custom))
         symbol<?))

  (define program-registry
    (make-program-runtime-constant-registry
     '((program-string "program"))
     '((program-bytes #"program"))
     '((program-symbol program-symbol))
     '(primitive)
     '(ffi)
     '(lambda custom)))
  (define program-symbol-declaration-names
    (form-names (runtime-constant-registry-declare-symbols! program-registry)))
  (check-not-false (memq '$symbol:lambda program-symbol-declaration-names))
  (check-not-false (memq '$symbol:custom program-symbol-declaration-names))
  (check-not-false (memq '$symbol:primitive program-symbol-declaration-names))
  (check-not-false (memq '$symbol:ffi program-symbol-declaration-names)))
