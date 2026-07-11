#lang racket

(provide (struct-out split-runtime-modules)
         core-runtime-helper-import-form
         core-runtime-helper-import-forms
         split-core-runtime-module)

(require "core-helper.rkt"
         "core-runtime.rkt"
         "module-forms.rkt"
         "shared-types.rkt")

;; A split runtime result contains the standalone runtime module and the
;; rewritten program module that imports selected helper functions from it.
(struct split-runtime-modules (core program imported-names import-forms) #:transparent)

;; function-import-form? : any/c -> boolean?
;;   Check whether form is a top-level imported function declaration.
(define (function-import-form? form)
  (match form
    [`(func ,(? symbol?) ,parts ...)
     (for/or ([part (in-list parts)])
       (match part
         [`(import ,(? string?) ,(? string?)) #t]
         [_ #f]))]
    [_ #f]))

;; function-definition-form? : any/c -> boolean?
;;   Check whether form is a named, non-imported function definition.
(define (function-definition-form? form)
  (and (module-func-name form)
       (not (function-import-form? form))))

;; function-type-form? : any/c -> boolean?
;;   Check whether part is a named function type use.
(define (function-type-form? part)
  (match part
    [`(type ,(? symbol?)) #t]
    [_ #f]))

;; function-inline-signature-form? : any/c -> boolean?
;;   Check whether part belongs to an inline function signature.
(define (function-inline-signature-form? part)
  (match part
    [`(param . ,_) #t]
    [`(result . ,_) #t]
    [_ #f]))

;; function-import-signature-forms : datum? -> (listof datum?)
;;   Extract the type use or inline signature for an imported function.
(define (function-import-signature-forms function-form)
  (match function-form
    [`(func ,(? symbol?) ,parts ...)
     (define type-forms
       (for/list ([part (in-list parts)]
                  #:when (function-type-form? part))
         part))
     (cond
       [(pair? type-forms) (list (car type-forms))]
       [else
        (for/list ([part (in-list parts)]
                   #:when (function-inline-signature-form? part))
          part)])]
    [_
     (error 'function-import-signature-forms
            "expected a named function form, got: ~s"
            function-form)]))

;; core-runtime-helper-import-form :
;;   core-runtime-helper? [#:module string?] -> datum?
;;   Render an import declaration matching a registered core helper.
(define (core-runtime-helper-import-form helper #:module [module-name "core"])
  (define form (core-runtime-helper->form helper))
  (define name (core-runtime-helper-name helper))
  `(func ,name
         (import ,module-name ,(core-runtime-helper-export-name helper))
         ,@(function-import-signature-forms form)))

;; core-runtime-helper-import-forms :
;;   (listof core-runtime-helper?) [#:module string?] -> (listof datum?)
;;   Render import declarations for registered core helpers.
(define (core-runtime-helper-import-forms helpers #:module [module-name "core"])
  (for/list ([helper (in-list helpers)])
    (core-runtime-helper-import-form helper #:module module-name)))

;; import-insertion-prefix-form? : any/c -> boolean?
;;   Recognize forms that should stay before generated core imports.
(define (import-insertion-prefix-form? form)
  (and (pair? form)
       (or (memq (car form) '(type rec import tag))
           (function-import-form? form))))

;; module-forms : datum? -> (listof datum?)
;;   Return a WAT module's body forms.
(define (module-forms module)
  (match module
    [`(module ,forms ...) forms]
    [_ (error 'module-forms "expected a WAT module, got: ~s" module)]))

;; helper-name-set : (listof core-runtime-helper?) -> hasheq?
;;   Build an eq-keyed set of helper function names.
(define (helper-name-set helpers)
  (for/hasheq ([helper (in-list helpers)])
    (values (core-runtime-helper-name helper) #t)))

;; helper-definition-counts : (listof datum?) hasheq? -> hasheq?
;;   Count helper definitions present in module forms.
(define (helper-definition-counts forms names)
  (define counts (make-hasheq))
  (for ([form (in-list forms)]
        #:when (function-definition-form? form))
    (define name (module-func-name form))
    (when (hash-ref names name #f)
      (hash-update! counts name add1 0)))
  counts)

;; sorted-symbols : (listof symbol?) -> (listof symbol?)
;;   Sort symbols by printed name for stable diagnostics.
(define (sorted-symbols syms)
  (sort syms string<? #:key symbol->string))

;; check-helper-definitions! : (listof core-runtime-helper?) hasheq? -> void?
;;   Require exactly one definition for each helper selected for splitting.
(define (check-helper-definitions! helpers counts)
  (define missing
    (for/list ([helper (in-list helpers)]
               #:do [(define name (core-runtime-helper-name helper))]
               #:when (zero? (hash-ref counts name 0)))
      name))
  (define duplicates
    (for/list ([(name count) (in-hash counts)]
               #:when (> count 1))
      name))
  (unless (null? missing)
    (error 'split-core-runtime-module
           "missing core helper definitions: ~a"
           (sorted-symbols missing)))
  (unless (null? duplicates)
    (error 'split-core-runtime-module
           "duplicate core helper definitions: ~a"
           (sorted-symbols duplicates))))

;; remove-helper-definitions : (listof datum?) hasheq? -> (listof datum?)
;;   Remove selected helper function definitions from module body forms.
(define (remove-helper-definitions forms names)
  (for/list ([form (in-list forms)]
             #:unless (and (function-definition-form? form)
                           (hash-ref names (module-func-name form) #f)))
    form))

;; split-core-runtime-module :
;;   datum? [#:helpers (listof core-runtime-helper?)]
;;          [#:import-module string?] [#:core-module datum?] -> split-runtime-modules?
;;   Rewrite a full module so registered core helper definitions become imports.
(define (split-core-runtime-module module
                                   #:helpers [helpers core-runtime-helpers]
                                   #:import-module [import-module-name "core"]
                                   #:core-module [core-module (generate-core-runtime)])
  (define forms (module-forms module))
  (define names (helper-name-set helpers))
  (define counts (helper-definition-counts forms names))
  (check-helper-definitions! helpers counts)
  (define forms-without-helpers (remove-helper-definitions forms names))
  (define import-forms
    (core-runtime-helper-import-forms helpers #:module import-module-name))
  (define-values (prefix rest)
    (splitf-at forms-without-helpers import-insertion-prefix-form?))
  (split-runtime-modules
   core-module
   `(module ,@prefix ,@import-forms ,@rest)
   (map core-runtime-helper-name helpers)
   import-forms))

(module+ test
  (require rackunit
           racket/system
           (only-in "../assembler.rkt" wat->wasm))

  (define sample-helpers
    (list
     (core-runtime-helper
      '$sample-add
      "$sample-add"
      (lambda ()
        '(func $sample-add
               (param $x i32)
               (param $y i32)
               (result i32)
               (i32.add (local.get $x) (local.get $y)))))
     (core-runtime-helper
      '$sample-id
      "$sample-id"
      (lambda ()
        '(func $sample-id
               (type $SampleId)
               (param $x i32)
               (result i32)
               (local.get $x))))))

  (check-equal?
   (core-runtime-helper-import-form (first sample-helpers))
   '(func $sample-add
          (import "core" "$sample-add")
          (param $x i32)
          (param $y i32)
          (result i32)))
  (check-equal?
   (core-runtime-helper-import-form (second sample-helpers))
   '(func $sample-id
          (import "core" "$sample-id")
          (type $SampleId)))

  (define sample-full-module
    `(module
       (type $SampleId (func (param i32) (result i32)))
       ,@(core-runtime-helper-forms sample-helpers)
       (func $probe (export "probe") (result i32)
             (call $sample-add
                   (call $sample-id (i32.const 10))
                   (i32.const 32)))))

  (define sample-split
    (split-core-runtime-module
     sample-full-module
     #:helpers sample-helpers
     #:core-module '(module)))
  (define sample-program-forms
    (module-forms (split-runtime-modules-program sample-split)))
  (check-equal? (split-runtime-modules-imported-names sample-split)
                '($sample-add $sample-id))
  (check-false
   (for/or ([form (in-list sample-program-forms)])
     (and (function-definition-form? form)
          (member (module-func-name form) '($sample-add $sample-id)))))
  (check-equal?
   (for/list ([form (in-list sample-program-forms)]
              #:when (function-import-form? form))
     (module-func-name form))
   '($sample-add $sample-id))

  (define core-link-probe-module
    `(module
       ,@(generate-shared-types)
       ,@(core-runtime-helper-forms core-runtime-helpers)
       (func (export "fx_fixnum_true") (result i32)
             (call $fx?/i32 (ref.i31 (i32.const 84))))
       (func (export "array_ref_tagged") (result i32)
             (i31.get_s
              (ref.cast (ref i31)
                        (call $array-ref
                              (call $make-array
                                    (i32.const 2)
                                    (ref.i31 (i32.const 40)))
                              (i32.const 1)))))))

  (define core-link-split (split-core-runtime-module core-link-probe-module))
  (define core-link-program (split-runtime-modules-program core-link-split))
  (check-equal? (length (split-runtime-modules-import-forms core-link-split))
                (length core-runtime-helpers))
  (for ([name (in-list (split-runtime-modules-imported-names core-link-split))])
    (check-false
     (for/or ([form (in-list (module-forms core-link-program))])
       (and (function-definition-form? form)
            (eq? (module-func-name form) name)))))

  (when (find-executable-path "wasm-tools")
    (define core-wat-path
      (make-temporary-file "webracket-split-core-runtime-~a.wat"))
    (define core-wasm-path
      (path-replace-extension core-wat-path ".wasm"))
    (define program-wat-path
      (make-temporary-file "webracket-split-program-~a.wat"))
    (define program-wasm-path
      (path-replace-extension program-wat-path ".wasm"))
    (check-true
     (wat->wasm (split-runtime-modules-core core-link-split)
                #:wat core-wat-path
                #:wasm core-wasm-path))
    (check-true
     (wat->wasm core-link-program
                #:wat program-wat-path
                #:wasm program-wasm-path))

    (define node-path (find-executable-path "node"))
    (when node-path
      (define node-script-path
        (make-temporary-file "webracket-split-runtime-link-~a.mjs"))
      (with-output-to-file node-script-path
        (lambda ()
          (display
           #<<JS
import fs from "node:fs/promises";

const [corePath, programPath] = process.argv.slice(2);
const coreBytes = await fs.readFile(corePath);
const programBytes = await fs.readFile(programPath);
const core = await WebAssembly.instantiate(coreBytes, {});
const program = await WebAssembly.instantiate(
  programBytes,
  { core: core.instance.exports },
);

const expected = new Map([
  ["fx_fixnum_true", 1],
  ["array_ref_tagged", 40],
]);

for (const [name, value] of expected) {
  const actual = program.instance.exports[name]();
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
                          (path->string program-wasm-path))
       0))))
