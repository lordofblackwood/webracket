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
                  js-undefined?
                  js-var)
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide (except-out (all-defined-out)
                     intersection-observer-entry-info?
                     intersection-observer-entry-info-raw))

;;;
;;; IntersectionObserver wrappers
;;;

;; intersection-observer-info : external/raw -> intersection-observer-info?
;;   Wrap a browser IntersectionObserver object.
(struct intersection-observer-info (raw) #:transparent)

;; intersection-observer-entry : external/raw -> intersection-observer-entry?
;;   Wrap a browser IntersectionObserverEntry object.
(struct intersection-observer-entry-info (raw)
  #:transparent
  #:constructor-name intersection-observer-entry)

;; observer-element-raw/checked : symbol? dom-element? -> external/raw
;;   Validate and unwrap a DOM element before passing it to observer host calls.
(define (observer-element-raw/checked who element)
  (define raw (dom-element-raw element))
  (unless (shared-dom-raw-host-value? raw)
    (raise-argument-error who
                          "dom-element with non-nullish raw value"
                          element))
  raw)

;; intersection-observer-options : any/c any/c any/c -> intersection-observer-options?
;;   Wrap constructor options for IntersectionObserver.
(struct intersection-observer-options (root root-margin threshold)
  #:transparent
  #:constructor-name make-intersection-observer-options
  #:guard
  (lambda (root root-margin threshold name)
    (when (dom-element? root)
      (observer-element-raw/checked name root))
    (unless (or (eq? root #f)
                (dom-element? root)
                (intersection-observer-raw-host-value? root))
      (raise-argument-error name "(or/c #f dom-element? external?)" root))
    (unless (or (eq? root-margin #f) (string? root-margin) (symbol? root-margin))
      (raise-argument-error name "(or/c #f string? symbol?)" root-margin))
    (unless (or (eq? threshold #f)
                (real? threshold)
                (and (vector? threshold)
                     (let loop ([i 0])
                       (if (= i (vector-length threshold))
                           #t
                           (and (real? (vector-ref threshold i))
                                (loop (add1 i)))))))
      (raise-argument-error name "(or/c #f real? (vectorof real?))" threshold))
    (values root root-margin threshold)))

;; intersection-observer-supported? : -> boolean?
;;   Report whether the browser exposes IntersectionObserver.
(define (intersection-observer-supported?)
  (js-constructible? (js-var "IntersectionObserver")))

;; intersection-observer : external/raw -> intersection-observer-info?
;;   Wrap a browser IntersectionObserver object.
(define (intersection-observer raw)
  (intersection-observer-info raw))

;; intersection-observer-raw : intersection-observer-info? -> external/raw
;;   Extract the raw browser IntersectionObserver object.
(define (intersection-observer-raw value)
  (intersection-observer-info-raw value))

;; intersection-observer-entry-raw : intersection-observer-entry? -> external/raw
;;   Extract the raw browser IntersectionObserverEntry object.
(define (intersection-observer-entry-raw value)
  (intersection-observer-entry-info-raw value))

;; intersection-observer? : any/c -> boolean?
;;   Report whether v is a wrapped IntersectionObserver value.
(define (intersection-observer? v)
  (and (intersection-observer-host-value? v)
       (intersection-observer-core-methods-present? (intersection-observer-raw v))))

;; intersection-observer-host-value? : any/c -> boolean?
;;   Report whether v wraps an external IntersectionObserver-like host value.
(define (intersection-observer-host-value? v)
  (and (intersection-observer-info? v)
       (intersection-observer-supported?)
       (intersection-observer-raw-host-value? (intersection-observer-raw v))
       (js-instanceof (intersection-observer-raw v) (js-var "IntersectionObserver"))))

;; intersection-observer-host-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable IntersectionObserver method.
(define (intersection-observer-host-method-present? raw method-name)
  (and (intersection-observer-raw-host-value? raw)
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; intersection-observer-core-methods-present? : external/raw -> boolean?
;;   Report whether raw has the required IntersectionObserver methods.
(define (intersection-observer-core-methods-present? raw)
  (and (intersection-observer-host-method-present? raw "observe")
       (intersection-observer-host-method-present? raw "unobserve")
       (intersection-observer-host-method-present? raw "disconnect")))

;; intersection-observer-raw-host-value? : any/c -> boolean?
;;   Report whether raw is a non-nullish external host value.
(define (intersection-observer-raw-host-value? raw)
  (and (external? raw)
       (not (js-nullish? raw))))

;; intersection-observer-entry-host-value? : any/c -> boolean?
;;   Report whether value wraps a non-null IntersectionObserverEntry-like host value.
(define (intersection-observer-entry-host-value? value)
  (and (intersection-observer-entry-info? value)
       (intersection-observer-raw-host-value?
        (intersection-observer-entry-raw value))))

;; intersection-observer-entry-non-null-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish entry property.
(define (intersection-observer-entry-non-null-property-present? raw property-name)
  (and (intersection-observer-raw-host-value? raw)
       (not (js-nullish? (js-ref/extern raw property-name)))))

;; intersection-observer-entry-nullable-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes an entry property, allowing null values.
(define (intersection-observer-entry-nullable-property-present? raw property-name)
  (and (intersection-observer-raw-host-value? raw)
       (not (js-undefined? (js-ref/extern raw property-name)))))

;; intersection-observer-entry-core-properties-present? : external/raw -> boolean?
;;   Report whether raw has the required IntersectionObserverEntry properties.
(define (intersection-observer-entry-core-properties-present? raw)
  (and (intersection-observer-entry-non-null-property-present? raw "target")
       (intersection-observer-entry-non-null-property-present? raw "isIntersecting")
       (intersection-observer-entry-non-null-property-present? raw "intersectionRatio")
       (intersection-observer-entry-non-null-property-present? raw "boundingClientRect")
       (intersection-observer-entry-non-null-property-present? raw "intersectionRect")
       (intersection-observer-entry-nullable-property-present? raw "rootBounds")
       (intersection-observer-entry-non-null-property-present? raw "time")))

;; intersection-observer-entry? : any/c -> boolean?
;;   Report whether value is a usable wrapped IntersectionObserverEntry value.
(define (intersection-observer-entry? value)
  (and (intersection-observer-entry-host-value? value)
       (intersection-observer-entry-core-properties-present?
        (intersection-observer-entry-raw value))))

;; check-intersection-observer-host-method : symbol? intersection-observer-info? string? -> void?
;;   Ensure a required IntersectionObserver host method is available.
(define (check-intersection-observer-host-method who observer method-name)
  (unless (intersection-observer-host-method-present? (intersection-observer-raw observer)
                                                      method-name)
    (raise-arguments-error who
                           (string-append "IntersectionObserver."
                                          method-name
                                          " is not available"))))

;; check-intersection-observer-entry-property : symbol? intersection-observer-entry? string? -> void?
;;   Ensure a required IntersectionObserverEntry property is available.
(define (check-intersection-observer-entry-property who entry property-name)
  (when (js-undefined? (js-ref/extern (intersection-observer-entry-raw entry) property-name))
    (raise-arguments-error who
                           (string-append "IntersectionObserverEntry."
                                          property-name
                                          " is not available"))))

;; check-intersection-observer-entry-non-null-property : symbol? intersection-observer-entry? string? -> void?
;;   Ensure a required non-null IntersectionObserverEntry property is available.
(define (check-intersection-observer-entry-non-null-property who entry property-name)
  (when (js-nullish? (js-ref/extern (intersection-observer-entry-raw entry) property-name))
    (raise-arguments-error who
                           (string-append "IntersectionObserverEntry."
                                          property-name
                                          " is not available"))))

;; observer-threshold->raw : any/c -> any/c
;;   Convert a threshold value to a browser-friendly representation.
(define (observer-threshold->raw threshold)
  (cond
    [(eq? threshold #f) (void)]
    [(real? threshold) threshold]
    [else threshold]))

;; intersection-observer-options->raw : intersection-observer-options? -> external/raw
;;   Convert a Rackety options struct into a browser dictionary.
(define (intersection-observer-options->raw options)
  (define root (intersection-observer-options-root options))
  (define root-margin (intersection-observer-options-root-margin options))
  (define threshold (intersection-observer-options-threshold options))
  (define fields
    (append
     (if (eq? root #f)
         '()
         (list (vector "root"
                       (if (dom-element? root)
                           (observer-element-raw/checked
                            'make-intersection-observer-options
                            root)
                           root))))
     (if (eq? root-margin #f)
         '()
         (list (vector "rootMargin"
                       (if (symbol? root-margin)
                           (symbol->string root-margin)
                           root-margin))))
     (if (eq? threshold #f)
         '()
         (list (vector "threshold" (observer-threshold->raw threshold))))))
  (js-object (list->vector fields)))

;; observer-target->raw : symbol? any/c -> external/raw
;;   Normalize an observed target to a raw browser Element object.
(define (observer-target->raw who target)
  (cond
    [(dom-element? target) (observer-element-raw/checked who target)]
    [(intersection-observer-raw-host-value? target) target]
    [else
     (raise-argument-error who "(or/c dom-element? external?)" target)]))

;; observer-entries->vector : external/raw -> vector?
;;   Convert a browser entries array to a vector of wrapped entries.
(define (observer-entries->vector entries)
  (define len (js-ref entries "length"))
  (list->vector
   (let loop ([i 0])
     (if (= i len)
         '()
         (cons (intersection-observer-entry (js-index entries i))
               (loop (add1 i)))))))

;; intersection-observer-callback-cache : hash?
;;   Reuse stable external callbacks for observer handlers.
(define intersection-observer-callback-cache (make-hasheq))

;; intersection-observer-callback->external : symbol? (or/c procedure? external?) -> external?
;;   Convert an observer callback to a stable external callback.
(define (intersection-observer-callback->external who callback)
  (cond
    [(external? callback) callback]
    [(procedure? callback)
     (define cached (hash-ref intersection-observer-callback-cache callback #f))
     (cond
       [cached cached]
       [else
        (define external
          (procedure->external
           (lambda (entries raw-observer)
             (callback (observer-entries->vector entries)
                       (intersection-observer raw-observer))
             (void))))
        (hash-set! intersection-observer-callback-cache callback external)
        external])]
    [else
     (raise-argument-error who "(or/c procedure? external?)" callback)]))

;; make-intersection-observer : (or/c procedure? external?) [(or/c #f intersection-observer-options?)] -> intersection-observer-info?
;;   Create a new browser IntersectionObserver.
(define (make-intersection-observer callback [options #f])
  (unless (intersection-observer-supported?)
    (raise-arguments-error 'make-intersection-observer
                           "IntersectionObserver is not available"))
  (unless (or (eq? options #f) (intersection-observer-options? options))
    (raise-argument-error 'make-intersection-observer
                          "(or/c #f intersection-observer-options?)"
                          options))
  (intersection-observer
   (if (eq? options #f)
       (js-new (js-var "IntersectionObserver")
               (vector (intersection-observer-callback->external
                        'make-intersection-observer
                        callback)))
       (js-new (js-var "IntersectionObserver")
               (vector (intersection-observer-callback->external
                        'make-intersection-observer
                        callback)
                       (intersection-observer-options->raw options))))))

;; intersection-observer-observe! : intersection-observer-info? (or/c dom-element? external?) -> void?
;;   Start observing a target element.
(define (intersection-observer-observe! observer target)
  (unless (intersection-observer-host-value? observer)
    (raise-argument-error 'intersection-observer-observe! "intersection-observer-info?" observer))
  (check-intersection-observer-host-method 'intersection-observer-observe! observer "observe")
  (js-send/extern/nullish (intersection-observer-raw observer)
                          "observe"
                          (vector (observer-target->raw 'intersection-observer-observe! target)))
  (void))

;; intersection-observer-unobserve! : intersection-observer-info? (or/c dom-element? external?) -> void?
;;   Stop observing a target element.
(define (intersection-observer-unobserve! observer target)
  (unless (intersection-observer-host-value? observer)
    (raise-argument-error 'intersection-observer-unobserve! "intersection-observer-info?" observer))
  (check-intersection-observer-host-method 'intersection-observer-unobserve! observer "unobserve")
  (js-send/extern/nullish (intersection-observer-raw observer)
                          "unobserve"
                          (vector (observer-target->raw 'intersection-observer-unobserve! target)))
  (void))

;; intersection-observer-disconnect! : intersection-observer-info? -> void?
;;   Disconnect the observer from all targets.
(define (intersection-observer-disconnect! observer)
  (unless (intersection-observer-host-value? observer)
    (raise-argument-error 'intersection-observer-disconnect! "intersection-observer-info?" observer))
  (check-intersection-observer-host-method 'intersection-observer-disconnect! observer "disconnect")
  (js-send/extern/nullish (intersection-observer-raw observer) "disconnect" (vector))
  (void))

;; intersection-observer-entry-target : intersection-observer-entry? -> dom-element?
;;   Read the observed target element.
(define (intersection-observer-entry-target entry)
  (unless (intersection-observer-entry-host-value? entry)
    (raise-argument-error 'intersection-observer-entry-target "intersection-observer-entry?" entry))
  (check-intersection-observer-entry-non-null-property 'intersection-observer-entry-target entry "target")
  (element-wrap (js-ref/extern (intersection-observer-entry-raw entry) "target")))

;; intersection-observer-entry-is-intersecting? : intersection-observer-entry? -> boolean?
;;   Report whether the target currently intersects the root.
(define (intersection-observer-entry-is-intersecting? entry)
  (unless (intersection-observer-entry-host-value? entry)
    (raise-argument-error 'intersection-observer-entry-is-intersecting? "intersection-observer-entry?" entry))
  (check-intersection-observer-entry-non-null-property 'intersection-observer-entry-is-intersecting?
                                                       entry
                                                       "isIntersecting")
  (js-ref (intersection-observer-entry-raw entry) "isIntersecting"))

;; intersection-observer-entry-intersection-ratio : intersection-observer-entry? -> real?
;;   Read the current intersection ratio.
(define (intersection-observer-entry-intersection-ratio entry)
  (unless (intersection-observer-entry-host-value? entry)
    (raise-argument-error 'intersection-observer-entry-intersection-ratio "intersection-observer-entry?" entry))
  (check-intersection-observer-entry-non-null-property 'intersection-observer-entry-intersection-ratio
                                                       entry
                                                       "intersectionRatio")
  (js-ref (intersection-observer-entry-raw entry) "intersectionRatio"))

;; intersection-observer-entry-bounding-client-rect : intersection-observer-entry? -> dom-rect?
;;   Read the target bounding rectangle.
(define (intersection-observer-entry-bounding-client-rect entry)
  (unless (intersection-observer-entry-host-value? entry)
    (raise-argument-error 'intersection-observer-entry-bounding-client-rect "intersection-observer-entry?" entry))
  (check-intersection-observer-entry-non-null-property 'intersection-observer-entry-bounding-client-rect
                                                       entry
                                                       "boundingClientRect")
  (dom-rect-wrap (js-ref/extern (intersection-observer-entry-raw entry) "boundingClientRect")))

;; intersection-observer-entry-intersection-rect : intersection-observer-entry? -> dom-rect?
;;   Read the current intersection rectangle.
(define (intersection-observer-entry-intersection-rect entry)
  (unless (intersection-observer-entry-host-value? entry)
    (raise-argument-error 'intersection-observer-entry-intersection-rect "intersection-observer-entry?" entry))
  (check-intersection-observer-entry-non-null-property 'intersection-observer-entry-intersection-rect
                                                       entry
                                                       "intersectionRect")
  (dom-rect-wrap (js-ref/extern (intersection-observer-entry-raw entry) "intersectionRect")))

;; intersection-observer-entry-root-bounds : intersection-observer-entry? -> (or/c #f dom-rect?)
;;   Read the root bounds, if present.
(define (intersection-observer-entry-root-bounds entry)
  (unless (intersection-observer-entry-host-value? entry)
    (raise-argument-error 'intersection-observer-entry-root-bounds "intersection-observer-entry?" entry))
  (check-intersection-observer-entry-property 'intersection-observer-entry-root-bounds
                                              entry
                                              "rootBounds")
  (define raw (js-ref/extern (intersection-observer-entry-raw entry) "rootBounds"))
  (and (not (js-nullish? raw))
       (dom-rect-wrap raw)))

;; intersection-observer-entry-time : intersection-observer-entry? -> real?
;;   Read the high-resolution timestamp for the observation.
(define (intersection-observer-entry-time entry)
  (unless (intersection-observer-entry-host-value? entry)
    (raise-argument-error 'intersection-observer-entry-time "intersection-observer-entry?" entry))
  (check-intersection-observer-entry-non-null-property 'intersection-observer-entry-time entry "time")
  (js-ref (intersection-observer-entry-raw entry) "time"))
