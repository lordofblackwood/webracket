#lang webracket/base

(require browser/element
         (only-in webracket/unsafe/dom
                  js-constructible?
                  js-index
                  js-instanceof
                  js-new
                  js-object
                  js-nullish?
                  js-ref
                  js-ref/extern
                  js-send/extern/nullish
                  js-typeof
                  js-var)
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide (all-defined-out))

;;;
;;; ResizeObserver wrappers
;;;

(struct resize-observer-info (raw) #:transparent)
(struct resize-observer-entry (raw) #:transparent)

(struct resize-observer-options (box)
  #:transparent
  #:constructor-name make-resize-observer-options
  #:guard
  (lambda (box name)
    (unless (or (eq? box #f) (string? box) (symbol? box))
      (raise-argument-error name "(or/c #f string? symbol?)" box))
    (values box)))

(define (resize-observer-supported?)
  (js-constructible? (js-var "ResizeObserver")))

(define (resize-observer raw)
  (resize-observer-info raw))

(define (resize-observer-raw value)
  (resize-observer-info-raw value))

(define (resize-observer? v)
  (and (resize-observer-info? v)
       (resize-observer-supported?)
       (external? (resize-observer-raw v))
       (js-instanceof (resize-observer-raw v) (js-var "ResizeObserver"))))

;; resize-observer-host-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable ResizeObserver method.
(define (resize-observer-host-method-present? raw method-name)
  (define method (js-ref/extern raw method-name))
  (and (not (js-nullish? method))
       (string=? (js-typeof method) "function")))

;; check-resize-observer-host-method : symbol? resize-observer-info? string? -> void?
;;   Ensure a required ResizeObserver host method is available.
(define (check-resize-observer-host-method who observer method-name)
  (unless (resize-observer-host-method-present? (resize-observer-raw observer)
                                                method-name)
    (raise-arguments-error who
                           (string-append "ResizeObserver."
                                          method-name
                                          " is not available"))))

(define (resize-observer-options->raw options)
  (define box (resize-observer-options-box options))
  (js-object
   (if (eq? box #f)
       #()
       (vector (vector "box" (if (symbol? box) (symbol->string box) box))))))

(define resize-observer-callback-cache (make-hasheq))

(define (resize-entries->vector entries)
  (define len (js-ref entries "length"))
  (list->vector
   (let loop ([i 0])
     (if (= i len)
         '()
         (cons (resize-observer-entry (js-index entries i))
               (loop (add1 i)))))))

(define (resize-observer-callback->external who callback)
  (cond
    [(external? callback) callback]
    [(procedure? callback)
     (define cached (hash-ref resize-observer-callback-cache callback #f))
     (cond
       [cached cached]
       [else
        (define external
          (procedure->external
           (lambda (entries raw-observer)
             (callback (resize-entries->vector entries)
                       (resize-observer raw-observer))
             (void))))
        (hash-set! resize-observer-callback-cache callback external)
        external])]
    [else
     (raise-argument-error who "(or/c procedure? external?)" callback)]))

(define (observer-target->raw who target)
  (cond
    [(dom-element? target) (dom-element-raw target)]
    [(external? target) target]
    [else
     (raise-argument-error who "(or/c dom-element? external?)" target)]))

(define (make-resize-observer callback)
  (unless (resize-observer-supported?)
    (raise-arguments-error 'make-resize-observer
                           "ResizeObserver is not available"))
  (resize-observer
   (js-new (js-var "ResizeObserver")
           (vector (resize-observer-callback->external
                    'make-resize-observer
                    callback)))))

(define (resize-observer-observe! observer target [options #f])
  (unless (resize-observer? observer)
    (raise-argument-error 'resize-observer-observe! "resize-observer-info?" observer))
  (check-resize-observer-host-method 'resize-observer-observe! observer "observe")
  (unless (or (eq? options #f) (resize-observer-options? options))
    (raise-argument-error 'resize-observer-observe! "(or/c #f resize-observer-options?)" options))
  (define target* (observer-target->raw 'resize-observer-observe! target))
  (if (eq? options #f)
      (js-send/extern/nullish (resize-observer-raw observer) "observe" (vector target*))
      (js-send/extern/nullish (resize-observer-raw observer)
                              "observe"
                              (vector target*
                                      (resize-observer-options->raw options))))
  (void))

(define (resize-observer-unobserve! observer target)
  (unless (resize-observer? observer)
    (raise-argument-error 'resize-observer-unobserve! "resize-observer-info?" observer))
  (check-resize-observer-host-method 'resize-observer-unobserve! observer "unobserve")
  (js-send/extern/nullish (resize-observer-raw observer)
                          "unobserve"
                          (vector (observer-target->raw 'resize-observer-unobserve! target)))
  (void))

(define (resize-observer-disconnect! observer)
  (unless (resize-observer? observer)
    (raise-argument-error 'resize-observer-disconnect! "resize-observer-info?" observer))
  (check-resize-observer-host-method 'resize-observer-disconnect! observer "disconnect")
  (js-send/extern/nullish (resize-observer-raw observer) "disconnect" (vector))
  (void))

(define (resize-observer-entry-target entry)
  (unless (and (resize-observer-entry? entry)
               (external? (resize-observer-entry-raw entry)))
    (raise-argument-error 'resize-observer-entry-target "resize-observer-entry?" entry))
  (element-wrap (js-ref/extern (resize-observer-entry-raw entry) "target")))

(define (resize-observer-entry-content-rect entry)
  (unless (and (resize-observer-entry? entry)
               (external? (resize-observer-entry-raw entry)))
    (raise-argument-error 'resize-observer-entry-content-rect "resize-observer-entry?" entry))
  (dom-rect-wrap (js-ref/extern (resize-observer-entry-raw entry) "contentRect")))
