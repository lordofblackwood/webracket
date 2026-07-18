#lang webracket/base

;; Browser smoke for History wrapper host-method boundary errors.

(require history
         (only-in webracket/unsafe/dom
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
 "globalThis.__wrHistoryBoundaryFake = (missing) => {
    const history = {
      length: 1,
      state: null,
      back() {},
      forward() {},
      go(_delta) {},
      pushState(_state, _unused, _url) {},
      replaceState(_state, _unused, _url) {}
    };
    delete history[missing];
    return history;
  };
  globalThis.__wrHistoryBoundarySaved = {};
  globalThis.__wrHistoryBoundaryPatchWindow = (methodName) => {
    if (!Object.prototype.hasOwnProperty.call(globalThis.__wrHistoryBoundarySaved, methodName)) {
      globalThis.__wrHistoryBoundarySaved[methodName] =
        Object.getOwnPropertyDescriptor(window, methodName) || null;
    }
    Object.defineProperty(window, methodName, {
      value: undefined,
      configurable: true,
      writable: true
    });
  };
  globalThis.__wrHistoryBoundaryRestoreWindow = (methodName) => {
    const descriptor = globalThis.__wrHistoryBoundarySaved[methodName];
    if (descriptor) {
      Object.defineProperty(window, methodName, descriptor);
    } else {
      delete window[methodName];
    }
    delete globalThis.__wrHistoryBoundarySaved[methodName];
  };
  globalThis.__wrHistoryBoundaryRestoreAll = () => {
    for (const methodName of Object.keys(globalThis.__wrHistoryBoundarySaved)) {
      globalThis.__wrHistoryBoundaryRestoreWindow(methodName);
    }
    delete globalThis.__wrHistoryBoundaryFake;
    delete globalThis.__wrHistoryBoundarySaved;
    delete globalThis.__wrHistoryBoundaryPatchWindow;
    delete globalThis.__wrHistoryBoundaryRestoreWindow;
    delete globalThis.__wrHistoryBoundaryRestoreAll;
  };")

(define (fake-history missing)
  (history-info (js-eval (string-append "__wrHistoryBoundaryFake('"
                                        missing
                                        "')"))))

(define (missing-window-method-message method thunk)
  (js-eval (string-append "__wrHistoryBoundaryPatchWindow('"
                          method
                          "')"))
  (define message (catch-message thunk))
  (js-eval (string-append "__wrHistoryBoundaryRestoreWindow('"
                          method
                          "')"))
  message)

(define missing-back-history (fake-history "back"))
(define missing-forward-history (fake-history "forward"))
(define missing-go-history (fake-history "go"))
(define missing-push-state-history (fake-history "pushState"))
(define missing-replace-state-history (fake-history "replaceState"))

(check-true (not (history? missing-back-history))
            "history? rejects missing back")
(check-true (not (history? missing-forward-history))
            "history? rejects missing forward")
(check-true (not (history? missing-go-history))
            "history? rejects missing go")
(check-true (not (history? missing-push-state-history))
            "history? rejects missing pushState")
(check-true (not (history? missing-replace-state-history))
            "history? rejects missing replaceState")

(define back-message
  (catch-message
   (lambda ()
     (history-back! missing-back-history))))

(define forward-message
  (catch-message
   (lambda ()
     (history-forward! missing-forward-history))))

(define go-message
  (catch-message
   (lambda ()
     (history-go! missing-go-history 0))))

(define push-state-message
  (catch-message
   (lambda ()
     (history-push-state! missing-push-state-history 'state))))

(define replace-state-message
  (catch-message
   (lambda ()
     (history-replace-state! missing-replace-state-history 'state))))

(define invalid-raw-message
  (catch-message
   (lambda ()
     (history-back! (history-info #f)))))

(define callback (lambda args (void)))

(define add-popstate-message
  (missing-window-method-message
   "addEventListener"
   (lambda ()
     (history-add-popstate-listener! callback))))

(define remove-popstate-message
  (missing-window-method-message
   "removeEventListener"
   (lambda ()
     (history-remove-popstate-listener! callback))))

(check-message back-message
               "History.back is not available"
               "missing History.back message")
(check-message forward-message
               "History.forward is not available"
               "missing History.forward message")
(check-message go-message
               "History.go is not available"
               "missing History.go message")
(check-message push-state-message
               "History.pushState is not available"
               "missing History.pushState message")
(check-message replace-state-message
               "History.replaceState is not available"
               "missing History.replaceState message")
(check-message invalid-raw-message
               "history?"
               "missing history invalid raw message")
(check-message add-popstate-message
               "window.addEventListener is not available"
               "missing window.addEventListener message")
(check-message remove-popstate-message
               "window.removeEventListener is not available"
               "missing window.removeEventListener message")

(js-eval "__wrHistoryBoundaryRestoreAll();")

(js-log "history-method-missing-host-ffi-ok")
#t
