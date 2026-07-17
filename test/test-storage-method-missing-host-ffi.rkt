#lang webracket/base

;; Browser smoke for Storage wrapper host-method boundary errors.

(require storage
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
 "globalThis.__wrStorageBoundaryFake = (missing) => {
    const storage = {
      length: 0,
      key(_index) { return null; },
      getItem(_key) { return null; },
      setItem(_key, _value) {},
      removeItem(_key) {},
      clear() {}
    };
    delete storage[missing];
    return storage;
  };")

(define (fake-storage missing)
  (storage (js-eval (string-append "__wrStorageBoundaryFake('"
                                   missing
                                   "')"))))

(define missing-key-storage (fake-storage "key"))
(define missing-get-storage (fake-storage "getItem"))
(define missing-set-storage (fake-storage "setItem"))
(define missing-remove-storage (fake-storage "removeItem"))
(define missing-clear-storage (fake-storage "clear"))

(check-true (not (storage? missing-key-storage))
            "storage? rejects missing key")
(check-true (not (storage? missing-get-storage))
            "storage? rejects missing getItem")
(check-true (not (storage? missing-set-storage))
            "storage? rejects missing setItem")
(check-true (not (storage? missing-remove-storage))
            "storage? rejects missing removeItem")
(check-true (not (storage? missing-clear-storage))
            "storage? rejects missing clear")

(define storage-key-message
  (catch-message
   (lambda ()
     (storage-key missing-key-storage 0))))

(define storage-get-message
  (catch-message
   (lambda ()
     (storage-get-item missing-get-storage "k"))))

(define storage-set-message
  (catch-message
   (lambda ()
     (storage-set-item! missing-set-storage "k" "v"))))

(define storage-remove-message
  (catch-message
   (lambda ()
     (storage-remove-item! missing-remove-storage "k"))))

(define storage-clear-message
  (catch-message
   (lambda ()
     (storage-clear! missing-clear-storage))))

(define storage-invalid-raw-message
  (catch-message
   (lambda ()
     (storage-length (storage #f)))))

(check-message storage-key-message
               "Storage.key is not available"
               "missing Storage.key message")
(check-message storage-get-message
               "Storage.getItem is not available"
               "missing Storage.getItem message")
(check-message storage-set-message
               "Storage.setItem is not available"
               "missing Storage.setItem message")
(check-message storage-remove-message
               "Storage.removeItem is not available"
               "missing Storage.removeItem message")
(check-message storage-clear-message
               "Storage.clear is not available"
               "missing Storage.clear message")
(check-message storage-invalid-raw-message
               "storage-info?"
               "missing storage-info invalid raw message")

(js-eval "delete globalThis.__wrStorageBoundaryFake;")

(js-log "storage-method-missing-host-ffi-ok")
#t
