#lang racket

;; This file implements the client-side bridge to the long-lived compile
;; server. It finds or starts the local daemon, pings it, forwards the shared
;; compile-config request, and relays buffered stdout/stderr back to the user so
;; `webracket.rkt` can opportunistically use the warm process without changing
;; its ordinary command-line surface.

(require racket/file
         racket/match
         racket/path
         racket/port
         racket/runtime-path
         racket/system
         racket/tcp
         "cli-lib.rkt"
         "compile-server-common.rkt")

(provide main
         run-webracket-compile-via-server)

(define-runtime-path server-path "server.rkt")

;; read-server-state : path-string? -> (or/c list? #f)
;;   Read the current server metadata if it exists and is parseable.
(define (read-server-state state-dir)
  (define path (server-state-path state-dir))
  (and (file-exists? path)
       (with-handlers ([exn:fail? (lambda (_e) #f)])
         (call-with-input-file path read))))

;; state-ref : list? symbol? -> any/c
;;   Lookup key in the persisted server metadata.
(define (state-ref state key)
  (define a (assq key state))
  (and a (cdr a)))

;; delete-server-state! : path-string? -> void?
;;   Remove the cached state file if it exists.
(define (delete-server-state! state-dir)
  (with-handlers ([exn:fail:filesystem? void])
    (delete-file (server-state-path state-dir))))

;; request-server : list? list? -> datum?
;;   Send request to the active server and read one response.
(define (request-server state request)
  (define-values (in out)
    (tcp-connect "127.0.0.1" (state-ref state 'port)))
  (write request out)
  (newline out)
  (flush-output out)
  (define response (read in))
  (close-input-port in)
  (close-output-port out)
  response)

;; ping-server? : list? -> boolean?
;;   Check whether the current state points to a live server.
(define (ping-server? state)
  (and state
       (with-handlers ([exn:fail:network? (lambda (_e) #f)]
                       [exn:fail? (lambda (_e) #f)])
         (match (request-server state `(ping ,(state-ref state 'token)))
           [`(pong ,_) #t]
           [_ #f]))))

;; current-racket-executable : -> path?
;;   Return the active Racket executable for spawning the server.
(define (current-racket-executable)
  (or (find-executable-path (path->string (find-system-path 'run-file)))
      (find-executable-path (path->string (find-system-path 'exec-file)))
      (find-executable-path "racket")
      (error 'webracket-client "unable to locate a racket executable")))

;; start-server! : path-string? -> void?
;;   Spawn the long-lived compile server in the background.
(define (start-server! state-dir)
  (make-directory* state-dir)
  (define log-port (open-output-file (server-log-path state-dir) #:exists 'append))
  (subprocess log-port
              (open-input-file "/dev/null")
              log-port
              "/usr/bin/env"
              (string-append "PLTCOLLECTS=" (webracket-collection-env-value))
              (path->string (current-racket-executable))
              (path->string server-path)
              "--state-dir"
              (path->string (path->complete-path state-dir))))

;; wait-for-server! : path-string? -> list?
;;   Poll the state file until the server responds to ping.
(define (wait-for-server! state-dir)
  (let loop ([remaining 120])
    (define state (read-server-state state-dir))
    (cond
      [(and state (ping-server? state)) state]
      [(zero? remaining)
       (error 'webracket-client
              "compile server did not become ready; see ~a"
              (server-log-path state-dir))]
      [else
       (sleep 0.25)
       (loop (sub1 remaining))])))

;; ensure-server-state! : path-string? -> list?
;;   Reuse a live server or start a new one.
(define (ensure-server-state! state-dir)
  (define state (read-server-state state-dir))
  (cond
    [(ping-server? state) state]
    [else
     (delete-server-state! state-dir)
     (start-server! state-dir)
     (wait-for-server! state-dir)]))

;; print-response-output! : list? -> void?
;;   Relay buffered stdout/stderr from the server back to the caller.
(define (print-response-output! fields)
  (define stdout (cdr (assq 'stdout fields)))
  (define stderr (cdr (assq 'stderr fields)))
  (when (and (string? stdout) (not (string=? stdout "")))
    (display stdout))
  (when (and (string? stderr) (not (string=? stderr "")))
    (display stderr (current-error-port))))

;; run-webracket-compile-via-server : webracket-compile-config? -> exact-integer?
;;   Auto-start the local compile server, run cfg through it, and return its exit code.
(define (run-webracket-compile-via-server cfg)
  (define state-dir (default-compile-server-state-dir))
  (define state (ensure-server-state! state-dir))
  (define response
    (with-handlers ([exn:fail:network?
                     (lambda (_e)
                       (delete-server-state! state-dir)
                       (define restarted (ensure-server-state! state-dir))
                       (request-server restarted
                                       `(compile ,(state-ref restarted 'token)
                                                 ,(compile-config->datum cfg))))])
      (request-server state
                      `(compile ,(state-ref state 'token)
                                ,(compile-config->datum cfg)))))
  (match response
    [`(ok ,fields)
     (print-response-output! fields)
     (cdr (assq 'exit-code fields))]
    [`(error ,fields)
     (print-response-output! fields)
     (error 'webracket-client "~a" (cdr (assq 'message fields)))]
    [_ (error 'webracket-client "unexpected response from compile server: ~s" response)]))

;; main : -> void?
;;   Parse ordinary CLI arguments and execute them through the compile server when relevant.
(define (main)
  (define command (parse-webracket-cli))
  (define exit-code
    (match (webracket-cli-command-kind command)
      ['compile
       (run-webracket-compile-via-server (webracket-cli-command-payload command))]
      [_ (run-webracket-cli-command command)]))
  (unless (zero? exit-code)
    (exit exit-code)))

(module+ main
  (main))
