#lang webracket/base

;; Browser smoke for IndexedDB wrapper host-method boundary errors.

(require indexed-db
         (only-in webracket/unsafe/standard
                  js-eval
                  js-truthy?))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

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

(js-eval
 "globalThis.__wrIndexedDBBoundarySaved = {};
  globalThis.__wrIndexedDBBoundaryConstructorDescriptor =
    Object.getOwnPropertyDescriptor(globalThis, 'IDBFactory') || null;
  globalThis.__wrIndexedDBBoundaryHideConstructor = () => {
    try {
      Object.defineProperty(globalThis, 'IDBFactory', {
        value: undefined,
        configurable: true,
        writable: true
      });
      return true;
    } catch (_e) {
      return false;
    }
  };
  globalThis.__wrIndexedDBBoundaryRestoreConstructor = () => {
    const saved = globalThis.__wrIndexedDBBoundaryConstructorDescriptor;
    if (saved) {
      Object.defineProperty(globalThis, 'IDBFactory', saved);
    } else {
      delete globalThis.IDBFactory;
    }
  };
  globalThis.__wrIndexedDBBoundaryPatch = (name) => {
    const proto = IDBFactory.prototype;
    if (!Object.prototype.hasOwnProperty.call(globalThis.__wrIndexedDBBoundarySaved, name)) {
      globalThis.__wrIndexedDBBoundarySaved[name] =
        Object.getOwnPropertyDescriptor(proto, name) || null;
    }
    Object.defineProperty(proto, name, {
      value: undefined,
      configurable: true,
      writable: true
    });
  };
  globalThis.__wrIndexedDBBoundaryRestore = (name) => {
    const proto = IDBFactory.prototype;
    const descriptor = globalThis.__wrIndexedDBBoundarySaved[name];
    if (descriptor) {
      Object.defineProperty(proto, name, descriptor);
    } else {
      delete proto[name];
    }
    delete globalThis.__wrIndexedDBBoundarySaved[name];
  };
  globalThis.__wrIndexedDBBoundaryRestoreAll = () => {
    globalThis.__wrIndexedDBBoundaryRestoreConstructor();
    for (const name of Object.keys(globalThis.__wrIndexedDBBoundarySaved)) {
      globalThis.__wrIndexedDBBoundaryRestore(name);
    }
    delete globalThis.__wrIndexedDBBoundarySaved;
    delete globalThis.__wrIndexedDBBoundaryConstructorDescriptor;
    delete globalThis.__wrIndexedDBBoundaryHideConstructor;
    delete globalThis.__wrIndexedDBBoundaryRestoreConstructor;
    delete globalThis.__wrIndexedDBBoundaryPatch;
    delete globalThis.__wrIndexedDBBoundaryRestore;
    delete globalThis.__wrIndexedDBBoundaryRestoreAll;
  };")

(define db (indexed-db))

(check-true (indexed-db? db)
            "indexed-db predicate before patches")

(define (hide-indexed-db-constructor?)
  (js-truthy?
   (js-eval "__wrIndexedDBBoundaryHideConstructor()")))

(define (restore-indexed-db-constructor!)
  (js-eval "__wrIndexedDBBoundaryRestoreConstructor();")
  (void))

(define constructor-message
  (cond
    [(hide-indexed-db-constructor?)
     (catch-message/restoring
      (lambda ()
        (indexed-db-open db "wr-missing-constructor"))
      restore-indexed-db-constructor!)]
    [else
     (restore-indexed-db-constructor!)
     #f]))

(define (missing-method-message method thunk)
  (js-eval (string-append "__wrIndexedDBBoundaryPatch('"
                          method
                          "')"))
  (define message (catch-message thunk))
  (js-eval (string-append "__wrIndexedDBBoundaryRestore('"
                          method
                          "')"))
  message)

(define open-message
  (missing-method-message
   "open"
   (lambda ()
     (indexed-db-open db "wr-missing-open"))))

(define delete-message
  (missing-method-message
   "deleteDatabase"
   (lambda ()
     (indexed-db-delete-database! db "wr-missing-delete"))))

(define cmp-message
  (missing-method-message
   "cmp"
   (lambda ()
     (indexed-db-cmp db 1 1))))

(define databases-message
  (missing-method-message
   "databases"
   (lambda ()
     (indexed-db-databases db))))

(check-message open-message
               "IDBFactory.open is not available"
               "missing IDBFactory.open message")
(when constructor-message
  (check-message constructor-message
                 "IDBFactory constructor is not available"
                 "missing IDBFactory constructor message"))
(check-message delete-message
               "IDBFactory.deleteDatabase is not available"
               "missing IDBFactory.deleteDatabase message")
(check-message cmp-message
               "IDBFactory.cmp is not available"
               "missing IDBFactory.cmp message")
(check-message databases-message
               "IDBFactory.databases is not available"
               "missing IDBFactory.databases message")

(js-eval "__wrIndexedDBBoundaryRestoreAll();")

(js-log "indexed-db-method-missing-host-ffi-ok")
#t
