#lang racket

(provide filesystem-temporary-global-forms
         filesystem-temporary-global-names
         filesystem-runtime-string-constants
         filesystem-runtime-symbol-constants
         filesystem-runtime-bytes-constants
         filesystem-core-runtime-helpers
         filesystem-runtime-only-helpers
         filesystem-runtime-only-helper-names
         filesystem-runtime-helper-forms)

(require "../core-helper.rkt")

;; filesystem-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by VFS helpers and file-operation errors.
(define filesystem-runtime-string-constants
  '((vfs:file-size-failed       "file-size: VFS path does not refer to a file")
    (vfs:read-file-failed       "VFS file read failed")
    (vfs:write-file-failed      "VFS file write failed")
    (vfs:delete-file-failed     "delete-file: VFS path does not refer to a file")
    (vfs:delete-directory-failed "delete-directory: VFS path does not refer to an empty directory")
    (vfs:delete-directory/files-failed "delete-directory/files: VFS recursive delete failed")
    (vfs:make-directory-failed  "make-directory: VFS directory creation failed")
    (vfs:make-directory*-failed "make-directory*: VFS directory creation failed")
    (vfs:make-parent-directory*-failed "make-parent-directory*: VFS directory creation failed")
    (vfs:directory-list-failed  "directory-list: VFS path does not refer to a directory")
    (vfs:root-list-failed       "filesystem-root-list: VFS root list failed")
    (vfs:rename-failed          "rename-file-or-directory: VFS rename failed")
    (vfs:copy-file-failed       "copy-file: VFS copy failed")
    (vfs:copy-directory/files-failed "copy-directory/files: VFS recursive copy failed")
    (vfs:temporary-template     "format string containing ~a")
    (vfs:modify-seconds-failed  "file-or-directory-modify-seconds: VFS path does not exist")
    (vfs:permissions-failed     "file-or-directory-permissions: VFS path does not exist")
    (vfs:stat-failed            "file-or-directory-stat: VFS path does not exist")
    (vfs:type-failed            "file-or-directory-type: VFS path does not exist")
    (vfs:identity-failed        "file-or-directory-identity: VFS path does not exist")
    (vfs:error-separator        ": ")
    (vfs:error-path             "\n  path: ")
    (vfs:error-source-path      "\n  source path: ")
    (vfs:error-destination-path "\n  destination path: ")
    (vfs:path-too-long          ": path is too long for WebRacket VFS\n  path: ")
    (vfs:file-buffer-too-small
     ": file content is too large for WebRacket VFS buffer\n  path: ")
    (permissions-mode           "(or/c #f 'bits (integer-in 0 65535))")
    (input-file-mode-flag       "(or/c 'binary 'text)")
    (output-file-mode-flag      "(or/c 'binary 'text)")
    (filesystem-input-port-procedure "(input-port? . -> . any)")
    (filesystem-output-port-procedure "(output-port? . -> . any)")
    (filesystem-thunk-procedure "(-> any)")
    (filesystem-procedure-arity-0 "(procedure-arity-includes/c 0)")
    (output-file-exists-flag    "(or/c 'error 'append 'replace 'truncate 'must-truncate 'truncate/replace)")))

;; filesystem-runtime-symbol-constants : (listof symbol?)
;;   Declare file mode and file-operation symbols used by filesystem helpers.
(define filesystem-runtime-symbol-constants
  '(posix
    gai
    read
    write
    execute
    bits
    binary
    text
    append
    update
    can-update
    replace
    truncate
    must-truncate
    truncate/replace
    file
    directory
    file-or-directory-modify-seconds
    call-with-input-file
    call-with-output-file
    call-with-input-file*
    call-with-output-file*
    with-input-from-file
    with-output-to-file
    error))

;; filesystem-runtime-bytes-constants : (listof (list/c symbol? bytes?))
;;   Declare byte-string constants used by filesystem helpers.
(define filesystem-runtime-bytes-constants
  '((rkttmp-template           #"rkttmp~a")))

;; filesystem-temporary-global-forms : (listof datum?)
;;   Declare filesystem state used for temporary file name generation.
(define filesystem-temporary-global-forms
  '(
               (global $temporary-file-counter   (mut i32)      (i32.const 0))))

;; filesystem-temporary-global-names : (listof symbol?)
;;   Enumerate filesystem globals used for temporary file name generation.
(define filesystem-temporary-global-names
  (for/list ([form (in-list filesystem-temporary-global-forms)])
    (match form
      [`(global ,name . ,_) name]
      [_ (error 'filesystem-temporary-global-names
                "expected global form, got: ~s"
                form)])))

;; filesystem-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for VFS and file-operation helpers.
(define filesystem-runtime-only-helper-names
  '($check-filesystem-procedure-arity
    $raise-vfs-file-error/path
    $raise-vfs-file-error/two-paths
    $raise-vfs-file-error/who-path
    $raise-vfs-path-too-long
    $raise-vfs-file-buffer-too-small
    $vfs-path-stat-kind
    $file-exists?
    $directory-exists?
    $link-exists?
    $file-or-directory-type
    $directory-list
    $webracket-directory-list-build-first
    $filesystem-root-list
    $file-or-directory-stat
    $file-or-directory-identity
    $file-size
    $vfs-read-file-bytes
    $file->bytes
    $file->string
    $file->lines
    $file->bytes-lines
    $display-value-to-port
    $display-to-file
    $display-lines-to-file
    $webracket-vfs-write-file
    $delete-file
    $make-directory
    $make-directory*
    $make-parent-directory*
    $delete-directory
    $delete-directory/files
    $rename-file-or-directory
    $copy-directory/files
    $copy-file
    $make-temporary-candidate
    $make-temporary-file
    $make-temporary-candidate*
    $make-temporary-file*
    $make-temporary-directory
    $make-temporary-directory*
    $file-or-directory-modify-seconds
    $file-or-directory-permissions
    $open-output-file
    $open-input-file
    $call-with-input-file
    $call-with-output-file
    $call-with-current-input-port/thunk
    $call-with-current-output-port/thunk
    $call-with-input-file*
    $call-with-output-file*
    $with-input-from-file
    $with-output-to-file))

;; filesystem-core-runtime-helper-names : (listof symbol?)
;;   Name filesystem helpers available in the standalone core runtime.
(define filesystem-core-runtime-helper-names
  '($raise-vfs-file-error/path
    $raise-vfs-file-error/two-paths
    $raise-vfs-file-error/who-path
    $raise-vfs-path-too-long
    $raise-vfs-file-buffer-too-small
    $vfs-path-stat-kind
    $file-exists?
    $directory-exists?
    $vfs-read-file-bytes
    $webracket-vfs-write-file
    $make-directory
    $copy-file
    $make-temporary-candidate
    $make-temporary-file
    $make-temporary-candidate*
    $make-temporary-file*
    $make-temporary-directory
    $make-temporary-directory*
    $open-output-file
    $open-input-file))

;; filesystem-runtime-only-forms : (listof datum?)
;;   Enumerate VFS and file-operation helpers used by the monolithic runtime.
(define filesystem-runtime-only-forms
  '(
    ;; check-filesystem-procedure-arity : symbol? string? any/c exact-nonnegative-integer? -> procedure?
    ;;   Validate a procedure-valued filesystem callback against an arity contract.
    (func $check-filesystem-procedure-arity
          (param $who      (ref eq))
          (param $contract (ref eq))
          (param $proc     (ref eq))
          (param $arity    i32)
          (result          (ref $Procedure))

          (local $f (ref $Procedure))

          (if (ref.eq (call $procedure? (local.get $proc))
                      (global.get $false))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (local.get $contract)
                          (local.get $proc))
                    (unreachable)))
          (local.set $f (ref.cast (ref $Procedure) (local.get $proc)))
          (if (i32.eqz
               (call $procedure-arity-includes?/checked/i32
                     (local.get $f)
                     (local.get $arity)))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (local.get $contract)
                          (local.get $proc))
                    (unreachable)))
          (local.get $f))

    (func $raise-vfs-file-error/path
          (param $message  (ref eq))
          (param $path-raw (ref eq))

          (local $out  (ref $GrowableArray))
          (local $full (ref $String))

          (local.set $out (call $make-growable-array (i32.const 3)))
          (call $growable-array-add! (local.get $out)
                (ref.cast (ref $String) (local.get $message)))
          (call $growable-array-add! (local.get $out)
                (global.get $string:vfs:error-path))
          (call $growable-array-add! (local.get $out)
                (call $format/write (local.get $path-raw)))
          (local.set $full
                     (call $growable-array-of-strings->string (local.get $out)))
          (call $raise-vfs-file-error (local.get $full))
          (unreachable))

    (func $raise-vfs-file-error/two-paths
          (param $message  (ref eq))
          (param $src-raw  (ref eq))
          (param $dest-raw (ref eq))

          (local $out  (ref $GrowableArray))
          (local $full (ref $String))

          (local.set $out (call $make-growable-array (i32.const 5)))
          (call $growable-array-add! (local.get $out)
                (ref.cast (ref $String) (local.get $message)))
          (call $growable-array-add! (local.get $out)
                (global.get $string:vfs:error-source-path))
          (call $growable-array-add! (local.get $out)
                (call $format/write (local.get $src-raw)))
          (call $growable-array-add! (local.get $out)
                (global.get $string:vfs:error-destination-path))
          (call $growable-array-add! (local.get $out)
                (call $format/write (local.get $dest-raw)))
          (local.set $full
                     (call $growable-array-of-strings->string (local.get $out)))
          (call $raise-vfs-file-error (local.get $full))
          (unreachable))

    (func $raise-vfs-file-error/who-path
          (param $who      (ref eq))
          (param $path-raw (ref eq))
          (param $detail   (ref eq))

          (local $out     (ref $GrowableArray))
          (local $message (ref $String))

          (local.set $out (call $make-growable-array (i32.const 5)))
          (call $growable-array-add! (local.get $out)
                (call $format/display (local.get $who)))
          (call $growable-array-add! (local.get $out)
                (global.get $string:vfs:error-separator))
          (call $growable-array-add! (local.get $out)
                (ref.cast (ref $String) (local.get $detail)))
          (call $growable-array-add! (local.get $out)
                (global.get $string:vfs:error-path))
          (call $growable-array-add! (local.get $out)
                (call $format/write (local.get $path-raw)))
          (local.set $message
                     (call $growable-array-of-strings->string (local.get $out)))
          (call $raise-vfs-file-error (local.get $message))
          (unreachable))

    (func $raise-vfs-path-too-long
          (param $who      (ref eq))
          (param $path-raw (ref eq))

          (local $out     (ref $GrowableArray))
          (local $message (ref $String))

          (local.set $out (call $make-growable-array (i32.const 3)))
          (call $growable-array-add! (local.get $out)
                (call $format/display (local.get $who)))
          (call $growable-array-add! (local.get $out)
                (global.get $string:vfs:path-too-long))
          (call $growable-array-add! (local.get $out)
                (call $format/write (local.get $path-raw)))
          (local.set $message
                     (call $growable-array-of-strings->string (local.get $out)))
          (call $raise
                (call $exn:fail:contract/make
                      (local.get $message)
                      (call $current-continuation-marks (global.get $missing)))
                (global.get $true))
          (unreachable))

    (func $raise-vfs-file-buffer-too-small
          (param $who      (ref eq))
          (param $path-raw (ref eq))

          (local $out     (ref $GrowableArray))
          (local $message (ref $String))

          (local.set $out (call $make-growable-array (i32.const 3)))
          (call $growable-array-add! (local.get $out)
                (call $format/display (local.get $who)))
          (call $growable-array-add! (local.get $out)
                (global.get $string:vfs:file-buffer-too-small))
          (call $growable-array-add! (local.get $out)
                (call $format/write (local.get $path-raw)))
          (local.set $message
                     (call $growable-array-of-strings->string (local.get $out)))
          (drop (call $raise
                      (call $make-exn:fail:out-of-memory
                            (local.get $message)
                            (call $current-continuation-marks
                                  (global.get $missing)))
                      (global.get $true)))
          (unreachable))

    (func $vfs-path-stat-kind
          (param $who      (ref eq)) ;; symbol? (currently for diagnostics)
          (param $path-raw (ref eq)) ;; path-string?
          (result          i32)      ;; 0 missing, 1 file, 2 directory

          (local $path  (ref $Path))
          (local $bytes (ref $Bytes))
          (local $len   i32)

          (local.set $path
                     (call $path-string->path/checked
                           (local.get $who)
                           (local.get $path-raw)))
          (local.set $bytes (struct.get $Path $bytes (local.get $path)))
          (local.set $len
                     (array.len
                      (struct.get $Bytes $bs (local.get $bytes))))
          (if (i32.gt_u (local.get $len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (local.get $who)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $len (call $copy-bytes-to-memory
                                (local.get $bytes)
                                (global.get $memory-map:vfs-path-buffer-base)))
          (call $js-vfs-stat-kind
                (global.get $memory-map:vfs-path-buffer-base)
                (local.get $len)))

    (func $file-exists? (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (if (result (ref eq))
              (i32.eq (call $vfs-path-stat-kind
                            (global.get $symbol:file-exists?)
                            (local.get $path-raw))
                      (i32.const 1))
              (then (global.get $true))
              (else (global.get $false))))

    (func $directory-exists? (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (if (result (ref eq))
              (i32.eq (call $vfs-path-stat-kind
                            (global.get $symbol:directory-exists?)
                            (local.get $path-raw))
                      (i32.const 2))
              (then (global.get $true))
              (else (global.get $false))))

    ;; link-exists? : path-string? -> boolean?
    ;;   Return #f in the current VFS model; links are not modeled yet.
    (func $link-exists? (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (drop (call $path-string->path/checked
                      (global.get $symbol:link-exists?)
                      (local.get $path-raw)))
          (global.get $false))

    ;; file-or-directory-type : path-string? [any/c] -> (or/c 'file 'directory #f)
    ;;   Report the VFS path kind; links are not modeled yet.
    (func $file-or-directory-type (type $Prim12)
          (param $path-raw       (ref eq)) ;; path-string?
          (param $must-exist-raw (ref eq)) ;; optional any/c, default = #f
          (result                (ref eq))

          (local $kind i32)

          (local.set $kind
                     (call $vfs-path-stat-kind
                           (global.get $symbol:file-or-directory-type)
                           (local.get $path-raw)))
          (if (i32.eq (local.get $kind) (i32.const 1))
              (then (return (global.get $symbol:file))))
          (if (i32.eq (local.get $kind) (i32.const 2))
              (then (return (global.get $symbol:directory))))
          (if (i32.eqz (ref.eq (local.get $must-exist-raw) (global.get $false)))
              (then
               (if (i32.eqz (ref.eq (local.get $must-exist-raw) (global.get $missing)))
                   (then (call $raise-vfs-file-error/path
                               (global.get $string:vfs:type-failed)
                               (local.get $path-raw))
                         (unreachable)))))
          (global.get $false))

    ;; directory-list : [path-string?] [any/c] -> (listof path?)
    ;;   Keywordless form of Racket's #:build? option; default #f.
    (func $directory-list (type $Prim02)
          (param $path-raw  (ref eq)) ;; optional path-string?, default = (current-directory)
          (param $build-raw (ref eq)) ;; optional any/c, default = #f
          (result           (ref eq))

          (local $path      (ref $Path))
          (local $path-bs   (ref $Bytes))
          (local $names-raw (ref eq))
          (local $names     (ref $Vector))
          (local $arr       (ref $Array))
          (local $entry     (ref eq))
          (local $entry-path (ref eq))
          (local $path-len  i32)
          (local $fasl-len  i32)
          (local $i         i32)
          (local $build?    i32)
          (local $xs        (ref eq))

          (if (ref.eq (local.get $path-raw) (global.get $missing))
              (then (local.set $path-raw
                               (call $current-directory
                                     (global.get $missing)))))
          (local.set $build?
                     (i32.and
                      (i32.eqz (ref.eq (local.get $build-raw)
                                       (global.get $missing)))
                      (i32.eqz (ref.eq (local.get $build-raw)
                                       (global.get $false)))))
          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:directory-list)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $path-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (if (i32.gt_u (local.get $path-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:directory-list)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-file-buffer-base)
                     (global.get $memory-map:vfs-file-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $path-len
                     (call $copy-bytes-to-memory
                           (local.get $path-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $fasl-len
                     (call $js-vfs-list-directory
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $path-len)
                           (global.get $memory-map:vfs-file-buffer-base)
                           (global.get $memory-map:vfs-file-buffer-length)))
          (if (i32.lt_s (local.get $fasl-len) (i32.const -1))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (if (i32.lt_s (local.get $fasl-len) (i32.const 0))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:directory-list-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $names-raw
                     (call $fasl-memory->s-exp
                           (global.get $memory-map:vfs-file-buffer-base)))
          (if (i32.eqz (ref.test (ref $Vector) (local.get $names-raw)))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:directory-list-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $names (ref.cast (ref $Vector) (local.get $names-raw)))
          (local.set $arr (struct.get $Vector $arr (local.get $names)))
          (if (i32.eqz (array.len (local.get $arr)))
              (then (return (global.get $null))))
          (local.set $xs (global.get $null))
          (local.set $i (i32.sub (array.len (local.get $arr)) (i32.const 1)))
          (block $done
                 (loop $build
                       (local.set $entry
                                  (array.get $Array
                                             (local.get $arr)
                                             (local.get $i)))
                       (if (i32.eqz (ref.test (ref $String) (local.get $entry)))
                           (then (call $raise-vfs-file-error/path
                                       (global.get $string:vfs:directory-list-failed)
                                       (local.get $path-raw))
                                 (unreachable)))
                       (local.set $entry-path
                                  (call $string->path
                                        (ref.cast (ref $String)
                                                  (local.get $entry))))
                       (if (local.get $build?)
                           (then
                            (local.set $entry-path
                                       (call $path-join-bytes/convention
                                             (global.get $symbol:directory-list)
                                             (struct.get $Path $convention (local.get $path))
                                             (local.get $path)
                                             (local.get $entry-path)))))
                       (local.set $xs
                                  (struct.new $Pair
                                              (i32.const 0)
                                              (local.get $entry-path)
                                              (local.get $xs)))
                       (br_if $done (i32.eqz (local.get $i)))
                       (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                       (br $build)))
          (local.get $xs))

    ;; webracket-directory-list-build-first : any/c path-string? -> (listof path?)
    ;;   Adapter for compiled Racket CS internal `directory-list.1`
    ;;   imports, which pass the #:build? value before the path.
    (func $webracket-directory-list-build-first (type $Prim2)
          (param $build-raw (ref eq)) ;; #:build? value
          (param $path-raw  (ref eq)) ;; path-string?
          (result           (ref eq))
          (return (call $directory-list
                        (local.get $path-raw)
                        (local.get $build-raw))))

    ;; filesystem-root-list : -> (listof path?)
    ;;   Return the mounted VFS roots as directory paths.
    (func $filesystem-root-list (type $Prim0)
          (result (ref eq))

          (local $roots-raw (ref eq))
          (local $roots     (ref $Vector))
          (local $arr       (ref $Array))
          (local $entry     (ref eq))
          (local $fasl-len  i32)
          (local $i         i32)
          (local $xs        (ref eq))

          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-file-buffer-base)
                     (global.get $memory-map:vfs-file-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $fasl-len
                     (call $js-vfs-root-list
                           (global.get $memory-map:vfs-file-buffer-base)
                           (global.get $memory-map:vfs-file-buffer-length)))
          (if (i32.lt_s (local.get $fasl-len) (i32.const -1))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (if (i32.lt_s (local.get $fasl-len) (i32.const 0))
              (then (call $raise-vfs-file-error
                          (global.get $string:vfs:root-list-failed))
                    (unreachable)))
          (local.set $roots-raw
                     (call $fasl-memory->s-exp
                           (global.get $memory-map:vfs-file-buffer-base)))
          (if (i32.eqz (ref.test (ref $Vector) (local.get $roots-raw)))
              (then (call $raise-vfs-file-error
                          (global.get $string:vfs:root-list-failed))
                    (unreachable)))
          (local.set $roots (ref.cast (ref $Vector) (local.get $roots-raw)))
          (local.set $arr (struct.get $Vector $arr (local.get $roots)))
          (if (i32.eqz (array.len (local.get $arr)))
              (then (return (global.get $null))))
          (local.set $xs (global.get $null))
          (local.set $i (i32.sub (array.len (local.get $arr)) (i32.const 1)))
          (block $done
                 (loop $build
                       (local.set $entry
                                  (array.get $Array
                                             (local.get $arr)
                                             (local.get $i)))
                       (if (i32.eqz (ref.test (ref $String) (local.get $entry)))
                           (then (call $raise-vfs-file-error
                                       (global.get $string:vfs:root-list-failed))
                                 (unreachable)))
                       (local.set $xs
                                  (struct.new $Pair
                                              (i32.const 0)
                                              (call $string->path (local.get $entry))
                                              (local.get $xs)))
                       (br_if $done (i32.eqz (local.get $i)))
                       (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                       (br $build)))
          (local.get $xs))

    ;; file-or-directory-stat : path-string? [boolean?] -> hash-eq?
    ;;   Return VFS stat metadata; as-link? is accepted but links are not modeled yet.
    (func $file-or-directory-stat (type $Prim12)
          (param $path-raw    (ref eq)) ;; path-string?
          (param $as-link-raw (ref eq)) ;; optional boolean?, default = #f
          (result             (ref eq))

          (local $path      (ref $Path))
          (local $path-bs   (ref $Bytes))
          (local $items-raw (ref eq))
          (local $items     (ref $Vector))
          (local $arr       (ref $Array))
          (local $ht        (ref eq))
          (local $path-len  i32)
          (local $fasl-len  i32)
          (local $i         i32)

          (if (i32.eqz
               (i32.or
                (ref.eq (local.get $as-link-raw) (global.get $missing))
                (i32.or
                 (ref.eq (local.get $as-link-raw) (global.get $false))
                 (ref.eq (local.get $as-link-raw) (global.get $true)))))
              (then (call $raise-argument-error1
                          (global.get $symbol:file-or-directory-stat)
                          (global.get $string:boolean?)
                          (local.get $as-link-raw))
                    (unreachable)))
          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:file-or-directory-stat)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $path-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (if (i32.gt_u (local.get $path-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:file-or-directory-stat)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-file-buffer-base)
                     (global.get $memory-map:vfs-file-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $path-len
                     (call $copy-bytes-to-memory
                           (local.get $path-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $fasl-len
                     (call $js-vfs-stat
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $path-len)
                           (global.get $memory-map:vfs-file-buffer-base)
                           (global.get $memory-map:vfs-file-buffer-length)))
          (if (i32.lt_s (local.get $fasl-len) (i32.const -1))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (if (i32.lt_s (local.get $fasl-len) (i32.const 0))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:stat-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $items-raw
                     (call $fasl-memory->s-exp
                           (global.get $memory-map:vfs-file-buffer-base)))
          (if (i32.eqz (ref.test (ref $Vector) (local.get $items-raw)))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:stat-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $items (ref.cast (ref $Vector) (local.get $items-raw)))
          (local.set $arr (struct.get $Vector $arr (local.get $items)))
          (if (i32.ne
               (i32.and (array.len (local.get $arr)) (i32.const 1))
              (i32.const 0))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:stat-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $ht (call $make-empty-hasheq))
          (local.set $i (i32.const 0))
          (block $done
                 (loop $build
                       (br_if $done
                              (i32.ge_u (local.get $i)
                                        (array.len (local.get $arr))))
                       (drop
                        (call $hash-set!
                              (local.get $ht)
                              (array.get $Array
                                         (local.get $arr)
                                         (local.get $i))
                              (array.get $Array
                                         (local.get $arr)
                                         (i32.add (local.get $i) (i32.const 1)))))
                       (local.set $i (i32.add (local.get $i) (i32.const 2)))
                       (br $build)))
          (local.get $ht))

    ;; file-or-directory-identity : path-string? [any/c] -> exact-positive-integer?
    ;;   Return a stable VFS identity; as-link? is accepted but links are not modeled yet.
    (func $file-or-directory-identity (type $Prim12)
          (param $path-raw    (ref eq)) ;; path-string?
          (param $as-link-raw (ref eq)) ;; optional any/c, default = #f
          (result             (ref eq))

          (local $path     (ref $Path))
          (local $path-bs  (ref $Bytes))
          (local $path-len i32)
          (local $id       i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:file-or-directory-identity)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $path-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (if (i32.gt_u (local.get $path-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:file-or-directory-identity)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $path-len
                     (call $copy-bytes-to-memory
                           (local.get $path-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $id
                     (call $js-vfs-identity
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $path-len)))
          (if (i32.le_s (local.get $id) (i32.const 0))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:identity-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (ref.i31 (i32.shl (local.get $id) (i32.const 1))))

    (func $file-size (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (local $path (ref $Path))
          (local $bytes (ref $Bytes))
          (local $len  i32)
          (local $size i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:file-size)
                           (local.get $path-raw)))
          (local.set $bytes (struct.get $Path $bytes (local.get $path)))
          (local.set $len
                     (array.len
                      (struct.get $Bytes $bs (local.get $bytes))))
          (if (i32.gt_u (local.get $len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:file-size)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $len (call $copy-bytes-to-memory
                                (local.get $bytes)
                                (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $size (call $js-vfs-file-size
                                 (global.get $memory-map:vfs-path-buffer-base)
                                 (local.get $len)))
          (if (i32.lt_s (local.get $size) (i32.const 0))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:file-size-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (ref.i31 (i32.shl (local.get $size) (i32.const 1))))

    ;; $vfs-read-file-bytes : symbol? path-string? -> bytes?
    ;;   Read a VFS file through the static file transfer buffer.
    (func $vfs-read-file-bytes
          (param $who      (ref eq)) ;; symbol?
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref $Bytes))

          (local $path      (ref $Path))
          (local $path-bs   (ref $Bytes))
          (local $path-len  i32)
          (local $expected  i32)
          (local $file-len  i32)

          (local.set $path
                     (call $path-string->path/checked
                           (local.get $who)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $path-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (if (i32.gt_u (local.get $path-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (local.get $who)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-file-buffer-base)
                     (global.get $memory-map:vfs-file-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $path-len (call $copy-bytes-to-memory
                                     (local.get $path-bs)
                                     (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $expected
                     (call $js-vfs-file-size
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $path-len)))
          (if (i32.lt_s (local.get $expected) (i32.const 0))
              (then (call $raise-vfs-file-error/who-path
                          (local.get $who)
                          (local.get $path-raw)
                          (global.get $string:vfs:read-file-failed))
                    (unreachable)))
          (if (i32.gt_u (local.get $expected)
                        (global.get $memory-map:vfs-file-buffer-length))
              (then (call $raise-vfs-file-buffer-too-small
                          (local.get $who)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $file-len
                     (call $js-vfs-read-file
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $path-len)
                           (global.get $memory-map:vfs-file-buffer-base)
                           (global.get $memory-map:vfs-file-buffer-length)))
          (if (i32.lt_s (local.get $file-len) (i32.const 0))
              (then (call $raise-vfs-file-error/who-path
                          (local.get $who)
                          (local.get $path-raw)
                          (global.get $string:vfs:read-file-failed))
                    (unreachable)))
          (if (i32.gt_u (local.get $file-len)
                        (global.get $memory-map:vfs-file-buffer-length))
              (then (call $raise-vfs-file-buffer-too-small
                          (local.get $who)
                          (local.get $path-raw))
                    (unreachable)))
          (call $memory-range->immutable-bytes
                (global.get $memory-map:vfs-file-buffer-base)
                (local.get $file-len)))

    ;; file->bytes : path-string? [(or/c 'binary 'text)] -> bytes?
    ;;   Keywordless form of Racket's #:mode option; text mode currently behaves like binary mode.
    (func $file->bytes (type $Prim12)
          (param $path-raw (ref eq)) ;; path-string?
          (param $mode-raw (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (result          (ref eq))

          (local $mode (ref eq))

          (local.set $mode
                     (if (result (ref eq))
                         (ref.eq (local.get $mode-raw) (global.get $missing))
                         (then (global.get $symbol:binary))
                         (else (local.get $mode-raw))))
          (if (i32.eqz
               (i32.or (ref.eq (local.get $mode) (global.get $symbol:binary))
                       (ref.eq (local.get $mode) (global.get $symbol:text))))
              (then (call $raise-argument-error1
                          (global.get $symbol:file->bytes)
                          (global.get $string:input-file-mode-flag)
                          (local.get $mode-raw))
                    (unreachable)))
          (call $vfs-read-file-bytes
                (global.get $symbol:file->bytes)
                (local.get $path-raw)))

    ;; file->string : path-string? [(or/c 'binary 'text)] -> string?
    ;;   Keywordless form of Racket's #:mode option; text mode currently behaves like binary mode.
    (func $file->string (type $Prim12)
          (param $path-raw (ref eq)) ;; path-string?
          (param $mode-raw (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (result          (ref eq))

          (local $mode (ref eq))

          (local.set $mode
                     (if (result (ref eq))
                         (ref.eq (local.get $mode-raw) (global.get $missing))
                         (then (global.get $symbol:binary))
                         (else (local.get $mode-raw))))
          (if (i32.eqz
               (i32.or (ref.eq (local.get $mode) (global.get $symbol:binary))
                       (ref.eq (local.get $mode) (global.get $symbol:text))))
              (then (call $raise-argument-error1
                          (global.get $symbol:file->string)
                          (global.get $string:input-file-mode-flag)
                          (local.get $mode-raw))
                    (unreachable)))
          (call $bytes->string/utf-8/checked
                (call $vfs-read-file-bytes
                      (global.get $symbol:file->string)
                      (local.get $path-raw))))

    ;; file->lines : path-string? [(or/c 'binary 'text)] [read-line-mode?] -> (listof string?)
    ;;   Keywordless form of Racket's #:mode and #:line-mode options; default line mode = 'any.
    (func $file->lines (type $Prim13)
          (param $path-raw      (ref eq)) ;; path-string?
          (param $mode-raw      (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (param $line-mode-raw (ref eq)) ;; optional read-line-mode?, default = 'any
          (result               (ref eq))

          (local $mode      (ref eq))
          (local $line-mode (ref eq))
          (local $port      (ref eq))
          (local $line      (ref eq))
          (local $acc       (ref eq))

          (local.set $mode
                     (if (result (ref eq))
                         (ref.eq (local.get $mode-raw) (global.get $missing))
                         (then (global.get $symbol:binary))
                         (else (local.get $mode-raw))))
          (if (i32.eqz
               (i32.or (ref.eq (local.get $mode) (global.get $symbol:binary))
                       (ref.eq (local.get $mode) (global.get $symbol:text))))
              (then (call $raise-argument-error1
                          (global.get $symbol:file->lines)
                          (global.get $string:input-file-mode-flag)
                          (local.get $mode-raw))
                    (unreachable)))
          (local.set $line-mode
                     (if (result (ref eq))
                         (ref.eq (local.get $line-mode-raw) (global.get $missing))
                         (then (global.get $symbol:any))
                         (else (local.get $line-mode-raw))))
          (local.set $port
                     (call $open-input-file
                           (local.get $path-raw)
                           (local.get $mode)
                           (global.get $missing)))
          (local.set $acc (global.get $null))
          (block $done
                 (loop $loop
                       (local.set $line
                                  (call $read-line
                                        (local.get $port)
                                        (local.get $line-mode)))
                       (br_if $done
                              (ref.eq (local.get $line) (global.get $eof)))
                       (local.set $acc
                                  (call $cons
                                        (local.get $line)
                                        (local.get $acc)))
                       (br $loop)))
          (drop (call $close-input-port (local.get $port)))
          (call $reverse (local.get $acc)))

    ;; file->bytes-lines : path-string? [(or/c 'binary 'text)] [read-line-mode?] -> (listof bytes?)
    ;;   Keywordless form of Racket's #:mode and #:line-mode options; default line mode = 'any.
    (func $file->bytes-lines (type $Prim13)
          (param $path-raw      (ref eq)) ;; path-string?
          (param $mode-raw      (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (param $line-mode-raw (ref eq)) ;; optional read-line-mode?, default = 'any
          (result               (ref eq))

          (local $mode      (ref eq))
          (local $line-mode (ref eq))
          (local $mode-code i32)
          (local $bytes     (ref $Bytes))
          (local $arr       (ref $I8Array))
          (local $len       i32)
          (local $i         i32)
          (local $start     i32)
          (local $end       i32)
          (local $b         i32)
          (local $next      i32)
          (local $acc       (ref eq))

          (local.set $mode
                     (if (result (ref eq))
                         (ref.eq (local.get $mode-raw) (global.get $missing))
                         (then (global.get $symbol:binary))
                         (else (local.get $mode-raw))))
          (if (i32.eqz
               (i32.or (ref.eq (local.get $mode) (global.get $symbol:binary))
                       (ref.eq (local.get $mode) (global.get $symbol:text))))
              (then (call $raise-argument-error1
                          (global.get $symbol:file->bytes-lines)
                          (global.get $string:input-file-mode-flag)
                          (local.get $mode-raw))
                    (unreachable)))
          (local.set $line-mode
                     (if (result (ref eq))
                         (ref.eq (local.get $line-mode-raw) (global.get $missing))
                         (then (global.get $symbol:any))
                         (else (local.get $line-mode-raw))))
          (local.set $mode-code
                     (call $read-line-mode-code
                           (global.get $symbol:file->bytes-lines)
                           (local.get $line-mode)))
          (local.set $bytes
                     (call $vfs-read-file-bytes
                           (global.get $symbol:file->bytes-lines)
                           (local.get $path-raw)))
          (local.set $arr (struct.get $Bytes $bs (local.get $bytes)))
          (local.set $len (array.len (local.get $arr)))
          (local.set $i (i32.const 0))
          (local.set $acc (global.get $null))
          (block $done
                 (loop $outer
                       (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                       (local.set $start (local.get $i))
                       (block $line-done
                              (loop $inner
                                    (if (i32.ge_u (local.get $i) (local.get $len))
                                        (then (local.set $end (local.get $len))
                                              (local.set $acc
                                                         (call $cons
                                                               (struct.new $Bytes
                                                                           (i32.const 0)
                                                                           (i32.const 0)
                                                                           (call $i8array-copy
                                                                                 (local.get $arr)
                                                                                 (local.get $start)
                                                                                 (local.get $end)))
                                                               (local.get $acc)))
                                              (br $done)))
                                    (local.set $b (array.get_u $I8Array (local.get $arr) (local.get $i)))

                                    (if (i32.and (i32.eq (local.get $mode-code) (i32.const 0))
                                                (i32.eq (local.get $b) (i32.const 10)))
                                        (then (local.set $end (local.get $i))
                                              (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                              (local.set $acc
                                                         (call $cons
                                                               (struct.new $Bytes
                                                                           (i32.const 0)
                                                                           (i32.const 0)
                                                                           (call $i8array-copy
                                                                                 (local.get $arr)
                                                                                 (local.get $start)
                                                                                 (local.get $end)))
                                                               (local.get $acc)))
                                              (br $line-done)))
                                    (if (i32.and (i32.eq (local.get $mode-code) (i32.const 1))
                                                (i32.eq (local.get $b) (i32.const 13)))
                                        (then (local.set $end (local.get $i))
                                              (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                              (local.set $acc
                                                         (call $cons
                                                               (struct.new $Bytes
                                                                           (i32.const 0)
                                                                           (i32.const 0)
                                                                           (call $i8array-copy
                                                                                 (local.get $arr)
                                                                                 (local.get $start)
                                                                                 (local.get $end)))
                                                               (local.get $acc)))
                                              (br $line-done)))
                                    (if (i32.and (i32.eq (local.get $mode-code) (i32.const 2))
                                                (i32.eq (local.get $b) (i32.const 13)))
                                        (then (if (i32.lt_u (i32.add (local.get $i) (i32.const 1))
                                                            (local.get $len))
                                                  (then (local.set $next
                                                                   (array.get_u $I8Array
                                                                                (local.get $arr)
                                                                                (i32.add (local.get $i)
                                                                                         (i32.const 1))))
                                                        (if (i32.eq (local.get $next) (i32.const 10))
                                                            (then (local.set $end (local.get $i))
                                                                  (local.set $i (i32.add (local.get $i) (i32.const 2)))
                                                                  (local.set $acc
                                                                             (call $cons
                                                                                   (struct.new $Bytes
                                                                                               (i32.const 0)
                                                                                               (i32.const 0)
                                                                                               (call $i8array-copy
                                                                                                     (local.get $arr)
                                                                                                     (local.get $start)
                                                                                                     (local.get $end)))
                                                                                   (local.get $acc)))
                                                                  (br $line-done)))))))
                                    (if (i32.and (i32.eq (local.get $mode-code) (i32.const 3))
                                                (i32.or (i32.eq (local.get $b) (i32.const 10))
                                                        (i32.eq (local.get $b) (i32.const 13))))
                                        (then (local.set $end (local.get $i))
                                              (if (i32.eq (local.get $b) (i32.const 13))
                                                  (then (if (i32.lt_u (i32.add (local.get $i) (i32.const 1))
                                                                      (local.get $len))
                                                            (then (local.set $next
                                                                             (array.get_u $I8Array
                                                                                          (local.get $arr)
                                                                                          (i32.add (local.get $i)
                                                                                                   (i32.const 1))))
                                                                  (if (i32.eq (local.get $next) (i32.const 10))
                                                                      (then (local.set $i
                                                                                       (i32.add (local.get $i)
                                                                                                (i32.const 1)))))))))
                                              (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                              (local.set $acc
                                                         (call $cons
                                                               (struct.new $Bytes
                                                                           (i32.const 0)
                                                                           (i32.const 0)
                                                                           (call $i8array-copy
                                                                                 (local.get $arr)
                                                                                 (local.get $start)
                                                                                 (local.get $end)))
                                                               (local.get $acc)))
                                              (br $line-done)))
                                    (if (i32.and (i32.eq (local.get $mode-code) (i32.const 4))
                                                (i32.or (i32.eq (local.get $b) (i32.const 10))
                                                        (i32.eq (local.get $b) (i32.const 13))))
                                        (then (local.set $end (local.get $i))
                                              (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                              (local.set $acc
                                                         (call $cons
                                                               (struct.new $Bytes
                                                                           (i32.const 0)
                                                                           (i32.const 0)
                                                                           (call $i8array-copy
                                                                                 (local.get $arr)
                                                                                 (local.get $start)
                                                                                 (local.get $end)))
                                                               (local.get $acc)))
                                              (br $line-done)))

                                    (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                    (br $inner)))
                       (br $outer)))
          (call $reverse (local.get $acc)))

    ;; display-value-to-port : any/c output-port? -> void?
    ;;   Display raw bytes directly; otherwise use the runtime display formatter.
    (func $display-value-to-port (type $Prim2)
          (param $v    (ref eq)) ;; any/c
          (param $port (ref eq)) ;; output-port?
          (result      (ref eq))

          (local $text (ref $String))

          (if (ref.test (ref $Bytes) (local.get $v))
              (then (drop (call $write-bytes
                                (local.get $v)
                                (local.get $port)
                                (global.get $missing)
                                (global.get $missing)))
                    (return (global.get $void))))
          (local.set $text (call $format/display (local.get $v)))
          (drop (call $write-string
                      (local.get $text)
                      (local.get $port)
                      (global.get $missing)
                      (global.get $missing)))
          (global.get $void))

    ;; display-to-file : any/c path-string? [(or/c 'binary 'text)] [output-file-exists-flag?] -> void?
    ;;   Keywordless form of Racket's #:mode and #:exists options; delegates options to open-output-file.
    (func $display-to-file (type $Prim24)
          (param $v          (ref eq)) ;; any/c
          (param $path-raw   (ref eq)) ;; path-string?
          (param $mode-raw   (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (param $exists-raw (ref eq)) ;; optional exists mode, default = 'error
          (result            (ref eq))

          (local $port (ref eq))

          (local.set $port
                     (call $open-output-file
                           (local.get $path-raw)
                           (local.get $mode-raw)
                           (local.get $exists-raw)))
          (drop (call $display-value-to-port
                      (local.get $v)
                      (local.get $port)))
          (drop (call $close-output-port (local.get $port)))
          (global.get $void))

    ;; display-lines-to-file : list? path-string? [any/c] [(or/c 'binary 'text)] [output-file-exists-flag?] -> void?
    ;;   Keywordless form of Racket's #:separator, #:mode, and #:exists options; default separator = #"\n".
    (func $display-lines-to-file (type $Prim25)
          (param $lst-raw    (ref eq)) ;; list?
          (param $path-raw   (ref eq)) ;; path-string?
          (param $sep-raw    (ref eq)) ;; optional any/c separator, default = #"\n"
          (param $mode-raw   (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (param $exists-raw (ref eq)) ;; optional exists mode, default = 'error
          (result            (ref eq))

          (local $port (ref eq))
          (local $node (ref eq))
          (local $pair (ref $Pair))

          (if (ref.eq (call $list? (local.get $lst-raw)) (global.get $false))
              (then (call $raise-argument-error1
                          (global.get $symbol:display-lines-to-file)
                          (global.get $string:list?)
                          (local.get $lst-raw))
                    (unreachable)))
          (local.set $port
                     (call $open-output-file
                           (local.get $path-raw)
                           (local.get $mode-raw)
                           (local.get $exists-raw)))
          (local.set $node (local.get $lst-raw))
          (block $done
                 (loop $loop
                       (br_if $done (ref.eq (local.get $node) (global.get $null)))
                       (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                       (drop (call $display-value-to-port
                                   (struct.get $Pair $a (local.get $pair))
                                   (local.get $port)))
                       (if (ref.eq (local.get $sep-raw) (global.get $missing))
                           (then (drop (call $write-byte
                                             (ref.i31 (i32.const 20))
                                             (local.get $port))))
                           (else (drop (call $display-value-to-port
                                             (local.get $sep-raw)
                                             (local.get $port)))))
                       (local.set $node (struct.get $Pair $d (local.get $pair)))
                       (br $loop)))
          (drop (call $close-output-port (local.get $port)))
          (global.get $void))

    (func $webracket-vfs-write-file (type $Prim2)
          (param $path-raw  (ref eq)) ;; path-string?
          (param $bytes-raw (ref eq)) ;; bytes?
          (result           (ref eq))

          (local $path      (ref $Path))
          (local $path-bs   (ref $Bytes))
          (local $path-len  i32)
          (local $bytes     (ref $Bytes))
          (local $bytes-len i32)
          (local $status    i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:webracket-vfs-write-file)
                           (local.get $path-raw)))
          (if (i32.eqz (ref.test (ref $Bytes) (local.get $bytes-raw)))
              (then (call $raise-check-bytes/who
                          (global.get $symbol:webracket-vfs-write-file)
                          (local.get $bytes-raw))
                    (unreachable)))
          (local.set $bytes (ref.cast (ref $Bytes) (local.get $bytes-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $path-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (local.set $bytes-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $bytes))))
          (if (i32.gt_u (local.get $path-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:webracket-vfs-write-file)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.gt_u (local.get $bytes-len)
                        (global.get $memory-map:vfs-file-buffer-length))
              (then (call $raise-vfs-file-buffer-too-small
                          (global.get $symbol:webracket-vfs-write-file)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-file-buffer-base)
                     (global.get $memory-map:vfs-file-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $path-len
                     (call $copy-bytes-to-memory
                           (local.get $path-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $bytes-len
                     (call $copy-bytes-to-memory
                           (local.get $bytes)
                           (global.get $memory-map:vfs-file-buffer-base)))
          (local.set $status
                     (call $js-vfs-write-file
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $path-len)
                           (global.get $memory-map:vfs-file-buffer-base)
                           (local.get $bytes-len)))
          (if (i32.lt_s (local.get $status) (i32.const 0))
              (then (call $raise-vfs-file-error/who-path
                          (global.get $symbol:webracket-vfs-write-file)
                          (local.get $path-raw)
                          (global.get $string:vfs:write-file-failed))
                    (unreachable)))
          (global.get $void))

    ;; delete-file : path-string? -> void?
    ;;   Delete an existing VFS file; directories and missing paths fail.
    (func $delete-file (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (local $path     (ref $Path))
          (local $path-bs  (ref $Bytes))
          (local $path-len i32)
          (local $status   i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:delete-file)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $path-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (if (i32.gt_u (local.get $path-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:delete-file)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $path-len
                     (call $copy-bytes-to-memory
                           (local.get $path-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $status
                     (call $js-vfs-delete-file
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $path-len)))
          (if (i32.lt_s (local.get $status) (i32.const 0))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:delete-file-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (global.get $void))

    ;; make-directory : path-string? [integer?] -> void?
    ;;   Create a VFS directory; optional permissions default to #o777 and are ignored.
    (func $make-directory (type $Prim12)
          (param $path-raw        (ref eq)) ;; path-string?
          (param $permissions-raw (ref eq)) ;; optional exact-integer?, default = #o777; ignored
          (result                 (ref eq))

          (local $path     (ref $Path))
          (local $path-bs  (ref $Bytes))
          (local $path-len i32)
          (local $status   i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:make-directory)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $path-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (if (i32.gt_u (local.get $path-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:make-directory)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $path-len
                     (call $copy-bytes-to-memory
                           (local.get $path-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $status
                     (call $js-vfs-make-directory
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $path-len)))
          (if (i32.lt_s (local.get $status) (i32.const 0))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:make-directory-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (global.get $void))

    ;; make-directory* : path-string? -> void?
    ;;   Create a VFS directory and its explicit ancestors; existing directories are accepted.
    (func $make-directory* (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (local $path     (ref $Path))
          (local $path-bs  (ref $Bytes))
          (local $path-len i32)
          (local $status   i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:make-directory*)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $path-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (if (i32.gt_u (local.get $path-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:make-directory*)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $path-len
                     (call $copy-bytes-to-memory
                           (local.get $path-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $status
                     (call $js-vfs-make-directory*
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $path-len)))
          (if (i32.lt_s (local.get $status) (i32.const 0))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:make-directory*-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (global.get $void))

    ;; make-parent-directory* : path-string? -> void?
    ;;   Create a VFS path's explicit parent directories.
    (func $make-parent-directory* (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (local $path     (ref $Path))
          (local $path-bs  (ref $Bytes))
          (local $path-len i32)
          (local $status   i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:make-parent-directory*)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $path-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (if (i32.gt_u (local.get $path-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:make-parent-directory*)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $path-len
                     (call $copy-bytes-to-memory
                           (local.get $path-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $status
                     (call $js-vfs-make-parent-directory*
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $path-len)))
          (if (i32.lt_s (local.get $status) (i32.const 0))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:make-parent-directory*-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (global.get $void))

    ;; delete-directory : path-string? -> void?
    ;;   Delete an existing empty VFS directory.
    (func $delete-directory (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (local $path     (ref $Path))
          (local $path-bs  (ref $Bytes))
          (local $path-len i32)
          (local $status   i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:delete-directory)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $path-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (if (i32.gt_u (local.get $path-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:delete-directory)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $path-len
                     (call $copy-bytes-to-memory
                           (local.get $path-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $status
                     (call $js-vfs-delete-directory
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $path-len)))
          (if (i32.lt_s (local.get $status) (i32.const 0))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:delete-directory-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (global.get $void))

    ;; delete-directory/files : path-string? [any/c] -> void?
    ;;   Keywordless form of Racket's #:must-exist? option; default #t.
    (func $delete-directory/files (type $Prim12)
          (param $path-raw       (ref eq)) ;; path-string?
          (param $must-exist-raw (ref eq)) ;; optional any/c, default = #t
          (result                (ref eq))

          (local $path     (ref $Path))
          (local $path-bs  (ref $Bytes))
          (local $path-len i32)
          (local $kind     i32)
          (local $status   i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:delete-directory/files)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $kind
                     (call $vfs-path-stat-kind
                           (global.get $symbol:delete-directory/files)
                           (local.get $path-raw)))
          (if (i32.eq (local.get $kind) (i32.const 0))
              (then
               (if (ref.eq (local.get $must-exist-raw) (global.get $false))
                   (then (return (global.get $void))))))
          (local.set $path-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (if (i32.gt_u (local.get $path-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:delete-directory/files)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $path-len
                     (call $copy-bytes-to-memory
                           (local.get $path-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $status
                     (call $js-vfs-delete-directory/files
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $path-len)))
          (if (i32.lt_s (local.get $status) (i32.const 0))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:delete-directory/files-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (global.get $void))

    ;; rename-file-or-directory : path-string? path-string? [any/c] -> void?
    ;;   Rename a VFS file or directory within the same mounted backend.
    (func $rename-file-or-directory (type $Prim23)
          (param $old-raw       (ref eq)) ;; path-string?
          (param $new-raw       (ref eq)) ;; path-string?
          (param $exists-ok-raw (ref eq)) ;; optional any/c, default = #f
          (result               (ref eq))

          (local $old      (ref $Path))
          (local $new      (ref $Path))
          (local $old-bs   (ref $Bytes))
          (local $new-bs   (ref $Bytes))
          (local $old-len  i32)
          (local $new-len  i32)
          (local $exists?  i32)
          (local $status   i32)

          (local.set $old
                     (call $path-string->path/checked
                           (global.get $symbol:rename-file-or-directory)
                           (local.get $old-raw)))
          (local.set $new
                     (call $path-string->path/checked
                           (global.get $symbol:rename-file-or-directory)
                           (local.get $new-raw)))
          (local.set $old-bs (struct.get $Path $bytes (local.get $old)))
          (local.set $new-bs (struct.get $Path $bytes (local.get $new)))
          (local.set $old-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $old-bs))))
          (local.set $new-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $new-bs))))
          (if (i32.gt_u (local.get $old-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:rename-file-or-directory)
                          (local.get $old-raw))
                    (unreachable)))
          (if (i32.gt_u (local.get $new-len)
                        (global.get $memory-map:vfs-file-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:rename-file-or-directory)
                          (local.get $new-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-file-buffer-base)
                     (global.get $memory-map:vfs-file-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $old-len
                     (call $copy-bytes-to-memory
                           (local.get $old-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $new-len
                     (call $copy-bytes-to-memory
                           (local.get $new-bs)
                           (global.get $memory-map:vfs-file-buffer-base)))
          (local.set $exists?
                     (if (result i32)
                         (ref.eq (local.get $exists-ok-raw) (global.get $missing))
                         (then (i32.const 0))
                         (else (i32.eqz (ref.eq (local.get $exists-ok-raw)
                                                (global.get $false))))))
          (local.set $status
                     (call $js-vfs-rename
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $old-len)
                           (global.get $memory-map:vfs-file-buffer-base)
                           (local.get $new-len)
                           (local.get $exists?)))
          (if (i32.lt_s (local.get $status) (i32.const 0))
              (then (call $raise-vfs-file-error/two-paths
                          (global.get $string:vfs:rename-failed)
                          (local.get $old-raw)
                          (local.get $new-raw))
                    (unreachable)))
          (global.get $void))

    ;; copy-directory/files : path-string? path-string? [any/c] [any/c] -> void?
    ;;   Keywordless form of #:keep-modify-seconds? and #:preserve-links?.
    ;;   The VFS has no links; metadata preservation is backend-defined for now.
    (func $copy-directory/files (type $Prim24)
          (param $src-raw                  (ref eq)) ;; path-string?
          (param $dest-raw                 (ref eq)) ;; path-string?
          (param $keep-modify-seconds-raw  (ref eq)) ;; optional any/c, default = #f; currently ignored
          (param $preserve-links-raw       (ref eq)) ;; optional any/c, default = #f; currently ignored
          (result                          (ref eq))

          (local $src      (ref $Path))
          (local $dest     (ref $Path))
          (local $src-bs   (ref $Bytes))
          (local $dest-bs  (ref $Bytes))
          (local $src-len  i32)
          (local $dest-len i32)
          (local $status   i32)

          (local.set $src
                     (call $path-string->path/checked
                           (global.get $symbol:copy-directory/files)
                           (local.get $src-raw)))
          (local.set $dest
                     (call $path-string->path/checked
                           (global.get $symbol:copy-directory/files)
                           (local.get $dest-raw)))
          (local.set $src-bs (struct.get $Path $bytes (local.get $src)))
          (local.set $dest-bs (struct.get $Path $bytes (local.get $dest)))
          (local.set $src-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $src-bs))))
          (local.set $dest-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $dest-bs))))
          (if (i32.gt_u (local.get $src-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:copy-directory/files)
                          (local.get $src-raw))
                    (unreachable)))
          (if (i32.gt_u (local.get $dest-len)
                        (global.get $memory-map:vfs-file-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:copy-directory/files)
                          (local.get $dest-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-file-buffer-base)
                     (global.get $memory-map:vfs-file-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $src-len
                     (call $copy-bytes-to-memory
                           (local.get $src-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $dest-len
                     (call $copy-bytes-to-memory
                           (local.get $dest-bs)
                           (global.get $memory-map:vfs-file-buffer-base)))
          (local.set $status
                     (call $js-vfs-copy-directory/files
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $src-len)
                           (global.get $memory-map:vfs-file-buffer-base)
                           (local.get $dest-len)))
          (if (i32.lt_s (local.get $status) (i32.const 0))
              (then (call $raise-vfs-file-error/two-paths
                          (global.get $string:vfs:copy-directory/files-failed)
                          (local.get $src-raw)
                          (local.get $dest-raw))
                    (unreachable)))
          (global.get $void))

    ;; copy-file : path-string? path-string? [any/c] -> void?
    ;;   Copy a VFS file within the same mounted backend; keyword options are not supported yet.
    (func $copy-file (type $Prim23)
          (param $src-raw       (ref eq)) ;; path-string?
          (param $dest-raw      (ref eq)) ;; path-string?
          (param $exists-ok-raw (ref eq)) ;; optional any/c, default = #f
          (result               (ref eq))

          (local $src      (ref $Path))
          (local $dest     (ref $Path))
          (local $src-bs   (ref $Bytes))
          (local $dest-bs  (ref $Bytes))
          (local $src-len  i32)
          (local $dest-len i32)
          (local $exists?  i32)
          (local $status   i32)

          (local.set $src
                     (call $path-string->path/checked
                           (global.get $symbol:copy-file)
                           (local.get $src-raw)))
          (local.set $dest
                     (call $path-string->path/checked
                           (global.get $symbol:copy-file)
                           (local.get $dest-raw)))
          (local.set $src-bs (struct.get $Path $bytes (local.get $src)))
          (local.set $dest-bs (struct.get $Path $bytes (local.get $dest)))
          (local.set $src-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $src-bs))))
          (local.set $dest-len
                     (array.len
                      (struct.get $Bytes $bs (local.get $dest-bs))))
          (if (i32.gt_u (local.get $src-len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:copy-file)
                          (local.get $src-raw))
                    (unreachable)))
          (if (i32.gt_u (local.get $dest-len)
                        (global.get $memory-map:vfs-file-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:copy-file)
                          (local.get $dest-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-file-buffer-base)
                     (global.get $memory-map:vfs-file-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (local.set $src-len
                     (call $copy-bytes-to-memory
                           (local.get $src-bs)
                           (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $dest-len
                     (call $copy-bytes-to-memory
                           (local.get $dest-bs)
                           (global.get $memory-map:vfs-file-buffer-base)))
          (local.set $exists?
                     (if (result i32)
                         (ref.eq (local.get $exists-ok-raw) (global.get $missing))
                         (then (i32.const 0))
                         (else (i32.eqz (ref.eq (local.get $exists-ok-raw)
                                                (global.get $false))))))
          (local.set $status
                     (call $js-vfs-copy-file
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $src-len)
                           (global.get $memory-map:vfs-file-buffer-base)
                           (local.get $dest-len)
                           (local.get $exists?)))
          (if (i32.lt_s (local.get $status) (i32.const 0))
              (then (call $raise-vfs-file-error/two-paths
                          (global.get $string:vfs:copy-file-failed)
                          (local.get $src-raw)
                          (local.get $dest-raw))
                    (unreachable)))
          (global.get $void))

    ;; make-temporary-candidate : symbol? (or/c string? missing) (or/c path-string? #f missing) -> path?
    ;;   Build a complete temporary path by replacing the first ~a in template with a counter.
    (func $make-temporary-candidate
          (param $who          (ref eq)) ;; symbol?
          (param $template-raw (ref eq)) ;; optional string?, default = "rkttmp~a"
          (param $base-dir-raw (ref eq)) ;; optional (or/c path-string? #f), default = (find-system-path 'temp-dir)
          (result              (ref eq))

          (local $template-bs (ref $Bytes))
          (local $template-ar (ref $I8Array))
          (local $template-len i32)
          (local $i            i32)
          (local $marker       i32)
          (local $n            i32)
          (local $digits       (ref eq))
          (local $digits-bs    (ref eq))
          (local $prefix       (ref eq))
          (local $suffix       (ref eq))
          (local $name-bs      (ref eq))
          (local $base-dir     (ref eq))

          (local.set $template-bs
                     (ref.cast (ref $Bytes) (global.get $bytes:empty)))
          (local.set $template-ar
                     (struct.get $Bytes $bs (local.get $template-bs)))
          (local.set $digits    (global.get $false))
          (local.set $digits-bs (global.get $bytes:empty))
          (local.set $prefix    (global.get $bytes:empty))
          (local.set $suffix    (global.get $bytes:empty))
          (local.set $name-bs   (global.get $bytes:empty))
          (local.set $base-dir  (global.get $false))

          (if (ref.eq (local.get $template-raw) (global.get $missing))
              (then
               (local.set $template-bs
                          (ref.cast (ref $Bytes)
                                    (global.get $bytes:rkttmp-template))))
              (else
               (if (i32.eqz (ref.test (ref $String) (local.get $template-raw)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:string?)
                               (local.get $template-raw))
                         (unreachable)))
               (local.set $template-bs
                          (ref.cast (ref $Bytes)
                                    (call $string->bytes/utf-8
                                          (local.get $template-raw)
                                          (global.get $false)
                                          (global.get $false)
                                          (global.get $false))))))
          (local.set $template-ar (struct.get $Bytes $bs (local.get $template-bs)))
          (local.set $template-len (array.len (local.get $template-ar)))
          (local.set $marker (i32.const -1))
          (block $done
                 (loop $loop
                       (br_if $done
                              (i32.ge_u
                               (i32.add (local.get $i) (i32.const 1))
                               (local.get $template-len)))
                       (if (i32.and
                            (i32.eq (array.get_u $I8Array
                                                 (local.get $template-ar)
                                                 (local.get $i))
                                    (i32.const 126)) ;; ~
                            (i32.eq (array.get_u $I8Array
                                                 (local.get $template-ar)
                                                 (i32.add (local.get $i) (i32.const 1)))
                                    (i32.const 97))) ;; a
                           (then (local.set $marker (local.get $i))
                                 (br $done)))
                       (local.set $i (i32.add (local.get $i) (i32.const 1)))
                       (br $loop)))
          (if (i32.lt_s (local.get $marker) (i32.const 0))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:vfs:temporary-template)
                          (local.get $template-raw))
                    (unreachable)))
          (global.set $temporary-file-counter
                      (i32.add (global.get $temporary-file-counter)
                               (i32.const 1)))
          (local.set $n (global.get $temporary-file-counter))
          (local.set $digits
                     (call $number->string
                           (ref.i31 (i32.shl (local.get $n) (i32.const 1)))
                           (global.get $missing)))
          (local.set $digits-bs
                     (call $string->bytes/utf-8
                           (local.get $digits)
                           (global.get $false)
                           (global.get $false)
                           (global.get $false)))
          (local.set $prefix
                     (call $subbytes
                           (local.get $template-bs)
                           (ref.i31 (i32.shl (i32.const 0) (i32.const 1)))
                           (ref.i31 (i32.shl (local.get $marker) (i32.const 1)))))
          (local.set $suffix
                     (call $subbytes
                           (local.get $template-bs)
                           (ref.i31 (i32.shl
                                     (i32.add (local.get $marker) (i32.const 2))
                                     (i32.const 1)))
                           (ref.i31 (i32.shl (local.get $template-len) (i32.const 1)))))
          (local.set $name-bs
                     (call $bytes-append/2
                           (call $bytes-append/2
                                 (local.get $prefix)
                                 (local.get $digits-bs))
                           (local.get $suffix)))
          (if (call $path-bytes-absolute?
                    (ref.cast (ref $Bytes) (local.get $name-bs)))
              (then (return
                     (call $bytes->path
                           (local.get $name-bs)
                           (global.get $missing)))))
          (local.set $base-dir
                     (if (result (ref eq))
                         (i32.or (ref.eq (local.get $base-dir-raw) (global.get $missing))
                                 (ref.eq (local.get $base-dir-raw) (global.get $false)))
                         (then (call $find-system-path (global.get $symbol:temp-dir)))
                         (else (local.get $base-dir-raw))))
          (call $path-join-bytes
                (local.get $base-dir)
                (call $bytes->path
                      (local.get $name-bs)
                      (global.get $missing))))

    ;; make-temporary-file : [string?] [(or/c path-string? #f 'directory)] [(or/c path-string? #f)] -> complete-path?
    ;;   Keywordless form of Racket's #:copy-from and #:base-dir options.
    ;;   Template support currently recognizes one literal ~a placeholder.
    (func $make-temporary-file (type $Prim03)
          (param $template-raw (ref eq)) ;; optional string?, default = "rkttmp~a"
          (param $copy-from-raw (ref eq)) ;; optional (or/c path-string? #f 'directory), default = #f
          (param $base-dir-raw (ref eq)) ;; optional (or/c path-string? #f), default = #f
          (result (ref eq))

          (local $copy-from (ref eq))
          (local $candidate (ref eq))
          (local $port      (ref eq))

          (local.set $copy-from (global.get $false))
          (local.set $candidate (global.get $false))
          (local.set $port      (global.get $false))
          (local.set $copy-from
                     (if (result (ref eq))
                         (ref.eq (local.get $copy-from-raw) (global.get $missing))
                         (then (global.get $false))
                         (else (local.get $copy-from-raw))))
          (block $done
                 (loop $loop
                       (local.set $candidate
                                  (call $make-temporary-candidate
                                        (global.get $symbol:make-temporary-file)
                                        (local.get $template-raw)
                                        (local.get $base-dir-raw)))
                       (br_if $loop
                              (i32.or
                               (ref.eq (call $file-exists? (local.get $candidate))
                                       (global.get $true))
                               (ref.eq (call $directory-exists? (local.get $candidate))
                                       (global.get $true))))
                       (if (ref.eq (local.get $copy-from) (global.get $symbol:directory))
                           (then
                            (drop (call $make-directory
                                        (local.get $candidate)
                                        (global.get $missing))))
                           (else
                            (if (ref.eq (local.get $copy-from) (global.get $false))
                                (then
                                 (local.set $port
                                            (call $open-output-file
                                                  (local.get $candidate)
                                                  (global.get $symbol:binary)
                                                  (global.get $symbol:error)))
                                 (drop (call $close-output-port
                                             (local.get $port))))
                                (else
                                 (drop (call $copy-file
                                             (local.get $copy-from)
                                             (local.get $candidate)
                                             (global.get $false)))))))
                       (br $done)))
          (local.get $candidate))

    ;; make-temporary-candidate* : symbol? bytes? bytes? (or/c path-string? #f missing) -> path?
    ;;   Build a complete temporary path as bytes-append of prefix, counter, and suffix.
    (func $make-temporary-candidate*
          (param $who          (ref eq)) ;; symbol?
          (param $prefix-raw   (ref eq)) ;; bytes?
          (param $suffix-raw   (ref eq)) ;; bytes?
          (param $base-dir-raw (ref eq)) ;; optional (or/c path-string? #f), default = (find-system-path 'temp-dir)
          (result              (ref eq))

          (local $prefix   (ref $Bytes))
          (local $suffix   (ref $Bytes))
          (local $digits   (ref eq))
          (local $digits-bs (ref eq))
          (local $name-bs   (ref eq))
          (local $base-dir  (ref eq))
          (local $n         i32)

          (local.set $prefix
                     (ref.cast (ref $Bytes) (global.get $bytes:empty)))
          (local.set $suffix
                     (ref.cast (ref $Bytes) (global.get $bytes:empty)))
          (local.set $digits    (global.get $false))
          (local.set $digits-bs (global.get $bytes:empty))
          (local.set $name-bs   (global.get $bytes:empty))
          (local.set $base-dir  (global.get $false))
          (if (i32.eqz (ref.test (ref $Bytes) (local.get $prefix-raw)))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:bytes?)
                          (local.get $prefix-raw))
                    (unreachable)))
          (if (i32.eqz (ref.test (ref $Bytes) (local.get $suffix-raw)))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:bytes?)
                          (local.get $suffix-raw))
                    (unreachable)))
          (local.set $prefix (ref.cast (ref $Bytes) (local.get $prefix-raw)))
          (local.set $suffix (ref.cast (ref $Bytes) (local.get $suffix-raw)))
          (global.set $temporary-file-counter
                      (i32.add (global.get $temporary-file-counter)
                               (i32.const 1)))
          (local.set $n (global.get $temporary-file-counter))
          (local.set $digits
                     (call $number->string
                           (ref.i31 (i32.shl (local.get $n) (i32.const 1)))
                           (global.get $missing)))
          (local.set $digits-bs
                     (call $string->bytes/utf-8
                           (local.get $digits)
                           (global.get $false)
                           (global.get $false)
                           (global.get $false)))
          (local.set $name-bs
                     (call $bytes-append/2
                           (call $bytes-append/2
                                 (local.get $prefix)
                                 (local.get $digits-bs))
                           (local.get $suffix)))
          (if (call $path-bytes-absolute?
                    (ref.cast (ref $Bytes) (local.get $name-bs)))
              (then (return
                     (call $bytes->path
                           (local.get $name-bs)
                           (global.get $missing)))))
          (local.set $base-dir
                     (if (result (ref eq))
                         (i32.or (ref.eq (local.get $base-dir-raw) (global.get $missing))
                                 (ref.eq (local.get $base-dir-raw) (global.get $false)))
                         (then (call $find-system-path (global.get $symbol:temp-dir)))
                         (else (local.get $base-dir-raw))))
          (call $path-join-bytes
                (local.get $base-dir)
                (call $bytes->path
                      (local.get $name-bs)
                      (global.get $missing))))

    ;; make-temporary-file* : bytes? bytes? [(or/c path-string? #f)] [(or/c path-string? #f)] -> complete-path?
    ;;   Keywordless form of Racket's #:copy-from and #:base-dir options.
    (func $make-temporary-file* (type $Prim24)
          (param $prefix-raw    (ref eq)) ;; bytes?
          (param $suffix-raw    (ref eq)) ;; bytes?
          (param $copy-from-raw (ref eq)) ;; optional (or/c path-string? #f), default = #f
          (param $base-dir-raw  (ref eq)) ;; optional (or/c path-string? #f), default = #f
          (result (ref eq))

          (local $copy-from (ref eq))
          (local $candidate (ref eq))
          (local $port      (ref eq))

          (local.set $copy-from (global.get $false))
          (local.set $candidate (global.get $false))
          (local.set $port      (global.get $false))
          (local.set $copy-from
                     (if (result (ref eq))
                         (ref.eq (local.get $copy-from-raw) (global.get $missing))
                         (then (global.get $false))
                         (else (local.get $copy-from-raw))))
          (block $done
                 (loop $loop
                       (local.set $candidate
                                  (call $make-temporary-candidate*
                                        (global.get $symbol:make-temporary-file*)
                                        (local.get $prefix-raw)
                                        (local.get $suffix-raw)
                                        (local.get $base-dir-raw)))
                       (br_if $loop
                              (i32.or
                               (ref.eq (call $file-exists? (local.get $candidate))
                                       (global.get $true))
                               (ref.eq (call $directory-exists? (local.get $candidate))
                                       (global.get $true))))
                       (if (ref.eq (local.get $copy-from) (global.get $false))
                           (then
                            (local.set $port
                                       (call $open-output-file
                                             (local.get $candidate)
                                             (global.get $symbol:binary)
                                             (global.get $symbol:error)))
                            (drop (call $close-output-port
                                        (local.get $port))))
                           (else
                            (drop (call $copy-file
                                        (local.get $copy-from)
                                        (local.get $candidate)
                                        (global.get $false)))))
                       (br $done)))
          (local.get $candidate))

    ;; make-temporary-directory : [string?] [(or/c path-string? #f)] -> complete-path?
    ;;   Keywordless form of Racket's #:base-dir option.
    (func $make-temporary-directory (type $Prim02)
          (param $template-raw (ref eq)) ;; optional string?, default = "rkttmp~a"
          (param $base-dir-raw (ref eq)) ;; optional (or/c path-string? #f), default = #f
          (result (ref eq))

          (local $candidate (ref eq))

          (local.set $candidate (global.get $false))
          (block $done
                 (loop $loop
                       (local.set $candidate
                                  (call $make-temporary-candidate
                                        (global.get $symbol:make-temporary-directory)
                                        (local.get $template-raw)
                                        (local.get $base-dir-raw)))
                       (br_if $loop
                              (i32.or
                               (ref.eq (call $file-exists? (local.get $candidate))
                                       (global.get $true))
                               (ref.eq (call $directory-exists? (local.get $candidate))
                                       (global.get $true))))
                       (drop (call $make-directory
                                   (local.get $candidate)
                                   (global.get $missing)))
                       (br $done)))
          (local.get $candidate))

    ;; make-temporary-directory* : bytes? bytes? [(or/c path-string? #f)] -> complete-path?
    ;;   Keywordless form of Racket's #:base-dir option.
    (func $make-temporary-directory* (type $Prim23)
          (param $prefix-raw   (ref eq)) ;; bytes?
          (param $suffix-raw   (ref eq)) ;; bytes?
          (param $base-dir-raw (ref eq)) ;; optional (or/c path-string? #f), default = #f
          (result (ref eq))

          (local $candidate (ref eq))

          (local.set $candidate (global.get $false))
          (block $done
                 (loop $loop
                       (local.set $candidate
                                  (call $make-temporary-candidate*
                                        (global.get $symbol:make-temporary-directory*)
                                        (local.get $prefix-raw)
                                        (local.get $suffix-raw)
                                        (local.get $base-dir-raw)))
                       (br_if $loop
                              (i32.or
                               (ref.eq (call $file-exists? (local.get $candidate))
                                       (global.get $true))
                               (ref.eq (call $directory-exists? (local.get $candidate))
                                       (global.get $true))))
                       (drop (call $make-directory
                                   (local.get $candidate)
                                   (global.get $missing)))
                       (br $done)))
          (local.get $candidate))

    ;; file-or-directory-modify-seconds : path-string? [(or/c exact-nonnegative-integer? #f)] [(-> any)] -> any
    ;;   Get or set the VFS modification time. Optional secs defaults
    ;;   to #f, and optional fail-thunk is called on missing VFS paths.
    (func $file-or-directory-modify-seconds (type $Prim13)
          (param $path-raw (ref eq)) ;; path-string?
          (param $secs-raw (ref eq)) ;; optional (or/c exact-nonnegative-integer? #f), default = #f
          (param $fail-raw (ref eq)) ;; optional (-> any), default = raise filesystem error
          (result          (ref eq))

          (local $path     (ref $Path))
          (local $bytes    (ref $Bytes))
          (local $fail     (ref null $Procedure))
          (local $fail-inv (ref null $ProcedureInvoker))
          (local $args     (ref $Args))
          (local $len      i32)
          (local $has-secs i32)
          (local $secs     i32)
          (local $mtime    i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:file-or-directory-modify-seconds)
                           (local.get $path-raw)))
          (local.set $bytes (struct.get $Path $bytes (local.get $path)))
          (local.set $len
                     (array.len
                      (struct.get $Bytes $bs (local.get $bytes))))
          (if (i32.gt_u (local.get $len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:file-or-directory-modify-seconds)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (if (ref.eq (local.get $secs-raw) (global.get $missing))
              (then (local.set $has-secs (i32.const 0)))
              (else
               (if (ref.eq (local.get $secs-raw) (global.get $false))
                   (then (local.set $has-secs (i32.const 0)))
                   (else
                    (if (ref.eq (call $exact-nonnegative-integer? (local.get $secs-raw))
                                (global.get $false))
                        (then (call $raise-argument-error1
                                    (global.get $symbol:file-or-directory-modify-seconds)
                                    (global.get $string:exact-nonnegative-integer?)
                                    (local.get $secs-raw))
                              (unreachable)))
                    (local.set $has-secs (i32.const 1))
                    (local.set $secs
                               (i32.shr_s
                                (i31.get_s
                                 (ref.cast (ref i31) (local.get $secs-raw)))
                                (i32.const 1)))))))
          (if (i32.eqz (ref.eq (local.get $fail-raw) (global.get $missing)))
              (then
               (local.set $fail
                          (call $check-filesystem-procedure-arity
                                (global.get $symbol:file-or-directory-modify-seconds)
                                (global.get $string:filesystem-procedure-arity-0)
                                (local.get $fail-raw)
                                (i32.const 0)))
               (local.set $fail-inv
                          (struct.get $Procedure $invoke
                                      (ref.as_non_null (local.get $fail))))))
          (local.set $len (call $copy-bytes-to-memory
                                (local.get $bytes)
                                (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $mtime
                     (call $js-vfs-modify-seconds
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $len)
                          (local.get $has-secs)
                          (local.get $secs)))
          (if (i32.lt_s (local.get $mtime) (i32.const 0))
              (then
               (if (ref.eq (local.get $fail-raw) (global.get $missing))
                   (then (call $raise-vfs-file-error/path
                               (global.get $string:vfs:modify-seconds-failed)
                               (local.get $path-raw))
                         (unreachable)))
               (local.set $args
                          (array.new $Args
                                     (global.get $null)
                                     (i32.const 0)))
               (return_call_ref $ProcedureInvoker
                                (ref.as_non_null (local.get $fail))
                                (local.get $args)
                                (ref.as_non_null (local.get $fail-inv)))))
          (if (result (ref eq))
              (i32.eqz (local.get $has-secs))
              (then (ref.i31 (i32.shl (local.get $mtime) (i32.const 1))))
              (else (global.get $void))))

    ;; file-or-directory-permissions : path-string? [(or/c #f 'bits (integer-in 0 65535))] -> (or/c list? fixnum? void?)
    ;;   Get or set VFS permission bits; default mode returns '(read write execute)-style permissions.
    (func $file-or-directory-permissions (type $Prim12)
          (param $path-raw (ref eq)) ;; path-string?
          (param $mode-raw (ref eq)) ;; optional (or/c #f 'bits (integer-in 0 65535)), default = #f
          (result          (ref eq))

          (local $path      (ref $Path))
          (local $bytes     (ref $Bytes))
          (local $len       i32)
          (local $set-mode? i32)
          (local $bits-mode? i32)
          (local $mode      i32)
          (local $bits      i32)
          (local $perms     (ref eq))

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:file-or-directory-permissions)
                           (local.get $path-raw)))
          (local.set $bytes (struct.get $Path $bytes (local.get $path)))
          (local.set $len
                     (array.len
                      (struct.get $Bytes $bs (local.get $bytes))))
          (if (i32.gt_u (local.get $len)
                        (global.get $memory-map:vfs-path-buffer-length))
              (then (call $raise-vfs-path-too-long
                          (global.get $symbol:file-or-directory-permissions)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz
               (call $linear-memory-range-available?
                     (global.get $memory-map:vfs-path-buffer-base)
                     (global.get $memory-map:vfs-path-buffer-length)))
              (then (call $raise-string-buffer-overflow)
                    (unreachable)))
          (if (ref.eq (local.get $mode-raw) (global.get $missing))
              (then (local.set $set-mode? (i32.const 0)))
              (else
               (if (ref.eq (local.get $mode-raw) (global.get $false))
                   (then (local.set $set-mode? (i32.const 0)))
                   (else
                    (if (ref.eq (local.get $mode-raw) (global.get $symbol:bits))
                        (then (local.set $set-mode? (i32.const 0))
                              (local.set $bits-mode? (i32.const 1)))
                        (else
                         (if (ref.eq (call $exact-nonnegative-integer? (local.get $mode-raw))
                                     (global.get $false))
                             (then (call $raise-argument-error1
                                         (global.get $symbol:file-or-directory-permissions)
                                         (global.get $string:permissions-mode)
                                         (local.get $mode-raw))
                                   (unreachable)))
                         (local.set $mode
                                    (i32.shr_s
                                     (i31.get_s
                                      (ref.cast (ref i31) (local.get $mode-raw)))
                                     (i32.const 1)))
                         (if (i32.gt_u (local.get $mode) (i32.const 65535))
                             (then (call $raise-argument-error1
                                         (global.get $symbol:file-or-directory-permissions)
                                         (global.get $string:permissions-mode)
                                         (local.get $mode-raw))
                                   (unreachable)))
                         (local.set $set-mode? (i32.const 1))))))))
          (local.set $len (call $copy-bytes-to-memory
                                (local.get $bytes)
                                (global.get $memory-map:vfs-path-buffer-base)))
          (local.set $bits
                     (call $js-vfs-permissions
                           (global.get $memory-map:vfs-path-buffer-base)
                           (local.get $len)
                           (local.get $set-mode?)
                           (local.get $mode)))
          (if (i32.lt_s (local.get $bits) (i32.const 0))
              (then (call $raise-vfs-file-error/path
                          (global.get $string:vfs:permissions-failed)
                          (local.get $path-raw))
                    (unreachable)))
          (if (local.get $set-mode?)
              (then (return (global.get $void))))
          (if (local.get $bits-mode?)
              (then (return (ref.i31 (i32.shl (local.get $bits) (i32.const 1))))))
          (local.set $perms (global.get $null))
          (if (i32.ne (i32.and (local.get $bits) (i32.const #o100)) (i32.const 0))
              (then (local.set $perms
                               (call $cons
                                     (global.get $symbol:execute)
                                     (local.get $perms)))))
          (if (i32.ne (i32.and (local.get $bits) (i32.const #o200)) (i32.const 0))
              (then (local.set $perms
                               (call $cons
                                     (global.get $symbol:write)
                                     (local.get $perms)))))
          (if (i32.ne (i32.and (local.get $bits) (i32.const #o400)) (i32.const 0))
              (then (local.set $perms
                               (call $cons
                                     (global.get $symbol:read)
                                     (local.get $perms)))))
          (local.get $perms))

    ;; open-output-file : path-string? [(or/c 'binary 'text)] [(or/c 'error 'append 'replace 'truncate 'must-truncate 'truncate/replace)] -> output-port?
    ;;   Keywordless form of Racket's #:mode and #:exists options.
    ;;   Text mode is accepted but currently behaves like binary mode.
    ;;   Update-style modes wait on random-access file-position support.
    (func $open-output-file (type $Prim13)
          (param $path-raw   (ref eq)) ;; path-string?
          (param $mode-raw   (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (param $exists-raw (ref eq)) ;; optional exists mode, default = 'error
          (result            (ref eq))

          (local $path     (ref $Path))
          (local $bs       (ref $Bytes))
          (local $file-bs  (ref $Bytes))
          (local $loc      (ref $Location))
          (local $mode     (ref eq))
          (local $exists   (ref eq))
          (local $kind     i32)
          (local $append?  i32)
          (local $idx      i32)
          (local $capacity i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:open-output-file)
                           (local.get $path-raw)))
          (local.set $mode
                     (if (result (ref eq))
                         (ref.eq (local.get $mode-raw) (global.get $missing))
                         (then (global.get $symbol:binary))
                         (else (local.get $mode-raw))))
          (if (i32.eqz
               (i32.or (ref.eq (local.get $mode) (global.get $symbol:binary))
                       (ref.eq (local.get $mode) (global.get $symbol:text))))
              (then (call $raise-argument-error1
                          (global.get $symbol:open-output-file)
                          (global.get $string:output-file-mode-flag)
                          (local.get $mode-raw))
                    (unreachable)))
          (local.set $exists
                     (if (result (ref eq))
                         (ref.eq (local.get $exists-raw) (global.get $missing))
                         (then (global.get $symbol:error))
                         (else (local.get $exists-raw))))
          (if (i32.eqz
               (i32.or
                (i32.or (ref.eq (local.get $exists) (global.get $symbol:error))
                        (ref.eq (local.get $exists) (global.get $symbol:append)))
                (i32.or
                 (i32.or (ref.eq (local.get $exists) (global.get $symbol:replace))
                         (ref.eq (local.get $exists) (global.get $symbol:truncate)))
                 (i32.or (ref.eq (local.get $exists) (global.get $symbol:must-truncate))
                         (ref.eq (local.get $exists) (global.get $symbol:truncate/replace))))))
              (then (call $raise-argument-error1
                          (global.get $symbol:open-output-file)
                          (global.get $string:output-file-exists-flag)
                          (local.get $exists-raw))
                    (unreachable)))
          (local.set $kind
                     (call $vfs-path-stat-kind
                           (global.get $symbol:open-output-file)
                           (local.get $path-raw)))
          (if (i32.eq (local.get $kind) (i32.const 2))
              (then (call $raise-vfs-file-error/who-path
                          (global.get $symbol:open-output-file)
                          (local.get $path-raw)
                          (global.get $string:vfs:write-file-failed))
                    (unreachable)))
          (if (i32.and
               (ref.eq (local.get $exists) (global.get $symbol:error))
               (i32.ne (local.get $kind) (i32.const 0)))
              (then (call $raise-vfs-file-error/who-path
                          (global.get $symbol:open-output-file)
                          (local.get $path-raw)
                          (global.get $string:vfs:write-file-failed))
                    (unreachable)))
          (if (i32.and
               (ref.eq (local.get $exists) (global.get $symbol:must-truncate))
               (i32.ne (local.get $kind) (i32.const 1)))
              (then (call $raise-vfs-file-error/who-path
                          (global.get $symbol:open-output-file)
                          (local.get $path-raw)
                          (global.get $string:vfs:write-file-failed))
                    (unreachable)))
          (local.set $append?
                     (ref.eq (local.get $exists) (global.get $symbol:append)))
          (local.set $capacity (i32.const 32))
          (local.set $idx (i32.const 0))
          (local.set $bs
                     (struct.new $Bytes
                                 (i32.const 0)
                                 (i32.const 0)
                                 (call $i8make-array
                                       (i32.const 32)
                                       (i32.const 0))))
          (if (i32.and (local.get $append?)
                       (i32.eq (local.get $kind) (i32.const 1)))
              (then
               (local.set $file-bs
                          (call $vfs-read-file-bytes
                                (global.get $symbol:open-output-file)
                                (local.get $path-raw)))
               (local.set $idx
                          (array.len
                           (struct.get $Bytes $bs (local.get $file-bs))))
               (if (local.get $idx)
                   (then
                    (local.set $capacity (local.get $idx))
                    (local.set $bs
                               (struct.new $Bytes
                                           (i32.const 0)
                                           (i32.const 0)
                                           (struct.get $Bytes $bs
                                                       (local.get $file-bs))))))))
          (local.set $loc
                     (ref.cast (ref $Location)
                               (call $make-initial-location)))
          (struct.new $OutputFilePort
                      (i32.const 0)        ;; $hash
                      (local.get $path)    ;; $name
                      (i32.const 0)        ;; $closed
                      (local.get $bs)      ;; $bytes
                      (local.get $capacity) ;; $len
                      (local.get $idx)     ;; $idx
                      (local.get $loc)     ;; $loc
                      (i32.const 0)        ;; $utf8-len
                      (i32.const 0)        ;; $utf8-left
                      (i32.const 0)        ;; $utf8-bytes
                      (local.get $path)))  ;; $path

    ;; open-input-file : path-string? [(or/c 'binary 'text)] [any/c] -> input-port?
    ;;   Keywordless form of Racket's #:mode and #:for-module? options.
    ;;   Text mode is accepted but currently behaves like binary mode.
    (func $open-input-file (type $Prim13)
          (param $path-raw       (ref eq)) ;; path-string?
          (param $mode-raw       (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (param $for-module-raw (ref eq)) ;; optional any/c, default = #f; currently ignored
          (result                (ref eq))

          (local $path      (ref $Path))
          (local $file-bs   (ref $Bytes))
          (local $mode      (ref eq))

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:open-input-file)
                           (local.get $path-raw)))
          (local.set $mode
                     (if (result (ref eq))
                         (ref.eq (local.get $mode-raw) (global.get $missing))
                         (then (global.get $symbol:binary))
                         (else (local.get $mode-raw))))
          (if (i32.eqz
               (i32.or (ref.eq (local.get $mode) (global.get $symbol:binary))
                       (ref.eq (local.get $mode) (global.get $symbol:text))))
              (then (call $raise-argument-error1
                          (global.get $symbol:open-input-file)
                          (global.get $string:input-file-mode-flag)
                          (local.get $mode-raw))
                    (unreachable)))
          (local.set $file-bs
                     (call $vfs-read-file-bytes
                           (global.get $symbol:open-input-file)
                           (local.get $path-raw)))
          (call $open-input-bytes
                (local.get $file-bs)
                (local.get $path)))

    ;; $call-with-input-file : path-string? (input-port? . -> . any) [(or/c 'binary 'text)] -> any
    ;;   Open a VFS file, pass its input port to proc, and return proc's result.
    (func $call-with-input-file (type $Prim23)
          (param $path-raw (ref eq)) ;; path-string?
          (param $proc     (ref eq)) ;; procedure?
          (param $mode-raw (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (result          (ref eq))

          (local $f    (ref $Procedure))
          (local $finv (ref $ProcedureInvoker))
          (local $port (ref eq))
          (local $args (ref $Args))
          (local $res  (ref eq))

          (local.set $f
                     (call $check-filesystem-procedure-arity
                           (global.get $symbol:call-with-input-file)
                           (global.get $string:filesystem-input-port-procedure)
                           (local.get $proc)
                           (i32.const 1)))
          (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
          (local.set $port
                     (call $open-input-file
                           (local.get $path-raw)
                           (local.get $mode-raw)
                           (global.get $missing)))
          (local.set $args (array.new_fixed $Args 1 (local.get $port)))
          (local.set $res
                     (call_ref $ProcedureInvoker
                               (local.get $f)
                               (local.get $args)
                               (local.get $finv)))
          (drop (call $close-input-port (local.get $port)))
          (local.get $res))

    ;; $call-with-output-file : path-string? (output-port? . -> . any) [(or/c 'binary 'text)] [exists-mode] -> any
    ;;   Open a VFS output file, pass its output port to proc, close it,
    ;;   and return proc's result.
    (func $call-with-output-file (type $Prim24)
          (param $path-raw   (ref eq)) ;; path-string?
          (param $proc       (ref eq)) ;; procedure?
          (param $mode-raw   (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (param $exists-raw (ref eq)) ;; optional exists mode, default = 'error
          (result            (ref eq))

          (local $f    (ref $Procedure))
          (local $finv (ref $ProcedureInvoker))
          (local $port (ref eq))
          (local $args (ref $Args))
          (local $res  (ref eq))

          (local.set $f
                     (call $check-filesystem-procedure-arity
                           (global.get $symbol:call-with-output-file)
                           (global.get $string:filesystem-output-port-procedure)
                           (local.get $proc)
                           (i32.const 1)))
          (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
          (local.set $port
                     (call $open-output-file
                           (local.get $path-raw)
                           (local.get $mode-raw)
                           (local.get $exists-raw)))
          (local.set $args (array.new_fixed $Args 1 (local.get $port)))
          (local.set $res
                     (call_ref $ProcedureInvoker
                               (local.get $f)
                               (local.get $args)
                               (local.get $finv)))
          (drop (call $close-output-port (local.get $port)))
          (local.get $res))

    ;; $call-with-current-input-port/thunk : input-port? procedure? -> any
    ;;   Install port as the current input port while thunk runs, then restore it.
    (func $call-with-current-input-port/thunk
          (param $port  (ref eq)) ;; input-port?
          (param $thunk (ref eq)) ;; procedure?
          (result       (ref eq))

          (local $f       (ref $Procedure))
          (local $finv    (ref $ProcedureInvoker))
          (local $args    (ref $Args))
          (local $old     (ref eq))
          (local $res     (ref eq))
          (local $exn-val (ref eq))

          (if (ref.eq (call $procedure? (local.get $thunk))
                      (global.get $false))
              (then (call $raise-argument-error:procedure-expected
                          (local.get $thunk))
                    (unreachable)))
          (local.set $f    (ref.cast (ref $Procedure) (local.get $thunk)))
          (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
          (local.set $args (array.new $Args (global.get $null) (i32.const 0)))
          (local.set $old
                     (call $current-input-port
                           (global.get $missing)))
          (drop (call $current-input-port (local.get $port)))
          (local.set $res
                     (block $done (result (ref eq))
                            (block $handler-block (result (ref eq))
                                   (try_table (result (ref eq))
                                              (catch $exn $handler-block)
                                              (call_ref $ProcedureInvoker
                                                        (local.get $f)
                                                        (local.get $args)
                                                        (local.get $finv))
                                              (br $done)))
                            (local.set $exn-val)
                            (drop (call $current-input-port (local.get $old)))
                            (throw $exn (local.get $exn-val))
                            (unreachable)))
          (drop (call $current-input-port (local.get $old)))
          (local.get $res))

    ;; $call-with-current-output-port/thunk : output-port? procedure? -> any
    ;;   Install port as the current output port while thunk runs, then restore it.
    (func $call-with-current-output-port/thunk
          (param $port  (ref eq)) ;; output-port?
          (param $thunk (ref eq)) ;; procedure?
          (result       (ref eq))

          (local $f       (ref $Procedure))
          (local $finv    (ref $ProcedureInvoker))
          (local $args    (ref $Args))
          (local $old     (ref eq))
          (local $res     (ref eq))
          (local $exn-val (ref eq))

          (if (ref.eq (call $procedure? (local.get $thunk))
                      (global.get $false))
              (then (call $raise-argument-error:procedure-expected
                          (local.get $thunk))
                    (unreachable)))
          (local.set $f    (ref.cast (ref $Procedure) (local.get $thunk)))
          (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
          (local.set $args (array.new $Args (global.get $null) (i32.const 0)))
          (local.set $old
                     (call $current-output-port
                           (global.get $missing)))
          (drop (call $current-output-port (local.get $port)))
          (local.set $res
                     (block $done (result (ref eq))
                            (block $handler-block (result (ref eq))
                                   (try_table (result (ref eq))
                                              (catch $exn $handler-block)
                                              (call_ref $ProcedureInvoker
                                                        (local.get $f)
                                                        (local.get $args)
                                                        (local.get $finv))
                                              (br $done)))
                            (local.set $exn-val)
                            (drop (call $current-output-port (local.get $old)))
                            (throw $exn (local.get $exn-val))
                            (unreachable)))
          (drop (call $current-output-port (local.get $old)))
          (local.get $res))

    ;; $call-with-input-file* : path-string? (input-port? . -> . any) [(or/c 'binary 'text)] -> any
    ;;   Open a VFS file, pass its input port to proc, and close it on return or exception.
    (func $call-with-input-file* (type $Prim23)
          (param $path-raw (ref eq)) ;; path-string?
          (param $proc     (ref eq)) ;; procedure?
          (param $mode-raw (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (result          (ref eq))

          (local $f       (ref $Procedure))
          (local $finv    (ref $ProcedureInvoker))
          (local $port    (ref eq))
          (local $args    (ref $Args))
          (local $res     (ref eq))
          (local $exn-val (ref eq))

          (local.set $f
                     (call $check-filesystem-procedure-arity
                           (global.get $symbol:call-with-input-file*)
                           (global.get $string:filesystem-input-port-procedure)
                           (local.get $proc)
                           (i32.const 1)))
          (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
          (local.set $port
                     (call $open-input-file
                           (local.get $path-raw)
                           (local.get $mode-raw)
                           (global.get $missing)))
          (local.set $args (array.new_fixed $Args 1 (local.get $port)))
          (local.set $res
                     (block $done (result (ref eq))
                            (block $handler-block (result (ref eq))
                                   (try_table (result (ref eq))
                                              (catch $exn $handler-block)
                                              (call_ref $ProcedureInvoker
                                                        (local.get $f)
                                                        (local.get $args)
                                                        (local.get $finv))
                                              (br $done)))
                            (local.set $exn-val)
                            (drop (call $close-input-port (local.get $port)))
                            (throw $exn (local.get $exn-val))
                            (unreachable)))
          (drop (call $close-input-port (local.get $port)))
          (local.get $res))

    ;; $call-with-output-file* : path-string? (output-port? . -> . any) [(or/c 'binary 'text)] [exists-mode] -> any
    ;;   Open a VFS file, pass its output port to proc, and close it on return or exception.
    (func $call-with-output-file* (type $Prim24)
          (param $path-raw   (ref eq)) ;; path-string?
          (param $proc       (ref eq)) ;; procedure?
          (param $mode-raw   (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (param $exists-raw (ref eq)) ;; optional exists mode, default = 'error
          (result            (ref eq))

          (local $f       (ref $Procedure))
          (local $finv    (ref $ProcedureInvoker))
          (local $port    (ref eq))
          (local $args    (ref $Args))
          (local $res     (ref eq))
          (local $exn-val (ref eq))

          (local.set $f
                     (call $check-filesystem-procedure-arity
                           (global.get $symbol:call-with-output-file*)
                           (global.get $string:filesystem-output-port-procedure)
                           (local.get $proc)
                           (i32.const 1)))
          (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
          (local.set $port
                     (call $open-output-file
                           (local.get $path-raw)
                           (local.get $mode-raw)
                           (local.get $exists-raw)))
          (local.set $args (array.new_fixed $Args 1 (local.get $port)))
          (local.set $res
                     (block $done (result (ref eq))
                            (block $handler-block (result (ref eq))
                                   (try_table (result (ref eq))
                                              (catch $exn $handler-block)
                                              (call_ref $ProcedureInvoker
                                                        (local.get $f)
                                                        (local.get $args)
                                                        (local.get $finv))
                                              (br $done)))
                            (local.set $exn-val)
                            (drop (call $close-output-port (local.get $port)))
                            (throw $exn (local.get $exn-val))
                            (unreachable)))
          (drop (call $close-output-port (local.get $port)))
          (local.get $res))

    ;; $with-input-from-file : path-string? (-> any) [(or/c 'binary 'text)] -> any
    ;;   Install a VFS input file as the current input port while thunk runs.
    (func $with-input-from-file (type $Prim23)
          (param $path-raw (ref eq)) ;; path-string?
          (param $thunk    (ref eq)) ;; procedure?
          (param $mode-raw (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (result          (ref eq))

          (local $port    (ref eq))
          (local $res     (ref eq))
          (local $exn-val (ref eq))

          (drop (call $check-filesystem-procedure-arity
                      (global.get $symbol:with-input-from-file)
                      (global.get $string:filesystem-thunk-procedure)
                      (local.get $thunk)
                      (i32.const 0)))
          (local.set $port
                     (call $open-input-file
                           (local.get $path-raw)
                           (local.get $mode-raw)
                           (global.get $missing)))

          (local.set $res
                     (block $done (result (ref eq))
                            (block $handler-block (result (ref eq))
                                   (try_table (result (ref eq))
                                              (catch $exn $handler-block)
                                              (call $call-with-current-input-port/thunk
                                                    (local.get $port)
                                                    (local.get $thunk))
                                              (br $done)))
                            (local.set $exn-val)
                            (drop (call $close-input-port (local.get $port)))
                            (throw $exn (local.get $exn-val))
                            (unreachable)))
          (drop (call $close-input-port (local.get $port)))
          (local.get $res))

    ;; $with-output-to-file : path-string? (-> any) [(or/c 'binary 'text)] [exists-mode] -> any
    ;;   Install a VFS output file as the current output port while thunk runs.
    (func $with-output-to-file (type $Prim24)
          (param $path-raw   (ref eq)) ;; path-string?
          (param $thunk      (ref eq)) ;; procedure?
          (param $mode-raw   (ref eq)) ;; optional (or/c 'binary 'text), default = 'binary
          (param $exists-raw (ref eq)) ;; optional exists mode, default = 'error
          (result            (ref eq))

          (local $port    (ref eq))
          (local $res     (ref eq))
          (local $exn-val (ref eq))

          (drop (call $check-filesystem-procedure-arity
                      (global.get $symbol:with-output-to-file)
                      (global.get $string:filesystem-thunk-procedure)
                      (local.get $thunk)
                      (i32.const 0)))
          (local.set $port
                     (call $open-output-file
                           (local.get $path-raw)
                           (local.get $mode-raw)
                           (local.get $exists-raw)))

          (local.set $res
                     (block $done (result (ref eq))
                            (block $handler-block (result (ref eq))
                                   (try_table (result (ref eq))
                                              (catch $exn $handler-block)
                                              (call $call-with-current-output-port/thunk
                                                    (local.get $port)
                                                    (local.get $thunk))
                                              (br $done)))
                            (local.set $exn-val)
                            (drop (call $close-output-port (local.get $port)))
                            (throw $exn (local.get $exn-val))
                            (unreachable)))
          (drop (call $close-output-port (local.get $port)))
          (local.get $res))))

;; filesystem-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate VFS and file-operation helpers used by the monolithic runtime.
(define filesystem-all-runtime-helpers
  (function-forms->runtime-helpers
   'filesystem-runtime-only-helpers
   filesystem-runtime-only-forms))

;; filesystem-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate filesystem helpers available in the standalone core runtime.
(define filesystem-core-runtime-helpers
  (select-runtime-helpers filesystem-all-runtime-helpers
                          filesystem-core-runtime-helper-names))

;; filesystem-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate filesystem helpers that still depend on monolithic runtime definitions.
(define filesystem-runtime-only-helpers
  (remove-runtime-helpers filesystem-all-runtime-helpers
                          filesystem-core-runtime-helper-names))

;; filesystem-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render VFS and file-operation helpers in runtime assembly order.
(define (filesystem-runtime-helper-forms helper-index)
  (for/list ([name (in-list filesystem-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define filesystem-helper-index
    (make-core-runtime-helper-index
     (append filesystem-core-runtime-helpers
             filesystem-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name filesystem-core-runtime-helpers)
   filesystem-core-runtime-helper-names)

  (check-equal?
   (map form-name (filesystem-runtime-helper-forms filesystem-helper-index))
   filesystem-runtime-only-helper-names))
