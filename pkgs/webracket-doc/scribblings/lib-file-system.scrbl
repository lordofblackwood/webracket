#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-file-system-labels.rkt" "webracket-doc")
                     (lib "scribblings/lib-js-promise-labels.rkt" "webracket-doc"))
          "browser-api-docs.rkt"
          "webracket-scribble-utils.rkt")

@title{Library: @racketmodname[file-system]}
@declare-exporting[(lib "scribblings/lib-file-system-labels.rkt" "webracket-doc")]

@defmodule[file-system]

@nested[#:style 'inset]{
 @bold{Important: read the MDN File System API documentation before using this library.}
 The picker methods are experimental and have limited browser availability.
 They require a secure context and must be called directly from a user gesture
 such as a button click. The origin-private file system (OPFS) is separate: it
 stores data for the current origin and does not show files in the user's file
 browser.

 @(mdn-bar "File System API"
           "https://developer.mozilla.org/en-US/docs/Web/API/File_System_API")}

This module provides checked wrappers around a small, static subset of the
File System Access API. It supports default open/save/directory pickers,
origin-private storage, child-file and child-directory handles, file metadata
and text reads, and string or byte writes through a writable file stream.

The imports come from @tt{ffi/file-system.ffi}. They name fixed browser
operations; the public API does not send JavaScript property names or arbitrary
options objects across the boundary.

@section{Scope}

This first wrapper uses the browser defaults for @tt{showOpenFilePicker},
@tt{showSaveFilePicker}, and @tt{showDirectoryPicker}. In particular,
@racket[file-system-pick-open-file] selects the first returned handle and does
not expose multiple selection, filters, @tt{startIn}, or picker IDs yet.

The wrapper does not yet cover permission queries, directory async iterators,
@tt{resolve}, custom @tt{write} command objects, or worker-only synchronous
OPFS access handles. Those need their own typed designs rather than a generic
JavaScript-object escape hatch.

@section{Quick Start: OPFS}

The OPFS path has no picker UI, so it is suitable for a startup task or a
browser smoke test. Each File System operation returns a @racket[js-promise?].
The values received by a Promise callback are raw host values; wrap them before
passing them to checked file-system functions.

@racketblock[
(require file-system js/promise)

(js-promise-then
 (file-system-origin-private-directory)
 (lambda (raw-directory)
   (define directory (file-system-directory-handle-wrap raw-directory))
   (js-promise-then
    (file-system-directory-get-file-handle directory "draft.txt" #t)
    (lambda (raw-handle)
      (define handle (file-system-file-handle-wrap raw-handle))
      (js-promise-then
       (file-system-file-handle-create-writable handle)
       (lambda (raw-stream)
         (define stream (file-system-writable-file-stream-wrap raw-stream))
         (js-promise-then
          (file-system-writable-file-stream-write stream "hello")
          (lambda (_ignored)
            (file-system-writable-file-stream-close stream)
            (void)))
         (void)))
    (void)))
 (lambda (_reason) (void))))
]

@bold{Promise callbacks cross a FASL boundary.} A callback should schedule its
next @racket[js-promise?] operation and return @racket[(void)], rather than
returning that wrapper. The full Web Easy example demonstrates the complete
write, close, read, and text-check sequence.

@section{Availability and Input Types}

@defproc[(file-system-open-picker-supported?) boolean?]{
Reports whether @tt{Window.showOpenFilePicker()} is present. Presence does not
grant permission and does not remove the user-gesture requirement.
}

@defproc[(file-system-save-picker-supported?) boolean?]{
Reports whether @tt{Window.showSaveFilePicker()} is present.
}

@defproc[(file-system-directory-picker-supported?) boolean?]{
Reports whether @tt{Window.showDirectoryPicker()} is present.
}

@defproc[(file-system-origin-private-supported?) boolean?]{
Reports whether @tt{navigator.storage.getDirectory()} is present.
}

@defproc[(file-system-supported?) boolean?]{
Reports whether the module's OPFS workflow is available. It does not imply
that user-selected file pickers are available.
}

@defproc[(file-system-name? [value any/c]) boolean?]{
Recognizes child-entry names accepted by directory operations: strings and
symbols. Symbols are converted to their names.
}

@defproc[(file-system-write-data? [value any/c]) boolean?]{
Recognizes data accepted by
@racket[file-system-writable-file-stream-write]: strings and byte strings.
}

@defproc[(file-system-byte-count? [value any/c]) boolean?]{
Recognizes the byte offsets and sizes accepted by this library: exact
nonnegative integers no larger than @racket[9007199254740991], JavaScript's
largest safe integer. This prevents a byte position from being rounded when it
crosses the static FASL-marshalled FFI boundary.
}

@section{Pickers and OPFS}

@defproc[(file-system-pick-open-file) js-promise?]{
@(mdn-bar "Window: showOpenFilePicker()"
          "https://developer.mozilla.org/en-US/docs/Web/API/Window/showOpenFilePicker")
Starts the default single-file picker. Call it directly from an event handler.
Its fulfillment value is raw and must be passed to
@racket[file-system-file-handle-wrap]. User cancellation rejects the Promise.
}

@defproc[(file-system-pick-save-file) js-promise?]{
@(mdn-bar "Window: showSaveFilePicker()"
          "https://developer.mozilla.org/en-US/docs/Web/API/Window/showSaveFilePicker")
Starts the default save-file picker. Its fulfillment value is raw and must be
passed to @racket[file-system-file-handle-wrap].
}

@defproc[(file-system-pick-directory) js-promise?]{
@(mdn-bar "Window: showDirectoryPicker()"
          "https://developer.mozilla.org/en-US/docs/Web/API/Window/showDirectoryPicker")
Starts the default directory picker. Its fulfillment value is raw and must be
passed to @racket[file-system-directory-handle-wrap].
}

@defproc[(file-system-origin-private-directory) js-promise?]{
@(mdn-bar "StorageManager: getDirectory()"
          "https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/getDirectory")
Returns a Promise whose fulfillment value is the raw OPFS root directory.
Pass it to @racket[file-system-directory-handle-wrap].
}

@section{Handle Values}

@defproc[(file-system-file-handle? [value any/c]) boolean?]{
Recognizes wrapped @tt{FileSystemFileHandle} values.
}

@defproc[(file-system-directory-handle? [value any/c]) boolean?]{
Recognizes wrapped @tt{FileSystemDirectoryHandle} values.
}

@defproc[(file-system-writable-file-stream? [value any/c]) boolean?]{
Recognizes wrapped @tt{FileSystemWritableFileStream} values.
}

@defproc[(file-system-file? [value any/c]) boolean?]{
Recognizes wrapped browser @tt{File} snapshots.
}

@defproc[(file-system-file-handle-wrap [raw external/raw]) file-system-file-handle?]{
Validates and wraps a file handle supplied by a picker or directory-operation
Promise callback.
}

@defproc[(file-system-directory-handle-wrap [raw external/raw]) file-system-directory-handle?]{
Validates and wraps a directory handle supplied by a picker or OPFS Promise
callback.
}

@defproc[(file-system-writable-file-stream-wrap [raw external/raw])
         file-system-writable-file-stream?]{
Validates and wraps the writable stream supplied by a
@racket[file-system-file-handle-create-writable] Promise callback.
}

@defproc[(file-system-file-wrap [raw external/raw]) file-system-file?]{
Validates and wraps the @tt{File} supplied by a
@racket[file-system-file-handle-get-file] Promise callback.
}

@section{File and Directory Handles}

@defproc[(file-system-file-handle-name [handle file-system-file-handle?]) string?]{
Returns the file handle's entry name.
}

@defproc[(file-system-directory-handle-name [handle file-system-directory-handle?]) string?]{
Returns the directory handle's entry name. The OPFS root name is browser-defined.
}

@defproc[(file-system-file-handle-get-file [handle file-system-file-handle?]) js-promise?]{
@(mdn-bar "FileSystemFileHandle: getFile()"
          "https://developer.mozilla.org/en-US/docs/Web/API/FileSystemFileHandle/getFile")
Returns a Promise for a snapshot @tt{File}. Wrap its fulfillment value with
@racket[file-system-file-wrap].
}

@defproc[(file-system-file-handle-create-writable
          [handle file-system-file-handle?]
          [keep-existing-data? boolean? #f])
         js-promise?]{
@(mdn-bar "FileSystemFileHandle: createWritable()"
          "https://developer.mozilla.org/en-US/docs/Web/API/FileSystemFileHandle/createWritable")
Returns a Promise for a writable file stream. With the default @racket[#f],
the browser starts a new file contents buffer. With @racket[#t], existing
contents are retained before subsequent writes.
}

@defproc[(file-system-directory-get-file-handle
          [directory file-system-directory-handle?]
          [name file-system-name?]
          [create? boolean? #f])
         js-promise?]{
@(mdn-bar "FileSystemDirectoryHandle: getFileHandle()"
          "https://developer.mozilla.org/en-US/docs/Web/API/FileSystemDirectoryHandle/getFileHandle")
Returns a Promise for a named child file. With @racket[#t], creates the file
when it does not exist. Wrap the fulfillment value with
@racket[file-system-file-handle-wrap].
}

@defproc[(file-system-directory-get-directory-handle
          [directory file-system-directory-handle?]
          [name file-system-name?]
          [create? boolean? #f])
         js-promise?]{
@(mdn-bar "FileSystemDirectoryHandle: getDirectoryHandle()"
          "https://developer.mozilla.org/en-US/docs/Web/API/FileSystemDirectoryHandle/getDirectoryHandle")
Returns a Promise for a named child directory. With @racket[#t], creates the
directory when it does not exist. Wrap the fulfillment value with
@racket[file-system-directory-handle-wrap].
}

@defproc[(file-system-directory-remove-entry!
          [directory file-system-directory-handle?]
          [name file-system-name?]
          [recursive? boolean? #f])
         js-promise?]{
@(mdn-bar "FileSystemDirectoryHandle: removeEntry()"
          "https://developer.mozilla.org/en-US/docs/Web/API/FileSystemDirectoryHandle/removeEntry")
Returns a Promise that removes a child file or an empty child directory. Pass
@racket[#t] to remove a directory recursively.
}

@section{File Snapshots}

@defproc[(file-system-file-name [file file-system-file?]) string?]{
Returns the snapshot's file name.
}

@defproc[(file-system-file-size [file file-system-file?]) file-system-byte-count?]{
Returns the snapshot's size in bytes.
}

@defproc[(file-system-file-type [file file-system-file?]) string?]{
Returns the snapshot's MIME type, which may be the empty string.
}

@defproc[(file-system-file-last-modified [file file-system-file?])
         exact-nonnegative-integer?]{
Returns the snapshot's modification timestamp in milliseconds since the Unix
epoch.
}

@defproc[(file-system-file-text [file file-system-file?]) js-promise?]{
@(mdn-bar "Blob: text()"
          "https://developer.mozilla.org/en-US/docs/Web/API/Blob/text")
Returns a Promise that fulfills with the file's UTF-8 decoded text.
}

@section{Writable File Streams}

@defproc[(file-system-writable-file-stream-write
          [stream file-system-writable-file-stream?]
          [data file-system-write-data?])
         js-promise?]{
@(mdn-bar "FileSystemWritableFileStream: write()"
          "https://developer.mozilla.org/en-US/docs/Web/API/FileSystemWritableFileStream/write")
Writes a string or byte string at the current cursor and returns its completion
Promise. This wrapper deliberately does not accept JavaScript command objects
for seek, truncate, or arbitrary data types.
}

@defproc[(file-system-writable-file-stream-seek
          [stream file-system-writable-file-stream?]
          [offset file-system-byte-count?])
         js-promise?]{
@(mdn-bar "FileSystemWritableFileStream: seek()"
          "https://developer.mozilla.org/en-US/docs/Web/API/FileSystemWritableFileStream/seek")
Moves the current write cursor to @racket[offset] bytes from the beginning.
The exact integer is marshalled to a JavaScript number only after the safe-range
check.
}

@defproc[(file-system-writable-file-stream-truncate
          [stream file-system-writable-file-stream?]
          [size file-system-byte-count?])
         js-promise?]{
@(mdn-bar "FileSystemWritableFileStream: truncate()"
          "https://developer.mozilla.org/en-US/docs/Web/API/FileSystemWritableFileStream/truncate")
Resizes the file to @racket[size] bytes. The size must satisfy
@racket[file-system-byte-count?].
}

@defproc[(file-system-writable-file-stream-close
          [stream file-system-writable-file-stream?])
         js-promise?]{
@(mdn-bar "FileSystemWritableFileStream: close()"
          "https://developer.mozilla.org/en-US/docs/Web/API/FileSystemWritableFileStream/close")
Closes the writable stream and commits its changes. Always wait for the
returned Promise before reopening the file for a new snapshot.
}
