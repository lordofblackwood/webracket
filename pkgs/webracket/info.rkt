#lang info

(define collection "webracket")
(define deps '("base"
               "math-lib"
               "webracket-lib"))
(define pkg-desc "WebRacket public language and library collection")
(define racket-launcher-libraries '("command.rkt"))
(define racket-launcher-names '("webracket"))
(define raco-commands
  '(("webracket" webracket/command "compile Racket programs to WebAssembly" #f)))
