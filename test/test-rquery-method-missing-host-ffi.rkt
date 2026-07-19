#lang webracket/base

;; Browser smoke for RQuery host-boundary errors.

(require rquery
         (only-in browser/element
                  element-wrap)
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

(js-eval
 "globalThis.__wrRQueryBoundarySavedEvent = globalThis.Event;
  globalThis.__wrRQueryBoundaryInstallEventMissing = () => {
    globalThis.Event = undefined;
  };
  globalThis.__wrRQueryBoundaryInstallEventNonConstructor = () => {
    globalThis.Event = () => {};
  };
  globalThis.__wrRQueryBoundaryInstallDispatchMissing = () => {
    const target = document.createElement('button');
    target.dispatchEvent = undefined;
    globalThis.__wrRQueryBoundaryDispatchTarget = target;
  };
  globalThis.__wrRQueryBoundaryInstallContainsMissing = () => {
    const root = document.createElement('div');
    const child = document.createElement('button');
    child.className = 'delegate-target';
    root.appendChild(child);
    document.body.appendChild(root);
    root.contains = undefined;
    globalThis.__wrRQueryBoundaryDelegateRoot = root;
    globalThis.__wrRQueryBoundaryDelegateChild = child;
  };
  globalThis.__wrRQueryBoundaryRestoreEvent = () => {
    if (globalThis.__wrRQueryBoundarySavedEvent === undefined) {
      delete globalThis.Event;
    } else {
      globalThis.Event = globalThis.__wrRQueryBoundarySavedEvent;
    }
  };
  globalThis.__wrRQueryBoundaryRestoreAll = () => {
    globalThis.__wrRQueryBoundaryRestoreEvent();
    if (globalThis.__wrRQueryBoundaryDelegateRoot &&
        globalThis.__wrRQueryBoundaryDelegateRoot.parentNode) {
      globalThis.__wrRQueryBoundaryDelegateRoot.parentNode.removeChild(
        globalThis.__wrRQueryBoundaryDelegateRoot);
    }
    delete globalThis.__wrRQueryBoundarySavedEvent;
    delete globalThis.__wrRQueryBoundaryInstallEventMissing;
    delete globalThis.__wrRQueryBoundaryInstallEventNonConstructor;
    delete globalThis.__wrRQueryBoundaryInstallDispatchMissing;
    delete globalThis.__wrRQueryBoundaryInstallContainsMissing;
    delete globalThis.__wrRQueryBoundaryRestoreEvent;
    delete globalThis.__wrRQueryBoundaryRestoreAll;
    delete globalThis.__wrRQueryBoundaryDispatchTarget;
    delete globalThis.__wrRQueryBoundaryDelegateRoot;
    delete globalThis.__wrRQueryBoundaryDelegateChild;
  };")

(define event-constructor-message
  (catch-message
   (lambda ()
     (js-eval "__wrRQueryBoundaryInstallEventMissing();")
     ($trigger 'click
               (list->$selection
                (list (element-wrap (js-eval "document.createElement('button')"))))))))

(js-eval "__wrRQueryBoundaryRestoreEvent();")

(define event-non-constructor-message
  (catch-message
   (lambda ()
     (js-eval "__wrRQueryBoundaryInstallEventNonConstructor();")
     ($trigger 'click
               (list->$selection
                (list (element-wrap (js-eval "document.createElement('button')"))))))))

(js-eval "__wrRQueryBoundaryRestoreEvent();")

(define dispatch-event-message
  (catch-message
   (lambda ()
     (js-eval "__wrRQueryBoundaryInstallDispatchMissing();")
     ($trigger 'click
               (list->$selection
                (list (element-wrap
                       (js-eval "globalThis.__wrRQueryBoundaryDispatchTarget"))))))))

(define contains-message
  (catch-message
   (lambda ()
     (js-eval "__wrRQueryBoundaryInstallContainsMissing();")
     (define root
       (element-wrap (js-eval "globalThis.__wrRQueryBoundaryDelegateRoot")))
     (define child
       (element-wrap (js-eval "globalThis.__wrRQueryBoundaryDelegateChild")))
     ($on-delegate 'click
                   ".delegate-target"
                   (lambda (_matched _evt) (void))
                   (list->$selection (list root)))
     ($trigger 'click (list->$selection (list child))))))

(check-message event-constructor-message
               "Event constructor is not available"
               "missing Event constructor message")
(check-message event-non-constructor-message
               "Event constructor is not available"
               "non-constructible Event constructor message")
(check-message dispatch-event-message
               "EventTarget.dispatchEvent is not available"
               "missing dispatchEvent message")
(check-message contains-message
               "Element.contains is not available"
               "missing Element.contains message")

(js-eval "__wrRQueryBoundaryRestoreAll();")

(js-log "rquery-method-missing-host-ffi-ok")
#t
