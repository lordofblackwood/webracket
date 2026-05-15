#lang racket/base

(require racket/runtime-path
         racket/system)

(define-runtime-path probe-path "probe-installed-module-deps.rkt")

(module+ main
  (define status
    (system*/exit-code
     (find-system-path 'exec-file)
     "-y"
     (path->string probe-path)
     "--goal1-compact-bounded"
     "--goal1-limit"
     "2"
     "--timeout"
     "120"
     "--memory-mb"
     "1024"))
  (exit status))
