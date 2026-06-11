#lang racket

;; This file keeps the historical `webracket.rkt` entrypoint stable while
;; delegating the real work to the shared CLI library and optional compile
;; server client. In the bigger picture it is the thin compatibility layer that
;; preserves the user-facing launcher while letting the compiler grow a warm
;; daemon path behind the same command-line interface.

(require "cli-lib.rkt"
         "client.rkt"
         "compile-server-common.rkt")

;; compile-server-enabled? : -> boolean?
;;   Respect WEBRACKET_COMPILE_SERVER for ordinary compile requests.
(define (compile-server-enabled?)
  (string-true-value? (getenv "WEBRACKET_COMPILE_SERVER")))

;; main : -> void?
;;   Parse the command line and dispatch locally or through the compile server.
(define (main)
  (define command (parse-webracket-cli))
  (define exit-code
    (match (webracket-cli-command-kind command)
      ['server-start
       (run-compile-server-foreground)
       0]
      ['server-status
       (define status (compile-server-status))
       (printf "running:\t~a\n" (if (compile-server-status-info-running? status) "yes" "no"))
       (printf "port:\t~a\n" (or (compile-server-status-info-port status) "-"))
       (printf "pid:\t~a\n" (or (compile-server-status-info-pid status) "-"))
       (printf "state-dir:\t~a\n" (path->string (compile-server-status-info-state-dir status)))
       (printf "log:\t~a\n" (path->string (compile-server-status-info-log-path status)))
       0]
      ['server-stop
       (define stopped? (stop-compile-server!))
       (printf "stopped:\t~a\n" (if stopped? "yes" "no"))
       0]
      ['compile
       (if (compile-server-enabled?)
           (run-webracket-compile-via-server
            (webracket-cli-command-payload command))
           (run-webracket-cli-command command))]
      [_
       (run-webracket-cli-command command)]))
  (unless (zero? exit-code)
    (exit exit-code)))

(main)
