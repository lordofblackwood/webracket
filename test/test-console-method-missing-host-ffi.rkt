#lang webracket/base

;; Browser smoke for console FFI degraded-host behavior.

(require js/console
         (only-in webracket/unsafe/standard
                  js-eval
                  js-ref
                  js-var))

(define (check-equal got want label)
  (unless (equal? got want)
    (error 'check-equal (format "~a: got ~s want ~s" label got want))))

(define (check-false got label)
  (when got
    (error 'check-false label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(define (check-no-error thunk label)
  (check-false (catch-message thunk) label))

(define calls
  (let ()
    (js-eval
     "globalThis.__wrConsoleBoundarySaved = globalThis.console;
      globalThis.console = {
        calls: [],
        log(...args) { this.calls.push(['log', ...args]); }
      };")
    (check-no-error (lambda () (console-info "info"))
                    "missing console.info")
    (check-no-error (lambda () (console-warn "warn"))
                    "missing console.warn")
    (check-no-error (lambda () (console-error "error"))
                    "missing console.error")
    (check-no-error (lambda () (console-debug "debug"))
                    "missing console.debug")
    (check-no-error (lambda () (console-dir "dir"))
                    "missing console.dir")
    (check-no-error (lambda () (console-dirxml "dirxml"))
                    "missing console.dirxml")
    (check-no-error (lambda () (console-table "table"))
                    "missing console.table")
    (check-no-error (lambda () (console-group "group"))
                    "missing console.group")
    (check-no-error (lambda () (console-group-collapsed "collapsed"))
                    "missing console.groupCollapsed")
    (check-no-error (lambda () (console-count 'hits))
                    "missing console.count")
    (check-no-error (lambda () (console-trace "trace"))
                    "missing console.trace")
    (check-no-error (lambda () (console-clear))
                    "missing console.clear")
    (check-no-error (lambda () (console-group-end))
                    "missing console.groupEnd")
    (check-no-error (lambda () (console-time 'phase))
                    "missing console.time")
    (check-no-error (lambda () (console-time-end 'phase))
                    "missing console.timeEnd")
    (check-no-error (lambda () (console-time-log 'phase "step"))
                    "missing console.timeLog")
    (check-no-error (lambda () (console-profile 'profile))
                    "missing console.profile")
    (check-no-error (lambda () (console-profile-end 'profile))
                    "missing console.profileEnd")
    (check-no-error (lambda () (console-exception "exception"))
                    "missing console.exception")
    (define calls (js-ref (js-var "console") "calls"))
    (js-eval
     "globalThis.console = globalThis.__wrConsoleBoundarySaved;
      delete globalThis.__wrConsoleBoundarySaved;")
    calls))

(check-equal calls
             (vector (vector "log" "info")
                     (vector "log" "warn")
                     (vector "log" "error")
                     (vector "log" "debug")
                     (vector "log" "dir")
                     (vector "log" "dirxml")
                     (vector "log" "table")
                     (vector "log" "group")
                     (vector "log" "collapsed")
                     (vector "log" "hits")
                     (vector "log" "trace"))
             "console fallback calls")

(define js-log-calls
  (let ()
    (js-eval
     "globalThis.__wrConsoleBoundarySaved = globalThis.console;
      globalThis.console = {
        calls: [],
        log(...args) { this.calls.push(['log', ...args]); }
      };")
    (check-no-error (lambda () (js-log "js-log fallback"))
                    "js-log missing console.error")
    (define calls (js-ref (js-var "console") "calls"))
    (js-eval "globalThis.console = undefined;")
    (check-no-error (lambda () (js-log "js-log no console"))
                    "js-log missing console object")
    (js-eval
     "globalThis.console = globalThis.__wrConsoleBoundarySaved;
      delete globalThis.__wrConsoleBoundarySaved;")
    calls))

(check-equal js-log-calls
             (vector (vector "log" "js-log fallback"))
             "js-log console fallback calls")

(js-log "console-method-missing-host-ffi-ok")
#t
