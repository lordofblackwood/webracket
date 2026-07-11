#lang racket

(provide (struct-out split-runtime-modules)
         core-runtime-helper-import-form
         core-runtime-helper-import-forms
         classified-runtime-import/export-forms
         runtime-tag-export-form
         runtime-tag-import-form
         runtime-function-export-form
         runtime-function-import-form
         runtime-global-export-form
         runtime-global-import-form
         split-classified-runtime-module
         split-core-runtime-module)

(require "core-helper.rkt"
         "core-runtime.rkt"
         "module-forms.rkt"
         (only-in "runtime-analysis.rkt"
                  split-module-forms)
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

;; global-import-form? : any/c -> boolean?
;;   Check whether form is a top-level imported global declaration.
(define (global-import-form? form)
  (match form
    [`(global ,(? symbol?) ,parts ...)
     (for/or ([part (in-list parts)])
       (match part
         [`(import ,(? string?) ,(? string?)) #t]
         [_ #f]))]
    [_ #f]))

;; tag-import-form? : any/c -> boolean?
;;   Check whether form is a top-level imported tag declaration.
(define (tag-import-form? form)
  (match form
    [`(tag ,(? symbol?) ,parts ...)
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

;; global-definition-form? : any/c -> boolean?
;;   Check whether form is a named, non-imported global definition.
(define (global-definition-form? form)
  (and (module-global-name form)
       (not (global-import-form? form))))

;; module-tag-name : any/c -> (or/c symbol? #f)
;;   Return the name of a WAT tag form, if the form has one.
(define (module-tag-name form)
  (and (pair? form)
       (eq? (car form) 'tag)
       (pair? (cdr form))
       (symbol? (cadr form))
       (cadr form)))

;; tag-definition-form? : any/c -> boolean?
;;   Check whether form is a named, non-imported tag definition.
(define (tag-definition-form? form)
  (and (module-tag-name form)
       (not (tag-import-form? form))))

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

;; tag-signature-form? : any/c -> boolean?
;;   Check whether part belongs to a tag signature.
(define (tag-signature-form? part)
  (match part
    [`(param . ,_) #t]
    [_ #f]))

;; tag-import-signature-forms : datum? -> (listof datum?)
;;   Extract the parameter signature for an imported tag.
(define (tag-import-signature-forms tag-form)
  (match tag-form
    [`(tag ,(? symbol?) ,parts ...)
     (for/list ([part (in-list parts)]
                #:when (tag-signature-form? part))
       part)]
    [_
     (error 'tag-import-signature-forms
            "expected a named tag form, got: ~s"
            tag-form)]))

;; core-runtime-helper-import-form :
;;   core-runtime-helper? [#:module string?] -> datum?
;;   Render an import declaration matching a registered core helper.
(define (core-runtime-helper-import-form helper #:module [module-name "core"])
  (define form (core-runtime-helper->form helper))
  (define name (core-runtime-helper-name helper))
  `(func ,name
         (import ,module-name ,(core-runtime-helper-export-name helper))
         ,@(function-import-signature-forms form)))

;; runtime-export-name : symbol? -> string?
;;   Derive a stable runtime export name from a Wasm identifier.
(define (runtime-export-name name)
  (symbol->string name))

;; runtime-function-import-form : datum? [#:module string?] -> datum?
;;   Render an import declaration matching a runtime function definition.
(define (runtime-function-import-form function-form #:module [module-name "core"])
  (define name (module-func-name function-form))
  (unless name
    (error 'runtime-function-import-form
           "expected a named function form, got: ~s"
           function-form))
  `(func ,name
         (import ,module-name ,(runtime-export-name name))
         ,@(function-import-signature-forms function-form)))

;; runtime-function-export-form : symbol? -> datum?
;;   Render an export declaration for a runtime function.
(define (runtime-function-export-form name)
  `(export ,(runtime-export-name name) (func ,name)))

;; runtime-tag-import-form : datum? [#:module string?] -> datum?
;;   Render an import declaration matching a runtime tag definition.
(define (runtime-tag-import-form tag-form #:module [module-name "core"])
  (define name (module-tag-name tag-form))
  (unless name
    (error 'runtime-tag-import-form
           "expected a named tag form, got: ~s"
           tag-form))
  `(tag ,name
        (import ,module-name ,(runtime-export-name name))
        ,@(tag-import-signature-forms tag-form)))

;; runtime-tag-export-form : symbol? -> datum?
;;   Render an export declaration for a runtime tag.
(define (runtime-tag-export-form name)
  `(export ,(runtime-export-name name) (tag ,name)))

;; global-type-form : datum? -> datum?
;;   Extract the type declaration from a named global definition.
(define (global-type-form global-form)
  (match global-form
    [`(global ,(? symbol?) ,type ,_ ...)
     type]
    [_
     (error 'global-type-form
            "expected a named global form, got: ~s"
            global-form)]))

;; runtime-global-import-form : datum? [#:module string?] -> datum?
;;   Render an import declaration matching a runtime global definition.
(define (runtime-global-import-form global-form #:module [module-name "core"])
  (define name (module-global-name global-form))
  (unless name
    (error 'runtime-global-import-form
           "expected a named global form, got: ~s"
           global-form))
  `(global ,name
           (import ,module-name ,(runtime-export-name name))
           ,(global-type-form global-form)))

;; runtime-global-export-form : symbol? -> datum?
;;   Render an export declaration for a runtime global.
(define (runtime-global-export-form name)
  `(export ,(runtime-export-name name) (global ,name)))

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
           (function-import-form? form)
           (global-import-form? form)
           (tag-import-form? form))))

;; named-form-index : (listof datum?) (datum? -> (or/c symbol? #f)) -> hasheq?
;;   Build an index from Wasm identifier to top-level module form.
(define (named-form-index forms name-of)
  (for/hasheq ([form (in-list forms)]
               #:do [(define name (name-of form))]
               #:when name)
    (values name form)))

;; walk-symbol-refs : any/c hasheq? -> (listof symbol?)
;;   Find symbolic references represented by keys in `available-names`.
(define (walk-symbol-refs x available-names)
  (define refs (make-hasheq))
  (define (walk x)
    (cond
      [(symbol? x)
       (when (hash-ref available-names x #f)
         (hash-set! refs x #t))]
      [(pair? x)
       (walk (car x))
       (walk (cdr x))]
      [else (void)]))
  (walk x)
  (hash-keys refs))

;; referenced-runtime-names : (listof datum?) hasheq? -> (listof symbol?)
;;   Return runtime names referenced by the program forms.
(define (referenced-runtime-names program-forms available-names)
  (sort
   (remove-duplicates
    (append*
     (for/list ([form (in-list program-forms)])
       (walk-symbol-refs form available-names))))
   symbol<?))

;; classified-runtime-import/export-forms :
;;   (listof datum?) (listof datum?) [#:module string?]
;;   -> (values (listof symbol?) (listof datum?) (listof datum?))
;;   Build import and export declarations for runtime definitions used by program forms.
(define (classified-runtime-import/export-forms runtime-forms
                                                program-forms
                                                #:module [module-name "core"])
  (define function-form-by-name
    (named-form-index
     (filter function-definition-form? runtime-forms)
     module-func-name))
  (define global-form-by-name
    (named-form-index
     (filter global-definition-form? runtime-forms)
     module-global-name))
  (define tag-form-by-name
    (named-form-index
     (filter tag-definition-form? runtime-forms)
     module-tag-name))
  (define available-names
    (for/hasheq ([name (in-list (append (hash-keys function-form-by-name)
                                        (hash-keys global-form-by-name)
                                        (hash-keys tag-form-by-name)))])
      (values name #t)))
  (define referenced-names
    (referenced-runtime-names program-forms available-names))
  (define referenced-function-names
    (filter (lambda (name) (hash-ref function-form-by-name name #f))
            referenced-names))
  (define referenced-global-names
    (filter (lambda (name) (hash-ref global-form-by-name name #f))
            referenced-names))
  (define referenced-tag-names
    (filter (lambda (name) (hash-ref tag-form-by-name name #f))
            referenced-names))
  (define import-forms
    (append
     (for/list ([name (in-list referenced-function-names)])
       (runtime-function-import-form (hash-ref function-form-by-name name)
                                     #:module module-name))
     (for/list ([name (in-list referenced-global-names)])
       (runtime-global-import-form (hash-ref global-form-by-name name)
                                   #:module module-name))
     (for/list ([name (in-list referenced-tag-names)])
       (runtime-tag-import-form (hash-ref tag-form-by-name name)
                                #:module module-name))))
  (define export-forms
    (append
     (map runtime-function-export-form referenced-function-names)
     (map runtime-global-export-form referenced-global-names)
     (map runtime-tag-export-form referenced-tag-names)))
  (values (append referenced-function-names
                  referenced-global-names
                  referenced-tag-names)
          import-forms
          export-forms))

;; type-prefix-form? : any/c -> boolean?
;;   Check whether form declares types that must be duplicated across modules.
(define (type-prefix-form? form)
  (and (pair? form)
       (memq (car form) '(type rec))))

;; declare-elem-form? : any/c -> boolean?
;;   Check whether form is an `elem declare funcref` declaration.
(define (declare-elem-form? form)
  (match form
    [`(elem declare funcref . ,_) #t]
    [_ #f]))

;; ref-func-name : any/c -> (or/c symbol? #f)
;;   Return the function name referenced by a `ref.func` expression.
(define (ref-func-name form)
  (match form
    [`(ref.func ,(? symbol? name)) name]
    [_ #f]))

;; filter-declare-elem-form : datum? hasheq? -> (or/c datum? #f)
;;   Keep only declared function refs present in `names`.
(define (filter-declare-elem-form form names)
  (match form
    [`(elem declare funcref ,refs ...)
     (define kept-refs
       (for/list ([ref (in-list refs)]
                  #:do [(define name (ref-func-name ref))]
                  #:when (and name (hash-ref names name #f)))
         ref))
     (and (pair? kept-refs)
          `(elem declare funcref ,@kept-refs))]
    [_
     (error 'filter-declare-elem-form
            "expected an elem declare funcref form, got: ~s"
            form)]))

;; split-declare-elem-forms : (listof datum?) hasheq? hasheq?
;;   -> (values (listof datum?) (listof datum?))
;;   Split declared function refs according to runtime and program availability.
(define (split-declare-elem-forms forms runtime-function-names program-function-names)
  (for/fold ([runtime-forms '()]
             [program-forms '()])
            ([form (in-list forms)]
             #:when (declare-elem-form? form))
    (define runtime-form
      (filter-declare-elem-form form runtime-function-names))
    (define program-form
      (filter-declare-elem-form form program-function-names))
    (values (if runtime-form (cons runtime-form runtime-forms) runtime-forms)
            (if program-form (cons program-form program-forms) program-forms))))

;; form-function-name-set : (listof datum?) -> hasheq?
;;   Build a set of named function declarations in module body forms.
(define (form-function-name-set forms)
  (for/hasheq ([form (in-list forms)]
               #:do [(define name (module-func-name form))]
               #:when name)
    (values name #t)))

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
;;          [#:require-all? boolean?] [#:import-module string?]
;;          [#:core-module datum?] -> split-runtime-modules?
;;   Rewrite a full module so registered core helper definitions become imports.
(define (split-core-runtime-module module
                                   #:helpers [helpers core-runtime-helpers]
                                   #:require-all? [require-all? #t]
                                   #:import-module [import-module-name "core"]
                                   #:core-module [core-module (generate-core-runtime)])
  (define forms (module-forms module))
  (define names (helper-name-set helpers))
  (define counts (helper-definition-counts forms names))
  (define selected-helpers
    (if require-all?
        helpers
        (for/list ([helper (in-list helpers)]
                   #:when (positive? (hash-ref counts (core-runtime-helper-name helper) 0)))
          helper)))
  (check-helper-definitions! selected-helpers counts)
  (define forms-without-helpers (remove-helper-definitions forms names))
  (define import-forms
    (core-runtime-helper-import-forms selected-helpers #:module import-module-name))
  (define-values (prefix rest)
    (splitf-at forms-without-helpers import-insertion-prefix-form?))
  (split-runtime-modules
   core-module
   `(module ,@prefix ,@import-forms ,@rest)
   (map core-runtime-helper-name selected-helpers)
   import-forms))

;; split-classified-runtime-module :
;;   datum? #:program-function-names (listof symbol?) #:result-global symbol?
;;          #:top-level-variable-declarations (listof datum?)
;;          #:string-constants list? #:bytes-constants list? #:symbol-constants list?
;;          [#:import-module string?] -> split-runtime-modules?
;;   Split a generated module into runtime and program modules using runtime metadata.
(define (split-classified-runtime-module
         module
         #:program-function-names program-function-names
         #:result-global result
         #:top-level-variable-declarations top-level-variable-declarations
         #:string-constants string-constants
         #:bytes-constants bytes-constants
         #:symbol-constants symbol-constants
         #:import-module [import-module-name "core"])
  (define-values (runtime-forms/reversed program-forms/reversed)
    (split-module-forms
     module
     #:program-function-names program-function-names
     #:result-global result
     #:top-level-variable-declarations top-level-variable-declarations
     #:string-constants string-constants
     #:bytes-constants bytes-constants
     #:symbol-constants symbol-constants))
  (define runtime-forms (reverse runtime-forms/reversed))
  (define program-forms (reverse program-forms/reversed))
  (define runtime-body-forms
    (for/list ([form (in-list runtime-forms)]
               #:unless (declare-elem-form? form))
      form))
  (define-values (imported-names import-forms export-forms)
    (classified-runtime-import/export-forms
     runtime-body-forms
     program-forms
     #:module import-module-name))
  (define runtime-function-names
    (form-function-name-set runtime-body-forms))
  (define program-available-function-names
    (form-function-name-set (append import-forms program-forms)))
  (define-values (runtime-elem-forms/reversed program-elem-forms/reversed)
    (split-declare-elem-forms runtime-forms
                              runtime-function-names
                              program-available-function-names))
  (define program-type-forms
    (for/list ([form (in-list runtime-body-forms)]
               #:when (type-prefix-form? form))
      form))
  (split-runtime-modules
   `(module
      ,@runtime-body-forms
      ,@(reverse runtime-elem-forms/reversed)
      ,@export-forms)
   `(module
      ,@program-type-forms
      ,@import-forms
      ,@program-forms
      ,@(reverse program-elem-forms/reversed))
   imported-names
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

  (define sample-pruned-module
    `(module
       (type $SampleId (func (param i32) (result i32)))
       ,(core-runtime-helper->form (first sample-helpers))
       (func $probe (export "probe") (result i32)
             (call $sample-add (i32.const 10) (i32.const 32)))))
  (define sample-pruned-split
    (split-core-runtime-module
     sample-pruned-module
     #:helpers sample-helpers
     #:require-all? #f
     #:core-module '(module)))
  (check-equal? (split-runtime-modules-imported-names sample-pruned-split)
                '($sample-add))

  (define boundary-runtime-forms
    '((tag $boundary-exn (param i32))
      (global $runtime-state (mut i32) (i32.const 40))
      (func $runtime-add-state
            (param $x i32)
            (result i32)
            (i32.add (local.get $x) (global.get $runtime-state)))
      (func $unused-runtime-helper
            (result i32)
            (i32.const 0))))

  (define boundary-program-forms
    '((func $probe
            (export "probe")
            (result i32)
            (if (i32.const 0)
                (then
                 (throw $boundary-exn (i32.const 5))))
            (global.set $runtime-state (i32.const 2))
            (call $runtime-add-state (i32.const 40)))))

  (define-values (boundary-imported-names
                  boundary-import-forms
                  boundary-export-forms)
    (classified-runtime-import/export-forms
     boundary-runtime-forms
     boundary-program-forms))

  (check-equal? boundary-imported-names
                '($runtime-add-state $runtime-state $boundary-exn))
  (check-equal?
   boundary-import-forms
   '((func $runtime-add-state
           (import "core" "$runtime-add-state")
           (param $x i32)
           (result i32))
     (global $runtime-state
             (import "core" "$runtime-state")
             (mut i32))
     (tag $boundary-exn
          (import "core" "$boundary-exn")
          (param i32))))
  (check-equal?
   boundary-export-forms
   '((export "$runtime-add-state" (func $runtime-add-state))
     (export "$runtime-state" (global $runtime-state))
     (export "$boundary-exn" (tag $boundary-exn))))

  (define classified-sample-module
    '(module
      (type $Probe (func (result i32)))
      (tag $boundary-exn (param i32))
      (global $runtime-state (mut i32) (i32.const 40))
      (func $runtime-add-state
            (param $x i32)
            (result i32)
            (i32.add (local.get $x) (global.get $runtime-state)))
      (global $result (mut i32) (i32.const 0))
      (func $probe
            (export "probe")
            (result i32)
            (if (i32.const 0)
                (then
                 (throw $boundary-exn (i32.const 5))))
            (global.set $runtime-state (i32.const 2))
            (call $runtime-add-state (i32.const 40)))
      (elem declare funcref
            (ref.func $runtime-add-state)
            (ref.func $probe))))

  (define classified-split
    (split-classified-runtime-module
     classified-sample-module
     #:program-function-names '($probe)
     #:result-global '$result
     #:top-level-variable-declarations
     '((global $result (mut i32) (i32.const 0)))
     #:string-constants '()
     #:bytes-constants '()
     #:symbol-constants '()))
  (define classified-core-forms
    (module-forms (split-runtime-modules-core classified-split)))
  (define classified-program-forms
    (module-forms (split-runtime-modules-program classified-split)))

  (check-equal? (split-runtime-modules-imported-names classified-split)
                '($runtime-add-state $runtime-state $boundary-exn))
  (check-not-false
   (member '(elem declare funcref (ref.func $runtime-add-state))
           classified-core-forms))
  (check-not-false
   (member '(elem declare funcref
                  (ref.func $runtime-add-state)
                  (ref.func $probe))
           classified-program-forms))
  (check-false
   (for/or ([form (in-list classified-program-forms)])
     (and (function-definition-form? form)
          (eq? (module-func-name form) '$runtime-add-state))))

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
    (define boundary-core-wat-path
      (make-temporary-file "webracket-boundary-core-~a.wat"))
    (define boundary-core-wasm-path
      (path-replace-extension boundary-core-wat-path ".wasm"))
    (define boundary-program-wat-path
      (make-temporary-file "webracket-boundary-program-~a.wat"))
    (define boundary-program-wasm-path
      (path-replace-extension boundary-program-wat-path ".wasm"))
    (define classified-core-wat-path
      (make-temporary-file "webracket-classified-core-~a.wat"))
    (define classified-core-wasm-path
      (path-replace-extension classified-core-wat-path ".wasm"))
    (define classified-program-wat-path
      (make-temporary-file "webracket-classified-program-~a.wat"))
    (define classified-program-wasm-path
      (path-replace-extension classified-program-wat-path ".wasm"))
    (check-true
     (wat->wasm (split-runtime-modules-core core-link-split)
                #:wat core-wat-path
                #:wasm core-wasm-path))
    (check-true
     (wat->wasm core-link-program
                #:wat program-wat-path
                #:wasm program-wasm-path))
    (check-true
     (wat->wasm `(module
                   ,@boundary-runtime-forms
                   ,@boundary-export-forms)
                #:wat boundary-core-wat-path
                #:wasm boundary-core-wasm-path))
    (check-true
     (wat->wasm `(module
                   ,@boundary-import-forms
                   ,@boundary-program-forms)
                #:wat boundary-program-wat-path
                #:wasm boundary-program-wasm-path))
    (check-true
     (wat->wasm (split-runtime-modules-core classified-split)
                #:wat classified-core-wat-path
                #:wasm classified-core-wasm-path))
    (check-true
     (wat->wasm (split-runtime-modules-program classified-split)
                #:wat classified-program-wat-path
                #:wasm classified-program-wasm-path))

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
       0)
      (define boundary-node-script-path
        (make-temporary-file "webracket-boundary-link-~a.mjs"))
      (with-output-to-file boundary-node-script-path
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

const actual = program.instance.exports.probe();
if (actual !== 42) {
  throw new Error(`probe: expected 42, got ${actual}`);
}
JS
           ))
        #:exists 'replace)
      (check-equal?
       (system*/exit-code node-path
                          (path->string boundary-node-script-path)
                          (path->string boundary-core-wasm-path)
                          (path->string boundary-program-wasm-path))
       0)
      (define classified-node-script-path
        (make-temporary-file "webracket-classified-link-~a.mjs"))
      (with-output-to-file classified-node-script-path
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

const actual = program.instance.exports.probe();
if (actual !== 42) {
  throw new Error(`probe: expected 42, got ${actual}`);
}
JS
           ))
        #:exists 'replace)
      (check-equal?
       (system*/exit-code node-path
                          (path->string classified-node-script-path)
                          (path->string classified-core-wasm-path)
                          (path->string classified-program-wasm-path))
       0))))
