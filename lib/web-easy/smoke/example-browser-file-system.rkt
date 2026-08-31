#lang webracket/base

(require browser/dom
         file-system
         js/promise)

(define (set-status! text)
  (js-set! (js-document-body) "textContent" text))

(define (run-file-system-smoke!)
  (define handle #f)
  (define writable #f)
  (define (promise-failed _reason)
    (set-status! "FAIL: a File System API Promise was rejected")
    (void))
  (define (finish-text text)
    (if (string=? text "static file-system smoke")
        (set-status! "PASS: static file-system OPFS round trip")
        (set-status! "FAIL: unexpected file text"))
    (void))
  (define (finish-file raw-file)
    (define file (file-system-file-wrap raw-file))
    (unless (and (string=? (file-system-file-name file) "file-system-smoke.txt")
                 (= (file-system-file-size file) 24))
      (set-status! "FAIL: file metadata did not match the written file"))
    (js-promise-then (file-system-file-text file)
                     finish-text
                     promise-failed)
    (void))
  (define (finish-close _ignored)
    (js-promise-then (file-system-file-handle-get-file handle)
                     finish-file
                     promise-failed)
    (void))
  (define (finish-truncate _ignored)
    (js-promise-then (file-system-writable-file-stream-close writable)
                     finish-close
                     promise-failed)
    (void))
  (define (finish-rewrite _ignored)
    (js-promise-then (file-system-writable-file-stream-truncate writable 24)
                     finish-truncate
                     promise-failed)
    (void))
  (define (finish-seek _ignored)
    (js-promise-then (file-system-writable-file-stream-write writable "static")
                     finish-rewrite
                     promise-failed)
    (void))
  (define (finish-write _ignored)
    (js-promise-then (file-system-writable-file-stream-seek writable 0)
                     finish-seek
                     promise-failed)
    (void))
  (define (finish-writable raw-stream)
    (set! writable (file-system-writable-file-stream-wrap raw-stream))
    (js-promise-then (file-system-writable-file-stream-write
                      writable
                      "static file-system smoke")
                     finish-write
                     promise-failed)
    (void))
  (define (finish-handle raw-handle)
    (set! handle (file-system-file-handle-wrap raw-handle))
    (js-promise-then (file-system-file-handle-create-writable handle)
                     finish-writable
                     promise-failed)
    (void))
  (define (finish-directory raw-directory)
    (define directory (file-system-directory-handle-wrap raw-directory))
    (js-promise-then (file-system-directory-get-file-handle
                      directory
                      "file-system-smoke.txt"
                      #t)
                     finish-handle
                     promise-failed)
    (void))
  (js-promise-then (file-system-origin-private-directory)
                   finish-directory
                   promise-failed)
  (void))

(if (file-system-supported?)
    (run-file-system-smoke!)
    (set-status! "FAIL: File System API OPFS support is unavailable."))
