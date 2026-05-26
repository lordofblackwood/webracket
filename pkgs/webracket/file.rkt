#lang racket/base

(require (only-in "primitives.rkt"
                  call-with-input-file
                  call-with-input-file*
                  call-with-output-file
                  call-with-output-file*
                  copy-directory/files
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
                  with-input-from-file
                  with-output-to-file))

(provide call-with-input-file
         call-with-input-file*
         call-with-output-file
         call-with-output-file*
         copy-directory/files
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
         with-input-from-file
         with-output-to-file)

;; A small `racket/file` substitute for Goal 1 module programs. It exposes the
;; file helpers that are already backed by WebRacket's virtual filesystem
;; primitives. OS-specific helpers such as file locks and preferences remain
;; intentionally absent.
