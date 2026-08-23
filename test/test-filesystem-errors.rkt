;; Focused no-stdlib generated-output checks for filesystem errors.
;;
;; Compile this file with `--no-stdlib`.

(define long-vfs-path
  (string-append "/app/" (make-string 4100 #\a)))

(define huge-vfs-path
  (string-append "/app/" (make-string 1048577 #\a)))

(struct filesystem-plain ())

(define filesystem-plain-given
  "given: #(struct filesystem-plain)")

(define (catch-fail/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail?
                          (lambda (exn)
                            (exn-message exn))])
           (thunk)
           #f)])
    (and message
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(list
 (list "VFS write rejects non-byte content with who"
       (catch-fail/contains?
        (lambda () (webracket-vfs-write-file "/tmp/out" 'bad))
        "webracket-vfs-write-file"
        "bytes?"
        "given: 'bad"))
 (list "VFS write reports oversized file content with who"
       (catch-fail/contains?
        (lambda () (webracket-vfs-write-file "/tmp/too-large"
                                             (make-bytes 1048577 65)))
        "webracket-vfs-write-file"
        "file content is too large"
        "/tmp/too-large"))
 (list "permissions mode bignum errors are catchable"
       (let ([_ (webracket-vfs-write-file "/app/perms-bignum.txt" #"x")])
         (catch-fail/contains?
          (lambda () (file-or-directory-permissions "/app/perms-bignum.txt" 536870912))
          "file-or-directory-permissions"
          "(or/c #f 'bits (integer-in 0 65535))"
          "given: 536870912")))
 (list "read-side VFS failures report who and path"
       (and
        (catch-fail/contains?
         (lambda () (file->bytes "/app/missing-read-bytes.txt"))
         "file->bytes"
         "VFS file read failed"
         "/app/missing-read-bytes.txt")
        (catch-fail/contains?
         (lambda () (file->string "/app/missing-read-string.txt"))
         "file->string"
         "VFS file read failed"
         "/app/missing-read-string.txt")
        (catch-fail/contains?
         (lambda () (open-input-file "/app/missing-open-input.txt"))
         "open-input-file"
         "VFS file read failed"
         "/app/missing-open-input.txt")))
 (list "single-path VFS failures report paths"
       (and
        (catch-fail/contains?
         (lambda () (file-size "/app/missing-size.txt"))
         "file-size"
         "path:"
         "/app/missing-size.txt")
        (catch-fail/contains?
         (lambda () (file-or-directory-type "/app/missing-type.txt" #t))
         "file-or-directory-type"
         "path:"
         "/app/missing-type.txt")
        (catch-fail/contains?
         (lambda () (directory-list "/app/missing-list-dir"))
         "directory-list"
         "path:"
         "/app/missing-list-dir")
        (catch-fail/contains?
         (lambda () (delete-file "/app/missing-delete.txt"))
         "delete-file"
         "path:"
         "/app/missing-delete.txt")
        (catch-fail/contains?
         (lambda () (make-directory "/app/missing-parent/child"))
         "make-directory"
         "path:"
         "/app/missing-parent/child")
        (catch-fail/contains?
         (lambda () (delete-directory "/app/missing-empty-dir"))
         "delete-directory"
         "path:"
         "/app/missing-empty-dir")
        (catch-fail/contains?
         (lambda () (delete-directory/files "/app/missing-tree"))
         "delete-directory/files"
         "path:"
         "/app/missing-tree")
        (catch-fail/contains?
         (lambda () (file-or-directory-modify-seconds "/app/missing-mtime"))
         "file-or-directory-modify-seconds"
         "path:"
         "/app/missing-mtime")
        (catch-fail/contains?
         (lambda () (file-or-directory-permissions "/app/missing-perms"))
         "file-or-directory-permissions"
         "path:"
         "/app/missing-perms")))
 (list "write-side VFS failures report who and path"
       (and
        (let ([_ (webracket-vfs-write-file "/app/existing-output.txt" #"old")])
          (catch-fail/contains?
           (lambda () (open-output-file "/app/existing-output.txt"))
           "open-output-file"
           "VFS file write failed"
           "/app/existing-output.txt"))
        (let ([_ (make-directory "/app/output-dir")])
          (catch-fail/contains?
           (lambda () (open-output-file "/app/output-dir"))
           "open-output-file"
           "VFS file write failed"
           "/app/output-dir"))
        (catch-fail/contains?
         (lambda () (open-output-file "/app/missing-must-truncate.txt"
                                      'binary
                                      'must-truncate))
         "open-output-file"
         "VFS file write failed"
         "/app/missing-must-truncate.txt")))
 (list "multi-path VFS failures report source and destination paths"
       (and
        (catch-fail/contains?
         (lambda () (rename-file-or-directory "/app/missing-rename-source"
                                              "/app/rename-destination"))
         "rename-file-or-directory"
         "source path:"
         "/app/missing-rename-source"
         "destination path:"
         "/app/rename-destination")
        (catch-fail/contains?
         (lambda () (copy-file "/app/missing-copy-source"
                               "/app/copy-destination"))
         "copy-file"
         "source path:"
         "/app/missing-copy-source"
         "destination path:"
         "/app/copy-destination")
        (catch-fail/contains?
         (lambda () (copy-directory/files "/app/missing-copy-tree-source"
                                          "/app/copy-tree-destination"))
         "copy-directory/files"
         "source path:"
         "/app/missing-copy-tree-source"
         "destination path:"
         "/app/copy-tree-destination")))
 (list "multi-path VFS operations report oversized destination paths with who"
       (and
        (catch-fail/contains?
         (lambda () (rename-file-or-directory "/app/source.txt" huge-vfs-path))
         "rename-file-or-directory"
         "path is too long"
         "path:")
        (catch-fail/contains?
         (lambda () (copy-file "/app/source.txt" huge-vfs-path))
         "copy-file"
         "path is too long"
         "path:")
        (catch-fail/contains?
         (lambda () (copy-directory/files "/app/source-dir" huge-vfs-path))
         "copy-directory/files"
         "path is too long"
         "path:")))
 (list "long VFS paths raise catchable errors with who"
       (and
        (catch-fail/contains?
         (lambda () (file-exists? long-vfs-path))
         "file-exists?"
         "path is too long"
         "path:")
        (catch-fail/contains?
         (lambda () (directory-list long-vfs-path))
         "directory-list"
         "path is too long"
         "path:")
        (catch-fail/contains?
         (lambda () (webracket-vfs-write-file long-vfs-path #"x"))
         "webracket-vfs-write-file"
         "path is too long"
         "path:")
        (catch-fail/contains?
         (lambda () (delete-file long-vfs-path))
         "delete-file"
         "path is too long"
         "path:")
        (catch-fail/contains?
         (lambda () (file-or-directory-modify-seconds long-vfs-path))
         "file-or-directory-modify-seconds"
         "path is too long"
         "path:")))
 (list "filesystem callbacks reject plain structs with callback contracts"
       (let ([_ (webracket-vfs-write-file "/app/callback-source.txt" #"data")])
         (and
          (catch-fail/contains?
           (lambda () (file-or-directory-modify-seconds
                       "/app/missing-callback-mtime"
                       #f
                       (filesystem-plain)))
           "file-or-directory-modify-seconds"
           "(procedure-arity-includes/c 0)"
           filesystem-plain-given)
          (catch-fail/contains?
           (lambda () (call-with-input-file
                       "/app/callback-source.txt"
                       (filesystem-plain)))
           "call-with-input-file"
           "(input-port? . -> . any)"
           filesystem-plain-given)
          (catch-fail/contains?
           (lambda () (call-with-output-file
                       "/app/callback-output.txt"
                       (filesystem-plain)))
           "call-with-output-file"
           "(output-port? . -> . any)"
           filesystem-plain-given)
          (catch-fail/contains?
           (lambda () (call-with-input-file*
                       "/app/callback-source.txt"
                       (filesystem-plain)))
           "call-with-input-file*"
           "(input-port? . -> . any)"
           filesystem-plain-given)
          (catch-fail/contains?
           (lambda () (call-with-output-file*
                       "/app/callback-output-star.txt"
                       (filesystem-plain)))
           "call-with-output-file*"
           "(output-port? . -> . any)"
           filesystem-plain-given)
          (catch-fail/contains?
           (lambda () (with-input-from-file
                       "/app/callback-source.txt"
                       (filesystem-plain)))
           "with-input-from-file"
           "(-> any)"
           filesystem-plain-given)
          (catch-fail/contains?
           (lambda () (with-output-to-file
                       "/app/callback-output-with.txt"
                       (filesystem-plain)))
           "with-output-to-file"
           "(-> any)"
           filesystem-plain-given))))
 (list "filesystem callback arity contracts match Racket"
       (let ([_ (webracket-vfs-write-file "/app/callback-arity-source.txt" #"data")])
         (and
          (catch-fail/contains?
           (lambda () (file-or-directory-modify-seconds
                       "/app/missing-callback-arity-mtime"
                       #f
                       (lambda (x) x)))
           "file-or-directory-modify-seconds"
           "(procedure-arity-includes/c 0)")
          (catch-fail/contains?
           (lambda () (call-with-input-file
                       "/app/missing-callback-arity-input.txt"
                       (lambda () 1)))
           "call-with-input-file"
           "(input-port? . -> . any)")
          (catch-fail/contains?
           (lambda () (call-with-output-file
                       "/app/callback-arity-output.txt"
                       (lambda () 1)))
           "call-with-output-file"
           "(output-port? . -> . any)")
          (catch-fail/contains?
           (lambda () (call-with-input-file*
                       "/app/callback-arity-source.txt"
                       (lambda () 1)))
           "call-with-input-file*"
           "(input-port? . -> . any)")
          (catch-fail/contains?
           (lambda () (call-with-output-file*
                       "/app/callback-arity-output-star.txt"
                       (lambda () 1)))
           "call-with-output-file*"
           "(output-port? . -> . any)")
          (catch-fail/contains?
           (lambda () (with-input-from-file
                       "/app/missing-callback-arity-with-input.txt"
                       (lambda (x) x)))
           "with-input-from-file"
           "(-> any)")
          (catch-fail/contains?
           (lambda () (with-output-to-file
                       "/app/callback-arity-output-with.txt"
                       (lambda (x) x)))
           "with-output-to-file"
           "(-> any)")))))
