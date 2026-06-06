#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         racket/string
         rackunit)

(define-runtime-path repo-root "..")
(define primitives-db-path
  (build-path repo-root "pkgs" "webracket-lib" "compiler" "private" "primitives-db.rkt"))
(define runtime-wasm-path  (build-path repo-root "pkgs" "webracket-lib" "compiler" "runtime-wasm.rkt"))
(define compiler-path      (build-path repo-root "pkgs" "webracket-lib" "compiler" "compiler.rkt"))

(define primitives-db-source (file->string primitives-db-path))
(define runtime-wasm-source  (file->string runtime-wasm-path))
(define compiler-source      (file->string compiler-path))

(define optional-direct-wrapper-expectations
  '((check-list           "1 2"   "$Prim12")
    (number->string       "1 2"   "$Prim12")
    (string-join          "1 2"   "$Prim12")
    (make-bytes           "1 2"   "$Prim12")
    (make-string          "1 2"   "$Prim12")
    (make-vector          "1 2"   "$Prim12")
    (open-input-bytes     "1 2"   "$Prim12")
    (open-input-string    "1 2"   "$Prim12")
    (read-bytes           "1 2"   "$Prim12")
    (read-string          "1 2"   "$Prim12")
    (write-byte           "1 2"   "$Prim12")
    (write-char           "1 2"   "$Prim12")
    (vector-copy          "1 2 3" "$Prim13")
    (vector->values       "1 2 3" "$Prim13")
    (string-utf-8-length  "1 2 3" "$Prim13")
    (range                "1 2 3" "$Prim13")
    (hash-iterate-key     "2 3"   "$Prim23")
    (hash-iterate-value   "2 3"   "$Prim23")
    (hash-iterate-pair    "2 3"   "$Prim23")
    (hash-iterate-key+value "2 3" "$Prim23")
    (mutable-hash-iterate-key "2 3" "$Prim23")
    (mutable-hash-iterate-value "2 3" "$Prim23")
    (mutable-hash-iterate-pair "2 3" "$Prim23")
    (mutable-hash-iterate-key+value "2 3" "$Prim23")))

;; primitive-bracketed-arity : symbol? -> (or/c string? #f)
;;   Read one bracketed arity declaration from primitives-db.rkt.
(define (primitive-bracketed-arity name)
  (define pattern
    (pregexp
     (format "\\(define-primitive[[:space:]]+~a[[:space:]]+\\[([^]]+)\\]"
             (regexp-quote (symbol->string name)))))
  (define match (regexp-match pattern primitives-db-source))
  (and match (regexp-replace* #px"[[:space:]]+" (string-trim (cadr match)) " ")))

;; compiler-optionally-pads? : symbol? -> boolean?
;;   Check that the optional-argument inliner knows about the primitive.
(define (compiler-optionally-pads? name)
  (regexp-match?
   (pregexp
    (format "(?s:optional/default.*~a)"
            (regexp-quote (symbol->string name))))
   compiler-source))

;; runtime-direct-wrapper-type : symbol? -> (or/c string? #f)
;;   Read the direct `(func $name (type $Prim..))` wrapper type from runtime-wasm.rkt.
(define (runtime-direct-wrapper-type name)
  (define match
    (regexp-match
     (pregexp
      (format "\\(func[[:space:]]+\\$~a[[:space:]]+\\(type[[:space:]]+(\\$Prim[0-9]+)\\)"
              (regexp-quote (symbol->string name))))
     runtime-wasm-source))
  (and match (cadr match)))

;; runtime-generated-hash-key/value-wrapper-uses-prim12? : -> boolean?
;;   Check the generated hash-keys/hash-values wrapper group has the [1 2] type.
(define (runtime-generated-hash-key/value-wrapper-uses-prim12?)
  (regexp-match?
   #px"\\[prim[[:space:]]+'\\(\\$hash-keys[[:space:]]+\\$hash-values\\)\\].*?`\\(func[[:space:]]+,prim[[:space:]]+\\(type[[:space:]]+\\$Prim12\\)"
   runtime-wasm-source))

(test-case "hash-keys/hash-values optional primitive shapes stay consistent"
  (for ([name (in-list '(hash-keys hash-values))])
    (check-equal? (primitive-bracketed-arity name) "1 2" (symbol->string name))
    (check-true (compiler-optionally-pads? name) (symbol->string name)))
  (check-true (runtime-generated-hash-key/value-wrapper-uses-prim12?)))

(test-case "sample optional direct primitive wrappers match their arity declarations"
  (for ([row (in-list optional-direct-wrapper-expectations)])
    (define name (first row))
    (define expected-arity (second row))
    (define expected-type (third row))
    (check-equal? (primitive-bracketed-arity name)
                  expected-arity
                  (symbol->string name))
    (check-equal? (runtime-direct-wrapper-type name)
                  expected-type
                  (symbol->string name))))

(module+ main
  (void))
