#lang webracket/base

;; Browser smoke for JavaScript Array wrapper and import host-method boundaries.

(require js/array
         (only-in webracket/unsafe/array
                  js-array-length
                  js-eval
                  js-set-array-length!
                  js-truthy?))

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

(define (catch-message/restoring thunk restore!)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (restore!)
                     (exn-message e))])
    (thunk)
    (restore!)
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
  (unless (and message
               (string-contains/simple? message method-name)
               (string-contains/simple? message "not available"))
    (error 'check-unavailable-message
           (string-append label
                          ": "
                          (if message message "#f")))))

(define (check-message message needle label)
  (check-true (and message
                   (string-contains/simple? message needle))
              label))

(define js-null (js-eval "null"))
(define missing-length-object (js-eval "({})"))

(js-eval
 "globalThis.__wrArrayBoundary = {
    arrayDescriptor: Object.getOwnPropertyDescriptor(globalThis, 'Array') || null,
    uint8ArrayDescriptor: Object.getOwnPropertyDescriptor(globalThis, 'Uint8Array') || null,
    hideArray() {
      try {
        return delete globalThis.Array;
      } catch (_e) {
        return false;
      }
    },
    restoreArray() {
      const saved = globalThis.__wrArrayBoundary.arrayDescriptor;
      if (saved) {
        Object.defineProperty(globalThis, 'Array', saved);
      } else {
        delete globalThis.Array;
      }
    },
    makeArrayNonConstructor() {
      const fake = (() => false);
      fake.from = (_source) => [1, 2, 3];
      fake.of = (...items) => items;
      globalThis.Array = fake;
    },
    hideUint8Array() {
      try {
        return delete globalThis.Uint8Array;
      } catch (_e) {
        return false;
      }
    },
    restoreUint8Array() {
      const saved = globalThis.__wrArrayBoundary.uint8ArrayDescriptor;
      if (saved) {
        Object.defineProperty(globalThis, 'Uint8Array', saved);
      } else {
        delete globalThis.Uint8Array;
      }
    },
    makeUint8ArrayNonConstructor() {
      const fake = (() => false);
      fake.from = (_source) => ({length: 0});
      globalThis.Uint8Array = fake;
    },
    arrayStaticDescriptors: {},
    arrayPrototypeDescriptors: {},
    replaceArrayStaticWithBadResult(methodName) {
      this.arrayStaticDescriptors[methodName] =
        Object.getOwnPropertyDescriptor(Array, methodName) || null;
      Object.defineProperty(Array, methodName, {
        value: (..._args) => 42,
        writable: true,
        configurable: true
      });
    },
    restoreArrayStatic(methodName) {
      const saved = this.arrayStaticDescriptors[methodName];
      if (saved) {
        Object.defineProperty(Array, methodName, saved);
      } else {
        delete Array[methodName];
      }
      delete this.arrayStaticDescriptors[methodName];
    },
    replaceArrayPrototypeWithBadResult(methodName) {
      this.arrayPrototypeDescriptors[methodName] =
        Object.getOwnPropertyDescriptor(Array.prototype, methodName) || null;
      Object.defineProperty(Array.prototype, methodName, {
        value: function(..._args) { return 42; },
        writable: true,
        configurable: true
      });
    },
    restoreArrayPrototype(methodName) {
      const saved = this.arrayPrototypeDescriptors[methodName];
      if (saved) {
        Object.defineProperty(Array.prototype, methodName, saved);
      } else {
        delete Array.prototype[methodName];
      }
      delete this.arrayPrototypeDescriptors[methodName];
    }
  };")

(define (hide-array-global?)
  (js-truthy?
   (js-eval "globalThis.__wrArrayBoundary.hideArray()")))

(define (restore-array-global!)
  (js-eval "globalThis.__wrArrayBoundary.restoreArray();")
  (void))

(define (hide-uint8-array-global?)
  (js-truthy?
   (js-eval "globalThis.__wrArrayBoundary.hideUint8Array()")))

(define (restore-uint8-array-global!)
  (js-eval "globalThis.__wrArrayBoundary.restoreUint8Array();")
  (void))

(define (replace-array-static-with-bad-result! method-name)
  (js-eval
   (string-append
    "globalThis.__wrArrayBoundary.replaceArrayStaticWithBadResult('"
    method-name
    "');"))
  (void))

(define (restore-array-static! method-name)
  (js-eval
   (string-append
    "globalThis.__wrArrayBoundary.restoreArrayStatic('"
    method-name
    "');"))
  (void))

(define (replace-array-prototype-with-bad-result! method-name)
  (js-eval
   (string-append
    "globalThis.__wrArrayBoundary.replaceArrayPrototypeWithBadResult('"
    method-name
    "');"))
  (void))

(define (restore-array-prototype! method-name)
  (js-eval
   (string-append
    "globalThis.__wrArrayBoundary.restoreArrayPrototype('"
    method-name
    "');"))
  (void))

(define (check-hidden-array-global thunk needle label)
  (cond
    [(hide-array-global?)
     (define message
       (catch-message/restoring thunk restore-array-global!))
     (check-message message needle label)]
    [else
     (restore-array-global!)]))

(define (check-hidden-uint8-array-global thunk needle label)
  (cond
    [(hide-uint8-array-global?)
     (define message
       (catch-message/restoring thunk restore-uint8-array-global!))
     (check-message message needle label)]
    [else
     (restore-uint8-array-global!)]))

(define (bad-static-array-result-message method-name thunk)
  (catch-message/restoring
   (lambda ()
     (replace-array-static-with-bad-result! method-name)
     (thunk))
   (lambda ()
     (restore-array-static! method-name))))

(define (bad-prototype-array-result-message method-name thunk)
  (catch-message/restoring
   (lambda ()
     (replace-array-prototype-with-bad-result! method-name)
     (thunk))
   (lambda ()
     (restore-array-prototype! method-name))))

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

(define array-from-non-constructor-message
  (catch-message/restoring
   (lambda ()
     (js-eval "globalThis.__wrArrayBoundary.makeArrayNonConstructor();")
     (array-from #(1 2 3)))
   restore-array-global!))

(define array-of-non-constructor-message
  (catch-message/restoring
   (lambda ()
     (js-eval "globalThis.__wrArrayBoundary.makeArrayNonConstructor();")
     (array-of 1 2 3))
   restore-array-global!))

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

(define bytes-source-array
  (array-of 1 2 3))

(define uint8-array-from-non-constructor-message
  (catch-message/restoring
   (lambda ()
     (js-eval "globalThis.__wrArrayBoundary.makeUint8ArrayNonConstructor();")
     (array->bytes bytes-source-array))
   restore-uint8-array-global!))

(js-eval
 "globalThis.__wrArrayBoundarySavedUint8ArrayFromDescriptor =
    Object.getOwnPropertyDescriptor(Uint8Array, 'from') || null;
  Object.defineProperty(Uint8Array, 'from', {
    value: undefined,
    writable: true,
    configurable: true
  });")

(define missing-uint8-array-from-message
  (catch-message
   (lambda ()
     (array->bytes bytes-source-array))))

(js-eval
 "Array.from = globalThis.__wrArrayBoundarySavedFrom;
  if (globalThis.__wrArrayBoundarySavedFromAsync === undefined) {
    delete Array.fromAsync;
  } else {
    Array.fromAsync = globalThis.__wrArrayBoundarySavedFromAsync;
  }
  if (globalThis.__wrArrayBoundarySavedUint8ArrayFromDescriptor) {
    Object.defineProperty(Uint8Array,
                          'from',
                          globalThis.__wrArrayBoundarySavedUint8ArrayFromDescriptor);
  } else {
    delete Uint8Array.from;
  }
  delete globalThis.__wrArrayBoundarySavedFrom;
  delete globalThis.__wrArrayBoundarySavedFromAsync;
  delete globalThis.__wrArrayBoundarySavedUint8ArrayFromDescriptor;")

(define bad-from-result-message
  (bad-static-array-result-message
   "from"
   (lambda ()
     (array-from #(1 2 3)))))

(define bad-of-result-message
  (bad-static-array-result-message
   "of"
   (lambda ()
     (array-of 1 2 3))))

(define bad-vector->array-result-message
  (bad-static-array-result-message
   "of"
   (lambda ()
     (vector->array #(1 2 3)))))

(define bad-slice-result-message
  (bad-prototype-array-result-message
   "slice"
   (lambda ()
     (array-slice (array-of 1 2 3)))))

(define bad-concat-result-message
  (bad-prototype-array-result-message
   "concat"
   (lambda ()
     (array-concat (array-of 1) (array-of 2)))))

(define bad-copy-within-result-message
  (bad-prototype-array-result-message
   "copyWithin"
   (lambda ()
     (array-copy-within! (array-of 1 2 3) 0 1))))

(define bad-fill-result-message
  (bad-prototype-array-result-message
   "fill"
   (lambda ()
     (array-fill! (array-of 1 2 3) 'x))))

(define bad-reverse-result-message
  (bad-prototype-array-result-message
   "reverse"
   (lambda ()
     (array-reverse! (array-of 1 2 3)))))

(define bad-sort-result-message
  (bad-prototype-array-result-message
   "sort"
   (lambda ()
     (array-sort! (array-of 3 1 2)))))

(define bad-splice-result-message
  (bad-prototype-array-result-message
   "splice"
   (lambda ()
     (array-splice! (array-of 1 2 3) 1 1))))

(define bad-flat-result-message
  (bad-prototype-array-result-message
   "flat"
   (lambda ()
     (array-flat (array-of (array-of 1 2) (array-of 3))))))

(define bad-to-reversed-result-message
  (bad-prototype-array-result-message
   "toReversed"
   (lambda ()
     (array-to-reversed (array-of 1 2 3)))))

(define bad-to-sorted-result-message
  (bad-prototype-array-result-message
   "toSorted"
   (lambda ()
     (array-to-sorted (array-of 3 1 2)))))

(define bad-to-spliced-result-message
  (bad-prototype-array-result-message
   "toSpliced"
   (lambda ()
     (array-to-spliced (array-of 1 2 3) 1 1))))

(define bad-with-result-message
  (bad-prototype-array-result-message
   "with"
   (lambda ()
     (array-with (array-of 1 2 3) 1 'x))))

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

(define length-null-message
  (catch-message
   (lambda ()
     (js-array-length js-null))))

(define set-length-null-message
  (catch-message
   (lambda ()
     (js-set-array-length! js-null 0))))

(define length-missing-message
  (catch-message
   (lambda ()
     (js-array-length missing-length-object))))

(define set-length-missing-message
  (catch-message
   (lambda ()
     (js-set-array-length! missing-length-object 0))))

(define null-array (array-wrap js-null))

(define to-reversed-null-message
  (catch-message
   (lambda ()
     (array-to-reversed null-array))))

(define to-sorted-null-message
  (catch-message
   (lambda ()
     (array-to-sorted null-array))))

(define to-spliced-null-message
  (catch-message
   (lambda ()
     (array-to-spliced null-array 0 0))))

(define with-null-message
  (catch-message
   (lambda ()
     (array-with null-array 0 'x))))

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
(check-unavailable-message missing-uint8-array-from-message
                           "Uint8Array.from"
                           "missing Uint8Array.from message")
(check-message array-from-non-constructor-message
               "Array is not available"
               "non-constructible Array.from message")
(check-message array-of-non-constructor-message
               "Array.of not available in this environment"
               "non-constructible Array.of message")
(check-message uint8-array-from-non-constructor-message
               "Uint8Array.from not available in this environment"
               "non-constructible Uint8Array.from message")
(check-message bad-from-result-message
               "Array.from result must be an Array"
               "bad Array.from result message")
(check-message bad-of-result-message
               "Array.of result must be an Array"
               "bad Array.of result message")
(check-message bad-vector->array-result-message
               "Array.of result must be an Array"
               "bad vector->array result message")
(check-message bad-slice-result-message
               "Array.slice result must be an Array"
               "bad Array.slice result message")
(check-message bad-concat-result-message
               "Array.concat result must be an Array"
               "bad Array.concat result message")
(check-message bad-copy-within-result-message
               "Array.copyWithin result must be an Array"
               "bad Array.copyWithin result message")
(check-message bad-fill-result-message
               "Array.fill result must be an Array"
               "bad Array.fill result message")
(check-message bad-reverse-result-message
               "Array.reverse result must be an Array"
               "bad Array.reverse result message")
(check-message bad-sort-result-message
               "Array.sort result must be an Array"
               "bad Array.sort result message")
(check-message bad-splice-result-message
               "Array.splice result must be an Array"
               "bad Array.splice result message")
(check-message bad-flat-result-message
               "Array.flat result must be an Array"
               "bad Array.flat result message")
(check-message bad-to-reversed-result-message
               "Array.toReversed result must be an Array"
               "bad Array.toReversed result message")
(check-message bad-to-sorted-result-message
               "Array.toSorted result must be an Array"
               "bad Array.toSorted result message")
(check-message bad-to-spliced-result-message
               "Array.toSpliced result must be an Array"
               "bad Array.toSpliced result message")
(check-message bad-with-result-message
               "Array.with result must be an Array"
               "bad Array.with result message")
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
(check-message length-null-message
               "Array.length: target object is null or undefined"
               "null Array.length message")
(check-message set-length-null-message
               "Array.length: target object is null or undefined"
               "null Array.length setter message")
(check-message length-missing-message
               "Array.length not available in this environment"
               "missing Array.length message")
(check-message set-length-missing-message
               "Array.length not available in this environment"
               "missing Array.length setter message")
(check-message to-reversed-null-message
               "Array.toReversed: target object is null or undefined"
               "null Array.toReversed message")
(check-message to-sorted-null-message
               "Array.toSorted: target object is null or undefined"
               "null Array.toSorted message")
(check-message to-spliced-null-message
               "Array.toSpliced: target object is null or undefined"
               "null Array.toSpliced message")
(check-message with-null-message
               "Array.with: target object is null or undefined"
               "null Array.with message")
(check-hidden-array-global
 (lambda () (array-of 1 2 3))
 "Array.of not available in this environment"
 "missing Array global Array.of message")
(check-hidden-uint8-array-global
 (lambda () (array->bytes bytes-source-array))
 "Uint8Array.from not available in this environment"
 "missing Uint8Array global Uint8Array.from message")
(check-equal to-sorted-fallback
             #(1 2 3)
             "Array.toSorted fallback")

(js-eval
 "globalThis.__wrArrayBoundary.restoreArray();
  globalThis.__wrArrayBoundary.restoreUint8Array();
  delete globalThis.__wrArrayBoundary;")

(js-log "js-array-method-missing-host-ffi-ok")
#t
