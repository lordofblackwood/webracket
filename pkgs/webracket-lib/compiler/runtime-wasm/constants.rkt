#lang racket

(provide make-runtime-constant-registry
         runtime-constant-registry-add-string!
         runtime-constant-registry-add-bytes!
         runtime-constant-registry-add-symbol!
         runtime-constant-registry-add-string-constants!
         runtime-constant-registry-add-bytes-constants!
         runtime-constant-registry-add-symbols!
         make-populated-runtime-constant-registry
         string-data-name
         string-global-name
         bytes-data-name
         bytes-global-name
         symbol-data-name
         symbol-global-name
         program-constant-global-names
         program-constant-data-names
         constant-global-name?
         constant-data-name?
         runtime-constant-registry-declare-strings
         runtime-constant-registry-declare-bytes
         runtime-constant-registry-declare-symbols!
         runtime-constant-registry-initialize-strings
         runtime-constant-registry-initialize-bytes
         runtime-constant-registry-initialize-symbols!
         runtime-constant-declaration-forms
         runtime-constant-initializer-forms)

(require "../private/wasm-data.rkt"
         "../private/wasm-utils.rkt")

;; A runtime constant registry tracks program constants plus constants needed
;; by runtime support. Symbols are normalized lazily because runtime-wasm.rkt
;; keeps adding symbols while it builds the runtime tree.
(struct runtime-constant-registry (strings bytes symbols seen-symbols)
  #:mutable
  #:transparent)

;; make-runtime-constant-registry : list? list? list? -> runtime-constant-registry?
;;   Create a mutable registry seeded with program string, byte, and symbol constants.
(define (make-runtime-constant-registry string-constants
                                        bytes-constants
                                        symbol-constants)
  (runtime-constant-registry string-constants
                             bytes-constants
                             symbol-constants
                             (make-hasheq)))

;; runtime-constant-registry-add-string! : runtime-constant-registry? symbol? string? -> void?
;;   Add a string constant to the registry.
(define (runtime-constant-registry-add-string! registry name string)
  (set-runtime-constant-registry-strings!
   registry
   (cons (list name string)
         (runtime-constant-registry-strings registry))))

;; runtime-constant-registry-add-bytes! : runtime-constant-registry? symbol? bytes? -> void?
;;   Add a byte string constant to the registry.
(define (runtime-constant-registry-add-bytes! registry name bytes)
  (set-runtime-constant-registry-bytes!
   registry
   (cons (list name bytes)
         (runtime-constant-registry-bytes registry))))

;; runtime-constant-registry-add-symbol! : runtime-constant-registry? symbol? -> void?
;;   Add an interned-symbol constant to the registry, avoiding duplicate additions.
(define (runtime-constant-registry-add-symbol! registry symbol)
  (define seen (runtime-constant-registry-seen-symbols registry))
  (unless (hash-ref seen symbol #f)
    (hash-set! seen symbol #t)
    (set-runtime-constant-registry-symbols!
     registry
     (cons (list symbol symbol)
           (runtime-constant-registry-symbols registry)))))

;; runtime-constant-registry-add-string-constants! : runtime-constant-registry? list? -> void?
;;   Add a sequence of named string constants to the registry.
(define (runtime-constant-registry-add-string-constants! registry constants)
  (for ([constant (in-list constants)])
    (runtime-constant-registry-add-string! registry
                                           (first constant)
                                           (second constant))))

;; runtime-constant-registry-add-bytes-constants! : runtime-constant-registry? list? -> void?
;;   Add a sequence of named byte-string constants to the registry.
(define (runtime-constant-registry-add-bytes-constants! registry constants)
  (for ([constant (in-list constants)])
    (runtime-constant-registry-add-bytes! registry
                                          (first constant)
                                          (second constant))))

;; runtime-constant-registry-add-symbols! : runtime-constant-registry? (listof symbol?) -> void?
;;   Add a sequence of interned-symbol constants to the registry.
(define (runtime-constant-registry-add-symbols! registry symbols)
  (for ([symbol (in-list symbols)])
    (runtime-constant-registry-add-symbol! registry symbol)))

;; make-populated-runtime-constant-registry : list? list? list? list? list? list? list? list? list? -> runtime-constant-registry?
;;   Create and populate the registry with program, primitive, reserved, and core constants.
(define (make-populated-runtime-constant-registry string-constants
                                                  bytes-constants
                                                  symbol-constants
                                                  primitive-symbols
                                                  ffi-primitive-symbols
                                                  reserved-symbols
                                                  core-string-constants
                                                  core-bytes-constants
                                                  core-symbol-constants)
  (define registry
    (make-runtime-constant-registry string-constants
                                    bytes-constants
                                    symbol-constants))
  (runtime-constant-registry-add-symbols! registry primitive-symbols)
  (runtime-constant-registry-add-symbols! registry ffi-primitive-symbols)
  (runtime-constant-registry-add-symbols! registry reserved-symbols)
  (runtime-constant-registry-add-string-constants! registry core-string-constants)
  (runtime-constant-registry-add-bytes-constants! registry core-bytes-constants)
  (runtime-constant-registry-add-symbols! registry core-symbol-constants)
  registry)

;; string-data-name : symbol? -> symbol?
;;   Return the WAT data segment name for a string constant.
(define (string-data-name name)
  (string->symbol (~a "$string-data:" name)))

;; string-global-name : symbol? -> symbol?
;;   Return the WAT global name for a string constant.
(define (string-global-name name)
  (string->symbol (~a "$string:" name)))

;; bytes-data-name : symbol? -> symbol?
;;   Return the WAT data segment name for a byte string constant.
(define (bytes-data-name name)
  (string->symbol (~a "$bytes-data:" name)))

;; bytes-global-name : symbol? -> symbol?
;;   Return the WAT global name for a byte string constant.
(define (bytes-global-name name)
  (string->symbol (~a "$bytes:" name)))

;; symbol-data-name : symbol? -> symbol?
;;   Return the WAT data segment name for a symbol constant.
(define (symbol-data-name name)
  (string->symbol (~a "$symbol-data:" name)))

;; symbol-global-name : symbol? -> symbol?
;;   Return the WAT global name for a symbol constant.
(define (symbol-global-name name)
  (string->symbol (~a "$symbol:" name)))

;; program-constant-global-names : list? list? list? -> (listof symbol?)
;;   Return the global names owned by user-program constants.
(define (program-constant-global-names string-constants
                                       bytes-constants
                                       symbol-constants)
  (append (for/list ([constant (in-list string-constants)])
            (string-global-name (first constant)))
          (for/list ([constant (in-list bytes-constants)])
            (bytes-global-name (first constant)))
          (for/list ([constant (in-list symbol-constants)])
            (symbol-global-name (first constant)))))

;; program-constant-data-names : list? list? list? -> (listof symbol?)
;;   Return the data-segment names owned by user-program constants.
(define (program-constant-data-names string-constants
                                     bytes-constants
                                     symbol-constants)
  (append (for/list ([constant (in-list string-constants)])
            (string-data-name (first constant)))
          (for/list ([constant (in-list bytes-constants)])
            (bytes-data-name (first constant)))
          (for/list ([constant (in-list symbol-constants)])
            (symbol-data-name (first constant)))))

;; constant-global-name? : any/c -> boolean?
;;   Check whether name is a generated constant global name.
(define (constant-global-name? name)
  (and (symbol? name)
       (let ([s (symbol->string name)])
         (or (string-prefix? s "$string:")
             (string-prefix? s "$bytes:")
             (string-prefix? s "$symbol:")))))

;; constant-data-name? : any/c -> boolean?
;;   Check whether name is a generated constant data-segment name.
(define (constant-data-name? name)
  (and (symbol? name)
       (let ([s (symbol->string name)])
         (or (string-prefix? s "$string-data:")
             (string-prefix? s "$bytes-data:")
             (string-prefix? s "$symbol-data:")))))

;; remove-duplicates/string : list? procedure? -> list?
;;   Remove duplicates using a string key in linear time.
(define (remove-duplicates/string xs key)
  ;; `remove-duplicates` with string=? is quadratic on large inputs because
  ;; racket/list only switches to a hash-table implementation for a few
  ;; built-in equality predicates.
  (define seen (make-hash))
  (let loop ([rest xs] [acc '()])
    (cond
      [(null? rest) (reverse acc)]
      [else
       (define v (car rest))
       (define k (key v))
       (cond
         [(hash-ref seen k #f)
          (loop (cdr rest) acc)]
         [else
          (hash-set! seen k #t)
          (loop (cdr rest) (cons v acc))])])))

;; runtime-constant-registry-normalize-symbols! : runtime-constant-registry? -> void?
;;   Remove duplicate symbol constants by generated global name.
(define (runtime-constant-registry-normalize-symbols! registry)
  (set-runtime-constant-registry-symbols!
   registry
   (remove-duplicates/string (runtime-constant-registry-symbols registry)
                             (lambda (ns)
                               (symbol->string (first ns))))))

;; runtime-constant-registry-declare-strings : runtime-constant-registry? -> list?
;;   Emit WAT data/global declarations for registered string constants.
(define (runtime-constant-registry-declare-strings registry)
  (append*
   (for/list ([ns (reverse (runtime-constant-registry-strings registry))])
     (define name (first ns))
     (define string (second ns))
     (define $string-data:name (string-data-name name))
     (define $string:name (string-global-name name))
     (list `(data ,$string-data:name ,(wasm-data (string->bytes/utf-8 string)))
           `(global ,$string:name (mut (ref eq)) ,(Imm #f))))))

;; runtime-constant-registry-initialize-strings : runtime-constant-registry? -> list?
;;   Emit WAT initialization forms for registered string constants.
(define (runtime-constant-registry-initialize-strings registry)
  (for/list ([ns (reverse (runtime-constant-registry-strings registry))])
    (define name (first ns))
    (define string (second ns))
    (define $string-data:name (string-data-name name))
    (define $string:name (string-global-name name))
    (define n (bytes-length (string->bytes/utf-8 string)))
    `(global.set ,$string:name
                 (call $i8array->string
                       (array.new_data $I8Array ,$string-data:name
                                       (i32.const 0) (i32.const ,n))))))

;; runtime-constant-registry-declare-bytes : runtime-constant-registry? -> list?
;;   Emit WAT data/global declarations for registered byte string constants.
(define (runtime-constant-registry-declare-bytes registry)
  (append*
   (for/list ([ns (reverse (runtime-constant-registry-bytes registry))])
     (define name (first ns))
     (define bytes (second ns))
     (define $bytes-data:name (bytes-data-name name))
     (define $bytes:name (bytes-global-name name))
     (list `(data ,$bytes-data:name ,(wasm-data bytes))
           `(global ,$bytes:name (mut (ref eq)) ,(Imm #f))))))

;; runtime-constant-registry-initialize-bytes : runtime-constant-registry? -> list?
;;   Emit WAT initialization forms for registered byte string constants.
(define (runtime-constant-registry-initialize-bytes registry)
  (for/list ([ns (reverse (runtime-constant-registry-bytes registry))])
    (define name (first ns))
    (define bytes (second ns))
    (define $bytes-data:name (bytes-data-name name))
    (define $bytes:name (bytes-global-name name))
    (define n (bytes-length bytes))
    `(global.set ,$bytes:name
                 (call $i8array->immutable-bytes
                       (array.new_data $I8Array ,$bytes-data:name
                                       (i32.const 0) (i32.const ,n))))))

;; runtime-constant-registry-declare-symbols! : runtime-constant-registry? -> list?
;;   Emit WAT data/global declarations for registered symbol constants.
(define (runtime-constant-registry-declare-symbols! registry)
  (runtime-constant-registry-normalize-symbols! registry)
  (append*
   (for/list ([ns (reverse (runtime-constant-registry-symbols registry))])
     (define name (first ns))
     (define symbol (second ns))
     (define string (symbol->string symbol))
     (define $symbol-data:name (symbol-data-name name))
     (define $symbol:name (symbol-global-name name))
     (list `(data ,$symbol-data:name ,string)
           `(global ,$symbol:name (mut (ref eq)) ,(Imm #f))))))

;; runtime-constant-registry-initialize-symbols! : runtime-constant-registry? -> list?
;;   Emit WAT initialization forms for registered symbol constants.
(define (runtime-constant-registry-initialize-symbols! registry)
  (runtime-constant-registry-normalize-symbols! registry)
  (for/list ([ns (reverse (runtime-constant-registry-symbols registry))])
    (define name (first ns))
    (define symbol (second ns))
    (define string (symbol->string symbol))
    (define $symbol-data:name (symbol-data-name name))
    (define $symbol:name (symbol-global-name name))
    (define n (bytes-length (string->bytes/utf-8 string)))
    `(global.set ,$symbol:name
                 (call $string->symbol
                       (call $i8array->string
                             (array.new_data $I8Array ,$symbol-data:name
                                             (i32.const 0) (i32.const ,n)))))))

;; runtime-constant-declaration-forms : runtime-constant-registry? -> (listof datum?)
;;   Emit all runtime constant data/global declaration forms in assembly order.
(define (runtime-constant-declaration-forms registry)
  (append (runtime-constant-registry-declare-strings registry)
          (runtime-constant-registry-declare-bytes registry)
          (runtime-constant-registry-declare-symbols! registry)))

;; runtime-constant-initializer-forms : runtime-constant-registry? -> (listof datum?)
;;   Emit all runtime constant initialization forms in assembly order.
(define (runtime-constant-initializer-forms registry)
  (append (runtime-constant-registry-initialize-strings registry)
          (runtime-constant-registry-initialize-bytes registry)
          (runtime-constant-registry-initialize-symbols! registry)))

(module+ test
  (require rackunit)

  ;; form-names : (listof datum?) -> (listof symbol?)
  ;;   Extract data/global names from declaration forms.
  (define (form-names forms)
    (for/list ([form (in-list forms)])
      (second form)))

  (check-equal? (string-global-name 'hello) '$string:hello)
  (check-equal? (bytes-global-name 'hello) '$bytes:hello)
  (check-equal? (symbol-global-name 'hello) '$symbol:hello)
  (check-equal? (string-data-name 'hello) '$string-data:hello)
  (check-equal? (bytes-data-name 'hello) '$bytes-data:hello)
  (check-equal? (symbol-data-name 'hello) '$symbol-data:hello)
  (check-true (constant-global-name? '$string:hello))
  (check-true (constant-global-name? '$bytes:hello))
  (check-true (constant-global-name? '$symbol:hello))
  (check-false (constant-global-name? '$not-a-constant))
  (check-true (constant-data-name? '$string-data:hello))
  (check-true (constant-data-name? '$bytes-data:hello))
  (check-true (constant-data-name? '$symbol-data:hello))
  (check-false (constant-data-name? '$string:hello))

  (check-equal?
   (program-constant-global-names '((program-string "program"))
                                  '((program-bytes #"program"))
                                  '((program-symbol program-symbol)))
   '($string:program-string
     $bytes:program-bytes
     $symbol:program-symbol))
  (check-equal?
   (program-constant-data-names '((program-string "program"))
                                '((program-bytes #"program"))
                                '((program-symbol program-symbol)))
   '($string-data:program-string
     $bytes-data:program-bytes
     $symbol-data:program-symbol))

  (let ([registry (make-runtime-constant-registry
                   '((program-string "program"))
                   '((program-bytes #"program"))
                   '())])
    (runtime-constant-registry-add-string! registry 'runtime-string "runtime")
    (runtime-constant-registry-add-bytes! registry 'runtime-bytes #"runtime")
    (check-equal?
     (form-names (runtime-constant-registry-declare-strings registry))
     '($string-data:program-string
       $string:program-string
       $string-data:runtime-string
       $string:runtime-string))
    (check-equal?
     (form-names (runtime-constant-registry-declare-bytes registry))
     '($bytes-data:program-bytes
       $bytes:program-bytes
       $bytes-data:runtime-bytes
       $bytes:runtime-bytes)))

  (let ([registry (make-runtime-constant-registry
                   '()
                   '()
                   '((foo foo)))])
    (runtime-constant-registry-add-symbol! registry 'foo)
    (runtime-constant-registry-add-symbol! registry 'bar)
    (runtime-constant-registry-add-symbol! registry 'bar)
    (check-equal?
     (form-names (runtime-constant-registry-declare-symbols! registry))
     '($symbol-data:foo
       $symbol:foo
       $symbol-data:bar
       $symbol:bar)))

  (define (sample-populated-runtime-constant-registry)
    (make-populated-runtime-constant-registry
     '((program-string "program"))
     '((program-bytes #"program"))
     '((program-symbol program-symbol))
     '(primitive)
     '(ffi)
     '(reserved primitive)
     '((core-string "core"))
     '((core-bytes #"core"))
     '(core-symbol reserved)))

  (let ([registry (sample-populated-runtime-constant-registry)])
    (check-equal?
     (form-names (runtime-constant-registry-declare-strings registry))
     '($string-data:program-string
       $string:program-string
       $string-data:core-string
       $string:core-string))
    (check-equal?
     (form-names (runtime-constant-registry-declare-bytes registry))
     '($bytes-data:program-bytes
       $bytes:program-bytes
       $bytes-data:core-bytes
       $bytes:core-bytes))
    (check-equal?
     (form-names (runtime-constant-registry-declare-symbols! registry))
     '($symbol-data:program-symbol
       $symbol:program-symbol
       $symbol-data:primitive
       $symbol:primitive
       $symbol-data:ffi
       $symbol:ffi
       $symbol-data:reserved
       $symbol:reserved
       $symbol-data:core-symbol
       $symbol:core-symbol)))

  (let ([registry (sample-populated-runtime-constant-registry)])
    (check-equal?
     (form-names (runtime-constant-declaration-forms registry))
     '($string-data:program-string
       $string:program-string
       $string-data:core-string
       $string:core-string
       $bytes-data:program-bytes
       $bytes:program-bytes
       $bytes-data:core-bytes
       $bytes:core-bytes
       $symbol-data:program-symbol
       $symbol:program-symbol
       $symbol-data:primitive
       $symbol:primitive
       $symbol-data:ffi
       $symbol:ffi
       $symbol-data:reserved
       $symbol:reserved
       $symbol-data:core-symbol
       $symbol:core-symbol)))

  (let ([registry (sample-populated-runtime-constant-registry)])
    (check-equal?
     (map car (runtime-constant-initializer-forms registry))
     '(global.set
       global.set
       global.set
       global.set
       global.set
       global.set
       global.set
       global.set
       global.set))))
