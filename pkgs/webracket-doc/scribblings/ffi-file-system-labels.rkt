#lang racket/base

(require (only-in "../../webracket/unsafe/file-system.rkt"
                  js-file-system-open-picker-supported?
                  js-file-system-save-picker-supported?
                  js-file-system-directory-picker-supported?
                  js-file-system-origin-private-supported?
                  js-file-system-file-handle?
                  js-file-system-directory-handle?
                  js-file-system-writable-file-stream?
                  js-file-system-file?
                  js-file-system-show-open-file-picker
                  js-file-system-show-save-file-picker
                  js-file-system-show-directory-picker
                  js-file-system-origin-private-directory
                  js-file-system-handle-name
                  js-file-system-file-handle-get-file
                  js-file-system-file-handle-create-writable
                  js-file-system-directory-handle-get-file-handle
                  js-file-system-directory-handle-get-directory-handle
                  js-file-system-directory-handle-remove-entry!
                  js-file-system-file-name
                  js-file-system-file-size
                  js-file-system-file-type
                  js-file-system-file-last-modified
                  js-file-system-file-text
                  js-file-system-writable-file-stream-write
                  js-file-system-writable-file-stream-seek
                  js-file-system-writable-file-stream-truncate
                  js-file-system-writable-file-stream-close))

(provide js-file-system-open-picker-supported?
         js-file-system-save-picker-supported?
         js-file-system-directory-picker-supported?
         js-file-system-origin-private-supported?
         js-file-system-file-handle?
         js-file-system-directory-handle?
         js-file-system-writable-file-stream?
         js-file-system-file?
         js-file-system-show-open-file-picker
         js-file-system-show-save-file-picker
         js-file-system-show-directory-picker
         js-file-system-origin-private-directory
         js-file-system-handle-name
         js-file-system-file-handle-get-file
         js-file-system-file-handle-create-writable
         js-file-system-directory-handle-get-file-handle
         js-file-system-directory-handle-get-directory-handle
         js-file-system-directory-handle-remove-entry!
         js-file-system-file-name
         js-file-system-file-size
         js-file-system-file-type
         js-file-system-file-last-modified
         js-file-system-file-text
         js-file-system-writable-file-stream-write
         js-file-system-writable-file-stream-seek
         js-file-system-writable-file-stream-truncate
         js-file-system-writable-file-stream-close)
