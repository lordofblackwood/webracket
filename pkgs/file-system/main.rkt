#lang webracket/base

(require js/promise
         webracket/unsafe/file-system
         (only-in webracket/primitives external?))

(provide file-system-open-picker-supported?
         file-system-save-picker-supported?
         file-system-directory-picker-supported?
         file-system-origin-private-supported?
         file-system-supported?
         file-system-name?
         file-system-write-data?
         file-system-byte-count?
         file-system-file-handle?
         file-system-directory-handle?
         file-system-writable-file-stream?
         file-system-file?
         file-system-file-handle-wrap
         file-system-directory-handle-wrap
         file-system-writable-file-stream-wrap
         file-system-file-wrap
         file-system-pick-open-file
         file-system-pick-save-file
         file-system-pick-directory
         file-system-origin-private-directory
         file-system-file-handle-name
         file-system-directory-handle-name
         file-system-file-handle-get-file
         file-system-file-handle-create-writable
         file-system-directory-get-file-handle
         file-system-directory-get-directory-handle
         file-system-directory-remove-entry!
         file-system-file-name
         file-system-file-size
         file-system-file-type
         file-system-file-last-modified
         file-system-file-text
         file-system-writable-file-stream-write
         file-system-writable-file-stream-seek
         file-system-writable-file-stream-truncate
         file-system-writable-file-stream-close)

;; The low-level procedures are fixed imports from `file-system.ffi`. These
;; wrapper values hide browser objects from normal callers while preserving the
;; File System API's asynchronous handle-based workflow.

;; file-system-file-handle-info : external/raw -> file-system-file-handle-info?
;;   Hold one browser FileSystemFileHandle.
(struct file-system-file-handle-info (raw) #:transparent)

;; file-system-directory-handle-info : external/raw -> file-system-directory-handle-info?
;;   Hold one browser FileSystemDirectoryHandle.
(struct file-system-directory-handle-info (raw) #:transparent)

;; file-system-writable-file-stream-info : external/raw -> file-system-writable-file-stream-info?
;;   Hold one browser FileSystemWritableFileStream.
(struct file-system-writable-file-stream-info (raw) #:transparent)

;; file-system-file-info : external/raw -> file-system-file-info?
;;   Hold one browser File returned by a file handle.
(struct file-system-file-info (raw) #:transparent)

;; file-system-name? : any/c -> boolean?
;;   Recognize file and directory entry names accepted by this wrapper.
(define (file-system-name? value)
  (or (string? value)
      (symbol? value)))

;; file-system-name->string : symbol? file-system-name? -> string?
;;   Convert a supported file-system name to the browser string form.
(define (file-system-name->string who value)
  (cond
    [(string? value) value]
    [(symbol? value) (symbol->string value)]
    [else
     (raise-argument-error who "file-system-name?" value)]))

;; file-system-write-data? : any/c -> boolean?
;;   Recognize the text and byte chunks accepted by writable file streams.
(define (file-system-write-data? value)
  (or (string? value)
      (bytes? value)))

;; file-system-byte-count? : any/c -> boolean?
;;   Recognize exact byte offsets that JavaScript can represent without loss.
(define (file-system-byte-count? value)
  (and (exact-nonnegative-integer? value)
       (<= value 9007199254740991)))

;; file-system-external? : any/c -> boolean?
;;   Recognize a raw host object.
(define (file-system-external? value)
  (external? value))

;; file-system-open-picker-supported? : -> boolean?
;;   Report whether the default open-file picker is available.
(define (file-system-open-picker-supported?)
  (js-file-system-open-picker-supported?))

;; file-system-save-picker-supported? : -> boolean?
;;   Report whether the default save-file picker is available.
(define (file-system-save-picker-supported?)
  (js-file-system-save-picker-supported?))

;; file-system-directory-picker-supported? : -> boolean?
;;   Report whether the default directory picker is available.
(define (file-system-directory-picker-supported?)
  (js-file-system-directory-picker-supported?))

;; file-system-origin-private-supported? : -> boolean?
;;   Report whether the browser exposes origin-private file-system storage.
(define (file-system-origin-private-supported?)
  (js-file-system-origin-private-supported?))

;; file-system-supported? : -> boolean?
;;   Report whether the wrapper's headless-testable OPFS path is available.
(define (file-system-supported?)
  (file-system-origin-private-supported?))

;; file-system-file-handle? : any/c -> boolean?
;;   Report whether value wraps a browser FileSystemFileHandle.
(define (file-system-file-handle? value)
  (and (file-system-file-handle-info? value)
       (file-system-external? (file-system-file-handle-info-raw value))
       (js-file-system-file-handle?
        (file-system-file-handle-info-raw value))))

;; file-system-directory-handle? : any/c -> boolean?
;;   Report whether value wraps a browser FileSystemDirectoryHandle.
(define (file-system-directory-handle? value)
  (and (file-system-directory-handle-info? value)
       (file-system-external? (file-system-directory-handle-info-raw value))
       (js-file-system-directory-handle?
        (file-system-directory-handle-info-raw value))))

;; file-system-writable-file-stream? : any/c -> boolean?
;;   Report whether value wraps a browser FileSystemWritableFileStream.
(define (file-system-writable-file-stream? value)
  (and (file-system-writable-file-stream-info? value)
       (file-system-external? (file-system-writable-file-stream-info-raw value))
       (js-file-system-writable-file-stream?
        (file-system-writable-file-stream-info-raw value))))

;; file-system-file? : any/c -> boolean?
;;   Report whether value wraps a browser File.
(define (file-system-file? value)
  (and (file-system-file-info? value)
       (file-system-external? (file-system-file-info-raw value))
       (js-file-system-file? (file-system-file-info-raw value))))

;; file-system-file-handle-wrap : external/raw -> file-system-file-handle?
;;   Validate and wrap a raw FileSystemFileHandle from a Promise callback.
(define (file-system-file-handle-wrap raw)
  (define value (file-system-file-handle-info raw))
  (unless (file-system-file-handle? value)
    (raise-argument-error 'file-system-file-handle-wrap
                          "FileSystemFileHandle external/raw"
                          raw))
  value)

;; file-system-directory-handle-wrap : external/raw -> file-system-directory-handle?
;;   Validate and wrap a raw FileSystemDirectoryHandle from a Promise callback.
(define (file-system-directory-handle-wrap raw)
  (define value (file-system-directory-handle-info raw))
  (unless (file-system-directory-handle? value)
    (raise-argument-error 'file-system-directory-handle-wrap
                          "FileSystemDirectoryHandle external/raw"
                          raw))
  value)

;; file-system-writable-file-stream-wrap : external/raw -> file-system-writable-file-stream?
;;   Validate and wrap a raw FileSystemWritableFileStream from a Promise callback.
(define (file-system-writable-file-stream-wrap raw)
  (define value (file-system-writable-file-stream-info raw))
  (unless (file-system-writable-file-stream? value)
    (raise-argument-error 'file-system-writable-file-stream-wrap
                          "FileSystemWritableFileStream external/raw"
                          raw))
  value)

;; file-system-file-wrap : external/raw -> file-system-file?
;;   Validate and wrap a raw File from a Promise callback.
(define (file-system-file-wrap raw)
  (define value (file-system-file-info raw))
  (unless (file-system-file? value)
    (raise-argument-error 'file-system-file-wrap "File external/raw" raw))
  value)

;; check-file-system-file-handle : symbol? any/c -> void?
;;   Raise an argument error unless value is a checked file handle.
(define (check-file-system-file-handle who value)
  (unless (file-system-file-handle? value)
    (raise-argument-error who "file-system-file-handle?" value)))

;; check-file-system-directory-handle : symbol? any/c -> void?
;;   Raise an argument error unless value is a checked directory handle.
(define (check-file-system-directory-handle who value)
  (unless (file-system-directory-handle? value)
    (raise-argument-error who "file-system-directory-handle?" value)))

;; check-file-system-writable-file-stream : symbol? any/c -> void?
;;   Raise an argument error unless value is a checked writable file stream.
(define (check-file-system-writable-file-stream who value)
  (unless (file-system-writable-file-stream? value)
    (raise-argument-error who "file-system-writable-file-stream?" value)))

;; check-file-system-file : symbol? any/c -> void?
;;   Raise an argument error unless value is a checked File.
(define (check-file-system-file who value)
  (unless (file-system-file? value)
    (raise-argument-error who "file-system-file?" value)))

;; check-file-system-boolean : symbol? any/c -> void?
;;   Raise an argument error unless value is a boolean option.
(define (check-file-system-boolean who value)
  (unless (boolean? value)
    (raise-argument-error who "boolean?" value)))

;; check-file-system-byte-count : symbol? any/c -> void?
;;   Raise an argument error unless value is a JavaScript-safe byte count.
(define (check-file-system-byte-count who value)
  (unless (file-system-byte-count? value)
    (raise-argument-error who "file-system-byte-count?" value)))

;; file-system-promise : symbol? string? external/raw -> js-promise?
;;   Validate and wrap one File System API Promise result.
(define (file-system-promise who operation raw)
  (js-promise-wrap-result who operation raw "File System API"))

;; file-system-pick-open-file : -> js-promise?
;;   Start the default single-file picker from a user gesture.
(define (file-system-pick-open-file)
  (file-system-promise 'file-system-pick-open-file
                       "showOpenFilePicker"
                       (js-file-system-show-open-file-picker)))

;; file-system-pick-save-file : -> js-promise?
;;   Start the default save-file picker from a user gesture.
(define (file-system-pick-save-file)
  (file-system-promise 'file-system-pick-save-file
                       "showSaveFilePicker"
                       (js-file-system-show-save-file-picker)))

;; file-system-pick-directory : -> js-promise?
;;   Start the default directory picker from a user gesture.
(define (file-system-pick-directory)
  (file-system-promise 'file-system-pick-directory
                       "showDirectoryPicker"
                       (js-file-system-show-directory-picker)))

;; file-system-origin-private-directory : -> js-promise?
;;   Get a Promise for the origin-private file-system root directory.
(define (file-system-origin-private-directory)
  (file-system-promise 'file-system-origin-private-directory
                       "StorageManager.getDirectory"
                       (js-file-system-origin-private-directory)))

;; file-system-file-handle-name : file-system-file-handle? -> string?
;;   Return the basename represented by a file handle.
(define (file-system-file-handle-name handle)
  (check-file-system-file-handle 'file-system-file-handle-name handle)
  (js-file-system-handle-name (file-system-file-handle-info-raw handle)))

;; file-system-directory-handle-name : file-system-directory-handle? -> string?
;;   Return the basename represented by a directory handle.
(define (file-system-directory-handle-name handle)
  (check-file-system-directory-handle 'file-system-directory-handle-name handle)
  (js-file-system-handle-name (file-system-directory-handle-info-raw handle)))

;; file-system-file-handle-get-file : file-system-file-handle? -> js-promise?
;;   Get a Promise for a snapshot File represented by handle.
(define (file-system-file-handle-get-file handle)
  (check-file-system-file-handle 'file-system-file-handle-get-file handle)
  (file-system-promise
   'file-system-file-handle-get-file
   "FileSystemFileHandle.getFile"
   (js-file-system-file-handle-get-file
    (file-system-file-handle-info-raw handle))))

;; file-system-file-handle-create-writable : file-system-file-handle? [boolean?] -> js-promise?
;;   Get a Promise for a writable stream, optionally keeping existing file data.
(define (file-system-file-handle-create-writable handle [keep-existing-data? #f])
  (check-file-system-file-handle 'file-system-file-handle-create-writable handle)
  (check-file-system-boolean 'file-system-file-handle-create-writable keep-existing-data?)
  (file-system-promise
   'file-system-file-handle-create-writable
   "FileSystemFileHandle.createWritable"
   (js-file-system-file-handle-create-writable
    (file-system-file-handle-info-raw handle)
    keep-existing-data?)))

;; file-system-directory-get-file-handle : file-system-directory-handle? file-system-name? [boolean?] -> js-promise?
;;   Get a Promise for a named child file handle, optionally creating it.
(define (file-system-directory-get-file-handle directory name [create? #f])
  (check-file-system-directory-handle 'file-system-directory-get-file-handle directory)
  (check-file-system-boolean 'file-system-directory-get-file-handle create?)
  (file-system-promise
   'file-system-directory-get-file-handle
   "FileSystemDirectoryHandle.getFileHandle"
   (js-file-system-directory-handle-get-file-handle
    (file-system-directory-handle-info-raw directory)
    (file-system-name->string 'file-system-directory-get-file-handle name)
    create?)))

;; file-system-directory-get-directory-handle : file-system-directory-handle? file-system-name? [boolean?] -> js-promise?
;;   Get a Promise for a named child directory handle, optionally creating it.
(define (file-system-directory-get-directory-handle directory name [create? #f])
  (check-file-system-directory-handle 'file-system-directory-get-directory-handle directory)
  (check-file-system-boolean 'file-system-directory-get-directory-handle create?)
  (file-system-promise
   'file-system-directory-get-directory-handle
   "FileSystemDirectoryHandle.getDirectoryHandle"
   (js-file-system-directory-handle-get-directory-handle
    (file-system-directory-handle-info-raw directory)
    (file-system-name->string 'file-system-directory-get-directory-handle name)
    create?)))

;; file-system-directory-remove-entry! : file-system-directory-handle? file-system-name? [boolean?] -> js-promise?
;;   Get a Promise that removes a named child entry, optionally recursively.
(define (file-system-directory-remove-entry! directory name [recursive? #f])
  (check-file-system-directory-handle 'file-system-directory-remove-entry! directory)
  (check-file-system-boolean 'file-system-directory-remove-entry! recursive?)
  (file-system-promise
   'file-system-directory-remove-entry!
   "FileSystemDirectoryHandle.removeEntry"
   (js-file-system-directory-handle-remove-entry!
    (file-system-directory-handle-info-raw directory)
    (file-system-name->string 'file-system-directory-remove-entry! name)
    recursive?)))

;; file-system-file-name : file-system-file? -> string?
;;   Return the file name recorded in a File snapshot.
(define (file-system-file-name file)
  (check-file-system-file 'file-system-file-name file)
  (js-file-system-file-name (file-system-file-info-raw file)))

;; file-system-file-size : file-system-file? -> file-system-byte-count?
;;   Return the byte length recorded in a File snapshot.
(define (file-system-file-size file)
  (check-file-system-file 'file-system-file-size file)
  (define size (js-file-system-file-size (file-system-file-info-raw file)))
  (unless (file-system-byte-count? size)
    (raise-arguments-error 'file-system-file-size
                           "File.size did not return a JavaScript-safe byte count"
                           "value" size))
  size)

;; file-system-file-type : file-system-file? -> string?
;;   Return the MIME type recorded in a File snapshot.
(define (file-system-file-type file)
  (check-file-system-file 'file-system-file-type file)
  (js-file-system-file-type (file-system-file-info-raw file)))

;; file-system-file-last-modified : file-system-file? -> exact-nonnegative-integer?
;;   Return the file modification timestamp in milliseconds since the epoch.
(define (file-system-file-last-modified file)
  (check-file-system-file 'file-system-file-last-modified file)
  (define timestamp
    (js-file-system-file-last-modified (file-system-file-info-raw file)))
  (unless (exact-nonnegative-integer? timestamp)
    (raise-arguments-error 'file-system-file-last-modified
                           "File.lastModified did not return an exact nonnegative integer"
                           "value" timestamp))
  timestamp)

;; file-system-file-text : file-system-file? -> js-promise?
;;   Get a Promise for the UTF-8 text content of a File snapshot.
(define (file-system-file-text file)
  (check-file-system-file 'file-system-file-text file)
  (file-system-promise
   'file-system-file-text
   "File.text"
   (js-file-system-file-text (file-system-file-info-raw file))))

;; file-system-writable-file-stream-write : file-system-writable-file-stream? file-system-write-data? -> js-promise?
;;   Write one text or byte chunk at the current stream cursor.
(define (file-system-writable-file-stream-write stream data)
  (check-file-system-writable-file-stream 'file-system-writable-file-stream-write stream)
  (unless (file-system-write-data? data)
    (raise-argument-error 'file-system-writable-file-stream-write
                          "file-system-write-data?"
                          data))
  (file-system-promise
   'file-system-writable-file-stream-write
   "FileSystemWritableFileStream.write"
   (js-file-system-writable-file-stream-write
    (file-system-writable-file-stream-info-raw stream)
    data)))

;; file-system-writable-file-stream-seek : file-system-writable-file-stream? file-system-byte-count? -> js-promise?
;;   Move the writable stream cursor to byte offset.
(define (file-system-writable-file-stream-seek stream offset)
  (check-file-system-writable-file-stream 'file-system-writable-file-stream-seek stream)
  (check-file-system-byte-count 'file-system-writable-file-stream-seek offset)
  (file-system-promise
   'file-system-writable-file-stream-seek
   "FileSystemWritableFileStream.seek"
   (js-file-system-writable-file-stream-seek
    (file-system-writable-file-stream-info-raw stream)
    offset)))

;; file-system-writable-file-stream-truncate : file-system-writable-file-stream? file-system-byte-count? -> js-promise?
;;   Resize the target file to byte length.
(define (file-system-writable-file-stream-truncate stream size)
  (check-file-system-writable-file-stream 'file-system-writable-file-stream-truncate stream)
  (check-file-system-byte-count 'file-system-writable-file-stream-truncate size)
  (file-system-promise
   'file-system-writable-file-stream-truncate
   "FileSystemWritableFileStream.truncate"
   (js-file-system-writable-file-stream-truncate
    (file-system-writable-file-stream-info-raw stream)
    size)))

;; file-system-writable-file-stream-close : file-system-writable-file-stream? -> js-promise?
;;   Close the stream and commit its changes to the file.
(define (file-system-writable-file-stream-close stream)
  (check-file-system-writable-file-stream 'file-system-writable-file-stream stream)
  (file-system-promise
   'file-system-writable-file-stream-close
   "FileSystemWritableFileStream.close"
   (js-file-system-writable-file-stream-close
    (file-system-writable-file-stream-info-raw stream))))
