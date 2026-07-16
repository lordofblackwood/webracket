#lang webracket/base

(require browser/image)

(define (all-procedures? xs)
  (cond
    [(null? xs) #t]
    [(procedure? (car xs)) (all-procedures? (cdr xs))]
    [else #f]))

(all-procedures?
 (list
 image-new
 image-alt
 image-set-alt!
 image-src
 image-set-src!
 image-width
 image-set-width!
 image-height
 image-set-height!
 image-current-src
 image-decoding
 image-set-decoding!
 image-loading
 image-set-loading!
 image-complete?
 image-cross-origin
 image-set-cross-origin!))
