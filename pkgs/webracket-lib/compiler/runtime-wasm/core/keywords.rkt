#lang racket

(provide keyword-core-runtime-helpers
         keyword-core-runtime-helper-forms
         keyword-runtime-string-constants
         keyword-table-global-forms
         keyword-table-initializer-runtime-helper-forms
         keyword-table-initializer-runtime-only-helper-names
         keyword-runtime-helper-forms
         keyword-runtime-only-helper-names
         keyword-runtime-only-helpers)

(require "../core-helper.rkt")

;; keyword-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by keyword helpers and keyword arguments.
(define keyword-runtime-string-constants
  '((keyword?            "keyword?")
    (keyword:key         "key")
    (keyword:cache-keys? "cache-keys?")))

;; keyword-table-global-forms : (listof datum?)
;;   Declare the global keyword interning table.
(define keyword-table-global-forms
  '(
         ;; The keyword table from strings to keywords.
         ;; Used to intern keywords.
         (global $the-keyword-table (mut (ref null $SymbolTable)) (ref.null $SymbolTable))))

;; keyword-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate keyword helpers that can be emitted in core runtime.
(define keyword-core-runtime-helpers
  (list
   ;; keyword?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a keyword, 0 otherwise.
   (core-runtime-helper
    '$keyword?/i32
    "$keyword?/i32"
    (lambda ()
      `(func $keyword?/i32
             (param $v (ref eq))
             (result i32)
             (ref.test (ref $Keyword) (local.get $v)))))))

;; keyword-core-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for keyword core helpers.
(define keyword-core-runtime-helper-names
  '($keyword?/i32))

;; keyword-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given keyword helper names from a helper index.
(define (keyword-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; keyword-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render keyword core helpers in runtime assembly order.
(define (keyword-core-runtime-helper-forms helper-index)
  (keyword-helper-forms helper-index keyword-core-runtime-helper-names))

;; keyword-table-initializer-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for keyword table initializer helpers.
(define keyword-table-initializer-runtime-only-helper-names
  '($initialize-the-keyword-table))

;; keyword-table-initializer-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render keyword table initializer helpers in runtime assembly order.
(define (keyword-table-initializer-runtime-helper-forms helper-index)
  (keyword-helper-forms helper-index keyword-table-initializer-runtime-only-helper-names))

;; keyword-table-initializer-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate keyword table initializer helpers used by the monolithic runtime.
(define keyword-table-initializer-runtime-only-helpers
  (function-forms->runtime-helpers
   'keyword-table-initializer-runtime-only-helpers
   '(
     (func $initialize-the-keyword-table
           (if (ref.is_null (global.get $the-keyword-table))
               (then (global.set $the-keyword-table (call $make-symbol-table))))))))

;; keyword-runtime-only-forms : (listof datum?)
;;   Enumerate keyword helpers used by the monolithic runtime.
(define keyword-runtime-only-forms
  '(
         ;;;
         ;;; 4.9 KEYWORDS
         ;;;

         ;; https://docs.racket-lang.org/reference/keywords.html

         ;; Keywords are interned using `the-keywords-table` which maps strings (without #:)
         ;; to keywords.

         (func $keyword? (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Keyword) (local.get $v))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $string->keyword (type $Prim1)
               (param $str (ref eq))
               (result (ref eq)) ; an (ref $Keyword)
               ;; Type check: must be a string
               (if (i32.eqz (ref.test (ref $String) (local.get $str)))
                   (then (call $raise-argument-error:string-expected (local.get $str))
                         (unreachable)))
               ;; Cast and delegate
               (call $string->keyword/checked (ref.cast (ref $String) (local.get $str))))


         (func $string->keyword/checked
               (param $str (ref $String))
               (result     (ref $Keyword))

               (local $existing (ref eq))
               (local $kw       (ref $Keyword))
               ;; Look up in table
               (local.set $existing (call $symbol-table-find
                                          (ref.as_non_null (global.get $the-keyword-table))
                                          (local.get $str)))
               (if (result (ref $Keyword))
                   (ref.eq (local.get $existing) (global.get $missing))
                   (then
                    ;; Not found – allocate and intern new keyword
                    (local.set $kw (struct.new $Keyword
                                               (i32.const 0) ;; hash will be assigned later
                                               (local.get $str)))
                    (call $symbol-table-insert
                          (ref.as_non_null (global.get $the-keyword-table))
                          (local.get $str)
                          (local.get $kw))
                    (local.get $kw))
                   (else
                    (ref.cast (ref $Keyword)
                              (local.get $existing)))))

         (func $raise-argument-error:keyword-expected (unreachable))

         (func $keyword->string (type $Prim1) ; the result does not contain #:
               (param $kw (ref eq))
               (result    (ref eq)) ; an (ref $String)
               ;; Type check: must be a keyword
               (if (i32.eqz (ref.test (ref $Keyword) (local.get $kw)))
                   (then (call $raise-argument-error:keyword-expected (local.get $kw))
                         (unreachable)))
               ;; Cast and delegate
               (call $keyword->string/checked (ref.cast (ref $Keyword) (local.get $kw))))

         (func $keyword->string/checked
               (param $kw       (ref $Keyword))
               (result          (ref $String))

               (local $name     (ref $String))
               (local.set $name (struct.get $Keyword $str (local.get $kw)))

               (ref.cast (ref $String) (call $string-copy (local.get $name))))

         (func $keyword->immutable-string (type $Prim1)
               (param $kw (ref eq))
               (result    (ref eq)) ; an (ref $String)
               ;; Type check: must be a keyword
               (if (i32.eqz (ref.test (ref $Keyword) (local.get $kw)))
                   (then (call $raise-argument-error:keyword-expected (local.get $kw))
                         (unreachable)))
               ;; Cast and delegate
               (call $keyword->immutable-string/checked (ref.cast (ref $Keyword) (local.get $kw))))

         (func $keyword->immutable-string/checked
               (param $kw (ref $Keyword))
               (result    (ref $String))

               (local $name (ref $String))
               (local $src  (ref $I32Array))
               (local $dst  (ref $I32Array))
               (local $len  i32)

               (local.set $name (struct.get $Keyword $str (local.get $kw)))

               (if (result (ref $String))
                   (i32.eq (struct.get $String $immutable (local.get $name)) (i32.const 1))
                   (then (local.get $name))
                   (else
                    (local.set $src (struct.get $String $codepoints (local.get $name)))
                    (local.set $len (array.len (local.get $src)))
                    (local.set $dst (call $i32array-copy
                                              (local.get $src) (i32.const 0) (local.get $len)))
                    (struct.new $String (i32.const 0) (i32.const 1) (local.get $dst)))))

        (func $raise-keyword-expected (unreachable))

         ;; keyword<? : (ref eq) (ref eq) ... -> (ref eq)  ;; returns #t/#f
         (func $keyword<? (type $Prim>=1)
               (param $a    (ref eq))
               (param $rest (ref eq))
               (result      (ref eq))

               (local $prev-str  (ref $String))
               (local $curr-str  (ref $String))
               (local $rest-list (ref eq))
               (local $pair      (ref $Pair))
               (local $next      (ref eq))

               ;; Type check: the first argument must be a keyword
               (if (i32.eqz (ref.test (ref $Keyword) (local.get $a)))
                   (then (call $raise-expected-keyword (global.get $symbol:keyword<?) (local.get $a))
                         (unreachable)))

               ;; Extract underlying string (without "#:") and prepare to iterate over the rest
               (local.set $prev-str (struct.get $Keyword $str (ref.cast (ref $Keyword) (local.get $a))))
               (local.set $rest-list (local.get $rest))

               ;; With a single argument, the result is #t
               (if (ref.eq (local.get $rest-list) (global.get $null))
                   (then (return (global.get $true))))

               (loop $loop
                     (if (ref.eq (local.get $rest-list) (global.get $null))
                         (then (return (global.get $true))))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $rest-list)))
                         (then (call $raise-pair-expected (local.get $rest-list))
                               (unreachable)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $rest-list)))
                     (local.set $next (struct.get $Pair $a (local.get $pair)))
                     ;; Ensure each remaining argument is a keyword
                     (if (i32.eqz (ref.test (ref $Keyword) (local.get $next)))
                         (then (call $raise-expected-keyword (global.get $symbol:keyword<?) (local.get $next))
                               (unreachable)))
                     (local.set $curr-str
                                (struct.get $Keyword $str
                                            (ref.cast (ref $Keyword) (local.get $next))))
                    (if (ref.eq (call $string<?/2 (local.get $prev-str) (local.get $curr-str))
                                 (global.get $false))
                         (then (return (global.get $false))))
                     (local.set $prev-str (local.get $curr-str))
                     (local.set $rest-list (struct.get $Pair $d (local.get $pair)))
                     (br $loop))
               (unreachable))


     ))

;; keyword-public-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate public keyword helpers used by the monolithic runtime.
(define keyword-public-runtime-only-helpers
  (function-forms->runtime-helpers
   'keyword-public-runtime-only-helpers
   keyword-runtime-only-forms))

;; keyword-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate all keyword helpers used by the monolithic runtime.
(define keyword-runtime-only-helpers
  (append keyword-table-initializer-runtime-only-helpers
          keyword-public-runtime-only-helpers))

;; keyword-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for keyword helpers.
(define keyword-runtime-only-helper-names
  (map core-runtime-helper-name keyword-public-runtime-only-helpers))

;; keyword-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render keyword helpers in runtime assembly order.
(define (keyword-runtime-helper-forms helper-index)
  (keyword-helper-forms helper-index keyword-runtime-only-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define keyword-core-helper-index
    (make-core-runtime-helper-index keyword-core-runtime-helpers))

  (define keyword-helper-index
    (make-core-runtime-helper-index keyword-runtime-only-helpers))

  (check-equal?
   (map form-name (keyword-core-runtime-helper-forms keyword-core-helper-index))
   keyword-core-runtime-helper-names)

  (check-equal?
   (map form-name (keyword-table-initializer-runtime-helper-forms keyword-helper-index))
   keyword-table-initializer-runtime-only-helper-names)

  (check-equal?
   (map form-name (keyword-runtime-helper-forms keyword-helper-index))
   keyword-runtime-only-helper-names))
