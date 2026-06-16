#lang racket/base

(require rackunit
         racket/file
         racket/path
         racket/runtime-path)

(define-runtime-path here ".")
(define repo-root
  (simplify-path (build-path here 'up)))

;; runtime-source : path?
;;   Locate the runtime implementation file under test.
(define runtime-source
  (build-path repo-root
              "pkgs"
              "webracket-lib"
              "compiler"
              "runtime-wasm.rkt"))

;; source-contains? : regexp? -> boolean?
;;   Check whether the runtime source contains the expected typed primitive declaration.
(define (source-contains? rx)
  (regexp-match? rx (file->string runtime-source)))

(module+ main
  (check-true
   (source-contains? #rx"\\(func \\$procedure-reduce-arity \\(type \\$Prim24\\)")
   "procedure-reduce-arity should use the Prim24 runtime type")
  (check-true
   (source-contains? #rx"\\(func \\$procedure-reduce-arity-mask \\(type \\$Prim24\\)")
   "procedure-reduce-arity-mask should use the Prim24 runtime type"))
