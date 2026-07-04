#lang racket

(provide core-runtime-bytes-constants)

(require (only-in "bytes.rkt"
                  bytes-runtime-bytes-constants)
         (only-in "filesystem.rkt"
                  filesystem-runtime-bytes-constants)
         (only-in "linklets.rkt"
                  linklet-runtime-bytes-constants)
         (only-in "paths.rkt"
                  path-runtime-bytes-constants)
         (only-in "regexps.rkt"
                  regexp-runtime-bytes-constants))

;; core-runtime-bytes-constants : (listof (list/c symbol? bytes?))
;;   Declare all domain-owned runtime byte-string constants in assembly order.
(define core-runtime-bytes-constants
  (append bytes-runtime-bytes-constants
          path-runtime-bytes-constants
          regexp-runtime-bytes-constants
          linklet-runtime-bytes-constants
          filesystem-runtime-bytes-constants))

(module+ test
  (require rackunit)

  (check-not-false (assoc 'empty core-runtime-bytes-constants)))
