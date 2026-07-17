#lang webracket/base

(require clipboard
         js/promise
         (only-in webracket/unsafe/standard
                  js-eval
                  js-ref
                  js-var))

;; Focused tests for the module-based clipboard wrapper.

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-equal got want label)
  (unless (equal? got want)
    (error 'check-equal (format "~a: got ~s want ~s" label got want))))

(define (install!)
  (js-eval
   "window.__clipboardTest = { writes: [], reads: [] };
    Object.defineProperty(window.navigator, 'clipboard', {
      configurable: true,
      value: {
        readText() {
          window.__clipboardTest.reads.push('read');
          return { tag: 'read-promise', then(fn) { fn('mock text'); return this; }, catch(_fn) { return this; } };
        },
        writeText(text) {
          window.__clipboardTest.writes.push(text);
          return { tag: 'write-promise', then(fn) { fn(undefined); return this; }, catch(_fn) { return this; } };
        }
      }
    });"))

(install!)

(define clip (clipboard))
(check-true (clipboard-supported?) "clipboard should be reported as supported")
(check-true clip "clipboard getter should produce a wrapped value")
(check-true (clipboard? clip) "clipboard predicate")

(define write-promise (clipboard-write-text! clip 'copied-symbol))
(define read-promise  (clipboard-read-text clip))

(check-true (js-promise-thenable? write-promise) "writeText should return a wrapped promise")
(check-true (js-promise-thenable? read-promise) "readText should return a wrapped promise")
(check-equal (js-ref (js-promise-unwrap write-promise) "tag") "write-promise" "write promise tag")
(check-equal (js-ref (js-promise-unwrap read-promise) "tag") "read-promise" "read promise tag")
(check-equal (vector-ref (js-ref (js-var "__clipboardTest") "writes") 0)
             "copied-symbol"
             "writeText payload")
(check-equal (vector-ref (js-ref (js-var "__clipboardTest") "reads") 0)
             "read"
             "readText call")

#t
