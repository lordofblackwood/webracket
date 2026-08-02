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

(struct semaphore-plain ())

(list
 (list "channel-get rejects non-channels with who"
       (catch-contract/contains?
        (lambda () (channel-get 42))
        "channel-get"
        "channel?"
        "given: 42"))
 (list "channel-try-get rejects non-channels with who"
       (catch-contract/contains?
        (lambda () (channel-try-get 42))
        "channel-try-get"
        "channel?"
        "given: 42"))
 (list "channel-put rejects non-channels with who"
       (catch-contract/contains?
        (lambda () (channel-put 42 'value))
        "channel-put"
        "channel?"
        "given: 42"))
 (list "channel-put-evt rejects non-channels with who"
       (catch-contract/contains?
        (lambda () (channel-put-evt 42 'value))
        "channel-put-evt"
        "channel?"
        "given: 42"))
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
 (list "sync/timeout rejects non-thunk timeout procedures with who"
       (catch-contract/contains?
        (lambda () (sync/timeout (lambda (x) 0) always-evt))
        "sync/timeout"
        "(or/c #f (and/c real? (not/c negative?)) (-> any))"
        "given:"))
 (list "sync/timeout rejects plain structs as non-timeouts"
       (catch-contract/contains?
        (lambda () (sync/timeout (semaphore-plain) always-evt))
        "sync/timeout"
        "(or/c #f (and/c real? (not/c negative?)) (-> any))"
        "given: #(struct semaphore-plain)"))
 (list "handle-evt rejects non-procedures with who"
       (catch-contract/contains?
        (lambda () (handle-evt always-evt 42))
        "handle-evt"
        "procedure?"
        "given: 42"))
 (list "handle-evt rejects plain structs as non-procedures"
       (catch-contract/contains?
        (lambda () (handle-evt always-evt (semaphore-plain)))
        "handle-evt"
        "procedure?"
        "given: #(struct semaphore-plain)"))
 (list "call-with-semaphore rejects non-procedures with who"
       (catch-contract/contains?
        (lambda () (call-with-semaphore (make-semaphore 1) 42))
        "call-with-semaphore"
        "procedure?"
        "given: 42"))
 (list "call-with-semaphore rejects plain structs as non-procedures"
       (catch-contract/contains?
        (lambda () (call-with-semaphore (make-semaphore 1) (semaphore-plain)))
        "call-with-semaphore"
        "procedure?"
        "given: #(struct semaphore-plain)"))
 (list "call-with-semaphore validates try-fail thunk with who"
       (catch-contract/contains?
        (lambda () (call-with-semaphore (make-semaphore 1) values 42))
        "call-with-semaphore"
        "(or/c (procedure-arity-includes/c 0) #f)"
        "given: 42"))
 (list "call-with-semaphore rejects plain structs as try-fail thunks"
       (catch-contract/contains?
        (lambda () (call-with-semaphore (make-semaphore 1) values (semaphore-plain)))
        "call-with-semaphore"
        "(or/c (procedure-arity-includes/c 0) #f)"
        "given: #(struct semaphore-plain)"))
 (list "sync still selects ready events"
       (and (equal? (sync always-evt) always-evt)
            (let ([s (make-semaphore 1)])
              (equal? (sync/timeout 0 s) s)))))
