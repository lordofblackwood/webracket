#lang racket

(provide entry-struct-property-global-forms
         entry-struct-property-initializer-forms)

(require (only-in "core/structs.rkt"
                  [struct-property-global-forms
                   entry-struct-property-global-forms]
                  [struct-property-initializer-forms
                   entry-struct-property-initializer-forms]))
