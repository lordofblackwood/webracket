#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         rackunit)

(define-runtime-path repo-root "..")
(define primitives-db-path (build-path repo-root "primitives-db.rkt"))
(define runtime-wasm-path  (build-path repo-root "runtime-wasm.rkt"))
(define compiler-path      (build-path repo-root "compiler.rkt"))

(define primitives-db-source (file->string primitives-db-path))
(define runtime-wasm-source  (file->string runtime-wasm-path))
(define compiler-source      (file->string compiler-path))

;; primitive-optional-arity : symbol? -> (or/c (list/c string? string?) #f)
;;   Read one optional arity declaration from primitives-db.rkt.
(define (primitive-optional-arity name)
  (define pattern
    (pregexp
     (format "\\(define-primitive[[:space:]]+~a[[:space:]]+\\[([0-9]+)[[:space:]]+([0-9]+)\\]"
             (regexp-quote (symbol->string name)))))
  (define match (regexp-match pattern primitives-db-source))
  (and match (list (cadr match) (caddr match))))

;; compiler-optionally-pads? : symbol? -> boolean?
;;   Check that the optional-argument inliner knows about the primitive.
(define (compiler-optionally-pads? name)
  (regexp-match?
   (pregexp
    (format "(?s:optional/default.*~a)"
            (regexp-quote (symbol->string name))))
   compiler-source))

;; runtime-generated-hash-key/value-wrapper-uses-prim12? : -> boolean?
;;   Check the generated hash-keys/hash-values wrapper group has the [1 2] type.
(define (runtime-generated-hash-key/value-wrapper-uses-prim12?)
  (regexp-match?
   #px"\\[prim[[:space:]]+'\\(\\$hash-keys[[:space:]]+\\$hash-values\\)\\].*?`\\(func[[:space:]]+,prim[[:space:]]+\\(type[[:space:]]+\\$Prim12\\)"
   runtime-wasm-source))

(test-case "hash-keys/hash-values optional primitive shapes stay consistent"
  (for ([name (in-list '(hash-keys hash-values))])
    (check-equal? (primitive-optional-arity name) '("1" "2") (symbol->string name))
    (check-true (compiler-optionally-pads? name) (symbol->string name)))
  (check-true (runtime-generated-hash-key/value-wrapper-uses-prim12?)))

(module+ main
  (void))
