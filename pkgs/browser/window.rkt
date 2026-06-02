#lang racket/base

(require webracket/unsafe/window)

;; Starter browser/window facade. Keep raw names visible during migration;
;; replace with checked public wrappers as examples move off legacy includes.
(provide (all-from-out webracket/unsafe/window))
