#lang racket/base

(require racket/include
         racket/list
         racket/string
         (for-syntax racket/base))

(begin-for-syntax
  (define (read-syntax/skip-first-line
           [source-name (object-name (current-input-port))]
           [in          (current-input-port)])
    (read-line in)
    (read-syntax source-name in)))

(include/reader "../../lib/libs/sxml.rkt" read-syntax/skip-first-line)

(provide sxml->html)
