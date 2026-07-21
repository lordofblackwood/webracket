#lang webracket/base

;; Browser smoke for JS Iterator wrapper host-method boundaries.

(require js/iterator
         (only-in webracket/unsafe/standard
                  js-eval
                  js-ref))

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

(define (check-message message needle label)
  (check-true (and message
                   (string-contains/simple? message needle))
              label))

(define (basic-iterator)
  (iterator-make
   (lambda ()
     (iterator-result "done" #t))))

(js-eval
 "globalThis.__wrIteratorBoundarySaved = globalThis.Iterator;
  globalThis.__wrIteratorBoundaryNoNext = {};
  globalThis.Iterator = undefined;")

(define no-next-iterator
  (make-iterator
   (js-eval "globalThis.__wrIteratorBoundaryNoNext")))

(define no-global-message
  (catch-message
   (lambda ()
     (iterator-from (basic-iterator)))))

(define no-global-prototype-message
  (catch-message
   (lambda ()
     (iterator-prototype))))

(js-eval
 "globalThis.Iterator = function Iterator() {};")

(define (restore-fake-iterator!)
  (js-eval "globalThis.Iterator = function Iterator() {};")
  (void))

(define no-from-message
  (catch-message
   (lambda ()
     (iterator-from (basic-iterator)))))

(define no-prototype-message
  (catch-message/restoring
   (lambda ()
     (js-eval "globalThis.Iterator.prototype = undefined;")
     (iterator-prototype))
   restore-fake-iterator!))

(define no-prototype-constructor-message
  (catch-message/restoring
   (lambda ()
     (js-eval "globalThis.Iterator.prototype = { constructor: undefined };")
     (iterator-prototype-constructor))
   restore-fake-iterator!))

(define no-next-message
  (catch-message
   (lambda ()
     (iterator-next no-next-iterator))))

(define return-result
  (iterator-return no-next-iterator "finished"))

(define dispose-message
  (catch-message
   (lambda ()
     (iterator-dispose! no-next-iterator))))

(js-eval
 "globalThis.Iterator = globalThis.__wrIteratorBoundarySaved;
  delete globalThis.__wrIteratorBoundarySaved;
  delete globalThis.__wrIteratorBoundaryNoNext;")

(js-eval
 "globalThis.__wrIteratorBoundarySavedObjectEntries =
    Object.getOwnPropertyDescriptor(Object, 'entries') || null;")

(define (hide-object-entries!)
  (js-eval
   "Object.defineProperty(Object, 'entries', {
      value: undefined,
      writable: true,
      configurable: true
    });")
  (void))

(define (restore-object-entries!)
  (js-eval
   "if (globalThis.__wrIteratorBoundarySavedObjectEntries) {
      Object.defineProperty(Object,
                            'entries',
                            globalThis.__wrIteratorBoundarySavedObjectEntries);
    } else {
      delete Object.entries;
    }
    delete globalThis.__wrIteratorBoundarySavedObjectEntries;")
  (void))

(define object-entries-message
  (catch-message/restoring
   (lambda ()
     (hide-object-entries!)
     (iterator-zip-keyed (js-eval "({a: [1]})")))
   restore-object-entries!))

(check-message no-global-message
               "Iterator is not available"
               "missing Iterator global message")
(check-message no-global-prototype-message
               "Iterator is not available"
               "missing Iterator prototype global message")
(check-message no-from-message
               "Iterator.from is not available"
               "missing Iterator.from message")
(check-message no-prototype-message
               "Iterator.prototype is not available"
               "missing Iterator.prototype message")
(check-message no-prototype-constructor-message
               "Iterator.prototype.constructor is not available"
               "missing Iterator.prototype.constructor message")
(check-message no-next-message
               "Iterator.next is not available"
               "missing Iterator.next message")
(check-equal (js-ref return-result "done") #t "iterator-return fallback done")
(check-equal (js-ref return-result "value") "finished" "iterator-return fallback value")
(check-equal dispose-message #f "iterator-dispose! ignores missing return")
(check-message object-entries-message
               "Object.entries is not available"
               "missing Object.entries message")

(js-log "js-iterator-method-missing-host-ffi-ok")
#t
