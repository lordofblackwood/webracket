#lang racket

(provide character-general-category-global-forms
         character-general-category-global-names
         character-general-category-initializer-forms
         character-general-category-runtime-symbol-constants
         character-runtime-string-constants
         character-runtime-symbol-constants
         character-core-runtime-helpers
         character-runtime-helper-forms
         character-runtime-only-helper-names
         character-runtime-only-helpers)

(require "../core-helper.rkt"
         "../../private/immediates.rkt")

;; character-general-category-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols returned by char-general-category.
(define character-general-category-runtime-symbol-constants
  '(lu ll lt lm lo mn mc me nd nl no ps pe pi pf pd pc po sc sm sk so zs zp zl cc cf cs co cn))

;; character-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by character and grapheme-break helpers.
(define character-runtime-symbol-constants
  '(char?
    char->integer
    integer->char
    char-utf-8-length
    char=?
    char<?
    char<=?
    char>?
    char>=?
    char-ci=?
    char-ci<?
    char-ci<=?
    char-ci>?
    char-ci>=?
    char-alphabetic?
    char-lower-case?
    char-upper-case?
    char-title-case?
    char-numeric?
    char-symbolic?
    char-punctuation?
    char-graphic?
    char-blank?
    char-iso-control?
    char-extended-pictographic?
    char-whitespace?
    char-general-category
    char-grapheme-break-property
    char-upcase
    char-downcase
    char-titlecase
    char-foldcase
    char-grapheme-step
    Other
    CR
    LF
    Control
    Extend
    ZWJ
    Regional_Indicator
    Prepend
    SpacingMark
    L
    V
    T
    LV
    LVT))

;; character-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by character contract checks.
(define character-runtime-string-constants
  '((valid-unicode-scalar-value? "valid-unicode-scalar-value?")
    (grapheme-cluster-state? "grapheme-cluster-state?")))

;; character-runtime-who-global : symbol? -> symbol?
;;   Return the runtime symbol global corresponding to a Wasm function name.
(define (character-runtime-who-global name)
  (string->symbol
   (format "$symbol:~a" (substring (symbol->string name) 1))))

;; raise-char-expected-form : symbol? datum? -> datum?
;;   Build a char? contract-error call for a public character function.
(define (raise-char-expected-form who-name value-form)
  `(call $raise-char-expected/who
         (global.get ,(character-runtime-who-global who-name))
         ,value-form))

;; character-general-category-global-forms : (listof datum?)
;;   Declare the symbol table used by char-general-category.
(define character-general-category-global-forms
  '(
         ;; The function $char-general-category returns symbols from this array,
         ;; based on an index computed on the host.
         (global $char-general-category-symbols (mut (ref null $Array)) (ref.null $Array))))

;; character-general-category-global-names : (listof symbol?)
;;   Enumerate character category table globals shared by split modules.
(define character-general-category-global-names
  '($char-general-category-symbols))

;; character-general-category-initializer-forms : (listof datum?)
;;   Initialize the char-general-category result symbol table.
(define character-general-category-initializer-forms
  '(
                     (global.set $char-general-category-symbols
                                 (array.new_fixed $Array 30
                                                  (global.get $symbol:lu)
                                                  (global.get $symbol:ll)
                                                  (global.get $symbol:lt)
                                                  (global.get $symbol:lm)
                                                  (global.get $symbol:lo)
                                                  (global.get $symbol:mn)
                                                  (global.get $symbol:mc)
                                                  (global.get $symbol:me)
                                                  (global.get $symbol:nd)
                                                  (global.get $symbol:nl)
                                                  (global.get $symbol:no)
                                                  (global.get $symbol:ps)
                                                  (global.get $symbol:pe)
                                                  (global.get $symbol:pi)
                                                  (global.get $symbol:pf)
                                                  (global.get $symbol:pd)
                                                  (global.get $symbol:pc)
                                                  (global.get $symbol:po)
                                                  (global.get $symbol:sc)
                                                  (global.get $symbol:sm)
                                                  (global.get $symbol:sk)
                                                  (global.get $symbol:so)
                                                  (global.get $symbol:zs)
                                                  (global.get $symbol:zp)
                                                  (global.get $symbol:zl)
                                                  (global.get $symbol:cc)
                                                  (global.get $symbol:cf)
                                                  (global.get $symbol:cs)
                                                  (global.get $symbol:co)
                                                  (global.get $symbol:cn)))))

;; character-runtime-only-forms : (listof datum?)
;;   Enumerate character helpers used by the monolithic runtime.
(define character-runtime-only-forms
  `(
         ;;;
         ;;; 4.6 Characters
         ;;;

         ;; https://docs.racket-lang.org/reference/characters.html

         (func $raise-check-char (param $x (ref eq))
               (call $raise-char-expected/who
                     (global.get $symbol:char?)
                     (local.get $x))
               (unreachable))
         (func $raise-char-expected/who
               (param $who (ref eq))
               (param $x   (ref eq))
               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:char?)
                     (local.get $x)))
         (func $raise-invalid-codepoint
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:integer->char)
                     (global.get $string:valid-unicode-scalar-value?)
                     (local.get $bad))
               (unreachable))

         ;; 4.6.1 Characters and Scalar Values

         (func $char? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (local $i31 (ref i31))
               ; Is $v an immediate?
               (if (i32.eqz (ref.test (ref i31) (local.get $v)))
                   (then (return (global.get $false))))
               (local.set $i31 (ref.cast (ref i31) (local.get $v)))
               ; Is it a character?
               (if (result (ref eq))
                   (i32.eq (i32.and (i31.get_s (local.get $i31)) (i32.const ,char-mask))
                           (i32.const ,char-tag))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $char->integer (type $Prim1) (param $c (ref eq)) (result (ref eq))
               (local $i31   (ref i31))
               (local $c/tag i32)
               (local $cp    i32)
               ;; Check if $c is an i31
               (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                   (then (call $raise-char-expected/who
                               (global.get $symbol:char->integer)
                               (local.get $c))))
               (local.set $i31   (ref.cast (ref i31) (local.get $c)))
               (local.set $c/tag (i31.get_u (local.get $i31)))
               ;; Check character tag
               (if (i32.ne (i32.and (local.get $c/tag) (i32.const ,char-mask))
                           (i32.const ,char-tag))
                   (then (call $raise-char-expected/who
                               (global.get $symbol:char->integer)
                               (local.get $c))))

               ;; Extract codepoint and return as fixnum
               (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))
               (ref.i31 (i32.shl (local.get $cp) (i32.const 1))))

         (func $char->integer/i32 (param $c (ref eq)) (result i32)
               (local $raw i32)
               ;; Check that $c is an i31
               (if (ref.test (ref i31) (local.get $c))
                   (then
                    ;; Extract the raw bits
                    (local.set $raw (i31.get_u (ref.cast (ref i31) (local.get $c))))
                    ;; Verify the tag is 0x0F
                    (if (i32.eq (i32.and (local.get $raw) (i32.const ,char-mask)) (i32.const ,char-tag))
                        (then
                         ;; Return the codepoint: raw >> 8
                         (return (i32.shr_u (local.get $raw) (i32.const ,char-shift))))
                        (else
                         (call $raise-check-char (local.get $c)))))
                   (else
                    (call $raise-check-char (local.get $c))))
               (unreachable))

         (func $integer->char (type $Prim1)
               (param $k (ref eq))
               (result   (ref eq))

               (local $k/i32 i32)
               ;; Fail early if not a fixnum
               (if (i32.eqz (ref.test (ref i31) (local.get $k)))
                   (then (call $raise-invalid-codepoint (local.get $k)) (unreachable)))
               ;; Unpack fixnum (must have LSB = 0)
               (local.set $k/i32 (i31.get_u (ref.cast (ref i31) (local.get $k))))
               (if (i32.and (local.get $k/i32) (i32.const 1))
                   (then (call $raise-invalid-codepoint (local.get $k)) (unreachable)))
               (local.set $k/i32 (i32.shr_u (local.get $k/i32) (i32.const 1)))
               ;; Check allowed Unicode code point range:
               ;;   [0, 0xD7FF] or [0xE000, 0x10FFFF]
               (if (i32.or (i32.and (i32.ge_u (local.get $k/i32) (i32.const #xD800))
                                    (i32.le_u (local.get $k/i32) (i32.const #xDFFF)))
                           (i32.gt_u (local.get $k/i32) (i32.const #x10FFFF)))
                   (then (call $raise-invalid-codepoint (local.get $k)) (unreachable)))
               ;; TODO: Shared character object for 0 <= k < 256
               ;; (if needed, insert lookup here)
               ;; Pack as character: (k << (char-shift - 1)) | char-tag
               (ref.i31 (i32.or (i32.shl (local.get $k/i32)
                                         (i32.const ,char-shift))
                               (i32.const ,char-tag))))

         (func $char-utf-8-length (type $Prim1) (param $c (ref eq)) (result (ref eq))
               (local $i31 (ref i31))
               (local $raw i32)
               (local $cp  i32)
               (local $len i32)
               ;; Returns bytes needed to encode $c in UTF-8.
               ;; Characters are limited to U+10FFFF so result is in [1,4].
               (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                   (then (call $raise-char-expected/who
                               (global.get $symbol:char-utf-8-length)
                               (local.get $c))
                         (unreachable)))
               (local.set $i31 (ref.cast (ref i31) (local.get $c)))
               (local.set $raw (i31.get_u (local.get $i31)))
               (if (i32.ne (i32.and (local.get $raw) (i32.const ,char-mask))
                           (i32.const ,char-tag))
                   (then (call $raise-char-expected/who
                               (global.get $symbol:char-utf-8-length)
                               (local.get $c))
                         (unreachable)))
               (local.set $cp (call $char->integer/i32 (local.get $c)))
               (local.set $len
                     (if (result i32)
                         (i32.le_u (local.get $cp) (i32.const #x7F))
                         (then (i32.const 1))
                         (else (if (result i32)
                                   (i32.le_u (local.get $cp) (i32.const #x7FF))
                                   (then (i32.const 2))
                                   (else (if (result i32)
                                             (i32.le_u (local.get $cp) (i32.const #xFFFF))
                                             (then (i32.const 3))
                                             (else (i32.const 4))))))))
               (ref.i31 (i32.shl (local.get $len) (i32.const 1))))

         ;; 4.6.2 Character Comparisons

        ,@(for/list ([$cmp   (in-list '($char=?   $char<?   $char<=?   $char>?   $char>=?))]
                     [$cmp/2 (in-list '($char=?/2 $char<?/2 $char<=?/2 $char>?/2 $char>=?/2))]
                     [inst   (in-list '(#f i32.lt_u i32.le_u i32.gt_u i32.ge_u))])
            ; binary version
            `(func ,$cmp/2 (param $c1 (ref eq)) (param $c2 (ref eq)) (result (ref eq))
                   ;; Ensure both arguments are characters
                   (if (ref.eq (call $char? (local.get $c1)) (global.get $false))
                       (then ,(raise-char-expected-form $cmp '(local.get $c1))))
                   (if (ref.eq (call $char? (local.get $c2)) (global.get $false))
                       (then ,(raise-char-expected-form $cmp '(local.get $c2))))
                   ,(if inst
                        `(if (result (ref eq))
                             (,inst (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $c1)))
                                            (i32.const ,char-shift))
                                   (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $c2)))
                                            (i32.const ,char-shift)))
                             (then (global.get $true))
                             (else (global.get $false)))
                        `(return_call $eq? (local.get $c1) (local.get $c2)))))

        ,@(for/list ([$cmp   (in-list '($char=?   $char<?   $char<=?   $char>?   $char>=?))]
                     [$cmp/2 (in-list '($char=?/2 $char<?/2 $char<=?/2 $char>?/2 $char>=?/2))])
            ; variadic version
            `(func ,$cmp (type $Prim>=1) (param $c0 (ref eq)) (param $cs (ref eq)) (result (ref eq))
                   (local $node  (ref $Pair))
                   (local $ch    (ref eq))
                   ;; Validate the first argument
                   (if (ref.eq (call $char? (local.get $c0)) (global.get $false))
                       (then ,(raise-char-expected-form $cmp '(local.get $c0))))
                    (block $done
                           (loop $loop
                                 (br_if $done (ref.eq (local.get $cs) (global.get $null)))
                                 (local.set $node (ref.cast (ref $Pair) (local.get $cs)))
                                 (local.set $ch   (struct.get $Pair $a (local.get $node)))
                                 ;; Validate each subsequent argument
                                 (if (ref.eq (call $char? (local.get $ch)) (global.get $false))
                                     (then ,(raise-char-expected-form $cmp '(local.get $ch))))
                                 (if (ref.eq (call ,$cmp/2 (local.get $c0) (local.get $ch))
                                             (global.get $false))
                                     (then (return (global.get $false))))
                                 (local.set $cs (struct.get $Pair $d (local.get $node)))
                                (br $loop)))
                   (global.get $true)))

        ,@(for/list ([$cmp   (in-list '($char-ci=?   $char-ci<?   $char-ci<=?   $char-ci>?   $char-ci>=?))]
                     [$cmp/2 (in-list '($char-ci=?/2 $char-ci<?/2 $char-ci<=?/2 $char-ci>?/2 $char-ci>=?/2))]
                     [inst   (in-list '(#f i32.lt_u i32.le_u i32.gt_u i32.ge_u))])
            ; binary case-insensitive version
            `(func ,$cmp/2 (param $c1 (ref eq)) (param $c2 (ref eq)) (result (ref eq))
                   (local $cp1 i32)
                   (local $cp2 i32)
                   (local $fc1 i32)
                   (local $fc2 i32)
                   ;; Ensure both arguments are characters
                   (if (ref.eq (call $char? (local.get $c1)) (global.get $false))
                       (then ,(raise-char-expected-form $cmp '(local.get $c1))))
                   (if (ref.eq (call $char? (local.get $c2)) (global.get $false))
                       (then ,(raise-char-expected-form $cmp '(local.get $c2))))
                   ;; Extract codepoints
                   (local.set $cp1 (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $c1)))
                                             (i32.const ,char-shift)))
                   (local.set $cp2 (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $c2)))
                                             (i32.const ,char-shift)))
                   ;; Foldcase codepoints
                   (local.set $fc1 (call $char-foldcase/ucs (local.get $cp1)))
                   (local.set $fc2 (call $char-foldcase/ucs (local.get $cp2)))
                   ,(if inst
                        `(if (result (ref eq))
                             (,inst (local.get $fc1) (local.get $fc2))
                             (then (global.get $true))
                             (else (global.get $false)))
                        `(if (result (ref eq))
                             (i32.eq (local.get $fc1) (local.get $fc2))
                             (then (global.get $true))
                             (else (global.get $false))))))

        ,@(for/list ([$cmp   (in-list '($char-ci=?   $char-ci<?   $char-ci<=?   $char-ci>?   $char-ci>=?))]
                     [$cmp/2 (in-list '($char-ci=?/2 $char-ci<?/2 $char-ci<=?/2 $char-ci>?/2 $char-ci>=?/2))])
            ; variadic case-insensitive version
            `(func ,$cmp (type $Prim>=1) (param $c0 (ref eq)) (param $cs (ref eq)) (result (ref eq))
                   (local $node  (ref $Pair))
                   (local $ch    (ref eq))
                   ;; Validate the first argument
                   (if (ref.eq (call $char? (local.get $c0)) (global.get $false))
                       (then ,(raise-char-expected-form $cmp '(local.get $c0))))
                   (block $done
                          (loop $loop
                                (br_if $done (ref.eq (local.get $cs) (global.get $null)))
                                (local.set $node (ref.cast (ref $Pair) (local.get $cs)))
                                (local.set $ch   (struct.get $Pair $a (local.get $node)))
                                ;; Validate each subsequent argument
                                (if (ref.eq (call $char? (local.get $ch)) (global.get $false))
                                    (then ,(raise-char-expected-form $cmp '(local.get $ch))))
                                (if (ref.eq (call ,$cmp/2 (local.get $c0) (local.get $ch))
                                            (global.get $false))
                                    (then (return (global.get $false))))
                                (local.set $cs (struct.get $Pair $d (local.get $node)))
                                (br $loop)))
                   (global.get $true)))

        ;; 4.6.3 Classifications

        ,@(for/list ([name+imp
                      (in-list '(( $char-alphabetic?    $char-alphabetic?/ucs)
                                 ( $char-lower-case?    $char-lower-case?/ucs)
                                 ( $char-upper-case?    $char-upper-case?/ucs)
                                 ( $char-title-case?    $char-title-case?/ucs)
                                 ( $char-numeric?       $char-numeric?/ucs)
                                 ( $char-symbolic?      $char-symbolic?/ucs)
                                 ( $char-punctuation?   $char-punctuation?/ucs)
                                 ( $char-graphic?       $char-graphic?/ucs)     ))])
            (define name (car  name+imp))
            (define imp  (cadr name+imp))
            `(func ,name (type $Prim1) (param $c (ref eq)) (result (ref eq))
                   (local $i31   (ref i31))
                   (local $c/tag i32)
                   (local $cp    i32)
                   ;; Type check
                   (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                       (then ,(raise-char-expected-form name '(local.get $c))))
                   (local.set $i31   (ref.cast (ref i31) (local.get $c)))
                   (local.set $c/tag (i31.get_u (local.get $i31)))
                   ;; Decode codepoint
                   (if (i32.ne (i32.and (local.get $c/tag)
                                        (i32.const ,char-mask))
                               (i32.const ,char-tag))
                       (then ,(raise-char-expected-form name '(local.get $c))))
                   (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))
                   (if (result (ref eq))
                       (call ,imp (local.get $cp))
                       (then (global.get $true))
                       (else (global.get $false)))))

        (func $char-blank? (type $Prim1) (param $c (ref eq)) (result (ref eq))
              (local $i31   (ref i31))
              (local $c/tag i32)
              (local $cp    i32)
              ;; Type check
              (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                  (then ,(raise-char-expected-form '$char-blank? '(local.get $c))))
              (local.set $i31   (ref.cast (ref i31) (local.get $c)))
              (local.set $c/tag (i31.get_u (local.get $i31)))
              ;; Decode codepoint
              (if (i32.ne (i32.and (local.get $c/tag)
                                   (i32.const ,char-mask))
                          (i32.const ,char-tag))
                  (then ,(raise-char-expected-form '$char-blank? '(local.get $c))))
              (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))
              ;; Delegate
              (call $char-blank?/ucs (local.get $cp)))

        (func $char-blank?/ucs (param $cp i32) (result (ref eq))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\tab)))
                  (then (return (global.get $true))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\space)))
                  (then (return (global.get $true))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u00A0)))
                  (then (return (global.get $true))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u1680)))
                  (then (return (global.get $true))))
              ;; U+2000–U+200A
              (if (i32.le_u (local.get $cp) (i32.const ,(char->integer #\u200A)))
                  (then (if (i32.ge_u (local.get $cp) (i32.const ,(char->integer #\u2000)))
                            (then (return (global.get $true))))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u202F)))
                  (then (return (global.get $true))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u205F)))
                  (then (return (global.get $true))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u3000)))
                  (then (return (global.get $true))))
              (global.get $false))

        (func $char-iso-control? (type $Prim1) (param $c (ref eq)) (result (ref eq))
              (local $i31   (ref i31))
              (local $c/tag i32)
              (local $cp    i32)
              ;; Type check
              (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                  (then ,(raise-char-expected-form '$char-iso-control? '(local.get $c))))
              (local.set $i31   (ref.cast (ref i31) (local.get $c)))
              (local.set $c/tag (i31.get_u (local.get $i31)))
              ;; Decode codepoint
              (if (i32.ne (i32.and (local.get $c/tag)
                                   (i32.const ,char-mask))
                          (i32.const ,char-tag))
                  (then ,(raise-char-expected-form '$char-iso-control? '(local.get $c))))
              (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))
              (if (i32.le_u (local.get $cp) (i32.const ,(char->integer #\u001F)))
                  (then (return (global.get $true))))
              (if (i32.le_u (local.get $cp) (i32.const ,(char->integer #\u009F)))
                  (then (if (i32.ge_u (local.get $cp) (i32.const ,(char->integer #\rubout)))
                            (then (return (global.get $true))))))
              (global.get $false))

        (func $char-extended-pictographic? (type $Prim1) (param $c (ref eq)) (result (ref eq))
              (local $i31   (ref i31))
              (local $c/tag i32)
              (local $cp    i32)
              ;; Type check
              (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                  (then ,(raise-char-expected-form '$char-extended-pictographic? '(local.get $c))))
              (local.set $i31   (ref.cast (ref i31) (local.get $c)))
              (local.set $c/tag (i31.get_u (local.get $i31)))
              ;; Decode codepoint
              (if (i32.ne (i32.and (local.get $c/tag)
                                   (i32.const ,char-mask))
                          (i32.const ,char-tag))
                  (then ,(raise-char-expected-form '$char-extended-pictographic? '(local.get $c))))
              (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))
              (if (result (ref eq))
                  (call $char-extended-pictographic?/ucs (local.get $cp))
                  (then (global.get $true))
                  (else (global.get $false))))

        (func $char-whitespace? (type $Prim1) (param $c (ref eq)) (result (ref eq))
              (local $i31   (ref i31))
              (local $c/tag i32)
              (local $cp    i32)
              ;; Type check
              (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                  (then ,(raise-char-expected-form '$char-whitespace? '(local.get $c))))
              (local.set $i31   (ref.cast (ref i31) (local.get $c)))
              (local.set $c/tag (i31.get_u (local.get $i31)))
              ;; Decode codepoint
              (if (i32.ne (i32.and (local.get $c/tag)
                                   (i32.const ,char-mask))
                          (i32.const ,char-tag))
                  (then ,(raise-char-expected-form '$char-whitespace? '(local.get $c))))
              (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))
              ;; Delegate
              (call $char-whitespace?/ucs (local.get $cp)))

        (func $char-whitespace?/ucs (param $cp i32) (result (ref eq))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\space)))
                  (then (return (global.get $true))))
              ;; U+0009..000D: tab, newline, vtab, formfeed, return
              (if (i32.le_u (local.get $cp) (i32.const ,(char->integer #\return)))
                  (then (if (i32.ge_u (local.get $cp) (i32.const ,(char->integer #\tab)))
                            (then (return (global.get $true))))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u0085))) ; NEXT LINE (NEL)
                  (then (return (global.get $true))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u00A0))) ; NO-BREAK SPACE (NBSP)
                  (then (return (global.get $true))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u1680))) ; OGHAM SPACE MARK
                  (then (return (global.get $true))))
              ;; U+2000–U+200A
              (if (i32.le_u (local.get $cp) (i32.const ,(char->integer #\u200A)))
                  (then (if (i32.ge_u (local.get $cp) (i32.const ,(char->integer #\u2000)))
                            (then (return (global.get $true))))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u2028))) ; LINE SEPARATOR
                  (then (return (global.get $true))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u2029))) ; PARAGRAPH SEPARATOR
                  (then (return (global.get $true))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u202F))) ; NARROW NO-BREAK SPACE
                  (then (return (global.get $true))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u205F))) ; MEDIUM MATHEMATICAL SPACE
                  (then (return (global.get $true))))
              (if (i32.eq (local.get $cp) (i32.const ,(char->integer #\u3000))) ; IDEOGRAPHIC SPACE
                  (then (return (global.get $true))))
              (global.get $false))

        (func $char-general-category (type $Prim1)
              (param $c (ref eq))
              (result   (ref eq))

              (local $i31   (ref i31))
              (local $c/tag i32)
              (local $cp    i32)
              (local $idx   i32)

              ;; Type check
              (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                  (then ,(raise-char-expected-form '$char-general-category '(local.get $c))))
              (local.set $i31   (ref.cast (ref i31) (local.get $c)))
              (local.set $c/tag (i31.get_u (local.get $i31)))
              (if (i32.ne (i32.and (local.get $c/tag) (i32.const ,char-mask))
                          (i32.const ,char-tag))
                  (then ,(raise-char-expected-form '$char-general-category '(local.get $c))))
              (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))
              ;; Delegate to host
              (local.set $idx (call $char-general-category/ucs (local.get $cp)))
              ;; Lookup symbol
              (array.get $Array (global.get $char-general-category-symbols) (local.get $idx)))

        (func $char-grapheme-break-property (type $Prim1)
              (param $c     (ref eq))
              (result       (ref eq))

              (local $i31   (ref i31))
              (local $c/tag i32)
              (local $cp    i32)
              (local $prop  i32)
              ;; Type check
              (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                  (then ,(raise-char-expected-form '$char-grapheme-break-property '(local.get $c))
                        (unreachable)))
              (local.set $i31   (ref.cast (ref i31) (local.get $c)))
              (local.set $c/tag (i31.get_u (local.get $i31)))
              ;; Decode codepoint
              (if (i32.ne (i32.and (local.get $c/tag)
                                   (i32.const ,char-mask))
                          (i32.const ,char-tag))
                  (then ,(raise-char-expected-form '$char-grapheme-break-property '(local.get $c))
                        (unreachable)))
              (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))
              ;; Delegate to host
              (local.set $prop
                         (call $char-grapheme-break-property/ucs (local.get $cp)))
              (block $ret (result (ref eq))
                (if (i32.eq (local.get $prop) (i32.const 1))
                    (then (br $ret (global.get $symbol:CR))))
                (if (i32.eq (local.get $prop) (i32.const 2))
                    (then (br $ret (global.get $symbol:LF))))
                (if (i32.eq (local.get $prop) (i32.const 3))
                    (then (br $ret (global.get $symbol:Control))))
                (if (i32.eq (local.get $prop) (i32.const 4))
                    (then (br $ret (global.get $symbol:Extend))))
                (if (i32.eq (local.get $prop) (i32.const 5))
                    (then (br $ret (global.get $symbol:ZWJ))))
                (if (i32.eq (local.get $prop) (i32.const 6))
                    (then (br $ret (global.get $symbol:Regional_Indicator))))
                (if (i32.eq (local.get $prop) (i32.const 7))
                    (then (br $ret (global.get $symbol:Prepend))))
                (if (i32.eq (local.get $prop) (i32.const 8))
                    (then (br $ret (global.get $symbol:SpacingMark))))
                (if (i32.eq (local.get $prop) (i32.const 9))
                    (then (br $ret (global.get $symbol:L))))
                (if (i32.eq (local.get $prop) (i32.const 10))
                    (then (br $ret (global.get $symbol:V))))
                (if (i32.eq (local.get $prop) (i32.const 11))
                    (then (br $ret (global.get $symbol:T))))
                (if (i32.eq (local.get $prop) (i32.const 12))
                    (then (br $ret (global.get $symbol:LV))))
                (if (i32.eq (local.get $prop) (i32.const 13))
                    (then (br $ret (global.get $symbol:LVT))))
                (br $ret (global.get $symbol:Other))))

        ;; 4.6.4 Character Conversions

        (func $char-upcase (type $Prim1) (param $c (ref eq)) (result (ref eq))
              (local $i31   (ref i31))
              (local $c/tag i32)
              (local $cp    i32)
              (local $cp2   i32)
              ;; Type check
              (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                  (then (call $raise-char-expected/who
                              (global.get $symbol:char-upcase)
                              (local.get $c))))
              (local.set $i31   (ref.cast (ref i31) (local.get $c)))
              (local.set $c/tag (i31.get_u (local.get $i31)))
              ;; Decode codepoint
              (if (i32.ne (i32.and (local.get $c/tag)
                                   (i32.const ,char-mask))
                          (i32.const ,char-tag))
                  (then (call $raise-char-expected/who
                              (global.get $symbol:char-upcase)
                              (local.get $c))))
              (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))
              ;; Call host to compute upcase mapping
              (local.set $cp2 (call $char-upcase/ucs (local.get $cp)))
              ;; Return tagged character
              (ref.i31 (i32.or (i32.shl (local.get $cp2) (i32.const ,char-shift))
                               (i32.const ,char-tag))))

        (func $char-downcase (type $Prim1) (param $c (ref eq)) (result (ref eq))
              (local $i31   (ref i31))
              (local $c/tag i32)
              (local $cp    i32)
              (local $cp2   i32)
              ;; Type check
              (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                  (then (call $raise-char-expected/who
                              (global.get $symbol:char-downcase)
                              (local.get $c))))
              (local.set $i31   (ref.cast (ref i31) (local.get $c)))
              (local.set $c/tag (i31.get_u (local.get $i31)))
              ;; Decode codepoint
              (if (i32.ne (i32.and (local.get $c/tag)
                                   (i32.const ,char-mask))
                          (i32.const ,char-tag))
                  (then (call $raise-char-expected/who
                              (global.get $symbol:char-downcase)
                              (local.get $c))))
              (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))
              ;; Call host to compute downcase mapping
              (local.set $cp2 (call $char-downcase/ucs (local.get $cp)))
              ;; Return tagged character
              (ref.i31 (i32.or (i32.shl (local.get $cp2) (i32.const ,char-shift))
                               (i32.const ,char-tag))))

        (func $char-titlecase (type $Prim1) (param $c (ref eq)) (result (ref eq))
              (local $i31   (ref i31))
              (local $c/tag i32)
              (local $cp    i32)
              (local $cp2   i32)
              ;; Type check
              (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                  (then (call $raise-char-expected/who
                              (global.get $symbol:char-titlecase)
                              (local.get $c))))
              (local.set $i31   (ref.cast (ref i31) (local.get $c)))
              (local.set $c/tag (i31.get_u (local.get $i31)))
              ;; Decode codepoint
              (if (i32.ne (i32.and (local.get $c/tag)
                                   (i32.const ,char-mask))
                          (i32.const ,char-tag))
                  (then (call $raise-char-expected/who
                              (global.get $symbol:char-titlecase)
                              (local.get $c))))
              (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))
              ;; Call host to compute titlecase mapping
              (local.set $cp2 (call $char-titlecase/ucs (local.get $cp)))
              ;; Return tagged character
              (ref.i31 (i32.or (i32.shl (local.get $cp2) (i32.const ,char-shift))
                               (i32.const ,char-tag))))

        ;; Note: JavaScript doesn't have a unicode aware `casefold` so instead
        ;        toLower is used. This is not 100% correct.
        (func $char-foldcase (type $Prim1) (param $c (ref eq)) (result (ref eq))
              (local $i31   (ref i31))
              (local $c/tag i32)
              (local $cp    i32)
              (local $cp2   i32)
              ;; Type check
              (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                  (then (call $raise-char-expected/who
                              (global.get $symbol:char-foldcase)
                              (local.get $c))))
              (local.set $i31   (ref.cast (ref i31) (local.get $c)))
              (local.set $c/tag (i31.get_u (local.get $i31)))
              ;; Decode codepoint
              (if (i32.ne (i32.and (local.get $c/tag)
                                   (i32.const ,char-mask))
                          (i32.const ,char-tag))
                  (then (call $raise-char-expected/who
                              (global.get $symbol:char-foldcase)
                              (local.get $c))))
              (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))
              ;; Call host to compute foldcase mapping
              (local.set $cp2 (call $char-foldcase/ucs (local.get $cp)))
              ;; Return tagged character
              (ref.i31 (i32.or (i32.shl (local.get $cp2) (i32.const ,char-shift))
                               (i32.const ,char-tag))))

        ;; 4.6.5 Character Grapheme-Cluster Streaming

        (func $char-grapheme-step (type $Prim2)
              (param $c     (ref eq))
              (param $state (ref eq))
              (result       (ref eq))

              (local $c/i31         (ref i31))
              (local $c/tag         i32)
              (local $cp            i32)
              (local $state/i31     (ref i31))
              (local $state/raw     i32)
              (local $state-val     i32)
              (local $prev-last     i32)
              (local $prev-base-field i32)
              (local $prev-base     i32)
              (local $prev-ri       i32)
              (local $prev-ext      i32)
              (local $prev-zwj      i32)
              (local $curr-prop     i32)
              (local $curr-ext      i32)
              (local $boundary      i32)
              (local $consumed      i32)
              (local $prev-base/eff i32)
              (local $prev-ri/eff   i32)
              (local $prev-ext/eff  i32)
              (local $prev-zwj/eff  i32)
              (local $new-base      i32)
              (local $new-ri        i32)
              (local $new-zwj       i32)
              (local $new-ext       i32)
              (local $new-state     i32)
              (local $base-field    i32)
              (local $last-field    i32)

              ;; Validate character argument
              (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                  (then ,(raise-char-expected-form '$char-grapheme-step '(local.get $c))
                        (unreachable)))
              (local.set $c/i31 (ref.cast (ref i31) (local.get $c)))
              (local.set $c/tag (i31.get_u (local.get $c/i31)))
              (if (i32.ne (i32.and (local.get $c/tag) (i32.const ,char-mask))
                          (i32.const ,char-tag))
                  (then ,(raise-char-expected-form '$char-grapheme-step '(local.get $c))
                        (unreachable)))
              (local.set $cp (i32.shr_u (local.get $c/tag) (i32.const ,char-shift)))

              ;; Validate fixnum state
              (if (i32.eqz (ref.test (ref i31) (local.get $state)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:char-grapheme-step)
                              (global.get $string:grapheme-cluster-state?)
                              (local.get $state))
                        (unreachable)))
              (local.set $state/i31 (ref.cast (ref i31) (local.get $state)))
              (local.set $state/raw (i31.get_s (local.get $state/i31)))
              (if (i32.ne (i32.and (local.get $state/raw) (i32.const 1)) (i32.const 0))
                  (then (call $raise-argument-error1
                              (global.get $symbol:char-grapheme-step)
                              (global.get $string:grapheme-cluster-state?)
                              (local.get $state))
                        (unreachable)))
              (local.set $state-val (i32.shr_s (local.get $state/raw) (i32.const 1)))

              ;; Decode previous-state fields
              (local.set $prev-last
                         (i32.sub (i32.and (local.get $state-val) (i32.const 15))
                                  (i32.const 1)))
              (local.set $prev-base-field
                         (i32.and (i32.shr_u (local.get $state-val) (i32.const 4))
                                  (i32.const 15)))
              (local.set $prev-base (local.get $prev-base-field))
              (if (i32.eqz (local.get $prev-base-field))
                  (then (if (i32.eqz (local.get $state-val))
                            (then (local.set $prev-base (i32.const -1)))
                            (else (local.set $prev-base (i32.const 0)))))
                  (else (local.set $prev-base
                                   (i32.sub (local.get $prev-base-field) (i32.const 1)))))
              (local.set $prev-ri
                         (i32.and (i32.shr_u (local.get $state-val) (i32.const 8))
                                  (i32.const 1)))
              (local.set $prev-ext
                         (i32.and (i32.shr_u (local.get $state-val) (i32.const 9))
                                  (i32.const 1)))
              (local.set $prev-zwj
                         (i32.and (i32.shr_u (local.get $state-val) (i32.const 10))
                                  (i32.const 1)))

              ;; Classify current character
              (local.set $curr-prop
                         (call $char-grapheme-break-property/ucs (local.get $cp)))
              (local.set $curr-ext
                         (i32.and (call $char-extended-pictographic?/ucs (local.get $cp))
                                  (i32.const 1)))

              ;; Determine whether a boundary has been crossed before this char
              (if (i32.ge_s (local.get $prev-last) (i32.const 0))
                  (then (local.set $boundary (i32.const 1)))
                  (else (local.set $boundary (i32.const 0))))
              (if (i32.ge_s (local.get $prev-last) (i32.const 0))
                  (then
                   ;; Handle CR × LF specially
                   (if (i32.and (i32.eq (local.get $prev-last) (i32.const 1))
                                (i32.eq (local.get $curr-prop) (i32.const 2)))
                       (then (local.set $boundary (i32.const 0)))
                       (else
                        ;; Forced breaks around controls
                        (if (i32.or (i32.eq (local.get $prev-last) (i32.const 1))
                                    (i32.or (i32.eq (local.get $prev-last) (i32.const 2))
                                            (i32.eq (local.get $prev-last) (i32.const 3))))
                            (then (local.set $boundary (i32.const 1)))
                            (else
                             (if (i32.or (i32.eq (local.get $curr-prop) (i32.const 1))
                                         (i32.or (i32.eq (local.get $curr-prop) (i32.const 2))
                                                 (i32.eq (local.get $curr-prop) (i32.const 3))))
                                 (then (local.set $boundary (i32.const 1)))
                                 (else
                                  ;; Suppress breaks for specific combinations
                                  (if (i32.eq (local.get $prev-last) (i32.const 7))
                                      (then (local.set $boundary (i32.const 0))))
                                  (if (i32.eq (local.get $curr-prop) (i32.const 8))
                                      (then (local.set $boundary (i32.const 0))))
                                  (if (i32.or (i32.eq (local.get $curr-prop) (i32.const 4))
                                              (i32.eq (local.get $curr-prop) (i32.const 5)))
                                      (then (local.set $boundary (i32.const 0))))
                                  (if (i32.eq (local.get $prev-base) (i32.const 9))
                                      (then (if (i32.or (i32.eq (local.get $curr-prop) (i32.const 9))
                                                        (i32.or (i32.eq (local.get $curr-prop) (i32.const 10))
                                                                (i32.or (i32.eq (local.get $curr-prop) (i32.const 12))
                                                                        (i32.eq (local.get $curr-prop) (i32.const 13)))))
                                                (then (local.set $boundary (i32.const 0))))))
                                  (if (i32.or (i32.eq (local.get $prev-base) (i32.const 12))
                                              (i32.eq (local.get $prev-base) (i32.const 10)))
                                      (then (if (i32.or (i32.eq (local.get $curr-prop) (i32.const 10))
                                                        (i32.eq (local.get $curr-prop) (i32.const 11)))
                                                (then (local.set $boundary (i32.const 0))))))
                                  (if (i32.or (i32.eq (local.get $prev-base) (i32.const 13))
                                              (i32.eq (local.get $prev-base) (i32.const 11)))
                                      (then (if (i32.eq (local.get $curr-prop) (i32.const 11))
                                                (then (local.set $boundary (i32.const 0))))))
                                  (if (i32.and (i32.eq (local.get $prev-last) (i32.const 6))
                                               (i32.eq (local.get $curr-prop) (i32.const 6)))
                                      (then (if (i32.eq (local.get $prev-ri) (i32.const 1))
                                                (then (local.set $boundary (i32.const 0))))))
                                  (if (i32.and (local.get $prev-zwj) (local.get $curr-ext))
                                      (then (local.set $boundary (i32.const 0))))))))))))

              ;; Determine whether a cluster has completed
              (local.set $consumed (local.get $boundary))
              (if (i32.or (i32.eq (local.get $curr-prop) (i32.const 2))
                          (i32.eq (local.get $curr-prop) (i32.const 3)))
                  (then (local.set $consumed (i32.const 1))))

              ;; Reset effective context when a cluster completed
              (local.set $prev-base/eff (local.get $prev-base))
              (local.set $prev-ri/eff   (local.get $prev-ri))
              (local.set $prev-ext/eff  (local.get $prev-ext))
              (local.set $prev-zwj/eff  (local.get $prev-zwj))
              (if (i32.eqz (local.get $consumed))
                  (then)
                  (else (local.set $prev-base/eff (i32.const -1))
                        (local.set $prev-ri/eff   (i32.const 0))
                        (local.set $prev-ext/eff  (i32.const 0))
                        (local.set $prev-zwj/eff  (i32.const 0))))

              ;; Update contextual fields with the current character.
              ;; Controls retain their last-property field but never become
              ;; the base of the next cluster.
              (if (i32.or (i32.eq (local.get $curr-prop) (i32.const 1))
                          (i32.or (i32.eq (local.get $curr-prop) (i32.const 2))
                                  (i32.eq (local.get $curr-prop) (i32.const 3))))
                  (then (local.set $new-base (i32.const -1))
                        (local.set $new-ext  (i32.const 0)))
                  (else
                   (if (i32.or (i32.eq (local.get $curr-prop) (i32.const 4))
                               (i32.or (i32.eq (local.get $curr-prop) (i32.const 5))
                                       (i32.eq (local.get $curr-prop) (i32.const 8))))
                       (then (local.set $new-base (local.get $prev-base/eff))
                             (local.set $new-ext  (local.get $prev-ext/eff)))
                       (else (local.set $new-base (local.get $curr-prop))
                             (local.set $new-ext  (local.get $curr-ext))))))

              (if (i32.eq (local.get $curr-prop) (i32.const 6))
                  (then (if (i32.eq (local.get $prev-base/eff) (i32.const 6))
                            (then (local.set $new-ri (i32.xor (local.get $prev-ri/eff)
                                                             (i32.const 1))))
                            (else (local.set $new-ri (i32.const 1)))))
                  (else (if (i32.or (i32.eq (local.get $curr-prop) (i32.const 4))
                                    (i32.or (i32.eq (local.get $curr-prop) (i32.const 5))
                                            (i32.eq (local.get $curr-prop) (i32.const 8))))
                            (then (local.set $new-ri (local.get $prev-ri/eff)))
                            (else (local.set $new-ri (i32.const 0))))))

              (if (i32.eq (local.get $curr-prop) (i32.const 5))
                  (then (if (i32.eq (local.get $prev-ext/eff) (i32.const 1))
                            (then (local.set $new-zwj (i32.const 1)))
                            (else (local.set $new-zwj (i32.const 0)))))
                  (else (if (i32.or (i32.eq (local.get $curr-prop) (i32.const 4))
                                    (i32.eq (local.get $curr-prop) (i32.const 8)))
                            (then (local.set $new-zwj (local.get $prev-zwj/eff)))
                            (else (local.set $new-zwj (i32.const 0))))))

              ;; Assemble new state. A standalone LF/Control and a completed
              ;; CRLF cluster reset to zero. Otherwise preserve the current
              ;; control's last-property field so the next step observes its
              ;; required boundary.
              (if (i32.and (i32.or (i32.eq (local.get $curr-prop) (i32.const 2))
                                   (i32.eq (local.get $curr-prop) (i32.const 3)))
                           (i32.eqz (local.get $boundary)))
                  (then (local.set $new-state (i32.const 0)))
                  (else
                   (local.set $base-field (i32.const 0))
                   (if (i32.lt_s (local.get $new-base) (i32.const 0))
                       (then (local.set $base-field (i32.const 0)))
                       (else (if (i32.eqz (local.get $new-base))
                                 (then (local.set $base-field (i32.const 0)))
                                 (else (local.set $base-field
                                                  (i32.add (local.get $new-base) (i32.const 1)))))))
                   (local.set $last-field (i32.add (local.get $curr-prop) (i32.const 1)))
                   (local.set $new-state
                              (i32.or (local.get $last-field)
                                      (i32.or (i32.shl (local.get $base-field) (i32.const 4))
                                              (i32.or
                                               (i32.shl (i32.and (local.get $new-ri) (i32.const 1))
                                                        (i32.const 8))
                                               (i32.or
                                                (i32.shl (i32.and (local.get $new-ext) (i32.const 1))
                                                         (i32.const 9))
                                                (i32.shl (i32.and (local.get $new-zwj) (i32.const 1))
                                                         (i32.const 10)))))))))

              ;; Return two values as an array
              (array.new_fixed $Values 2
                               (if (result (ref eq)) (local.get $consumed)
                                   (then (global.get $true))
                                   (else (global.get $false)))
                               (ref.i31 (i32.shl (local.get $new-state) (i32.const 1)))))


     ))

;; character-core-runtime-helper-names : (listof symbol?)
;;   Name character helpers available in the standalone core runtime.
(define character-core-runtime-helper-names
  '($raise-char-expected/who
    $char?
    $char-lower-case?
    $char-upper-case?
    $char-title-case?
    $char-blank?/ucs
    $char-whitespace?/ucs
    $char-general-category
    $char-upcase
    $char-downcase
    $char-titlecase
    $char-foldcase
    $char-grapheme-step))

;; character-all-runtime-helpers : (listof core-runtime-helper?)
;;   Register character helpers used by the monolithic runtime.
(define character-all-runtime-helpers
  (function-forms->runtime-helpers
   'character-all-runtime-helpers
   character-runtime-only-forms))

;; character-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for character helpers.
(define character-runtime-only-helper-names
  (map core-runtime-helper-name character-all-runtime-helpers))

;; character-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate character helpers available in the standalone core runtime.
(define character-core-runtime-helpers
  (select-runtime-helpers character-all-runtime-helpers
                          character-core-runtime-helper-names))

;; character-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate character helpers that still depend on monolithic runtime globals.
(define character-runtime-only-helpers
  (remove-runtime-helpers character-all-runtime-helpers
                          character-core-runtime-helper-names))

;; character-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render character helpers in runtime assembly order.
(define (character-runtime-helper-forms helper-index)
  (for/list ([name (in-list character-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define character-helper-index
    (make-core-runtime-helper-index
     (append character-core-runtime-helpers
             character-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name character-core-runtime-helpers)
   character-core-runtime-helper-names)

  (check-equal? character-general-category-global-names
                '($char-general-category-symbols))

  (check-equal?
   (map form-name (character-runtime-helper-forms character-helper-index))
   character-runtime-only-helper-names))
