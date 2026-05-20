#lang racket/base

(require racket/runtime-path)

;; Keep the repository root as an executable entrypoint, not a collection root.
;; The checkout-local launcher exposes `pkgs/` while loading the real CLI.
(define-runtime-path package-parent "pkgs")

(parameterize ([current-library-collection-paths
                (cons package-parent (current-library-collection-paths))])
  (dynamic-require "pkgs/webracket-lib/compiler/cli.rkt" #f))
