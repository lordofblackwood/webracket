#lang racket

;; This file implements the long-lived local compile daemon.
;; It keeps one Racket process warm, accepts token-guarded localhost requests,
;; runs the same shared compile path used by the ordinary CLI, and returns
;; structured results so we can remove startup and module-load cost without
;; forking compiler behavior.

(require racket/cmdline
         racket/file
         racket/format
         racket/match
         racket/port
         racket/tcp
         "cli-lib.rkt"
         "compile-server-common.rkt"
         "driver.rkt")

(provide main)

;; make-server-token : -> string?
;;   Build a cheap local-only bearer token for client requests.
(define (make-server-token)
  (format "~x-~x-~x"
          (inexact->exact (floor (current-inexact-milliseconds)))
          (random (expt 2 30))
          (random (expt 2 30))))

;; state-datum : exact-positive-integer? string? -> list?
;;   Build the persisted server metadata.
(define (state-datum port token)
  `((port . ,port)
    (token . ,token)
    (pid . "unknown")))

;; write-state! : path-string? exact-positive-integer? string? -> void?
;;   Persist the active server metadata.
(define (write-state! state-dir port token)
  (make-directory* state-dir)
  (with-output-to-file (server-state-path state-dir)
    (lambda ()
      (write (state-datum port token))
      (newline))
    #:exists 'replace))

;; try-listen : exact-positive-integer? exact-nonnegative-integer? boolean? -> (values tcp-listener? exact-positive-integer?)
;;   Bind localhost on the first free port in the configured range.
(define (try-listen start-port attempts reuse?)
  (let loop ([port start-port]
             [remaining attempts])
    (when (negative? remaining)
      (error 'webracket-server "unable to bind compile server near port ~a" start-port))
    (with-handlers ([exn:fail:network?
                     (lambda (_e)
                       (loop (add1 port) (sub1 remaining)))])
      (values (tcp-listen port 4 reuse? "127.0.0.1") port))))

;; valid-token? : any/c string? -> boolean?
;;   Check whether the request token matches the server token.
(define (valid-token? got expected)
  (and (string? got) (string=? got expected)))

;; response-error : string? string? string? [any/c] -> list?
;;   Format a structured error response.
(define (response-error message stdout stderr [elapsed-ms #f])
  `(error
    ((message . ,message)
     (stdout . ,stdout)
     (stderr . ,stderr)
     (elapsed-ms . ,elapsed-ms))))

;; compile-response : webracket-compile-config? -> list?
;;   Run one compile request and return the protocol response.
(define (compile-response cfg)
  (define stdout-port (open-output-string))
  (define stderr-port (open-output-string))
  (define start-ms (current-inexact-milliseconds))
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (response-error (exn-message e)
                                     (get-output-string stdout-port)
                                     (get-output-string stderr-port)
                                     (- (current-inexact-milliseconds) start-ms)))])
    (parameterize ([current-output-port stdout-port]
                   [current-error-port stderr-port])
      (call-with-webracket-collection-paths
       (lambda ()
         (define-values (exit-code timings output-paths)
           (run-webracket-compile cfg))
         `(ok
           ((exit-code . ,exit-code)
            (wat . ,(path->string (compilation-output-paths-wat output-paths)))
            (wasm . ,(path->string (compilation-output-paths-wasm output-paths)))
            (map . ,(path->string (compilation-output-paths-map output-paths)))
            (host . ,(path->string (compilation-output-paths-host output-paths)))
            (stdout . ,(get-output-string stdout-port))
            (stderr . ,(get-output-string stderr-port))
            (elapsed-ms . ,(if timings
                               (compilation-timings-driver-total timings)
                               (- (current-inexact-milliseconds) start-ms))))))))))

;; handle-request : any/c string? -> list?
;;   Validate and answer one client request.
(define (handle-request request token)
  (match request
    [`(ping ,request-token)
     (if (valid-token? request-token token)
         '(pong ((pid . "unknown")))
         (response-error "unauthorized ping" "" ""))]
    [`(compile ,request-token ,cfg-datum)
     (if (valid-token? request-token token)
         (compile-response (datum->compile-config cfg-datum))
         (response-error "unauthorized compile request" "" ""))]
    [`(stop ,request-token)
     (if (valid-token? request-token token)
         '(stopping ())
         (response-error "unauthorized stop request" "" ""))]
    [_ (response-error "unrecognized request" "" "")]))

;; serve-forever : tcp-listener? string? path-string? boolean? -> void?
;;   Accept one request per connection until a stop command arrives.
(define (serve-forever listener token state-dir verbose?)
  (let loop ()
    (define-values (in out) (tcp-accept listener))
    (define request
      (with-handlers ([exn:fail? (lambda (e)
                                   `(invalid-request ,(exn-message e)))])
        (read in)))
    (define response (handle-request request token))
    (when verbose?
      (fprintf (current-error-port) "webracket-server: ~s -> ~s\n" request (car response)))
    (write response out)
    (newline out)
    (flush-output out)
    (close-input-port in)
    (close-output-port out)
    (if (eq? (car response) 'stopping)
        (begin
          (with-handlers ([exn:fail:filesystem? void])
            (delete-file (server-state-path state-dir)))
          (tcp-close listener))
        (loop))))

;; main : [vector?] -> void?
;;   Start the long-lived compile server.
(define (main [argv (current-command-line-arguments)])
  (define state-dir (default-compile-server-state-dir))
  (define start-port (default-compile-server-port))
  (define verbose? #f)
  (command-line
   #:program "webracket-server"
   #:argv argv
   #:once-each
   [("--state-dir") dir "Use <dir> for server state files"
                    (set! state-dir dir)]
   [("--port") port-string "Start scanning for a free port at <port>"
               (define maybe-port (string->number port-string))
               (unless (and maybe-port (exact-integer? maybe-port) (<= 1 maybe-port 65535))
                 (error 'webracket-server "expected port in [1, 65535], got: ~a" port-string))
               (set! start-port maybe-port)]
   [("--verbose") "Log request summaries to stderr"
                  (set! verbose? #t)]
   #:args ()
   (void))
  (define token (make-server-token))
  (define log-path (server-log-path state-dir))
  (make-directory* state-dir)
  (define log-port (open-output-file log-path #:exists 'append))
  (parameterize ([current-output-port log-port]
                 [current-error-port log-port])
    (define-values (listener actual-port)
      (try-listen start-port 32 #t))
    (write-state! state-dir actual-port token)
    (when verbose?
      (fprintf (current-error-port)
               "webracket-server: listening on 127.0.0.1:~a state=~a\n"
               actual-port
               (server-state-path state-dir)))
    (serve-forever listener token state-dir verbose?)))

(module+ main
  (main))
