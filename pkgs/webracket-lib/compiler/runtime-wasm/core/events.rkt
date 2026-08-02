#lang racket

(provide event-global-forms
         event-runtime-string-constants
         event-runtime-symbol-constants
         event-initializer-forms
         event-core-runtime-helpers
         event-core-runtime-helper-forms
         event-channel-runtime-helper-forms
         event-sync-runtime-helper-forms
         event-runtime-only-helpers)

(require "../core-helper.rkt")

;; event-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by event helpers and event errors.
(define event-runtime-string-constants
  '((evt?        "evt?")
    (handle-evt? "handle-evt?")
    (channel?    "channel?")
    (sync-timeout-contract
     "(or/c #f (and/c real? (not/c negative?)) (-> any))")))

;; event-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by event and channel helpers.
(define event-runtime-symbol-constants
  '(make-channel
    channel?
    channel-get
    channel-try-get
    channel-put
    channel-put-evt
    channel-put-evt?
    evt?
    handle-evt
    handle-evt?
    sync
    sync/timeout))

;; event-global-forms : (listof datum?)
;;   Declare singleton event globals for the runtime.
(define event-global-forms
  '(
               (global $always-evt               (mut (ref eq)) (global.get $false))
               (global $never-evt                (mut (ref eq)) (global.get $false))))

;; event-initializer-forms : (listof datum?)
;;   Initialize singleton always and never events.
(define event-initializer-forms
  '(
                     (global.set $always-evt
                                 (struct.new $AlwaysEvt (i32.const 0)))
                     (global.set $never-evt
                                 (struct.new $NeverEvt (i32.const 0)))))

;; event-promoted-runtime-helper-names : (listof symbol?)
;;   Name event helpers that are available in the standalone core runtime.
(define event-promoted-runtime-helper-names
  '($make-channel
    $channel?
    $channel-put-evt?
    $evt?
    $channel-put
    $sync-one))

;; event-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate event and channel helpers in monolithic runtime order.
(define event-all-runtime-helpers
  (list
   ;; make-channel : -> channel?
   ;;   Create a single-threaded one-slot channel. Real Racket channels
   ;;   synchronize senders and receivers; WebRacket will need scheduler
   ;;   support before blocking semantics can be reinstated.
   (core-runtime-helper
    '$make-channel
    "$make-channel"
    (lambda ()
      `(func $make-channel (type $Prim0)
             (result (ref eq))
             (struct.new $Channel
                         (i32.const 0)
                         (i32.const 0)
                         (global.get $false)))))


   ;; channel? : any/c -> boolean?
   ;;   Predicate for WebRacket's lightweight channels.
   (core-runtime-helper
    '$channel?
    "$channel?"
    (lambda ()
      `(func $channel? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $Channel) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; channel-put-evt? : any/c -> boolean?
   ;;   Predicate for lightweight channel put events.
   (core-runtime-helper
    '$channel-put-evt?
    "$channel-put-evt?"
    (lambda ()
      `(func $channel-put-evt? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $ChannelPutEvt) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; handle-evt? : evt? -> boolean?
   ;;   Recognize lightweight events created by handle-evt. Racket also
   ;;   returns #t for choice events that contain handled events; WebRacket
   ;;   does not model choice events yet.
   (core-runtime-helper
    '$handle-evt?
    "$handle-evt?"
    (lambda ()
      `(func $handle-evt? (type $Prim1)
             (param $v (ref eq)) ;; evt?
             (result   (ref eq))
             (if (ref.eq (call $evt? (local.get $v)) (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:handle-evt?)
                             (global.get $string:evt?)
                             (local.get $v))
                       (unreachable)))
             (if (result (ref eq))
                 (ref.test (ref $HandleEvt) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; evt? : any/c -> boolean?
   ;;   Recognize the synchronizable event values implemented by the
   ;;   current single-threaded substrate.
   (core-runtime-helper
    '$evt?
    "$evt?"
    (lambda ()
      `(func $evt? (type $Prim1)
             (param $v (ref eq)) ;; any/c
             (result   (ref eq))
             (if (ref.test (ref $AlwaysEvt) (local.get $v))
                 (then (return (global.get $true))))
             (if (ref.test (ref $NeverEvt) (local.get $v))
                 (then (return (global.get $true))))
             (if (ref.test (ref $Thread) (local.get $v))
                 (then (return (global.get $true))))
             (if (ref.test (ref $Semaphore) (local.get $v))
                 (then (return (global.get $true))))
             (if (ref.test (ref $SemaphorePeekEvt) (local.get $v))
                 (then (return (global.get $true))))
             (if (ref.test (ref $Channel) (local.get $v))
                 (then (return (global.get $true))))
             (if (ref.test (ref $ChannelPutEvt) (local.get $v))
                 (then (return (global.get $true))))
             (if (ref.test (ref $HandleEvt) (local.get $v))
                 (then (return (global.get $true))))
             (if (ref.test (ref $WillExecutor) (local.get $v))
                 (then (return (global.get $true))))
             (if (ref.test (ref $LogReceiver) (local.get $v))
                 (then (return (global.get $true))))
             (if (ref.test (ref $CustodianBox) (local.get $v))
                 (then (return (global.get $true))))
             (global.get $false))))


   ;; channel-put : channel? any/c -> void?
   ;;   Store one pending value. Without a scheduler this does not block
   ;;   waiting for a receiver; later puts overwrite the pending slot.
   (core-runtime-helper
    '$channel-put
    "$channel-put"
    (lambda ()
      `(func $channel-put (type $Prim2)
             (param $ch-raw (ref eq)) ;; channel?
             (param $v      (ref eq)) ;; any/c
             (result        (ref eq))
             (if (i32.eqz (ref.test (ref $Channel) (local.get $ch-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:channel-put)
                             (global.get $string:channel?)
                             (local.get $ch-raw))
                       (unreachable)))
             (struct.set $Channel $value
                         (ref.cast (ref $Channel) (local.get $ch-raw))
                         (local.get $v))
             (struct.set $Channel $ready
                         (ref.cast (ref $Channel) (local.get $ch-raw))
                         (i32.const 1))
             (global.get $void))))


   ;; channel-try-get : channel? -> any/c
   ;;   Return a pending value if one is available, otherwise #f.
   (core-runtime-helper
    '$channel-try-get
    "$channel-try-get"
    (lambda ()
      `(func $channel-try-get (type $Prim1)
             (param $ch-raw (ref eq)) ;; channel?
             (result        (ref eq))
             (local $ch (ref $Channel))
             (if (i32.eqz (ref.test (ref $Channel) (local.get $ch-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:channel-try-get)
                             (global.get $string:channel?)
                             (local.get $ch-raw))
                       (unreachable)))
             (local.set $ch (ref.cast (ref $Channel) (local.get $ch-raw)))
             (if (i32.eqz (struct.get $Channel $ready (local.get $ch)))
                 (then (return (global.get $false))))
             (struct.set $Channel $ready (local.get $ch) (i32.const 0))
             (struct.get $Channel $value (local.get $ch)))))


   ;; channel-get : channel? -> any/c
   ;;   Single-threaded approximation: consume a pending value or return
   ;;   #f instead of blocking forever.
   (core-runtime-helper
    '$channel-get
    "$channel-get"
    (lambda ()
      `(func $channel-get (type $Prim1)
             (param $ch-raw (ref eq)) ;; channel?
             (result        (ref eq))
             (local $ch (ref $Channel))
             (if (i32.eqz (ref.test (ref $Channel) (local.get $ch-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:channel-get)
                             (global.get $string:channel?)
                             (local.get $ch-raw))
                       (unreachable)))
             (local.set $ch (ref.cast (ref $Channel) (local.get $ch-raw)))
             (if (i32.eqz (struct.get $Channel $ready (local.get $ch)))
                 (then (return (global.get $false))))
             (struct.set $Channel $ready (local.get $ch) (i32.const 0))
             (struct.get $Channel $value (local.get $ch)))))


   ;; channel-put-evt : channel? any/c -> channel-put-evt?
   ;;   Build a synchronizable put event. In the current single-threaded
   ;;   sync approximation it becomes ready immediately.
   (core-runtime-helper
    '$channel-put-evt
    "$channel-put-evt"
    (lambda ()
      `(func $channel-put-evt (type $Prim2)
             (param $ch-raw (ref eq)) ;; channel?
             (param $v      (ref eq)) ;; any/c
             (result        (ref eq))
             (if (i32.eqz (ref.test (ref $Channel) (local.get $ch-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:channel-put-evt)
                             (global.get $string:channel?)
                             (local.get $ch-raw))
                       (unreachable)))
             (struct.new $ChannelPutEvt
                         (i32.const 0)
                         (ref.cast (ref $Channel) (local.get $ch-raw))
                         (local.get $v)))))


   ;; handle-evt : evt? procedure? -> handle-evt?
   ;;   Wrap an event with a handler to apply to its synchronization
   ;;   result. This single-threaded approximation supports one-value
   ;;   event results from the currently implemented event substrate.
   (core-runtime-helper
    '$handle-evt
    "$handle-evt"
    (lambda ()
      `(func $handle-evt (type $Prim2)
             (param $evt-raw  (ref eq)) ;; evt?
             (param $proc-raw (ref eq)) ;; procedure?
             (result          (ref eq))
             (if (ref.eq (call $evt? (local.get $evt-raw)) (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:handle-evt)
                             (global.get $string:evt?)
                             (local.get $evt-raw))
                       (unreachable)))
             (if (ref.eq (call $procedure? (local.get $proc-raw))
                         (global.get $false))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:handle-evt)
                             (local.get $proc-raw))
                       (unreachable)))
             (struct.new $HandleEvt
                         (i32.const 0)
                         (local.get $evt-raw)
                         (ref.cast (ref $Procedure) (local.get $proc-raw))))))

   ;; $sync-one : evt? boolean? -> any/c
   ;;   Return the selected event value, or #f when it is not ready.
   ;;   Semaphore events consume when requested; peek events do not.
   (core-runtime-helper
    '$sync-one
    "$sync-one"
    (lambda ()
      `(func $sync-one
             (param $evt      (ref eq)) ;; event candidate
             (param $consume? i32)      ;; non-zero consumes semaphore counts
             (result          (ref eq))
       
             (local $sema (ref $Semaphore))
             (local $peek (ref $SemaphorePeekEvt))
             (local $ch   (ref $Channel))
             (local $put  (ref $ChannelPutEvt))
             (local $handle (ref $HandleEvt))
             (local $proc   (ref $Procedure))
             (local $inv    (ref $ProcedureInvoker))
             (local $r      (ref eq))
       
             (if (ref.test (ref $AlwaysEvt) (local.get $evt))
                 (then (return (local.get $evt))))
             (if (ref.test (ref $NeverEvt) (local.get $evt))
                 (then (return (global.get $false))))
             ;; Threads are synchronizable in Racket when they terminate. The
             ;; single WebRacket thread never terminates while user code runs.
             (if (ref.test (ref $Thread) (local.get $evt))
                 (then (return (global.get $false))))
             (if (ref.test (ref $Semaphore) (local.get $evt))
                 (then
                  (local.set $sema (ref.cast (ref $Semaphore) (local.get $evt)))
                  (if (i32.gt_s (struct.get $Semaphore $count (local.get $sema))
                                (i32.const 0))
                      (then
                       (if (local.get $consume?)
                           (then
                            (struct.set $Semaphore $count
                                        (local.get $sema)
                                        (i32.sub
                                         (struct.get $Semaphore $count (local.get $sema))
                                         (i32.const 1)))))
                       (return (local.get $evt))))
                  (return (global.get $false))))
             (if (ref.test (ref $SemaphorePeekEvt) (local.get $evt))
                 (then
                  (local.set $peek (ref.cast (ref $SemaphorePeekEvt) (local.get $evt)))
                  (local.set $sema (struct.get $SemaphorePeekEvt $sema (local.get $peek)))
                  (if (i32.gt_s (struct.get $Semaphore $count (local.get $sema))
                                (i32.const 0))
                      (then (return (local.get $evt))))
                  (return (global.get $false))))
             (if (ref.test (ref $Channel) (local.get $evt))
                 (then
                  (local.set $ch (ref.cast (ref $Channel) (local.get $evt)))
                  (if (i32.eqz (struct.get $Channel $ready (local.get $ch)))
                      (then (return (global.get $false))))
                  (if (local.get $consume?)
                      (then (struct.set $Channel $ready
                                        (local.get $ch)
                                        (i32.const 0))))
                  (return (struct.get $Channel $value (local.get $ch)))))
             (if (ref.test (ref $ChannelPutEvt) (local.get $evt))
                 (then
                  (local.set $put (ref.cast (ref $ChannelPutEvt) (local.get $evt)))
                  (if (local.get $consume?)
                      (then
                       (drop (call $channel-put
                                   (struct.get $ChannelPutEvt $ch (local.get $put))
                                   (struct.get $ChannelPutEvt $v (local.get $put))))))
                  (return (local.get $evt))))
             (if (ref.test (ref $HandleEvt) (local.get $evt))
                 (then
                  (local.set $handle (ref.cast (ref $HandleEvt) (local.get $evt)))
                  (local.set $r
                             (call $sync-one
                                   (struct.get $HandleEvt $evt (local.get $handle))
                                   (local.get $consume?)))
                  (if (ref.eq (local.get $r) (global.get $false))
                      (then (return (global.get $false))))
                  (local.set $proc (struct.get $HandleEvt $proc (local.get $handle)))
                  (local.set $inv  (struct.get $Procedure $invoke (local.get $proc)))
                  (return_call_ref $ProcedureInvoker
                                   (local.get $proc)
                                   (array.new_fixed $Args 1 (local.get $r))
                                   (local.get $inv))))
             ;; Log receivers are synchronizable events, but the current
             ;; inert logger substrate never queues events.
             (if (ref.test (ref $LogReceiver) (local.get $evt))
                 (then (return (global.get $false))))
             ;; Will executors are events when a GC-discovered will is ready.
             ;; WebRacket does not expose finalization yet.
             (if (ref.test (ref $WillExecutor) (local.get $evt))
                 (then (return (global.get $false))))
             ;; Keep the first event layer permissive: other event kinds from
             ;; imported linklets can be added here as they become reachable.
             (global.get $false))))


   ;; sync : evt? evt? ... -> any/c
   ;;   Select the first ready event. WebRacket has no scheduler yet, so
   ;;   an otherwise-blocking sync currently returns #f instead of waiting.
   (core-runtime-helper
    '$sync
    "$sync"
    (lambda ()
      `(func $sync (type $Prim>=0)
             (param $events (ref eq)) ;; event candidates
             (result        (ref eq))

             (local $r    (ref eq))
             (local $evt  (ref eq))
             (local $node (ref eq))
             (local $p    (ref $Pair))

             (local.set $node (local.get $events))
             (loop $again
               (if (ref.test (ref $Pair) (local.get $node))
                   (then
                    (local.set $p (ref.cast (ref $Pair) (local.get $node)))
                    (local.set $evt (struct.get $Pair $a (local.get $p)))
                    (if (ref.eq (call $evt? (local.get $evt)) (global.get $false))
                        (then (call $raise-argument-error1
                                    (global.get $symbol:sync)
                                    (global.get $string:evt?)
                                    (local.get $evt))
                              (unreachable)))
                    (local.set $r
                               (call $sync-one
                                     (local.get $evt)
                                     (i32.const 1)))
                    (if (i32.eqz (ref.eq (local.get $r) (global.get $false)))
                        (then (return (local.get $r))))
                    (local.set $node (struct.get $Pair $d (local.get $p)))
                    (br $again))))
             (global.get $false))))


   ;; sync/timeout : (or/c real? #f) evt? ... -> any/c
   ;;   Poll ready events. The timeout value is accepted but not used
   ;;   until WebRacket has a scheduler/timer queue.
   (core-runtime-helper
    '$sync/timeout
    "$sync/timeout"
    (lambda ()
      `(func $sync/timeout (type $Prim>=1)
             (param $timeout (ref eq)) ;; timeout or #f
             (param $events  (ref eq)) ;; rest event candidates
             (result         (ref eq))

             (local $r    (ref eq))
             (local $evt  (ref eq))
             (local $node (ref eq))
             (local $p    (ref $Pair))
             (local $timeout-procedure? i32)

             (if (i32.eqz (ref.eq (local.get $timeout) (global.get $false)))
                 (then
                  (local.set $timeout-procedure?
                             (ref.eq (call $procedure? (local.get $timeout))
                                     (global.get $true)))
                  (if (i32.eqz (local.get $timeout-procedure?))
                      (then
                       (if (ref.eq (call $real? (local.get $timeout)) (global.get $false))
                           (then (call $raise-argument-error1
                                       (global.get $symbol:sync/timeout)
                                       (global.get $string:sync-timeout-contract)
                                       (local.get $timeout))
                                 (unreachable)))
                       (if (ref.eq (call $negative? (local.get $timeout)) (global.get $true))
                           (then (call $raise-argument-error1
                                       (global.get $symbol:sync/timeout)
                                       (global.get $string:sync-timeout-contract)
                                       (local.get $timeout))
                                 (unreachable)))))
                  (if (local.get $timeout-procedure?)
                      (then
                       (if (i32.eqz
                            (call $procedure-arity-includes?/checked/i32
                                  (ref.cast (ref $Procedure) (local.get $timeout))
                                  (i32.const 0)))
                           (then (call $raise-argument-error1
                                       (global.get $symbol:sync/timeout)
                                       (global.get $string:sync-timeout-contract)
                                       (local.get $timeout))
                                 (unreachable)))))))

             (local.set $node (local.get $events))
             (loop $again
               (if (ref.test (ref $Pair) (local.get $node))
                   (then
                    (local.set $p (ref.cast (ref $Pair) (local.get $node)))
                    (local.set $evt (struct.get $Pair $a (local.get $p)))
                    (if (ref.eq (call $evt? (local.get $evt)) (global.get $false))
                        (then (call $raise-argument-error1
                                    (global.get $symbol:sync/timeout)
                                    (global.get $string:evt?)
                                    (local.get $evt))
                              (unreachable)))
                    (local.set $r
                               (call $sync-one
                                     (local.get $evt)
                                     (i32.const 1)))
                    (if (i32.eqz (ref.eq (local.get $r) (global.get $false)))
                        (then (return (local.get $r))))
                    (local.set $node (struct.get $Pair $d (local.get $p)))
                    (br $again))))
             (global.get $false))))
))

;; event-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate event helpers available in the standalone core runtime.
(define event-core-runtime-helpers
  (select-runtime-helpers event-all-runtime-helpers
                          event-promoted-runtime-helper-names))

;; event-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate event and channel helpers that still depend on monolithic runtime globals.
(define event-runtime-only-helpers
  (remove-runtime-helpers event-all-runtime-helpers
                          event-promoted-runtime-helper-names))

;; event-channel-runtime-helper-names : (listof symbol?)
;;   Preserve the full runtime emission order for channel and event helpers.
(define event-channel-runtime-helper-names
  '($handle-evt?
    $channel-put
    $channel-try-get
    $channel-get
    $channel-put-evt
    $handle-evt))

;; event-channel-runtime-only-helper-names : (listof symbol?)
;;   Preserve the program/runtime-local emission order for channel and event helpers.
(define event-channel-runtime-only-helper-names
  (remove* event-promoted-runtime-helper-names
           event-channel-runtime-helper-names))

;; event-sync-runtime-helper-names : (listof symbol?)
;;   Preserve the full runtime emission order for synchronization helpers.
(define event-sync-runtime-helper-names
  '($sync-one
    $sync
    $sync/timeout))

;; event-sync-runtime-only-helper-names : (listof symbol?)
;;   Preserve the program/runtime-local emission order for synchronization helpers.
(define event-sync-runtime-only-helper-names
  (remove* event-promoted-runtime-helper-names
           event-sync-runtime-helper-names))

;; event-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given event helper names from the runtime helper index.
(define (event-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; event-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted event helpers in runtime assembly order.
(define (event-core-runtime-helper-forms helper-index)
  (event-helper-forms helper-index event-promoted-runtime-helper-names))

;; event-channel-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render channel and event helpers in runtime assembly order.
(define (event-channel-runtime-helper-forms helper-index)
  (event-helper-forms helper-index event-channel-runtime-only-helper-names))

;; event-sync-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render event synchronization helpers in runtime assembly order.
(define (event-sync-runtime-helper-forms helper-index)
  (event-helper-forms helper-index event-sync-runtime-only-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define event-core-helper-index
    (make-core-runtime-helper-index event-core-runtime-helpers))

  (define event-helper-index
    (make-core-runtime-helper-index
     (append event-core-runtime-helpers
             event-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name event-core-runtime-helpers)
   event-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (event-core-runtime-helper-forms event-core-helper-index))
   event-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (event-channel-runtime-helper-forms event-helper-index))
   event-channel-runtime-only-helper-names)

  (check-equal?
   (map form-name (event-sync-runtime-helper-forms event-helper-index))
   event-sync-runtime-only-helper-names))
