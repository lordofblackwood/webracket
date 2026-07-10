;; Focused no-stdlib generated-output checks for event synchronization errors.
;;
;; Compile this file with `--no-stdlib`.

(define (catch-contract/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail:contract?
                          (lambda (exn)
                            (exn-message exn))])
           (thunk)
           #f)])
    (and message
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(list
 (list "sync rejects non-events with who"
       (catch-contract/contains?
        (lambda () (sync 42))
        "sync"
        "evt?"
        "given: 42"))
 (list "sync/timeout rejects non-events with who"
       (catch-contract/contains?
        (lambda () (sync/timeout #f 42))
        "sync/timeout"
        "evt?"
        "given: 42"))
 (list "sync/timeout rejects negative timeouts with who"
       (catch-contract/contains?
        (lambda () (sync/timeout -1 (make-semaphore 1)))
        "sync/timeout"
        "(or/c #f (and/c real? (not/c negative?)) (-> any))"
        "given: -1"))
 (list "sync/timeout rejects non-timeouts with who"
       (catch-contract/contains?
        (lambda () (sync/timeout 'bad always-evt))
        "sync/timeout"
        "(or/c #f (and/c real? (not/c negative?)) (-> any))"
        "given: 'bad"))
 (list "handle-evt rejects non-procedures with who"
       (catch-contract/contains?
        (lambda () (handle-evt always-evt 42))
        "handle-evt"
        "procedure?"
        "given: 42"))
 (list "call-with-semaphore rejects non-procedures with who"
       (catch-contract/contains?
        (lambda () (call-with-semaphore (make-semaphore 1) 42))
        "call-with-semaphore"
        "procedure?"
        "given: 42"))
 (list "call-with-semaphore validates try-fail thunk with who"
       (catch-contract/contains?
        (lambda () (call-with-semaphore (make-semaphore 1) values 42))
        "call-with-semaphore"
        "(or/c (procedure-arity-includes/c 0) #f)"
        "given: 42"))
 (list "sync still selects ready events"
       (and (equal? (sync always-evt) always-evt)
            (let ([s (make-semaphore 1)])
              (equal? (sync/timeout 0 s) s)))))
