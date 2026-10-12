#lang racket

(provide formatter-error-closure-core-runtime-helper-names
         formatter-error-closure-core-runtime-helpers)

(require "../core-helper.rkt"
         (only-in "bytes.rkt"
                  bytes-core-runtime-helpers)
         (only-in "characters.rkt"
                  character-runtime-only-helpers)
         (only-in "equality.rkt"
                  equality-runtime-only-helpers)
         (only-in "exceptions.rkt"
                  exception-core-runtime-helpers
                  exception-contract-runtime-only-helpers
                  exception-runtime-only-helpers)
         (only-in "fasl.rkt"
                  fasl-runtime-only-helpers)
         (only-in "ffi.rkt"
                  ffi-core-runtime-helpers
                  ffi-runtime-only-helpers)
         (only-in "fixnums.rkt"
                  fixnum-core-runtime-helpers
                  fixnum-runtime-only-helpers)
         (only-in "formatting.rkt"
                  formatting-core-runtime-helpers)
         (only-in "hashes.rkt"
                  hash-core-runtime-helpers
                  hash-runtime-only-helpers)
         (only-in "immutable-hashes.rkt"
                  immutable-hash-runtime-only-helpers)
         (only-in "keywords.rkt"
                  keyword-runtime-only-helpers)
         (only-in "lists.rkt"
                  list-core-runtime-helpers)
         (only-in "locations.rkt"
                  location-runtime-only-helpers)
         (only-in "mutable-hashes.rkt"
                  mutable-hash-runtime-only-helpers)
         (only-in "numbers.rkt"
                  number-core-runtime-helpers)
         (only-in "ports.rkt"
                  port-runtime-only-helpers)
         (only-in "procedures.rkt"
                  procedure-core-runtime-helpers
                  procedure-runtime-only-helpers)
         (only-in "strings.rkt"
                  string-core-runtime-helpers)
         (only-in "structs.rkt"
                  struct-runtime-only-helpers)
         (only-in "symbols.rkt"
                  symbol-runtime-only-helpers)
         (only-in "syntax.rkt"
                  syntax-runtime-only-helpers)
         (only-in "vectors.rkt"
                  vector-core-runtime-helpers))

;; formatter-error-closure-core-runtime-helper-names : (listof symbol?)
;;   Name the dependency-clean formatter and argument-error helper closure.
(define formatter-error-closure-core-runtime-helper-names
  '($raise-expected-bytes
    $raise-byte-string-index-out-of-range
    $raise-byte-string-end-before-start
    $raise-byte-string-range-error
    $raise-bytes->string/utf-8:bad-argument
    $raise-bytes->string/utf-8
    $raise-bytes->string/utf-8:invalid-err-char
    $raise-bytes->string/utf-8:range-error
    $bytes->string/utf-8
    $bytes->string/utf-8/checked
    $bytes->string/utf-8:work
    $raise-check-char
    $raise-char-expected/who
    $equal?
    $equal?/slow
    $regexp-equal?
    $equal?/pair
    $equal?/box
    $equal?/vector
    $equal?/hash
    $equal?/struct
    $struct-equal+hash-apply
    $struct-equal+hash-hash
    $equal-always?/struct
    $equal-always?
    $equal-always?/slow
    $equal-always?/pair
    $equal-always?/box
    $equal-always?/vector
    $equal-always?/string
    $raise-argument-error/internal
    $raise-output-port-closed
    $raise-argument-error1
    $exn-ensure-message
    $exn:fail/make
    $make-exn:fail
    $ensure-exn:fail:out-of-memory-type
    $exn:fail:out-of-memory/make
    $make-exn:fail:out-of-memory
    $ensure-exn:fail:unsupported-type
    $exn:fail:unsupported/make
    $s-exp->fasl
    $raise-s-exp->fasl:unsupported-value
    $fasl:s-exp->fasl
    $fasl:write-value
    $s-exp->fasl/immediate
    $fasl:write-u32
    $fasl:write-bytes
    $fasl:write-string
    $fasl:write-symbol
    $fasl:write-keyword
    $fasl:write-f64
    $fasl-memory:read-u32
    $fasl-memory:read-bytes
    $fasl-memory:read-string
    $fasl-memory:read-symbol
    $fasl-memory:read-f64
    $fasl-memory:read-s-exp
    $fasl-memory->s-exp
    $linear-memory->value
    $linear-memory->string
    $js-log
    $copy-bytes-to-memory
    $linear-memory-range-available?
    $copy-bytes-to-callback-buffer
    $raise-not-fixnum
    $fixnum->i32
    $format/struct/custom-write
    $format/display:flonum
    $format/display:complex/radix
    $format/display:complex
    $raise-format/display:unknown-datatype
    $format/display
    $format/display:regexp
    $format/write
    $format/print
    $format/write:pair
    $format/write:mpair
    $format/write:vector
    $format/display:hash
    $format/display:struct-type-property
    $format/display:procedure
    $format/display:primitive-procedure
    $format/display:symbol
    $format/display:keyword
    $raise-format/display:pair:expected-pair
    $format/display:pair
    $format/display:mpair
    $format/display:vector
    $format/display:treelist-node-into!
    $format/display:treelist
    $format/display:boxed
    $format/display:box
    $format/display:values
    $format/display:path
    $format/display:assoc
    $format/display:syntax
    $format/display:char
    $make-hex-string
    $hash-count
    $hasheq-count
    $hasheqv-count
    $hashequal-count
    $hashalw-count
    $hash->list
    $hash->list/generic
    $splitmix32
    $eq-hash/i32
    $eqv-hash/i32
    $equal-always-hash/i32
    $equal-hash/i32
    $equal-hash/pair
    $equal-hash/mpair
    $equal-hash/box
    $equal-hash/vector
    $equal-always-hash/pair
    $equal-always-hash/box
    $equal-always-hash/vector
    $equal-always-hash/struct
    $equal-hash/struct
    $equal-hash/hash
    $equal-hash/hash-generic
    $immutable-hasheqv-bucket-ref
    $immutable-hasheq-bucket-ref
    $immutable-hamt-bucket-ref/kind
    $immutable-hamt-key-matches?/kind
    $immutable-hamt-packed-node-ref/kind
    $immutable-hamt-node-ref/kind
    $immutable-hamt-entry-matches?/kind
    $immutable-hamt-cnode-ref/kind
    $immutable-hash-bucket-ref
    $immutable-hashalw-bucket-ref
    $immutable-hasheqv-ref
    $immutable-hasheq-ref
    $immutable-hash-ref
    $immutable-hashalw-ref
    $immutable-hash-as-hasheqv
    $immutable-hasheqv-iterate-entry
    $immutable-hasheqv-iterate-next
    $string->keyword/checked
    $raise-keyword-expected
    $raise-pair-expected/who
    $raise-pair-expected
    $raise-exact-nonnegative-integer-expected/who
    $append/2
    $list-from-range/checked
    $make-initial-location
    $raise-argument-error:pair-expected1
    $raise-argument-error:pair-expected2
    $make-hasheq/who
    $make-hasheq
    $raise-hash-ref-key-not-found
    $hash-ref
    $hasheq-ref
    $hasheqv-ref
    $hashequal-ref
    $hashalw-ref
    $raise-argument-error:hasheq-expected
    $raise-argument-error:hasheqv-expected
    $raise-argument-error:hash-expected
    $raise-argument-error:hashalw-expected
    $hasheq-ref/plain
    $hasheqv-ref/plain
    $hashequal-ref/plain
    $hashalw-ref/plain
    $hasheq-ref/plain/checked
    $hasheqv-ref/plain/checked
    $hashequal-ref/plain/checked
    $hashalw-ref/plain/checked
    $raise-argument-error:mutable-hasheq-expected
    $raise-argument-error:mutable-hasheqv-expected
    $raise-argument-error:mutable-hash-expected
    $raise-argument-error:mutable-hashalw-expected
    $raise-hash-insert:table-full
    $hash-key-hash/kind
    $hash-key-matches?/kind
    $hasheq-set!/mutable/checked
    $hasheq-resize
    $maybe-resize-hasheq
    $raise-mutable-hash-iterate-bad-index
    $mutable-hash-iterate-first/who
    $mutable-hash-iterate-first
    $mutable-hash-iterate-next/who
    $mutable-hash-iterate-next
    $hasheq-iterate-first
    $hasheqv-iterate-first
    $hashequal-iterate-first
    $hashalw-iterate-first
    $hasheq-iterate-next
    $hasheqv-iterate-next
    $hashequal-iterate-next
    $hashalw-iterate-next
    $mutable-hash-iterate-key/who
    $mutable-hash-iterate-key
    $mutable-hash-iterate-value/who
    $mutable-hash-iterate-value
    $mutable-hash-iterate-pair/who
    $mutable-hash-iterate-pair
    $hasheq-iterate-key
    $hasheq-iterate-value
    $hasheq-iterate-pair
    $hasheqv-iterate-key
    $hasheqv-iterate-value
    $hasheqv-iterate-pair
    $hashequal-iterate-key
    $hashequal-iterate-value
    $hashequal-iterate-pair
    $hashalw-iterate-key
    $hashalw-iterate-value
    $hashalw-iterate-pair
    $raise-number->string-bad-input
    $raise-number->string-bad-radix
    $number->string
    $flonum->string
    $arity-i32->string
    $raise-check-port-or-false
    $struct-has-property?/i32
    $output-port-like?/i32
    $prop-output-port-target
    $current-output-port
    $open-output-bytes
    $open-output-string
    $format-get-output-bytes:port-content
    $raise-get-output-bytes:port-expected
    $raise-get-output-bytes:start-expected
    $raise-get-output-bytes:end-expected
    $raise-get-output-bytes:range
    $get-output-bytes
    $get-output-string
    $write-byte
    $procedure-arity->expected-string
    $raise-arity-mismatch/name+given
    $raise-application-not-procedure
    $procedure?
    $raise-argument-error:procedure-expected/who
    $raise-argument-error:procedure-expected
    $ensure-arity-at-least-type
    $arity-at-least/make
    $procedure-arity
    $procedure-arity/checked
    $procedure-arity-mask/checked/i32
    $raise-argument-error:primitive-procedure-expected/who
    $raise-argument-error:primitive-procedure-expected
    $raise-string-copy:string-expected
    $string-copy
    $raise-string-append:string-expected
    $string-append/2
    $raise-string-utf8-index-out-of-range
    $raise-string-utf8-end-before-start
    $raise-string-utf8-range-error
    $raise-string->bytes/utf8
    $raise-string->bytes/utf8:expected-string
    $raise-string->bytes/utf8:range-error
    $string->bytes/utf-8
    $raise-string-buffer-overflow
    $make-struct-type-descriptor/checked
    $raise-format/display:struct:expected-struct
    $format/display:struct
    $struct-type-property-lookup
    $struct-type-property-lookup-by-name
    $struct-type-property-table-copy
    $struct-type-property-merge-list!
    $struct-type-properties-normalize
    $invoke-struct
    $applicable-struct?/i32
    $checked-procedure-struct?/i32
    $struct-procedure-delegate
    $raise-symbol-expected/who
    $raise-string-expected/who
    $raise-symbol->string:bad-argument
    $symbol->string
    $raise-string->symbol:bad-argument
    $string->symbol
    $string->symbol/checked
    $ensure-syntax-type
    $raise-argument-error:syntax-expected
    $syntax?
    $syntax-unwrap
    $syntax-e
    $raise-check-fixnum/who
    $raise-check-fixnum
    $raise-immutable-vector/who
    $raise-immutable-vector
    $raise-bad-vector-ref-index/who
    $raise-bad-vector-ref-index
    $vector-set!/checked))

;; formatter-error-closure-source-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate source helper groups in monolithic runtime order.
(define formatter-error-closure-source-runtime-helpers
  (remove-duplicates
   (append bytes-core-runtime-helpers
           character-runtime-only-helpers
           equality-runtime-only-helpers
           exception-core-runtime-helpers
           exception-contract-runtime-only-helpers
           exception-runtime-only-helpers
           fasl-runtime-only-helpers
           ffi-core-runtime-helpers
           ffi-runtime-only-helpers
           fixnum-core-runtime-helpers
           fixnum-runtime-only-helpers
           formatting-core-runtime-helpers
           hash-core-runtime-helpers
           hash-runtime-only-helpers
           immutable-hash-runtime-only-helpers
           keyword-runtime-only-helpers
           list-core-runtime-helpers
           location-runtime-only-helpers
           mutable-hash-runtime-only-helpers
           number-core-runtime-helpers
           port-runtime-only-helpers
           procedure-core-runtime-helpers
           procedure-runtime-only-helpers
           string-core-runtime-helpers
           struct-runtime-only-helpers
           symbol-runtime-only-helpers
           syntax-runtime-only-helpers
           vector-core-runtime-helpers)
   eq?
   #:key core-runtime-helper-name))

;; formatter-error-closure-core-runtime-helpers : (listof core-runtime-helper?)
;;   Select formatter/error closure helpers while preserving runtime order.
(define formatter-error-closure-core-runtime-helpers
  (select-runtime-helpers formatter-error-closure-source-runtime-helpers
                          formatter-error-closure-core-runtime-helper-names))

(module+ test
  (require rackunit)

  (define selected-names
    (map core-runtime-helper-name formatter-error-closure-core-runtime-helpers))

  (check-equal? (length formatter-error-closure-core-runtime-helper-names) 286)
  (check-equal? (length (remove-duplicates
                         formatter-error-closure-core-runtime-helper-names
                         eq?))
                286)
  (check-equal? (sort selected-names symbol<?)
                (sort formatter-error-closure-core-runtime-helper-names symbol<?))
  (check-not-false (member '$raise-argument-error1 selected-names))
  (check-not-false (member '$format/display selected-names)))
