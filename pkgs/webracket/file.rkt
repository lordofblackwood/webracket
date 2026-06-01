#lang racket/base

(require (only-in "primitives.rkt"
                  call-with-input-file
                  call-with-input-file*
                  call-with-output-file
                  call-with-output-file*
                  copy-directory/files
                  delete-directory/files
                  display-lines-to-file
                  display-to-file
                  file->bytes
                  file->bytes-lines
                  file->lines
                  file->string
                  file-exists?
                  make-directory*
                  make-parent-directory*
                  make-temporary-directory
                  make-temporary-directory*
                  make-temporary-file
                  make-temporary-file*
                  read
                  with-input-from-file
                  with-output-to-file)
         (only-in "private/format.rkt"
                  [format wr-format]))

(provide block-device-type-bits
         call-with-atomic-output-file
         call-with-input-file
         call-with-input-file*
         call-with-output-file
         call-with-output-file*
         character-device-type-bits
         copy-directory/files
         delete-directory/files
         directory-type-bits
         display-lines-to-file
         display-to-file
         fifo-type-bits
         file->bytes
         file->bytes-lines
         file->lines
         file->list
         file->string
         file->value
         file-exists?
         file-type-bits
         group-execute-bit
         group-permission-bits
         group-read-bit
         group-write-bit
         make-directory*
         make-parent-directory*
         make-temporary-directory
         make-temporary-directory*
         make-temporary-file
         make-temporary-file*
         other-execute-bit
         other-permission-bits
         other-read-bit
         other-write-bit
         regular-file-type-bits
         set-group-id-bit
         set-user-id-bit
         socket-type-bits
         sticky-bit
         symbolic-link-type-bits
         user-execute-bit
         user-permission-bits
         user-read-bit
         user-write-bit
         with-input-from-file
         with-output-to-file
         write-to-file)

;; A small `racket/file` substitute for Goal 1 module programs. It exposes the
;; file helpers that are already backed by WebRacket's virtual filesystem
;; primitives. OS-specific helpers such as file locks and preferences remain
;; intentionally absent.

(define block-device-type-bits 24576)
(define character-device-type-bits 8192)
(define directory-type-bits 16384)
(define fifo-type-bits 4096)
(define file-type-bits 61440)
(define regular-file-type-bits 32768)
(define socket-type-bits 49152)
(define symbolic-link-type-bits 40960)
(define user-read-bit 256)
(define user-write-bit 128)
(define user-execute-bit 64)
(define user-permission-bits 448)
(define group-read-bit 32)
(define group-write-bit 16)
(define group-execute-bit 8)
(define group-permission-bits 56)
(define other-read-bit 4)
(define other-write-bit 2)
(define other-execute-bit 1)
(define other-permission-bits 7)
(define set-user-id-bit 2048)
(define set-group-id-bit 1024)
(define sticky-bit 512)

;; file->value : path-string? [symbol?] -> any/c
;;   Read one datum from a file; mode defaults to binary.
(define file->value
  (case-lambda
    [(path) (file->value path 'binary)]
    [(path mode)
     (call-with-input-file path read mode)]))

;; file->list : path-string? [procedure?] [symbol?] -> list?
;;   Repeatedly read values from a file until EOF.
(define file->list
  (case-lambda
    [(path) (file->list path read 'binary)]
    [(path proc) (file->list path proc 'binary)]
    [(path proc mode)
     (unless (procedure? proc)
       (raise-argument-error 'file->list "procedure?" proc))
     (call-with-input-file
      path
      (lambda (in)
        (let loop ([acc null])
          (define v (proc in))
          (if (eof-object? v)
              (reverse acc)
              (loop (cons v acc)))))
      mode)]))

;; write-to-file : any/c path-string? [symbol?] [symbol?] -> void?
;;   Write a value to a file; mode defaults to binary and exists to error.
(define write-to-file
  (case-lambda
    [(v path) (write-to-file v path 'binary 'error)]
    [(v path mode) (write-to-file v path mode 'error)]
    [(v path mode exists)
     (call-with-output-file
      path
      (lambda (out) (display (wr-format "~s" v) out))
      mode
      exists)]))

;; call-with-atomic-output-file : path-string? procedure? -> any/c
;;   Browser/VFS version: call proc with an output port for path directly.
(define (call-with-atomic-output-file file proc
                                      #:security-guard [security-guard #f]
                                      #:rename-fail-handler [rename-fail-handler #f])
  (unless (procedure? proc)
    (raise-argument-error 'call-with-atomic-output-file "procedure?" proc))
  (call-with-output-file
   file
   (lambda (out) (proc out file))
   'binary
   'replace))
