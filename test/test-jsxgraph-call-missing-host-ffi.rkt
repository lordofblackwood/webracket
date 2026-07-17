#lang webracket/base

;; Browser smoke for dynamic JSXGraph method-call boundary errors.

(require (only-in webracket/unsafe/jsxgraph
                  js-jsx-board-add-grid!
                  js-jsx-board-create
                  js-jsx-board-create-point
                  js-jsx-board-generate-id
                  js-jsx-board-get-bounding-box
                  js-jsx-board-remove-object!
                  js-jsx-board-select
                  js-jsx-board-update!
                  js-jsx-circle-call
                  js-jsx-circle-call/nullish
                  js-jsx-curve-call
                  js-jsx-curve-call/nullish
                  js-jsx-element-call
                  js-jsx-element-call/nullish
                  js-jsx-line-call
                  js-jsx-line-call/nullish
                  js-jsx-polygon-call
                  js-jsx-polygon-call/nullish)
         (only-in webracket/unsafe/standard
                  js-eval))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(define (string-contains/simple? haystack needle)
  (define haystack-length (string-length haystack))
  (define needle-length (string-length needle))
  (let loop ([index 0])
    (cond
      [(> (+ index needle-length) haystack-length) #f]
      [(string=? (substring haystack index (+ index needle-length)) needle) #t]
      [else (loop (add1 index))])))

(define (check-message message needle label)
  (check-true (and message
                   (string-contains/simple? message needle))
              label))

(define target
  (js-eval "({ present() { return {ok: true}; } })"))

(define args (vector))

(define board-without-create
  (js-eval "({})"))

(define board-create-message
  (catch-message
   (lambda ()
     (js-jsx-board-create board-without-create "point" args args))))

(define board-create-point-message
  (catch-message
   (lambda ()
     (js-jsx-board-create-point board-without-create args args))))

(define board-add-grid-message
  (catch-message
   (lambda ()
     (js-jsx-board-add-grid! board-without-create))))

(define board-generate-id-message
  (catch-message
   (lambda ()
     (js-jsx-board-generate-id board-without-create))))

(define board-get-bounding-box-message
  (catch-message
   (lambda ()
     (js-jsx-board-get-bounding-box board-without-create))))

(define board-select-message
  (catch-message
   (lambda ()
     (js-jsx-board-select board-without-create "p1" #t))))

(define board-update-message
  (catch-message
   (lambda ()
     (js-jsx-board-update! board-without-create))))

(define board-remove-object-message
  (catch-message
   (lambda ()
     (js-jsx-board-remove-object! board-without-create target))))

(define element-call-message
  (catch-message
   (lambda ()
     (js-jsx-element-call target "missingMethod" args))))

(define element-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-element-call/nullish target "missingMethod" args))))

(define line-call-message
  (catch-message
   (lambda ()
     (js-jsx-line-call target "missingMethod" args))))

(define line-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-line-call/nullish target "missingMethod" args))))

(define circle-call-message
  (catch-message
   (lambda ()
     (js-jsx-circle-call target "missingMethod" args))))

(define circle-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-circle-call/nullish target "missingMethod" args))))

(define curve-call-message
  (catch-message
   (lambda ()
     (js-jsx-curve-call target "missingMethod" args))))

(define curve-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-curve-call/nullish target "missingMethod" args))))

(define polygon-call-message
  (catch-message
   (lambda ()
     (js-jsx-polygon-call target "missingMethod" args))))

(define polygon-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-polygon-call/nullish target "missingMethod" args))))

(check-message board-create-message
               "JSXGraph Board.create not available in this environment"
               "missing JSXGraph Board.create message")
(check-message board-create-point-message
               "JSXGraph Board.create not available in this environment"
               "missing JSXGraph Board.create point message")
(check-message board-add-grid-message
               "JSXGraph Board.addGrid not available in this environment"
               "missing JSXGraph Board.addGrid message")
(check-message board-generate-id-message
               "JSXGraph Board.generateId not available in this environment"
               "missing JSXGraph Board.generateId message")
(check-message board-get-bounding-box-message
               "JSXGraph Board.getBoundingBox not available in this environment"
               "missing JSXGraph Board.getBoundingBox message")
(check-message board-select-message
               "JSXGraph Board.select not available in this environment"
               "missing JSXGraph Board.select message")
(check-message board-update-message
               "JSXGraph Board.update not available in this environment"
               "missing JSXGraph Board.update message")
(check-message board-remove-object-message
               "JSXGraph Board.removeObject not available in this environment"
               "missing JSXGraph Board.removeObject message")
(check-message element-call-message
               "jsx-element.call: method missingMethod not available in this environment"
               "missing jsx-element call message")
(check-message element-call/nullish-message
               "jsx-element.call/nullish: method missingMethod not available in this environment"
               "missing jsx-element call/nullish message")
(check-message line-call-message
               "jsx-line.call: method missingMethod not available in this environment"
               "missing jsx-line call message")
(check-message line-call/nullish-message
               "jsx-line.call/nullish: method missingMethod not available in this environment"
               "missing jsx-line call/nullish message")
(check-message circle-call-message
               "jsx-circle.call: method missingMethod not available in this environment"
               "missing jsx-circle call message")
(check-message circle-call/nullish-message
               "jsx-circle.call/nullish: method missingMethod not available in this environment"
               "missing jsx-circle call/nullish message")
(check-message curve-call-message
               "jsx-curve.call: method missingMethod not available in this environment"
               "missing jsx-curve call message")
(check-message curve-call/nullish-message
               "jsx-curve.call/nullish: method missingMethod not available in this environment"
               "missing jsx-curve call/nullish message")
(check-message polygon-call-message
               "jsx-polygon.call: method missingMethod not available in this environment"
               "missing jsx-polygon call message")
(check-message polygon-call/nullish-message
               "jsx-polygon.call/nullish: method missingMethod not available in this environment"
               "missing jsx-polygon call/nullish message")

(js-log "jsxgraph-call-missing-host-ffi-ok")
#t
