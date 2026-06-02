#lang racket/base

(require webracket/unsafe/jsxgraph)

;; Starter JSXGraph facade. Public wrapper quality should be driven by the
;; migrated examples, not by blindly copying the raw surface forever.
(provide (all-from-out webracket/unsafe/jsxgraph))
