#lang webracket/base

;; Browser smoke for Clipboard wrapper host-method boundary errors.

(require clipboard
         (only-in webracket/unsafe/standard
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
 "globalThis.__wrClipboardBoundaryFake = (missing) => {
    const thenable = {
      then(fn) { fn(undefined); return this; },
      catch(_fn) { return this; }
    };
    const clip = {
      readText() { return thenable; },
      writeText(_text) { return thenable; }
    };
    delete clip[missing];
    return clip;
  };")

(define (fake-clipboard missing)
  (clipboard-info (js-eval (string-append "__wrClipboardBoundaryFake('"
                                          missing
                                          "')"))))

(define missing-read-clipboard
  (fake-clipboard "readText"))

(define missing-write-clipboard
  (fake-clipboard "writeText"))

(check-true (not (clipboard? missing-read-clipboard))
            "clipboard? rejects missing readText")
(check-true (not (clipboard? missing-write-clipboard))
            "clipboard? rejects missing writeText")

(define read-message
  (catch-message
   (lambda ()
     (clipboard-read-text missing-read-clipboard))))

(define write-message
  (catch-message
   (lambda ()
     (clipboard-write-text! missing-write-clipboard "text"))))

(define invalid-raw-message
  (catch-message
   (lambda ()
     (clipboard-read-text (clipboard-info #f)))))

(check-message read-message
               "Clipboard.readText is not available"
               "missing Clipboard.readText message")
(check-message write-message
               "Clipboard.writeText is not available"
               "missing Clipboard.writeText message")
(check-message invalid-raw-message
               "clipboard-info?"
               "missing clipboard-info invalid raw message")

(js-eval "delete globalThis.__wrClipboardBoundaryFake;")

(js-log "clipboard-method-missing-host-ffi-ok")
#t
