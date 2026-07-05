;; Focused no-stdlib generated-output checks for filesystem errors.
;;
;; Compile this file with `--no-stdlib`.

(define long-vfs-path
  (string-append "/app/" (make-string 4100 #\a)))

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
         "path:"))))
