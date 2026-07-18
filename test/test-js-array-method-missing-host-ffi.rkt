#lang webracket/base

;; Browser smoke for JavaScript Array wrapper and import host-method boundaries.

(require js/array
         (only-in webracket/unsafe/array
                  js-eval))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-equal got want label)
  (unless (equal? got want)
    (error 'check-equal label)))

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

(define (check-unavailable-message message method-name label)
  (check-true (and message
                   (string-contains/simple? message method-name)
                   (string-contains/simple? message "not available"))
              label))

(js-eval
 "globalThis.__wrArrayBoundaryFake = (missing) => {
    const arr = [3, 1, 2];
    arr[missing] = undefined;
    return arr;
  };")

(define (fake-array missing-method)
  (array-wrap
   (js-eval
    (string-append "__wrArrayBoundaryFake('"
                   missing-method
                   "')"))))

(js-eval
 "globalThis.__wrArrayBoundarySavedFrom = Array.from;
  globalThis.__wrArrayBoundarySavedFromAsync = Array.fromAsync;
  Array.from = undefined;
  Array.fromAsync = undefined;")

(define missing-from-message
  (catch-message
   (lambda ()
     (array-from #(1 2 3)))))

(define missing-from-async-message
  (catch-message
   (lambda ()
     (array-from-async #(1 2 3)))))

(js-eval
 "Array.from = globalThis.__wrArrayBoundarySavedFrom;
  if (globalThis.__wrArrayBoundarySavedFromAsync === undefined) {
    delete Array.fromAsync;
  } else {
    Array.fromAsync = globalThis.__wrArrayBoundarySavedFromAsync;
  }
  delete globalThis.__wrArrayBoundarySavedFrom;
  delete globalThis.__wrArrayBoundarySavedFromAsync;")

(define at-message
  (catch-message
   (lambda ()
     (array-at (fake-array "at") 0))))

(define slice-message
  (catch-message
   (lambda ()
     (array-slice (fake-array "slice")))))

(define copy-within-message
  (catch-message
   (lambda ()
     (array-copy-within! (fake-array "copyWithin") 0 1))))

(define fill-message
  (catch-message
   (lambda ()
     (array-fill! (fake-array "fill") 'x))))

(define sort-message
  (catch-message
   (lambda ()
     (array-sort! (fake-array "sort")))))

(define flat-message
  (catch-message
   (lambda ()
     (array-flat (fake-array "flat")))))

(define to-locale-string-message
  (catch-message
   (lambda ()
     (array-to-locale-string (fake-array "toLocaleString")))))

(define to-string-message
  (catch-message
   (lambda ()
     (array-to-string (fake-array "toString")))))

(js-eval
 "globalThis.__wrArrayBoundarySavedToSorted = Array.prototype.toSorted;
  Array.prototype.toSorted = undefined;")

(define to-sorted-fallback
  (array->vector
   (array-to-sorted
    (array-of 3 1 2))))

(js-eval
 "if (globalThis.__wrArrayBoundarySavedToSorted === undefined) {
    delete Array.prototype.toSorted;
  } else {
    Array.prototype.toSorted = globalThis.__wrArrayBoundarySavedToSorted;
  }
  delete globalThis.__wrArrayBoundarySavedToSorted;
  delete globalThis.__wrArrayBoundaryFake;")

(check-unavailable-message missing-from-message
                           "Array.from"
                           "missing Array.from message")
(check-unavailable-message missing-from-async-message
                           "Array.fromAsync"
                           "missing Array.fromAsync message")
(check-unavailable-message at-message
                           "Array.at"
                           "missing Array.at message")
(check-unavailable-message slice-message
                           "Array.slice"
                           "missing Array.slice message")
(check-unavailable-message copy-within-message
                           "Array.copyWithin"
                           "missing Array.copyWithin message")
(check-unavailable-message fill-message
                           "Array.fill"
                           "missing Array.fill message")
(check-unavailable-message sort-message
                           "Array.sort"
                           "missing Array.sort message")
(check-unavailable-message flat-message
                           "Array.flat"
                           "missing Array.flat message")
(check-unavailable-message to-locale-string-message
                           "Array.toLocaleString"
                           "missing Array.toLocaleString message")
(check-unavailable-message to-string-message
                           "Array.toString"
                           "missing Array.toString message")
(check-equal to-sorted-fallback
             #(1 2 3)
             "Array.toSorted fallback")

(js-log "js-array-method-missing-host-ffi-ok")
#t
