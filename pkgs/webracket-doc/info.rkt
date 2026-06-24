#lang info

(define collection "webracket-doc")
(define deps '("base"
               "scribble-lib"
               "scribble-tools"
               "webracket"
               "webracket-lib"))
(define build-deps '())
(define pkg-desc "WebRacket documentation")
(define scribblings '(("scribblings/webracket.scrbl" (multi-page) (language))))
