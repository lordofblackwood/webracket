#lang racket

(provide memory-import-forms
         memory-map-global-forms
         memory-map-global-names)

;; memory-import-forms : (listof datum?)
;;   Declare the single imported linear memory used by generated modules.
(define memory-import-forms
  '(
         (import "env" "memory" (memory $memory 1024))))

;; memory-map-global-forms : (listof datum?)
;;   Declare the static host bridge scratch memory map.
(define memory-map-global-forms
  '(
         ;;;
         ;;; Memory Map
         ;;;

         ;; Currently (June 2005) the proposal for multiple memories aren't supported
         ;; by Safari (WebKit). Therefore, we are forced to using a single memory only.

         ;; The following memory map is used to segment the linear memory.

         ;; Static host bridge scratch map:
         ;;   0..1MiB        VFS file transfer buffer
         ;;   +4KiB          VFS path buffer
         ;;   +16MiB         callback/FASL/string scratch buffer
         (global $memory-map:vfs-file-buffer-base   (mut i32) (i32.const 0))
         (global $memory-map:vfs-file-buffer-length (mut i32) (i32.const 1048576))
         (global $memory-map:vfs-path-buffer-base   (mut i32) (i32.const 1048576))
         (global $memory-map:vfs-path-buffer-length (mut i32) (i32.const 4096))
         (global $memory-map:callback-buffer-base   (mut i32) (i32.const 1052672))
         (global $memory-map:callback-buffer-length (mut i32) (i32.const 16777216))
         (global $memory-map:string-buffer-base     (mut i32) (i32.const 1052672))
         (global $memory-map:string-buffer-length   (mut i32) (i32.const 4096))))

;; memory-map-global-names : (listof symbol?)
;;   Enumerate static memory-map globals shared by split runtime modules.
(define memory-map-global-names
  (for/list ([form (in-list memory-map-global-forms)]
             #:when (match form
                      [`(global ,(? symbol?) . ,_) #t]
                      [_ #f]))
    (second form)))

(module+ test
  (require rackunit)

  (check-equal? memory-import-forms
                '((import "env" "memory" (memory $memory 1024))))
  (check-equal? (map second memory-map-global-forms)
                '($memory-map:vfs-file-buffer-base
                  $memory-map:vfs-file-buffer-length
                  $memory-map:vfs-path-buffer-base
                  $memory-map:vfs-path-buffer-length
                  $memory-map:callback-buffer-base
                  $memory-map:callback-buffer-length
                  $memory-map:string-buffer-base
                  $memory-map:string-buffer-length))
  (check-equal? memory-map-global-names
                '($memory-map:vfs-file-buffer-base
                  $memory-map:vfs-file-buffer-length
                  $memory-map:vfs-path-buffer-base
                  $memory-map:vfs-path-buffer-length
                  $memory-map:callback-buffer-base
                  $memory-map:callback-buffer-length
                  $memory-map:string-buffer-base
                  $memory-map:string-buffer-length)))
