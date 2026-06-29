#lang racket

(provide core-runtime-helpers
         core-runtime-helper-index
         generate-core-runtime)

(require "core-helper.rkt"
         "core/fixnums.rkt"
         "shared-types.rkt")

;; core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate the functions currently shared between monolithic and core runtime trees.
(define core-runtime-helpers
  (append
   fixnum-core-runtime-helpers))

;; core-runtime-helper-index : hasheq?
;;   Index core runtime helpers by Wasm function name.
(define core-runtime-helper-index
  (make-core-runtime-helper-index core-runtime-helpers))

;; generate-core-runtime : -> datum?
;;   Build the standalone core runtime module tree used by split-runtime experiments.
(define (generate-core-runtime)
  `(module
     ,@(generate-shared-types)
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

  (define shared-types (generate-shared-types))
  (define shared-type-names (shared-type-name-set shared-types))
  (define core-helper-names core-runtime-helper-index)
  (check-pred list? shared-types)
  (check-true (hash-has-key? shared-type-names '$Array))
  (check-true (hash-has-key? shared-type-names '$Pair))
  (check-true (for/or ([form (in-list shared-types)])
                (type-form-named? '$Array form)))
  (check-true (for/or ([form (in-list shared-types)])
                (match form
                  [`(rec . ,_) #t]
                  [_ #f])))

  (for ([helper (in-list core-runtime-helpers)])
    (define name (core-runtime-helper-name helper))
    (define export-name (core-runtime-helper-export-name helper))
    (check-equal? (core-runtime-helper-ref core-runtime-helper-index name)
                  helper)
    (check-equal? (function-export-names
                   (core-runtime-helper-form core-runtime-helper-index name))
                  '())
    (check-equal? (function-export-names
                   (core-runtime-helper-form core-runtime-helper-index name #:export? #t))
                  (list export-name)))
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
                   core-helper-names
                   shared-type-names)
                  '()))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $ok (param (ref eq)) (result i32)
                        (call $fx?/i32 (local.get $v)))
                 core-helper-names
                 shared-type-names)
                '())
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (result i32)
                        (global.get $false))
                 core-helper-names
                 shared-type-names)
                (list (helper-dependency-problem
                       'runtime-dependency
                       'global.get)))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (param (ref eq)) (result i32)
                        (call $other (local.get $v)))
                 core-helper-names
                 shared-type-names)
                (list (helper-dependency-problem
                       'runtime-call
                       '$other)))
  (check-equal? (core-runtime-helper-dependency-problems
                 '(func $bad (param (ref $NotShared)) (result i32)
                        (i32.const 0))
                 core-helper-names
                 shared-type-names)
                (list (helper-dependency-problem
                       'unshared-type
                       '$NotShared)))

  (define core-module (generate-core-runtime))
  (define core-forms (module-body core-module))
  (check-pred list? core-forms)
  (check-true (for/or ([form (in-list core-forms)])
                (type-form-named? '$Array form)))
  (for ([helper (in-list core-runtime-helpers)])
    (define name (core-runtime-helper-name helper))
    (define export-name (core-runtime-helper-export-name helper))
    (define matching-functions
      (for/list ([form (in-list core-forms)]
                 #:when (function-form-named? name form))
        form))
    (check-equal? (length matching-functions) 1)
    (check-equal? (function-export-names (first matching-functions))
                  (list export-name)))

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
               (call $fixnum?/i32 (ref.i31 (i32.const 85))))))

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
const core = await WebAssembly.instantiate(coreBytes, {});
const consumer = await WebAssembly.instantiate(
  consumerBytes,
  { core: core.instance.exports },
);

const expected = new Map([
  ["fx_fixnum_true", 1],
  ["fx_immediate_false", 0],
  ["fx_heap_false", 0],
  ["fixnum_fixnum_true", 1],
  ["fixnum_immediate_false", 0],
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
