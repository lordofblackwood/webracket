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

(js-eval
 "globalThis.Iterator = function Iterator() {};")

(define no-from-message
  (catch-message
   (lambda ()
     (iterator-from (basic-iterator)))))

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

(check-message no-global-message
               "Iterator is not available"
               "missing Iterator global message")
(check-message no-from-message
               "Iterator.from is not available"
               "missing Iterator.from message")
(check-message no-next-message
               "Iterator.next is not available"
               "missing Iterator.next message")
(check-equal (js-ref return-result "done") #t "iterator-return fallback done")
(check-equal (js-ref return-result "value") "finished" "iterator-return fallback value")
(check-equal dispose-message #f "iterator-dispose! ignores missing return")

(js-log "js-iterator-method-missing-host-ffi-ok")
#t
