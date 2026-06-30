#lang racket

(provide make-array
         array-copy!
         array-extend)

;; make-array : datum? datum? -> datum?
;;   Return WAT that allocates a generic $Array filled with value.
(define (make-array size value)
  `(array.new $Array ,value ,size))

;; array-copy! : datum? datum? datum? datum? datum? -> datum?
;;   Return WAT that copies len elements from src into dest.
(define (array-copy! dest dest-start src src-start len)
  `(array.copy $Array $Array
               ,dest ,dest-start
               ,src  ,src-start
               ,len))

;; array-extend : symbol? datum? datum? datum? datum? -> (listof datum?)
;;   Return WAT that stores a grown copy of arr in target-local.
(define (array-extend target-local arr new-size fill old-size)
  `((local.set ,target-local ,(make-array new-size fill))
    ,(array-copy! `(local.get ,target-local) `(i32.const 0)
                  arr `(i32.const 0)
                  old-size)))
