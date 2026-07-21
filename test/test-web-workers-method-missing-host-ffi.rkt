#lang webracket/base

;; Browser smoke for Web Worker wrapper host-method boundary errors.

(require web-workers
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
 "globalThis.__wrWorkerBoundarySavedWorker =
    Object.getOwnPropertyDescriptor(globalThis, 'Worker') || null;
  globalThis.__wrWorkerBoundaryInstallFake = (missing) => {
    function WebRacketBoundaryWorker(scriptUrl, options) {
      this.scriptUrl = scriptUrl;
      this.options = options || null;
      this.messages = [];
      this.listeners = [];
      this.terminated = false;
      if (missing !== 'onmessage') {
        this.onmessage = null;
      }
      if (missing !== 'onerror') {
        this.onerror = null;
      }
      if (missing !== 'postMessage') {
        this.postMessage = (message) => { this.messages.push(message); };
      }
      if (missing !== 'terminate') {
        this.terminate = () => { this.terminated = true; };
      }
      if (missing !== 'addEventListener') {
        this.addEventListener = (eventName, callback) => {
          this.listeners.push([eventName, callback]);
        };
      }
      if (missing !== 'removeEventListener') {
        this.removeEventListener = (eventName, callback) => {
          this.listeners = this.listeners.filter((entry) =>
            entry[0] !== eventName || entry[1] !== callback);
        };
      }
    }
    Object.defineProperty(globalThis, 'Worker', {
      value: WebRacketBoundaryWorker,
      configurable: true,
      writable: true
    });
  };
  globalThis.__wrWorkerBoundaryHideConstructor = () => {
    Object.defineProperty(globalThis, 'Worker', {
      value: undefined,
      configurable: true,
      writable: true
    });
  };
  globalThis.__wrWorkerBoundaryInstallNonConstructor = () => {
    Object.defineProperty(globalThis, 'Worker', {
      value: () => {},
      configurable: true,
      writable: true
    });
  };
  globalThis.__wrWorkerBoundaryRestoreWorker = () => {
    const descriptor = globalThis.__wrWorkerBoundarySavedWorker;
    if (descriptor) {
      Object.defineProperty(globalThis, 'Worker', descriptor);
    } else {
      delete globalThis.Worker;
    }
  };
  globalThis.__wrWorkerBoundaryRestoreAll = () => {
    globalThis.__wrWorkerBoundaryRestoreWorker();
    delete globalThis.__wrWorkerBoundarySavedWorker;
    delete globalThis.__wrWorkerBoundaryInstallFake;
    delete globalThis.__wrWorkerBoundaryHideConstructor;
    delete globalThis.__wrWorkerBoundaryInstallNonConstructor;
    delete globalThis.__wrWorkerBoundaryRestoreWorker;
    delete globalThis.__wrWorkerBoundaryRestoreAll;
  };")

(define (constructor-missing-message)
  (js-eval "__wrWorkerBoundaryHideConstructor();")
  (define message
    (catch-message
     (lambda ()
       (make-worker "worker.js"))))
  (js-eval "__wrWorkerBoundaryRestoreWorker();")
  message)

(define (constructor-non-constructor-message)
  (js-eval "__wrWorkerBoundaryInstallNonConstructor();")
  (define message
    (catch-message
     (lambda ()
       (make-worker "worker.js"))))
  (js-eval "__wrWorkerBoundaryRestoreWorker();")
  message)

(define (fake-worker missing)
  (js-eval (string-append "__wrWorkerBoundaryInstallFake('"
                          missing
                          "');"))
  (define worker (make-worker "worker.js"))
  (check-true (worker? worker)
              (string-append "worker? accepts fake Worker missing " missing))
  worker)

(define callback (lambda args (void)))

(define constructor-message
  (constructor-missing-message))

(define constructor-non-constructor-message*
  (constructor-non-constructor-message))

(define post-message-message
  (catch-message
   (lambda ()
     (worker-post-message! (fake-worker "postMessage") "hello"))))

(define terminate-message
  (catch-message
   (lambda ()
     (worker-terminate! (fake-worker "terminate")))))

(define add-event-message
  (catch-message
   (lambda ()
     (worker-add-event-listener! (fake-worker "addEventListener")
                                 'message
                                 callback))))

(define remove-event-message
  (catch-message
   (lambda ()
     (worker-remove-event-listener! (fake-worker "removeEventListener")
                                    'message
                                    callback))))

(define onmessage-message
  (catch-message
   (lambda ()
     (worker-onmessage! (fake-worker "onmessage") callback))))

(define onerror-message
  (catch-message
   (lambda ()
     (worker-onerror! (fake-worker "onerror") callback))))

(check-message constructor-message
               "Worker is not available"
               "missing Worker constructor message")
(check-message constructor-non-constructor-message*
               "Worker is not available"
               "non-constructible Worker constructor message")
(check-message post-message-message
               "Worker.postMessage is not available"
               "missing Worker.postMessage message")
(check-message terminate-message
               "Worker.terminate is not available"
               "missing Worker.terminate message")
(check-message add-event-message
               "Worker.addEventListener is not available"
               "missing Worker.addEventListener message")
(check-message remove-event-message
               "Worker.removeEventListener is not available"
               "missing Worker.removeEventListener message")
(check-message onmessage-message
               "Worker.onmessage is not available"
               "missing Worker.onmessage message")
(check-message onerror-message
               "Worker.onerror is not available"
               "missing Worker.onerror message")

(js-eval "__wrWorkerBoundaryRestoreAll();")

(js-log "web-workers-method-missing-host-ffi-ok")
#t
