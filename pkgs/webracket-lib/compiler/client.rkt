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
         racket/string
         racket/tcp
         "cli-lib.rkt"
         "compile-server-common.rkt"
         (prefix-in server: "server.rkt"))

(provide main
         (struct-out compile-server-status-info)
         compile-server-status
         run-compile-server-foreground
         run-webracket-compile-via-server
         start-compile-server!
         stop-compile-server!)

(define-runtime-path server-path "server.rkt")

(define compile-server-startup-attempts 480)

(struct compile-server-status-info
  (running?  ; whether a responsive compile server is available
   port      ; listening TCP port when running, otherwise #f
   pid       ; persisted process identifier placeholder, when available
   state-dir ; temp-directory root for server state and logs
   log-path  ; log file path for startup and request diagnostics
   )
  #:transparent)

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

;; status-info : boolean? any/c any/c path-string? -> compile-server-status-info?
;;   Build one status record for display and tests.
(define (status-info running? port pid state-dir)
  (compile-server-status-info running?
                              port
                              pid
                              (path->complete-path state-dir)
                              (server-log-path state-dir)))

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

;; find-racket-executable : path? path? -> path?
;;   Prefer Racket's executable path over the script being run.
(define (find-racket-executable exec-file run-file)
  (or (find-executable-path (path->string exec-file))
      (find-executable-path (path->string run-file))
      (find-executable-path "racket")
      (error 'webracket-client "unable to locate a racket executable")))

;; current-racket-executable : -> path?
;;   Return the active Racket executable for spawning the server.
(define (current-racket-executable)
  (find-racket-executable (find-system-path 'exec-file)
                          (find-system-path 'run-file)))

;; compiled-roots-env-variable : (or/c string? #f) -> (or/c string? #f)
;;   Encode a configured compiled-root path for the server environment.
(define (compiled-roots-env-variable roots)
  (and roots (string-append "PLTCOMPILEDROOTS=" roots)))

;; shell-quote : string? -> string?
;;   Quote one string for a POSIX shell command.
(define (shell-quote s)
  (string-append "'"
                 (regexp-replace* #px"'" s "'\"'\"'")
                 "'"))

;; launch-background-command! : string? -> void?
;;   Launch cmd detached from this client process.
(define (launch-background-command! cmd)
  (define ok?
    (cond
      [(eq? (system-type 'os) 'macosx)
       (system* "/usr/bin/osascript"
                "-e"
                (format "do shell script ~s" cmd))]
      [else
       (system* "/bin/sh" "-c" cmd)]))
  (unless ok?
    (error 'webracket-client "failed to launch compile server")))

;; launchctl-label : path-string? -> string?
;;   Build a stable launchd label for one server state directory.
(define (launchctl-label state-dir)
  (format "org.webracket.compile-server.~a"
          (abs (equal-hash-code
                (path->string (path->complete-path state-dir))))))

;; start-server! : path-string? -> void?
;;   Spawn the long-lived compile server in the background.
(define (start-server! state-dir)
  (make-directory* state-dir)
  (define compiled-roots-env
    (compiled-roots-env-variable (getenv "PLTCOMPILEDROOTS")))
  (define state-dir-string
    (path->string (path->complete-path state-dir)))
  (define log-path
    (path->string (path->complete-path (server-log-path state-dir))))
  (cond
    [(eq? (system-type 'os) 'macosx)
     (define label (launchctl-label state-dir))
     (with-handlers ([exn:fail? void])
       (system* "/bin/launchctl" "remove" label))
     (unless (apply system*
                    (append (list "/bin/launchctl"
                                  "submit"
                                  "-l" label
                                  "-o" log-path
                                  "-e" log-path
                                  "--"
                                  "/usr/bin/env"
                                  (string-append "PLTCOLLECTS="
                                                 (webracket-collection-env-value)))
                            (if compiled-roots-env
                                (list compiled-roots-env)
                                null)
                            (list (path->string (current-racket-executable))
                                  (path->string server-path)
                                  "--state-dir"
                                  state-dir-string)))
       (error 'webracket-client "failed to launch compile server"))]
    [else
     (define start-command
       (format "PLTCOLLECTS=~a~a nohup ~a ~a --state-dir ~a >> ~a 2>&1 </dev/null &"
               (shell-quote (webracket-collection-env-value))
               (if compiled-roots-env
                   (string-append " " (shell-quote compiled-roots-env))
                   "")
               (shell-quote (path->string (current-racket-executable)))
               (shell-quote (path->string server-path))
               (shell-quote state-dir-string)
               (shell-quote log-path)))
     (launch-background-command! start-command)]))

;; compile-server-status : [path-string?] -> compile-server-status-info?
;;   Report whether the local compile server is alive and where its state lives.
(define (compile-server-status [state-dir (default-compile-server-state-dir)])
  (define state (read-server-state state-dir))
  (cond
    [(ping-server? state)
     (status-info #t
                  (state-ref state 'port)
                  (state-ref state 'pid)
                  state-dir)]
    [state
     (delete-server-state! state-dir)
     (status-info #f #f (state-ref state 'pid) state-dir)]
    [else
     (status-info #f #f #f state-dir)]))

;; wait-for-server! : path-string? -> list?
;;   Poll the state file until the server responds to ping.
(define (wait-for-server! state-dir)
  (let loop ([remaining compile-server-startup-attempts])
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

;; start-compile-server! : [path-string?] -> compile-server-status-info?
;;   Ensure the local compile server is running and return its status.
(define (start-compile-server! [state-dir (default-compile-server-state-dir)])
  (ensure-server-state! state-dir)
  (compile-server-status state-dir))

;; stop-compile-server! : [path-string?] -> boolean?
;;   Stop the local compile server when it is running and report whether one was stopped.
(define (stop-compile-server! [state-dir (default-compile-server-state-dir)])
  (define state (read-server-state state-dir))
  (define label (launchctl-label state-dir))
  (cond
    [(ping-server? state)
     (with-handlers ([exn:fail:network? void]
                     [exn:fail? void])
       (request-server state `(stop ,(state-ref state 'token))))
     (when (eq? (system-type 'os) 'macosx)
     (with-handlers ([exn:fail? void])
         (system* "/bin/launchctl" "remove" label)))
     (let loop ([remaining 40])
       (define status (compile-server-status state-dir))
       (cond
         [(not (compile-server-status-info-running? status)) #t]
         [(zero? remaining) #t]
         [else
         (sleep 0.1)
          (loop (sub1 remaining))]))]
    [else
     (when (eq? (system-type 'os) 'macosx)
       (with-handlers ([exn:fail? void])
         (system* "/bin/launchctl" "remove" label)))
     (delete-server-state! state-dir)
     #f]))

;; display-server-status : compile-server-status-info? -> void?
;;   Print a compact human-readable server status summary.
(define (display-server-status status)
  (printf "running:\t~a\n" (if (compile-server-status-info-running? status) "yes" "no"))
  (printf "port:\t~a\n" (or (compile-server-status-info-port status) "-"))
  (printf "pid:\t~a\n" (or (compile-server-status-info-pid status) "-"))
  (printf "state-dir:\t~a\n" (path->string (compile-server-status-info-state-dir status)))
  (printf "log:\t~a\n" (path->string (compile-server-status-info-log-path status))))

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

;; run-compile-server-foreground : -> void?
;;   Run the compile server in the current process until it is stopped.
(define (run-compile-server-foreground)
  (server:main #()))

(module+ test
  (require rackunit)

  (test-case "compile-server launcher prefers the Racket executable"
    (define racket-executable (find-system-path 'exec-file))
    (define wrapper-script (build-path (current-directory) "webracket.rkt"))
    (check-equal? (find-racket-executable racket-executable wrapper-script)
                  (find-executable-path (path->string racket-executable))))

  (test-case "compile-server launcher preserves compiled roots"
    (check-equal? (compiled-roots-env-variable "/tmp/compiled")
                  "PLTCOMPILEDROOTS=/tmp/compiled")
    (check-false (compiled-roots-env-variable #f))))

;; main : -> void?
;;   Parse ordinary CLI arguments and execute them through the compile server when relevant.
(define (main)
  (define command (parse-webracket-cli))
  (define exit-code
    (match (webracket-cli-command-kind command)
      ['server-start
       (run-compile-server-foreground)
       0]
      ['server-status
       (display-server-status (compile-server-status))
       0]
      ['server-stop
       (define stopped? (stop-compile-server!))
       (printf "stopped:\t~a\n" (if stopped? "yes" "no"))
       0]
      ['compile
       (run-webracket-compile-via-server (webracket-cli-command-payload command))]
      [_ (run-webracket-cli-command command)]))
  (unless (zero? exit-code)
    (exit exit-code)))

(module+ main
  (main))
