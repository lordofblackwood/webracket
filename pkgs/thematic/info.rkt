#lang info

(define collection "thematic")
(define deps '("base"
               "lexers-lib"
               "parsers-lib"))
(define build-deps '("racket-doc"
                     "scribble-lib"))
(define pkg-desc "Convert Bootstrap and Bootswatch themes into web-easy themes")
(define scribblings '(("scribblings/thematic.scrbl" ())))
