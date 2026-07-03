#lang racket

(provide memory-map-global-forms)

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
         ;;   +64KiB         callback/FASL/string scratch buffer
         (global $memory-map:vfs-file-buffer-base   (mut i32) (i32.const 0))
         (global $memory-map:vfs-file-buffer-length (mut i32) (i32.const 1048576))
         (global $memory-map:vfs-path-buffer-base   (mut i32) (i32.const 1048576))
         (global $memory-map:vfs-path-buffer-length (mut i32) (i32.const 4096))
         (global $memory-map:callback-buffer-base   (mut i32) (i32.const 1052672))
         (global $memory-map:callback-buffer-length (mut i32) (i32.const 65536))
         (global $memory-map:string-buffer-base     (mut i32) (i32.const 1052672))
         (global $memory-map:string-buffer-length   (mut i32) (i32.const 4096))))
