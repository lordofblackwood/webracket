#lang racket

(provide path-current-global-forms
         path-current-global-names
         path-current-initializer-forms
         path-display-formatting-runtime-string-constants
         path-display-formatting-runtime-only-forms
         path-runtime-string-constants
         path-runtime-symbol-constants
         path-runtime-bytes-constants
         path-core-runtime-helpers
         path-core-runtime-helper-forms
         path-runtime-only-helpers
         path-runtime-only-helper-names
         path-runtime-helper-forms
         path-manipulation-runtime-only-helper-names
         path-manipulation-core-runtime-helper-forms
         path-manipulation-runtime-helper-forms)

(require "../core-helper.rkt")

;; path-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by path predicates and path errors.
(define path-runtime-string-constants
  '((system-path-kind           "(or/c 'home-dir 'pref-dir 'pref-file 'temp-dir 'init-dir 'init-file 'config-dir 'host-config-dir 'addon-dir 'host-addon-dir 'cache-dir 'doc-dir 'desk-dir 'sys-dir 'exec-file 'run-file 'collects-dir 'host-collects-dir 'orig-dir)")
    (relative-path-string-or-false "(or/c #f (and/c path-string? relative-path?))")
    (path?                     "path?")
    (path-string?              "path-string?")
    (path-string-or-some-system "(or/c path-string? path-for-some-system?)")
    (complete-path-string      "(and/c path-string? complete-path?)")
    (path-part                 "(or/c path-string? path-for-some-system? 'up 'same)")
    (path-for-some-system?     "path-for-some-system?")
    (path-element?             "path-element?")
    (listof-path?              "(listof path?)")
    (path-convention-type      "(or/c 'windows 'unix)")
    (absolute-path-cannot-be-added ": absolute path cannot be added to a path\n  absolute path: ")
    (bytes->path:empty         ": byte string is empty")
    (bytes->path:nul           ": byte string contains a nul character\n  byte string: ")
    (string->path:empty        ": path string is empty")
    (string->path:nul          ": path string contains a nul character\n  path string: ")))

;; path-display-formatting-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used to format unreadable path values.
(define path-display-formatting-runtime-string-constants
  '((hash-less-path-colon       "#<path:")
    (hash-less-unix-path-colon  "#<unix-path:")
    (hash-less-windows-path-colon "#<windows-path:")))

;; path-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by path decomposition and path-kind helpers.
(define path-runtime-symbol-constants
  '(relative
    up
    same
    unix
    windows
    macosx
    home-dir
    pref-dir
    pref-file
    temp-dir
    init-dir
    init-file
    config-dir
    host-config-dir
    addon-dir
    host-addon-dir
    cache-dir
    doc-dir
    desk-dir
    sys-dir
    exec-file
    run-file
    collects-dir
    host-collects-dir
    orig-dir))

;; path-runtime-bytes-constants : (listof (list/c symbol? bytes?))
;;   Declare byte-string constants used by path manipulation and system paths.
(define path-runtime-bytes-constants
  '((non-empty                 #"_")
    (slash                     #"/")
    (backslash                 #"\\")
    (dot                       #".")
    (dot-dot                   #"..")
    (app-dir                   #"/app/")
    (vfs-root                  #"/")
    (vfs-home-dir              #"/home/")
    (vfs-pref-dir              #"/home/.config/racket/")
    (vfs-pref-file             #"/home/.config/racket/racket-prefs.rktd")
    (vfs-temp-dir              #"/tmp/")
    (vfs-init-file             #"/home/.racketrc")
    (vfs-config-dir            #"/app/etc/")
    (vfs-addon-dir             #"/home/.local/share/racket/")
    (vfs-cache-dir             #"/home/.cache/racket/")
    (vfs-exec-file             #"/app/webracket")
    (vfs-run-file              #"/app/main.rkt")
    (vfs-collects-dir          #"/app/collects/")))

;; path-current-global-forms : (listof datum?)
;;   Declare globals for path convention and current-directory path state.
(define path-current-global-forms
  '(
               (global $system-path-convention   (mut (ref eq)) (ref.i31 (i32.const 0)))
               (global $current-directory-path   (mut (ref eq)) (ref.i31 (i32.const 0)))
               (global $current-directory-for-user-path (mut (ref eq)) (ref.i31 (i32.const 0)))
               (global $current-load-relative-directory-path (mut (ref eq)) (global.get $false))))

;; path-current-global-names : (listof symbol?)
;;   Enumerate path convention and current-directory globals.
(define path-current-global-names
  (for/list ([form (in-list path-current-global-forms)])
    (match form
      [`(global ,name . ,_) name]
      [_ (error 'path-current-global-names
                "expected global form, got: ~s"
                form)])))

;; path-current-initializer-forms : (listof datum?)
;;   Initialize path convention and current-directory path state.
(define path-current-initializer-forms
  '(
                     ;; Default to the host platform's path convention (currently Unix)
                     (global.set $system-path-convention (global.get $symbol:unix))
                     (global.set $current-directory-path
                                 (call $bytes->path
                                       (global.get $bytes:app-dir)
                                       (global.get $missing)))
                     (global.set $current-directory-for-user-path
                                 (global.get $current-directory-path))))

;; path-display-formatting-runtime-only-forms : (listof datum?)
;;   Enumerate path display helpers spliced into the formatting helper order.
(define path-display-formatting-runtime-only-forms
  '(
         (func $format/display:path
               (param $p (ref $Path))
               (result   (ref $String))

               (local $conv   (ref eq))
               (local $bytes  (ref $Bytes))
               (local $prefix (ref $String))
               (local $out    (ref $GrowableArray))

               ;; Extract path convention and byte representation.
               (local.set $conv  (struct.get $Path $convention (local.get $p)))
               (local.set $bytes (struct.get $Path $bytes      (local.get $p)))
               ;; Choose an appropriate prefix based on the path convention.
               (local.set $prefix (ref.cast (ref $String)
                                            (global.get $string:hash-less-path-colon)))

               (if (ref.eq (local.get $conv) (global.get $system-path-convention))
                   (then (nop))
                   (else
                    (if (ref.eq (local.get $conv) (global.get $symbol:unix))
                        (then (local.set $prefix
                                         (ref.cast (ref $String)
                                                   (global.get $string:hash-less-unix-path-colon))))
                        (else
                         (if (ref.eq (local.get $conv) (global.get $symbol:windows))
                             (then
                              (local.set
                               $prefix
                               (ref.cast (ref $String)
                                         (global.get $string:hash-less-windows-path-colon)))))))))
               ;; Render the unreadable path descriptor.
               (local.set $out (call $make-growable-array (i32.const 3)))
               (call $growable-array-add! (local.get $out) (local.get $prefix))
               (call $growable-array-add! (local.get $out)
                     (call $bytes->string/utf-8/checked (local.get $bytes)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:->)))
               (call $growable-array-of-strings->string (local.get $out)))))

;; path-promoted-runtime-helper-names : (listof symbol?)
;;   Name basic path helpers available in the standalone core runtime.
(define path-promoted-runtime-helper-names
  '($path?
    $path-for-some-system?
    $unix-or-windows
    $non-empty-bytes-without-nuls
    $non-empty-string-without-nuls
    $path->string
    $raise-bytes->path:nul
    $raise-string->path:nul
    $raise-bytes->path:bad-type
    $raise-path-argument-error1/write
    $raise-path-string-expected/who
    $raise-path-part-expected/who
    $raise-absolute-path-cannot-be-added
    $bytes->path
    $string->path
    $path-string->path/checked
    $path-bytes-absolute?
    $absolute-path?
    $path-join-bytes
    $path-part->path/convention
    $path-join-bytes/convention
    $find-system-path))

;; path-all-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for basic path helpers.
(define path-all-runtime-helper-names
  '($path?
    $path-for-some-system?
    $unix-or-windows
    $is-path-sep?
    $non-empty-bytes-without-nuls
    $non-empty-string-without-nuls
    $path-string?
    $path->bytes
    $path->string
    $path->bytes/current/checked
    $path<?
    $some-system-path->string
    $path-convention-type
    $system-path-convention-type
    $raise-bytes->path:nul
    $raise-string->path:nul
    $raise-bytes->path:bad-type
    $raise-path-argument-error1/write
    $raise-path-string-expected/who
    $raise-path-part-expected/who
    $raise-complete-path-expected/who
    $raise-absolute-path-cannot-be-added
    $bytes->path
    $string->path
    $string->path-element
    $bytes->path-element
    $string->some-system-path
    $path-string->path/checked
    $path-bytes-absolute?
    $absolute-path?
    $relative-path?
    $complete-path?
    $path-join-bytes
    $build-path
    $path-part->path/convention
    $path-join-bytes/convention
    $build-path/convention-type
    $find-system-path
    $find-executable-path
    $current-drive))

;; path-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime-only emission order for basic path helpers.
(define path-runtime-only-helper-names
  (remove* path-promoted-runtime-helper-names
           path-all-runtime-helper-names))

;; path-manipulation-promoted-runtime-helper-names : (listof symbol?)
;;   Name path manipulation helpers available in the standalone core runtime.
(define path-manipulation-promoted-runtime-helper-names
  '($path->complete-path
    $path-part-equal?
    $path-parts-suffix-diff-size
    $path-parts-equal?
    $find-relative-path
    $normal-case-path
    $string-or-bytes->bytes/checked
    $bytes-slice/unchecked
    $path-extension-start
    $path-suffix-start
    $path-final-element-start
    $path-byte-separator?
    $path-final-element-start/convention
    $path-syntactic-directory?
    $explode-path
    $path-element?))

;; path-manipulation-all-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for path manipulation helpers.
(define path-manipulation-all-runtime-helper-names
  '($path->complete-path
    $path->directory-path
    $cleanse-path
    $resolve-path
    $path-root-element?
    $simplify-path
    $simple-form-path
    $normalize-path
    $path-part-equal?
    $path-parts-suffix-diff-size
    $path-parts-equal?
    $build-path-from-reversed-prefix
    $find-relative-path
    $shrink-path-wrt
    $normal-case-path
    $reroot-path
    $string-or-bytes->bytes/checked
    $bytes-slice/unchecked
    $path-extension-start
    $path-suffix-start
    $path-final-element-start
    $path-byte-separator?
    $path-final-element-start/convention
    $path-syntactic-directory?
    $path-replace-extension
    $path-replace-suffix
    $path-add-extension
    $path-add-suffix
    $path-get-extension
    $filename-extension
    $path-has-extension?
    $file-name-from-path
    $split-path
    $explode-path
    $path-element?
    $path-element-trimmed-bytes/checked
    $path-element->bytes
    $path-element->string
    $path-only))

;; path-manipulation-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime-only emission order for path manipulation helpers.
(define path-manipulation-runtime-only-helper-names
  (remove* path-manipulation-promoted-runtime-helper-names
           path-manipulation-all-runtime-helper-names))

;; path-runtime-only-forms : (listof datum?)
;;   Enumerate basic and path manipulation helpers used by the monolithic runtime.
(define path-runtime-only-forms
  '(
    (func $path? (type $Prim1)
          (param $v (ref eq)) ;; any/c
          (result   (ref eq))

          (local $path (ref $Path))
          (local $conv (ref eq))

          (if (i32.eqz (ref.test (ref $Path) (local.get $v)))
              (then (return (global.get $false))))

          (local.set $path (ref.cast (ref $Path) (local.get $v)))
          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (if (result (ref eq))
              (ref.eq (local.get $conv) (global.get $system-path-convention))
              (then (global.get $true))
              (else (global.get $false))))

    (func $path-for-some-system? (type $Prim1)
          (param $v (ref eq)) ;; any/c
          (result   (ref eq))

          (if (i32.eqz (ref.test (ref $Path) (local.get $v)))
              (then (return (global.get $false))))
          (global.get $true))

    (func $unix-or-windows
          (param $sym (ref $Symbol)) ;; symbol?
          (result     (ref eq))      ;; boolean?

          (if (ref.eq (local.get $sym) (global.get $symbol:unix))
              (then (return (global.get $true))))
          (if (ref.eq (local.get $sym) (global.get $symbol:windows))
              (then (return (global.get $true))))
          (global.get $false))

    ; / is a separator on both unix and windows
    ; \ is a separator on windows
    (func $is-path-sep?
          (param $cp   i32)      ;; codepoint (char->integer)
          (param $conv (ref eq)) ;; symbol?
          (result      (ref eq)) ;; boolean?

          (if (i32.eq (local.get $cp) (i32.const 47))           ; #\/
              (then (return (global.get $true))))
          (if (ref.eq (local.get $conv) (global.get $symbol:windows))
              (then (if (i32.eq (local.get $cp) (i32.const 92)) ; #\\
                        (then (return (global.get $true))))))
          (global.get $false))

    (func $non-empty-bytes-without-nuls
          (param $bs (ref $Bytes)) ;; bytes?
          (result (ref eq))        ;; boolean?

          (local $arr (ref $I8Array))
          (local $len i32)
          (local $i   i32)
          (local $b   i32)

          (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
          (local.set $len (array.len (local.get $arr)))

          (if (i32.eqz (local.get $len))
              (then (return (global.get $false))))

          (local.set $i (i32.const 0))
          (block $done
                 (loop $loop
                       (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                       (local.set $b (call $i8array-ref (local.get $arr)
                                           (local.get $i)))
                       (if (i32.eqz (local.get $b))
                           (then (return (global.get $false))))
                       (local.set $i (i32.add (local.get $i) (i32.const 1)))
                       (br $loop)))
          (global.get $true))

    (func $non-empty-string-without-nuls
          (param $str (ref $String)) ;; string?
          (result     (ref eq))      ;; boolean?

          (local $len i32)
          (local $i   i32)
          (local $cp  i32)

          (local.set $len (call $string-length/checked/i32 (local.get $str)))
          (if (i32.eqz (local.get $len))
              (then (return (global.get $false))))
          (local.set $i (i32.const 0))
          (block $done
                 (loop $loop
                       (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                       (local.set $cp (call $string-ref/checked/i32 (local.get $str)
                                            (local.get $i)))
                       (if (i32.eqz (local.get $cp))
                           (then (return (global.get $false))))
                       (local.set $i (i32.add (local.get $i) (i32.const 1)))
                       (br $loop)))
          (global.get $true))

    (func $path-string? (type $Prim1)
          (param $v (ref eq)) ;; any/c
          (result (ref eq))

          (local $path? (ref eq))
          (local $str   (ref $String))
          ;; If it's already a path for the current system, succeed.
          (local.set $path? (call $path? (local.get $v)))
          (if (ref.eq (local.get $path?) (global.get $true))
              (then (return (global.get $true))))
          ;; Otherwise accept non-empty strings with no nul characters.
          (if (i32.eqz (ref.test (ref $String) (local.get $v)))
              (then (return (global.get $false))))
          (local.set $str (ref.cast (ref $String) (local.get $v)))
          (call $non-empty-string-without-nuls (local.get $str)))


    (func $path->bytes (type $Prim1)
          (param $path-raw (ref eq)) ;; path-for-some-system?
          (result (ref eq))          ;; bytes?

          (local $path (ref $Path))

          (if (i32.eqz (ref.test (ref $Path) (local.get $path-raw)))
              (then (call $raise-argument-error1
                          (global.get $symbol:path->bytes)
                          (global.get $string:path-for-some-system?)
                          (local.get $path-raw))
                    (unreachable)))

          (local.set $path (ref.cast (ref $Path) (local.get $path-raw)))
          (struct.get $Path $bytes (local.get $path)))

    (func $path->string (type $Prim1)
          (param $path-raw (ref eq)) ;; path?
          (result (ref eq))          ;; string?

          (local $path  (ref $Path))
          (local $bytes (ref $Bytes))
          (local $conv  (ref eq))

          (if (i32.eqz (ref.test (ref $Path) (local.get $path-raw)))
              (then (call $raise-argument-error1
                          (global.get $symbol:path->string)
                          (global.get $string:path?)
                          (local.get $path-raw))
                    (unreachable)))

          (local.set $path (ref.cast (ref $Path) (local.get $path-raw)))
          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (if (i32.eqz (ref.eq (local.get $conv) (global.get $system-path-convention)))
              (then (call $raise-argument-error1
                          (global.get $symbol:path->string)
                          (global.get $string:path?)
                          (local.get $path-raw))
                    (unreachable)))

          (local.set $bytes (struct.get $Path $bytes (local.get $path)))
          (call $bytes->string/utf-8/checked (local.get $bytes)))

    (func $path->bytes/current/checked
          (param $who      (ref eq)) ;; symbol?
          (param $path-raw (ref eq)) ;; path?
          (result          (ref $Bytes))

          (local $path (ref $Path))

          (if (i32.eqz (ref.test (ref $Path) (local.get $path-raw)))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:path?)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $path (ref.cast (ref $Path) (local.get $path-raw)))
          (if (i32.eqz (ref.eq (struct.get $Path $convention (local.get $path))
                               (global.get $system-path-convention)))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:path?)
                          (local.get $path-raw))
                    (unreachable)))
          (struct.get $Path $bytes (local.get $path)))

    ;; path<? : path? path? ... -> boolean?
    ;;   Compare current-system paths by their byte-string encodings.
    (func $path<? (type $Prim>=1)
          (param $first (ref eq)) ;; path?
          (param $rest  (ref eq)) ;; listof path?
          (result       (ref eq))

          (local $prev (ref $Bytes))
          (local $curr (ref $Bytes))
          (local $node (ref $Pair))
          (local $next (ref eq))

          (local.set $prev
                     (call $path->bytes/current/checked
                           (global.get $symbol:path<?)
                           (local.get $first)))
          (block $done
                 (loop $loop
                       (br_if $done (ref.eq (local.get $rest) (global.get $null)))
                       (local.set $node (ref.cast (ref $Pair) (local.get $rest)))
                       (local.set $next (struct.get $Pair $a (local.get $node)))
                       (local.set $curr
                                  (call $path->bytes/current/checked
                                        (global.get $symbol:path<?)
                                        (local.get $next)))
                       (if (ref.eq (call $bytes<?/2/checked
                                         (local.get $prev)
                                         (local.get $curr))
                                   (global.get $false))
                           (then (return (global.get $false))))
                       (local.set $prev (local.get $curr))
                       (local.set $rest (struct.get $Pair $d (local.get $node)))
                       (br $loop)))
          (global.get $true))

    ;; some-system-path->string : path-for-some-system? -> string?
    ;;   Convert any represented path convention through UTF-8 path bytes.
    (func $some-system-path->string (type $Prim1)
          (param $path-raw (ref eq)) ;; path-for-some-system?
          (result          (ref eq)) ;; string?

          (local $path (ref $Path))

          (if (i32.eqz (ref.test (ref $Path) (local.get $path-raw)))
              (then (call $raise-argument-error1
                          (global.get $symbol:some-system-path->string)
                          (global.get $string:path-for-some-system?)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $path (ref.cast (ref $Path) (local.get $path-raw)))
          (call $bytes->string/utf-8/checked
                (struct.get $Path $bytes (local.get $path))))

    ;; path-convention-type : path-for-some-system? -> (or/c 'unix 'windows)
    ;;   Return the stored convention symbol for a represented path.
    (func $path-convention-type (type $Prim1)
          (param $path-raw (ref eq)) ;; path-for-some-system?
          (result          (ref eq)) ;; symbol?

          (local $path (ref $Path))

          (if (i32.eqz (ref.test (ref $Path) (local.get $path-raw)))
              (then (call $raise-argument-error1
                          (global.get $symbol:path-convention-type)
                          (global.get $string:path-for-some-system?)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $path (ref.cast (ref $Path) (local.get $path-raw)))
          (struct.get $Path $convention (local.get $path)))

    ;; system-path-convention-type : -> (or/c 'unix 'windows)
    ;;   Return the active system path convention symbol.
    (func $system-path-convention-type (type $Prim0)
          (result (ref eq)) ;; symbol?

          (global.get $system-path-convention))

    (func $raise-bytes->path:nul
          (param $who  (ref eq))
          (param $bstr (ref eq))

          (local $bs      (ref $Bytes))
          (local $arr     (ref $I8Array))
          (local $out     (ref $GrowableArray))
          (local $message (ref $String))

          (local.set $bs  (ref.cast (ref $Bytes) (local.get $bstr)))
          (local.set $arr (struct.get $Bytes $bs (local.get $bs)))

          (if (i32.eqz (array.len (local.get $arr)))
              (then
               (local.set $out (call $make-growable-array (i32.const 2)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:bytes->path:empty))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable)))

          (local.set $out (call $make-growable-array (i32.const 3)))
          (call $growable-array-add! (local.get $out)
                (call $format/display (local.get $who)))
          (call $growable-array-add! (local.get $out)
                (global.get $string:bytes->path:nul))
          (call $growable-array-add! (local.get $out)
                (call $format/error-value->string (local.get $bstr)))
          (local.set $message
                     (call $growable-array-of-strings->string (local.get $out)))
          (call $raise
                (call $exn:fail:contract/make
                      (local.get $message)
                      (call $current-continuation-marks (global.get $missing)))
                (global.get $true))
          (unreachable))

    (func $raise-string->path:nul
          (param $who (ref eq))
          (param $str (ref eq))

          (local $s       (ref $String))
          (local $out     (ref $GrowableArray))
          (local $message (ref $String))

          (local.set $s (ref.cast (ref $String) (local.get $str)))

          (if (i32.eqz (call $string-length/checked/i32 (local.get $s)))
              (then
               (local.set $out (call $make-growable-array (i32.const 2)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string->path:empty))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable)))

          (local.set $out (call $make-growable-array (i32.const 3)))
          (call $growable-array-add! (local.get $out)
                (call $format/display (local.get $who)))
          (call $growable-array-add! (local.get $out)
                (global.get $string:string->path:nul))
          (call $growable-array-add! (local.get $out)
                (call $format/error-value->string (local.get $str)))
          (local.set $message
                     (call $growable-array-of-strings->string (local.get $out)))
          (call $raise
                (call $exn:fail:contract/make
                      (local.get $message)
                      (call $current-continuation-marks (global.get $missing)))
                (global.get $true))
          (unreachable))

    (func $raise-bytes->path:bad-type
          (param $who  (ref eq))
          (param $type (ref eq))
          (call $raise-argument-error1
                (local.get $who)
                (global.get $string:path-convention-type)
                (local.get $type))
          (unreachable))

    (func $raise-path-argument-error1/write
          (param $who      (ref eq))
          (param $expected (ref eq))
          (param $bad      (ref eq))

          (local $out     (ref $GrowableArray))
          (local $message (ref $String))

          (local.set $out (call $make-growable-array (i32.const 5)))
          (call $growable-array-add! (local.get $out)
                (call $format/display (local.get $who)))
          (call $growable-array-add! (local.get $out)
                (global.get $string:contract-violation:prefix))
          (call $growable-array-add! (local.get $out)
                (local.get $expected))
          (call $growable-array-add! (local.get $out)
                (global.get $string:arity-error:given))
          (call $growable-array-add! (local.get $out)
                (call $format/error-value->string (local.get $bad)))
          (local.set $message
                     (call $growable-array-of-strings->string (local.get $out)))
          (call $raise
                (call $exn:fail:contract/make
                      (local.get $message)
                      (call $current-continuation-marks (global.get $missing)))
                (global.get $true))
          (unreachable))

    (func $raise-path-string-expected/who
          (param $who (ref eq))
          (param $bad (ref eq))
          (call $raise-path-argument-error1/write
                (local.get $who)
                (global.get $string:path-string-or-some-system)
                (local.get $bad))
          (unreachable))

    (func $raise-path-part-expected/who
          (param $who (ref eq))
          (param $bad (ref eq))
          (call $raise-path-argument-error1/write
                (local.get $who)
                (global.get $string:path-part)
                (local.get $bad))
          (unreachable))

    (func $raise-complete-path-expected/who
          (param $who (ref eq))
          (param $bad (ref eq))
          (call $raise-path-argument-error1/write
                (local.get $who)
                (global.get $string:complete-path-string)
                (local.get $bad))
          (unreachable))

    (func $raise-absolute-path-cannot-be-added
          (param $who (ref eq))
          (param $bad (ref eq))

          (local $out     (ref $GrowableArray))
          (local $message (ref $String))

          (local.set $out (call $make-growable-array (i32.const 3)))
          (call $growable-array-add! (local.get $out)
                (call $format/display (local.get $who)))
          (call $growable-array-add! (local.get $out)
                (global.get $string:absolute-path-cannot-be-added))
          (call $growable-array-add! (local.get $out)
                (call $format/error-value->string (local.get $bad)))
          (local.set $message
                     (call $growable-array-of-strings->string (local.get $out)))
          (call $raise
                (call $exn:fail:contract/make
                      (local.get $message)
                      (call $current-continuation-marks (global.get $missing)))
                (global.get $true))
          (unreachable))

    (func $bytes->path (type $Prim12)
          (param $bstr-raw (ref eq)) ;; bytes?
          (param $type-raw (ref eq)) ;; optional, defaults to (system-path-convention-type)
          (result          (ref eq)) ;; path?

          (local $input-bytes (ref $Bytes))
          (local $bytes       (ref $Bytes))
          (local $conv        (ref eq))
          (local $type        (ref $Symbol))

          ;; Initialize non-defaultable locals
          (local.set $conv (global.get $system-path-convention))
          ;; Ensure the source is a byte string.
          (if (i32.eqz (ref.test (ref $Bytes) (local.get $bstr-raw)))
              (then (call $raise-check-bytes/who
                          (global.get $symbol:bytes->path)
                          (local.get $bstr-raw))
                    (unreachable)))
          (local.set $input-bytes (ref.cast (ref $Bytes) (local.get $bstr-raw)))
          ;; Reject byte strings that are empty or contain a NUL byte.
          (if (i32.eqz (ref.eq (call $non-empty-bytes-without-nuls (local.get $input-bytes))
                               (global.get $true)))
              (then (call $raise-bytes->path:nul
                          (global.get $symbol:bytes->path)
                          (local.get $bstr-raw))
                    (unreachable)))
          ;; Normalize to an immutable byte string for storage.
          (local.set $bytes (ref.cast (ref $Bytes)
                                      (call $bytes->immutable-bytes (local.get $bstr-raw))))
          ;; Determine the path convention symbol.
          (if (ref.eq (local.get $type-raw) (global.get $missing))
              (then (nop)) ; the default is system path convention
              (else (if (i32.eqz (ref.test (ref $Symbol) (local.get $type-raw)))
                        (then (call $raise-bytes->path:bad-type
                                    (global.get $symbol:bytes->path)
                                    (local.get $type-raw))
                              (unreachable)))

                    (local.set $type (ref.cast (ref $Symbol) (local.get $type-raw)))
                    (if (i32.eqz (ref.eq (call $unix-or-windows (local.get $type))
                                         (global.get $true)))
                        (then (call $raise-bytes->path:bad-type
                                    (global.get $symbol:bytes->path)
                                    (local.get $type-raw))
                              (unreachable)))
                    (local.set $conv (local.get $type-raw))))
          ;; Construct and return the new path struct.
          (struct.new $Path
                      (i32.const 0)
                      (local.get $bytes)
                      (local.get $conv)))

    (func $string->path (type $Prim1)
          (param $str-raw (ref eq)) ;; string?
          (result         (ref eq)) ;; path?

          (local $str   (ref $String))
          (local $bytes (ref eq))

          (if (i32.eqz (ref.test (ref $String) (local.get $str-raw)))
              (then (call $raise-argument-error1
                          (global.get $symbol:string->path)
                          (global.get $string:string?)
                          (local.get $str-raw))
                    (unreachable)))
          (local.set $str (ref.cast (ref $String) (local.get $str-raw)))
          (if (i32.eqz (ref.eq (call $non-empty-string-without-nuls (local.get $str))
                               (global.get $true)))
              (then (call $raise-string->path:nul
                          (global.get $symbol:string->path)
                          (local.get $str-raw))
                    (unreachable)))
          (local.set $bytes
                     (call $string->bytes/utf-8
                           (local.get $str)
                           (global.get $false)
                           (global.get $false)
                           (global.get $false)))
          (call $bytes->path (local.get $bytes) (global.get $missing)))

    ;; string->path-element : string? [any/c] -> (or/c path-element? #f)
    ;;   Convert a string to a path element; optional false-on-non-element? defaults to #f.
    (func $string->path-element (type $Prim12)
          (param $str-raw               (ref eq)) ;; string?
          (param $false-on-non-element? (ref eq)) ;; any/c, optional default #f
          (result                       (ref eq))

          (local $str  (ref $String))
          (local $path (ref eq))

          (if (i32.eqz (ref.test (ref $String) (local.get $str-raw)))
              (then (call $raise-argument-error1
                          (global.get $symbol:string->path-element)
                          (global.get $string:string?)
                          (local.get $str-raw))
                    (unreachable)))
          (if (ref.eq (local.get $false-on-non-element?) (global.get $missing))
              (then (local.set $false-on-non-element? (global.get $false))))
          (local.set $str (ref.cast (ref $String) (local.get $str-raw)))
          (if (i32.eqz (ref.eq (call $non-empty-string-without-nuls (local.get $str))
                               (global.get $true)))
              (then (call $raise-string->path:nul
                          (global.get $symbol:string->path-element)
                          (local.get $str-raw))
                    (unreachable)))
          (local.set $path (call $string->path (local.get $str)))
          (if (ref.eq (call $path-element? (local.get $path)) (global.get $true))
              (then (return (local.get $path))))
          (if (result (ref eq))
              (ref.eq (local.get $false-on-non-element?) (global.get $false))
              (then (call $raise-argument-error1
                          (global.get $symbol:string->path-element)
                          (global.get $string:path-element?)
                          (local.get $str-raw))
                    (unreachable))
              (else (global.get $false))))

    ;; bytes->path-element : bytes? [(or/c 'unix 'windows)] [any/c] -> (or/c path-element? #f)
    ;;   Convert bytes to a path element; optional type defaults to the system convention, and false-on-non-element? defaults to #f.
    (func $bytes->path-element (type $Prim3)
          (param $bstr-raw              (ref eq)) ;; bytes?
          (param $type-raw              (ref eq)) ;; (or/c 'unix 'windows), optional default system
          (param $false-on-non-element? (ref eq)) ;; any/c, optional default #f
          (result                       (ref eq))

          (local $bytes (ref $Bytes))
          (local $path  (ref eq))

          (if (i32.eqz (ref.test (ref $Bytes) (local.get $bstr-raw)))
              (then (call $raise-check-bytes/who
                          (global.get $symbol:bytes->path-element)
                          (local.get $bstr-raw))
                    (unreachable)))
          (if (ref.eq (local.get $false-on-non-element?) (global.get $missing))
              (then (local.set $false-on-non-element? (global.get $false))))
          (local.set $bytes (ref.cast (ref $Bytes) (local.get $bstr-raw)))
          (if (i32.eqz (ref.eq (call $non-empty-bytes-without-nuls (local.get $bytes))
                               (global.get $true)))
              (then (call $raise-bytes->path:nul
                          (global.get $symbol:bytes->path-element)
                          (local.get $bstr-raw))
                    (unreachable)))
          (if (i32.eqz (ref.eq (local.get $type-raw) (global.get $missing)))
              (then
               (if (i32.eqz (ref.test (ref $Symbol) (local.get $type-raw)))
                   (then (call $raise-bytes->path:bad-type
                               (global.get $symbol:bytes->path-element)
                               (local.get $type-raw))
                         (unreachable)))
               (if (i32.eqz
                    (ref.eq (call $unix-or-windows
                                  (ref.cast (ref $Symbol) (local.get $type-raw)))
                            (global.get $true)))
                   (then (call $raise-bytes->path:bad-type
                               (global.get $symbol:bytes->path-element)
                               (local.get $type-raw))
                         (unreachable)))))
          (local.set $path (call $bytes->path (local.get $bstr-raw) (local.get $type-raw)))
          (if (ref.eq (call $path-element? (local.get $path)) (global.get $true))
              (then (return (local.get $path))))
          (if (result (ref eq))
              (ref.eq (local.get $false-on-non-element?) (global.get $false))
              (then (call $raise-argument-error1
                          (global.get $symbol:bytes->path-element)
                          (global.get $string:path-element?)
                          (local.get $bstr-raw))
                    (unreachable))
              (else (global.get $false))))

    ;; string->some-system-path : string? (or/c 'unix 'windows) -> path-for-some-system?
    ;;   Encode a string as UTF-8 path bytes for an explicit convention.
    (func $string->some-system-path (type $Prim2)
          (param $str-raw  (ref eq)) ;; string?
          (param $kind-raw (ref eq)) ;; (or/c 'unix 'windows)
          (result          (ref eq))

          (local $str   (ref $String))
          (local $bytes (ref eq))
          (local $kind  (ref $Symbol))

          (if (i32.eqz (ref.test (ref $String) (local.get $str-raw)))
              (then (call $raise-argument-error1
                          (global.get $symbol:string->some-system-path)
                          (global.get $string:string?)
                          (local.get $str-raw))
                    (unreachable)))
          (if (i32.eqz (ref.test (ref $Symbol) (local.get $kind-raw)))
              (then (call $raise-bytes->path:bad-type
                          (global.get $symbol:string->some-system-path)
                          (local.get $kind-raw))
                    (unreachable)))
          (local.set $str (ref.cast (ref $String) (local.get $str-raw)))
          (local.set $kind (ref.cast (ref $Symbol) (local.get $kind-raw)))
          (if (i32.eqz (ref.eq (call $unix-or-windows (local.get $kind))
                               (global.get $true)))
              (then (call $raise-bytes->path:bad-type
                          (global.get $symbol:string->some-system-path)
                          (local.get $kind-raw))
                    (unreachable)))
          (local.set $bytes
                     (call $string->bytes/utf-8
                           (local.get $str)
                           (global.get $false)
                           (global.get $false)
                           (global.get $false)))
          (call $bytes->path (local.get $bytes) (local.get $kind-raw)))

    (func $path-string->path/checked
          (param $who      (ref eq)) ;; symbol? (currently for diagnostics)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref $Path))

          (local $path (ref $Path))
          (local $conv (ref eq))
          (local $str  (ref $String))

          (if (ref.test (ref $Path) (local.get $path-raw))
              (then
               (local.set $path (ref.cast (ref $Path) (local.get $path-raw)))
               (local.set $conv (struct.get $Path $convention (local.get $path)))
               (if (i32.eqz (ref.eq (local.get $conv) (global.get $system-path-convention)))
                   (then (call $raise-path-string-expected/who
                               (local.get $who)
                               (local.get $path-raw))
                         (unreachable)))
               (return (local.get $path))))

          (if (i32.eqz (ref.test (ref $String) (local.get $path-raw)))
              (then (call $raise-path-string-expected/who
                          (local.get $who)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $str (ref.cast (ref $String) (local.get $path-raw)))
          (if (i32.eqz (ref.eq (call $non-empty-string-without-nuls (local.get $str))
                               (global.get $true)))
              (then (call $raise-path-string-expected/who
                          (local.get $who)
                          (local.get $path-raw))
                    (unreachable)))
          (ref.cast (ref $Path) (call $string->path (local.get $str))))

    (func $path-bytes-absolute?
          (param $bytes (ref $Bytes))
          (result i32)

          (local $arr (ref $I8Array))
          (local $len i32)

          (local.set $arr (struct.get $Bytes $bs (local.get $bytes)))
          (local.set $len (array.len (local.get $arr)))
          (if (i32.eqz (local.get $len))
              (then (return (i32.const 0))))
          (i32.eq (array.get_u $I8Array (local.get $arr) (i32.const 0))
                  (i32.const 47)))

    (func $absolute-path? (type $Prim1)
          (param $path-raw (ref eq)) ;; path? string? or path-for-some-system?
          (result          (ref eq))

          (local $path  (ref null $Path))
          (local $bytes (ref $Bytes))
          (local $str   (ref $String))

          (if (ref.test (ref $Path) (local.get $path-raw))
              (then
               (local.set $path (ref.cast (ref $Path) (local.get $path-raw)))
               (local.set $bytes (struct.get $Path $bytes (local.get $path)))
               (return (if (result (ref eq))
                           (call $path-bytes-absolute? (local.get $bytes))
                           (then (global.get $true))
                           (else (global.get $false))))))
          (if (i32.eqz (ref.test (ref $String) (local.get $path-raw)))
              (then (return (global.get $false))))
          (local.set $str (ref.cast (ref $String) (local.get $path-raw)))
          (if (i32.eqz (ref.eq (call $non-empty-string-without-nuls (local.get $str))
                               (global.get $true)))
              (then (return (global.get $false))))
          (local.set $bytes
                     (ref.cast (ref $Bytes)
                               (call $string->bytes/utf-8
                                     (local.get $str)
                                     (global.get $false)
                                     (global.get $false)
                                     (global.get $false))))
          (if (result (ref eq))
              (call $path-bytes-absolute? (local.get $bytes))
              (then (global.get $true))
              (else (global.get $false))))

    (func $relative-path? (type $Prim1)
          (param $path-raw (ref eq))
          (result          (ref eq))

          (local $abs? (ref eq))

          (local.set $abs? (call $absolute-path? (local.get $path-raw)))
          (if (result (ref eq))
              (ref.eq (local.get $abs?) (global.get $true))
              (then (global.get $false))
              (else
               (if (result (ref eq))
                   (ref.eq (call $path-string? (local.get $path-raw)) (global.get $true))
                   (then (global.get $true))
                   (else (global.get $false))))))

    (func $complete-path? (type $Prim1)
          (param $path-raw (ref eq))
          (result          (ref eq))
          ;; In the initial browser/Unix path model, complete and
          ;; absolute paths are the same.
          (call $absolute-path? (local.get $path-raw)))

    (func $path-join-bytes
          (param $base-raw (ref eq)) ;; path-string?
          (param $rel-raw  (ref eq)) ;; path-string?
          (result          (ref eq)) ;; path?

          (local $base      (ref $Path))
          (local $rel       (ref $Path))
          (local $base-bs   (ref $Bytes))
          (local $rel-bs    (ref $Bytes))
          (local $base-arr  (ref $I8Array))
          (local $rel-arr   (ref $I8Array))
          (local $base-len  i32)
          (local $rel-len   i32)
          (local $need-sep  i32)
          (local $joined    (ref eq))

          (local.set $base (call $path-string->path/checked
                                (global.get $symbol:build-path)
                                (local.get $base-raw)))
          (local.set $rel (call $path-string->path/checked
                               (global.get $symbol:build-path)
                               (local.get $rel-raw)))
          (local.set $rel-bs (struct.get $Path $bytes (local.get $rel)))
          (if (call $path-bytes-absolute? (local.get $rel-bs))
              (then (call $raise-absolute-path-cannot-be-added
                          (global.get $symbol:build-path)
                          (local.get $rel-raw))
                    (unreachable)))
          (local.set $base-bs (struct.get $Path $bytes (local.get $base)))
          (local.set $base-arr (struct.get $Bytes $bs (local.get $base-bs)))
          (local.set $rel-arr (struct.get $Bytes $bs (local.get $rel-bs)))
          (local.set $base-len (array.len (local.get $base-arr)))
          (local.set $rel-len (array.len (local.get $rel-arr)))
          (local.set $need-sep (i32.const 1))
          (if (i32.eqz (local.get $base-len))
              (then (local.set $need-sep (i32.const 0))))
          (if (i32.eqz (local.get $rel-len))
              (then (local.set $need-sep (i32.const 0))))
          (if (i32.and (local.get $base-len)
                       (i32.eq (array.get_u $I8Array
                                            (local.get $base-arr)
                                            (i32.sub (local.get $base-len) (i32.const 1)))
                               (i32.const 47)))
              (then (local.set $need-sep (i32.const 0))))
          (local.set $joined
                     (if (result (ref eq))
                         (local.get $need-sep)
                         (then (call $bytes-append/2
                                     (call $bytes-append/2 (local.get $base-bs)
                                           (global.get $bytes:slash))
                                     (local.get $rel-bs)))
                         (else (call $bytes-append/2
                                     (local.get $base-bs)
                                     (local.get $rel-bs)))))
          (call $bytes->path (local.get $joined) (global.get $missing)))

    (func $build-path (type $Prim>=1)
          (param $first (ref eq)) ;; path part
          (param $rest  (ref eq)) ;; list of additional path parts
          (result       (ref eq))

          (local $first-path (ref $Path))
          (local $conv   (ref eq))
          (local $node   (ref $Pair))
          (local $result (ref eq))
          (local $next   (ref eq))

          (local.set $conv (global.get $system-path-convention))
          (if (ref.test (ref $Path) (local.get $first))
              (then
               (local.set $first-path (ref.cast (ref $Path) (local.get $first)))
               (local.set $conv (struct.get $Path $convention (local.get $first-path)))))
          (local.set $result
                     (call $path-part->path/convention
                           (global.get $symbol:build-path)
                           (local.get $conv)
                           (local.get $first)))
          (block $done
                 (loop $loop
                       (br_if $done (ref.eq (local.get $rest) (global.get $null)))
                       (local.set $node (ref.cast (ref $Pair) (local.get $rest)))
                       (local.set $next (struct.get $Pair $a (local.get $node)))
                       (local.set $result
                                  (call $path-join-bytes/convention
                                        (global.get $symbol:build-path)
                                        (local.get $conv)
                                        (local.get $result)
                                        (local.get $next)))
                       (local.set $rest (struct.get $Pair $d (local.get $node)))
                       (br $loop)))
          (local.get $result))

    (func $path-part->path/convention
          (param $who      (ref eq)) ;; symbol?
          (param $conv     (ref eq)) ;; (or/c 'unix 'windows)
          (param $part-raw (ref eq)) ;; path-string?, path-for-some-system?, 'up, or 'same
          (result          (ref $Path))

          (local $path (ref $Path))
          (local $str  (ref $String))

          (if (ref.eq (local.get $part-raw) (global.get $symbol:same))
              (then
               (return
                (ref.cast (ref $Path)
                          (call $bytes->path
                                (global.get $bytes:dot)
                                (local.get $conv))))))
          (if (ref.eq (local.get $part-raw) (global.get $symbol:up))
              (then
               (return
                (ref.cast (ref $Path)
                          (call $bytes->path
                                (global.get $bytes:dot-dot)
                                (local.get $conv))))))
          (if (ref.test (ref $Path) (local.get $part-raw))
              (then
               (local.set $path (ref.cast (ref $Path) (local.get $part-raw)))
               (if (i32.eqz (ref.eq (struct.get $Path $convention (local.get $path))
                                    (local.get $conv)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:path-for-some-system?)
                               (local.get $part-raw))
                         (unreachable)))
               (return (local.get $path))))
          (if (i32.eqz (ref.test (ref $String) (local.get $part-raw)))
              (then (call $raise-path-part-expected/who
                          (local.get $who)
                          (local.get $part-raw))
                    (unreachable)))
          (local.set $str (ref.cast (ref $String) (local.get $part-raw)))
          (if (i32.eqz (ref.eq (call $non-empty-string-without-nuls (local.get $str))
                               (global.get $true)))
              (then (call $raise-path-part-expected/who
                          (local.get $who)
                          (local.get $part-raw))
                    (unreachable)))
          (local.set $path (ref.cast (ref $Path) (call $string->path (local.get $str))))
          (if (i32.eqz (ref.eq (struct.get $Path $convention (local.get $path))
                               (local.get $conv)))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:path-for-some-system?)
                          (local.get $part-raw))
                    (unreachable)))
          (local.get $path))

    (func $path-join-bytes/convention
          (param $who      (ref eq)) ;; symbol?
          (param $conv     (ref eq)) ;; (or/c 'unix 'windows)
          (param $base-raw (ref eq)) ;; path-string?, path-for-some-system?, 'up, or 'same
          (param $rel-raw  (ref eq)) ;; relative path-string?, path-for-some-system?, 'up, or 'same
          (result          (ref eq)) ;; path-for-some-system?

          (local $base      (ref $Path))
          (local $rel       (ref $Path))
          (local $base-bs   (ref $Bytes))
          (local $rel-bs    (ref $Bytes))
          (local $sep-bs    (ref $Bytes))
          (local $base-arr  (ref $I8Array))
          (local $rel-arr   (ref $I8Array))
          (local $base-len  i32)
          (local $rel-len   i32)
          (local $need-sep  i32)
          (local $joined    (ref eq))

          (local.set $base
                     (call $path-part->path/convention
                           (local.get $who)
                           (local.get $conv)
                           (local.get $base-raw)))
          (local.set $rel
                     (call $path-part->path/convention
                           (local.get $who)
                           (local.get $conv)
                           (local.get $rel-raw)))
          (local.set $rel-bs (struct.get $Path $bytes (local.get $rel)))
          (if (call $path-bytes-absolute? (local.get $rel-bs))
              (then (call $raise-absolute-path-cannot-be-added
                          (local.get $who)
                          (local.get $rel-raw))
                    (unreachable)))
          (local.set $base-bs (struct.get $Path $bytes (local.get $base)))
          (local.set $sep-bs
                     (if (result (ref $Bytes))
                         (ref.eq (local.get $conv) (global.get $symbol:windows))
                         (then (ref.cast (ref $Bytes) (global.get $bytes:backslash)))
                         (else (ref.cast (ref $Bytes) (global.get $bytes:slash)))))
          (local.set $base-arr (struct.get $Bytes $bs (local.get $base-bs)))
          (local.set $rel-arr (struct.get $Bytes $bs (local.get $rel-bs)))
          (local.set $base-len (array.len (local.get $base-arr)))
          (local.set $rel-len (array.len (local.get $rel-arr)))
          (local.set $need-sep (i32.const 1))
          (if (i32.eqz (local.get $base-len))
              (then (local.set $need-sep (i32.const 0))))
          (if (i32.eqz (local.get $rel-len))
              (then (local.set $need-sep (i32.const 0))))
          (if (local.get $base-len)
              (then
               (if (call $path-byte-separator?
                         (array.get_u $I8Array
                                      (local.get $base-arr)
                                      (i32.sub (local.get $base-len) (i32.const 1)))
                         (local.get $conv))
                   (then (local.set $need-sep (i32.const 0))))))
          (local.set $joined
                     (if (result (ref eq))
                         (local.get $need-sep)
                         (then (call $bytes-append/2
                                     (call $bytes-append/2
                                           (local.get $base-bs)
                                           (local.get $sep-bs))
                                     (local.get $rel-bs)))
                         (else (call $bytes-append/2
                                     (local.get $base-bs)
                                     (local.get $rel-bs)))))
          (call $bytes->path (local.get $joined) (local.get $conv)))

    ;; build-path/convention-type : (or/c 'unix 'windows) path-part ... -> path-for-some-system?
    ;;   Build a path under an explicit convention; supports 'same and 'up path elements.
    (func $build-path/convention-type (type $Prim>=2)
          (param $type-raw (ref eq)) ;; (or/c 'unix 'windows)
          (param $first    (ref eq)) ;; path part
          (param $rest     (ref eq)) ;; list of additional path parts
          (result          (ref eq))

          (local $node   (ref $Pair))
          (local $type   (ref $Symbol))
          (local $result (ref eq))
          (local $next   (ref eq))

          (if (i32.eqz (ref.test (ref $Symbol) (local.get $type-raw)))
              (then (call $raise-bytes->path:bad-type
                          (global.get $symbol:build-path/convention-type)
                          (local.get $type-raw))
                    (unreachable)))
          (local.set $type (ref.cast (ref $Symbol) (local.get $type-raw)))
          (if (i32.eqz (ref.eq (call $unix-or-windows (local.get $type))
                               (global.get $true)))
              (then (call $raise-bytes->path:bad-type
                          (global.get $symbol:build-path/convention-type)
                          (local.get $type-raw))
                    (unreachable)))
          (local.set $result
                     (call $path-part->path/convention
                           (global.get $symbol:build-path/convention-type)
                           (local.get $type-raw)
                           (local.get $first)))
          (block $done
                 (loop $loop
                       (br_if $done (ref.eq (local.get $rest) (global.get $null)))
                       (local.set $node (ref.cast (ref $Pair) (local.get $rest)))
                       (local.set $next (struct.get $Pair $a (local.get $node)))
                       (local.set $result
                                  (call $path-join-bytes/convention
                                        (global.get $symbol:build-path/convention-type)
                                        (local.get $type-raw)
                                        (local.get $result)
                                        (local.get $next)))
                       (local.set $rest (struct.get $Pair $d (local.get $node)))
                       (br $loop)))
          (local.get $result))

    ;; find-system-path : symbol? -> path?
    ;;   Return stable complete paths in WebRacket's virtual filesystem.
    (func $find-system-path (type $Prim1)
          (param $kind-raw (ref eq)) ;; symbol?
          (result          (ref eq))

          (local $kind (ref $Symbol))

          (if (i32.eqz (ref.test (ref $Symbol) (local.get $kind-raw)))
              (then (call $raise-argument-error1
                          (global.get $symbol:find-system-path)
                          (global.get $string:symbol?)
                          (local.get $kind-raw))
                    (unreachable)))
          (local.set $kind (ref.cast (ref $Symbol) (local.get $kind-raw)))
          (if (ref.eq (local.get $kind) (global.get $symbol:home-dir))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-home-dir)
                                  (global.get $missing)))))
          (if (ref.eq (local.get $kind) (global.get $symbol:pref-dir))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-pref-dir)
                                  (global.get $missing)))))
          (if (ref.eq (local.get $kind) (global.get $symbol:pref-file))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-pref-file)
                                  (global.get $missing)))))
          (if (ref.eq (local.get $kind) (global.get $symbol:temp-dir))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-temp-dir)
                                  (global.get $missing)))))
          (if (ref.eq (local.get $kind) (global.get $symbol:init-dir))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-home-dir)
                                  (global.get $missing)))))
          (if (ref.eq (local.get $kind) (global.get $symbol:init-file))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-init-file)
                                  (global.get $missing)))))
          (if (i32.or (ref.eq (local.get $kind) (global.get $symbol:config-dir))
                      (ref.eq (local.get $kind) (global.get $symbol:host-config-dir)))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-config-dir)
                                  (global.get $missing)))))
          (if (i32.or (ref.eq (local.get $kind) (global.get $symbol:addon-dir))
                      (ref.eq (local.get $kind) (global.get $symbol:host-addon-dir)))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-addon-dir)
                                  (global.get $missing)))))
          (if (ref.eq (local.get $kind) (global.get $symbol:cache-dir))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-cache-dir)
                                  (global.get $missing)))))
          (if (i32.or (ref.eq (local.get $kind) (global.get $symbol:doc-dir))
                      (ref.eq (local.get $kind) (global.get $symbol:desk-dir)))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-home-dir)
                                  (global.get $missing)))))
          (if (ref.eq (local.get $kind) (global.get $symbol:sys-dir))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-root)
                                  (global.get $missing)))))
          (if (ref.eq (local.get $kind) (global.get $symbol:exec-file))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-exec-file)
                                  (global.get $missing)))))
          (if (ref.eq (local.get $kind) (global.get $symbol:run-file))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-run-file)
                                  (global.get $missing)))))
          (if (i32.or (ref.eq (local.get $kind) (global.get $symbol:collects-dir))
                      (ref.eq (local.get $kind) (global.get $symbol:host-collects-dir)))
              (then (return (call $bytes->path
                                  (global.get $bytes:vfs-collects-dir)
                                  (global.get $missing)))))
          (if (ref.eq (local.get $kind) (global.get $symbol:orig-dir))
              (then (return (call $bytes->path
                                  (global.get $bytes:app-dir)
                                  (global.get $missing)))))
          (call $raise-argument-error1
                (global.get $symbol:find-system-path)
                (global.get $string:system-path-kind)
                (local.get $kind-raw))
          (unreachable))

    ;; find-executable-path : path-string? [(or/c path-string? #f)] [any/c] -> (or/c path? #f)
    ;;   WebRacket has no host executable search path, so this validates inputs
    ;;   and reports that no executable can be found. The optional `related`
    ;;   argument defaults to #f and must be a relative path string when present.
    (func $find-executable-path (type $Prim13)
          (param $program-raw (ref eq)) ;; path-string?
          (param $related-raw (ref eq)) ;; optional (or/c #f relative-path-string?), default = #f
          (param $deepest-raw (ref eq)) ;; optional any/c, default = #f
          (result             (ref eq))

          (if (i32.eqz (ref.eq (call $path-string? (local.get $program-raw))
                               (global.get $true)))
              (then (call $raise-argument-error1
                          (global.get $symbol:find-executable-path)
                          (global.get $string:path-string?)
                          (local.get $program-raw))
                    (unreachable)))
          (if (i32.eqz (ref.eq (local.get $related-raw) (global.get $missing)))
              (then
               (if (i32.eqz (ref.eq (local.get $related-raw) (global.get $false)))
                   (then
                    (if (i32.eqz
                         (i32.and
                          (ref.eq (call $path-string? (local.get $related-raw))
                                  (global.get $true))
                          (ref.eq (call $relative-path? (local.get $related-raw))
                                  (global.get $true))))
                        (then (call $raise-argument-error1
                                    (global.get $symbol:find-executable-path)
                                    (global.get $string:relative-path-string-or-false)
                                    (local.get $related-raw))
                              (unreachable)))))))
          (global.get $false))

    ;; current-drive : -> path?
    ;;   Return the current VFS drive/root for WebRacket's Unix-style paths.
    (func $current-drive (type $Prim0)
          (result (ref eq))
          (call $bytes->path
                (global.get $bytes:vfs-root)
                (global.get $missing)))

    (func $path->complete-path (type $Prim12)
          (param $path-raw (ref eq)) ;; path-string?
          (param $base-raw (ref eq)) ;; optional path-string?, default current-directory
          (result          (ref eq)) ;; path?

          (local $path (ref $Path))
          (local $base (ref eq))

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:path->complete-path)
                           (local.get $path-raw)))
          (if (call $path-bytes-absolute? (struct.get $Path $bytes (local.get $path)))
              (then (return (local.get $path))))
          (local.set $base
                     (if (result (ref eq))
                         (ref.eq (local.get $base-raw) (global.get $missing))
                         (then (global.get $current-directory-path))
                         (else (local.get $base-raw))))
          (call $path-join-bytes (local.get $base) (local.get $path)))

    ;; path->directory-path : (or/c path-string? path-for-some-system?) -> path-for-some-system?
    ;;   Ensure a path syntactically ends in a convention-specific directory separator.
    (func $path->directory-path (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string? or path-for-some-system?
          (result          (ref eq))

          (local $path  (ref $Path))
          (local $bytes (ref $Bytes))
          (local $arr   (ref $I8Array))
          (local $conv  (ref eq))
          (local $sep   (ref $Bytes))
          (local $len   i32)

          (local.set $path (ref.cast (ref $Path) (global.get $current-directory-path)))
          (if (ref.test (ref $Path) (local.get $path-raw))
              (then
               (local.set $path (ref.cast (ref $Path) (local.get $path-raw))))
              (else
               (local.set $path
                          (call $path-string->path/checked
                                (global.get $symbol:path->directory-path)
                                (local.get $path-raw)))))
          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (local.set $bytes (struct.get $Path $bytes (local.get $path)))
          (local.set $arr (struct.get $Bytes $bs (local.get $bytes)))
          (local.set $len (array.len (local.get $arr)))
          (if (call $path-byte-separator?
                    (array.get_u $I8Array
                                 (local.get $arr)
                                 (i32.sub (local.get $len) (i32.const 1)))
                    (local.get $conv))
              (then (return (local.get $path))))
          (local.set $sep
                     (if (result (ref $Bytes))
                         (ref.eq (local.get $conv) (global.get $symbol:windows))
                         (then (ref.cast (ref $Bytes) (global.get $bytes:backslash)))
                         (else (ref.cast (ref $Bytes) (global.get $bytes:slash)))))
          (call $bytes->path
                (call $bytes-append/2 (local.get $bytes) (local.get $sep))
                (local.get $conv)))

    ;; cleanse-path : (or/c path-string? path-for-some-system?) -> path-for-some-system?
    ;;   Remove redundant consecutive separators without consulting the filesystem.
    (func $cleanse-path (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string? or path-for-some-system?
          (result          (ref eq))

          (local $path      (ref $Path))
          (local $bytes     (ref $Bytes))
          (local $arr       (ref $I8Array))
          (local $out       (ref $GrowableBytes))
          (local $conv      (ref eq))
          (local $len       i32)
          (local $i         i32)
          (local $b         i32)
          (local $prev-sep? i32)
          (local $sep?      i32)

          (local.set $path (ref.cast (ref $Path) (global.get $current-directory-path)))
          (if (ref.test (ref $Path) (local.get $path-raw))
              (then
               (local.set $path (ref.cast (ref $Path) (local.get $path-raw))))
              (else
               (local.set $path
                          (call $path-string->path/checked
                                (global.get $symbol:cleanse-path)
                                (local.get $path-raw)))))
          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (local.set $bytes (struct.get $Path $bytes (local.get $path)))
          (local.set $arr (struct.get $Bytes $bs (local.get $bytes)))
          (local.set $len (array.len (local.get $arr)))
          (local.set $out (call $make-growable-bytes (local.get $len)))
          (local.set $i (i32.const 0))
          (local.set $prev-sep? (i32.const 0))
          (block $done
                 (loop $loop
                       (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                       (local.set $b (array.get_u $I8Array (local.get $arr) (local.get $i)))
                       (local.set $sep?
                                  (call $path-byte-separator?
                                        (local.get $b)
                                        (local.get $conv)))
                       (if (i32.and (local.get $sep?) (local.get $prev-sep?))
                           (then
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
                       (call $growable-bytes-add! (local.get $out) (local.get $b))
                       (local.set $prev-sep? (local.get $sep?))
                       (local.set $i (i32.add (local.get $i) (i32.const 1)))
                       (br $loop)))
          (call $bytes->path
                (call $growable-bytes->bytes (local.get $out))
                (local.get $conv)))

    ;; resolve-path : path-string? -> path?
    ;;   Return the validated VFS path; soft links and full cleansing are not modeled yet.
    (func $resolve-path (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (call $path-string->path/checked
                (global.get $symbol:resolve-path)
                (local.get $path-raw)))

    (func $path-root-element?
          (param $path (ref $Path))
          (result      i32)

          (local $bytes (ref $Bytes))
          (local $arr   (ref $I8Array))
          (local $conv  (ref eq))

          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (local.set $bytes (struct.get $Path $bytes (local.get $path)))
          (local.set $arr (struct.get $Bytes $bs (local.get $bytes)))
          (if (i32.ne (array.len (local.get $arr)) (i32.const 1))
              (then (return (i32.const 0))))
          (call $path-byte-separator?
                (array.get_u $I8Array (local.get $arr) (i32.const 0))
                (local.get $conv)))

    ;; simplify-path : (or/c path-string? path-for-some-system?) [boolean?] -> path-for-some-system?
    ;;   Syntactically remove redundant separators, "." elements, and cancellable ".." elements.
    ;;   The optional use-filesystem? argument defaults to #t but is currently ignored:
    ;;   WebRacket does not model filesystem or link resolution here yet.
    (func $simplify-path (type $Prim12)
          (param $path-raw        (ref eq)) ;; path-string? or path-for-some-system?
          (param $use-filesystem? (ref eq)) ;; boolean?, optional default #t; currently ignored
          (result                 (ref eq))

          (local $path     (ref $Path))
          (local $path-bs  (ref $Bytes))
          (local $conv     (ref eq))
          (local $parts    (ref eq))
          (local $stack    (ref eq))
          (local $ordered  (ref eq))
          (local $node     (ref $Pair))
          (local $top-node (ref $Pair))
          (local $part     (ref eq))
          (local $top      (ref eq))
          (local $result   (ref eq))
          (local $dir?     i32)

          (local.set $path (ref.cast (ref $Path) (global.get $current-directory-path)))
          (if (ref.test (ref $Path) (local.get $path-raw))
              (then
               (local.set $path (ref.cast (ref $Path) (local.get $path-raw))))
              (else
               (local.set $path
                          (call $path-string->path/checked
                                (global.get $symbol:simplify-path)
                                (local.get $path-raw)))))
          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $dir? (call $path-syntactic-directory?
                                 (local.get $path-bs)
                                 (local.get $conv)))
          (local.set $parts (call $explode-path (local.get $path)))
          (local.set $stack (global.get $null))
          (block $done
                 (loop $loop
                       (br_if $done (ref.eq (local.get $parts) (global.get $null)))
                       (local.set $node (ref.cast (ref $Pair) (local.get $parts)))
                       (local.set $part (struct.get $Pair $a (local.get $node)))
                       (if (ref.eq (local.get $part) (global.get $symbol:same))
                           (then
                            (local.set $parts (struct.get $Pair $d (local.get $node)))
                            (br $loop)))
                       (if (ref.eq (local.get $part) (global.get $symbol:up))
                           (then
                            (if (ref.eq (local.get $stack) (global.get $null))
                                (then
                                 (local.set $stack
                                            (struct.new $Pair
                                                        (i32.const 0)
                                                        (local.get $part)
                                                        (local.get $stack))))
                                (else
                                 (local.set $top-node (ref.cast (ref $Pair) (local.get $stack)))
                                 (local.set $top (struct.get $Pair $a (local.get $top-node)))
                                 (if (ref.test (ref $Path) (local.get $top))
                                     (then
                                      (if (call $path-root-element?
                                                (ref.cast (ref $Path) (local.get $top)))
                                          (then)
                                          (else
                                           (local.set $stack
                                                      (struct.get $Pair $d (local.get $top-node))))))
                                     (else
                                      (local.set $stack
                                                 (struct.new $Pair
                                                             (i32.const 0)
                                                             (local.get $part)
                                                             (local.get $stack))))))))
                           (else
                            (local.set $stack
                                       (struct.new $Pair
                                                   (i32.const 0)
                                                   (local.get $part)
                                                   (local.get $stack)))))
                       (local.set $parts (struct.get $Pair $d (local.get $node)))
                       (br $loop)))
          (local.set $ordered (call $reverse (local.get $stack)))
          (local.set $result
                     (call $path-part->path/convention
                           (global.get $symbol:simplify-path)
                           (local.get $conv)
                           (global.get $symbol:same)))
          (if (ref.eq (local.get $ordered) (global.get $null))
              (then)
              (else
               (local.set $node (ref.cast (ref $Pair) (local.get $ordered)))
               (local.set $result
                          (call $path-part->path/convention
                                (global.get $symbol:simplify-path)
                                (local.get $conv)
                                (struct.get $Pair $a (local.get $node))))
               (local.set $ordered (struct.get $Pair $d (local.get $node)))
               (block $build-done
                      (loop $build-loop
                            (br_if $build-done
                                   (ref.eq (local.get $ordered) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $ordered)))
                            (local.set $result
                                       (call $path-join-bytes/convention
                                             (global.get $symbol:simplify-path)
                                             (local.get $conv)
                                             (local.get $result)
                                             (struct.get $Pair $a (local.get $node))))
                            (local.set $ordered (struct.get $Pair $d (local.get $node)))
                            (br $build-loop)))))
          (if (local.get $dir?)
              (then (return (call $path->directory-path (local.get $result)))))
          (local.get $result))

    ;; simple-form-path : path-string? -> path?
    ;;   Complete a path, then simplify it syntactically.
    (func $simple-form-path (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (call $simplify-path
                (call $path->complete-path
                      (local.get $path-raw)
                      (global.get $missing))
                (global.get $true)))

    ;; normalize-path : path-string? [complete-path?] -> path?
    ;;   Complete a path relative to wrt, then simplify syntactically.
    ;;   WebRacket does not resolve VFS links here yet.
    (func $normalize-path (type $Prim12)
          (param $path-raw (ref eq)) ;; path-string?
          (param $wrt-raw  (ref eq)) ;; complete path-string?, optional default current-directory
          (result          (ref eq))

          (local $wrt (ref eq))
          (local $wrt-path (ref $Path))

          (local.set $wrt-path
                     (ref.cast (ref $Path) (global.get $current-directory-path)))
          (local.set $wrt (local.get $wrt-path))
          (if (i32.eqz (ref.eq (local.get $wrt-raw) (global.get $missing)))
              (then
               (if (ref.test (ref $Path) (local.get $wrt-raw))
                   (then
                    (local.set $wrt-path (ref.cast (ref $Path) (local.get $wrt-raw)))
                    (if (i32.eqz
                         (ref.eq (struct.get $Path $convention (local.get $wrt-path))
                                 (global.get $system-path-convention)))
                        (then (call $raise-complete-path-expected/who
                                    (global.get $symbol:normalize-path)
                                    (local.get $wrt-raw))
                              (unreachable))))
                   (else
                    (if (i32.eqz (ref.test (ref $String) (local.get $wrt-raw)))
                        (then (call $raise-complete-path-expected/who
                                    (global.get $symbol:normalize-path)
                                    (local.get $wrt-raw))
                              (unreachable)))
                    (if (i32.eqz (ref.eq (call $non-empty-string-without-nuls
                                                 (ref.cast (ref $String)
                                                           (local.get $wrt-raw)))
                                         (global.get $true)))
                        (then (call $raise-complete-path-expected/who
                                    (global.get $symbol:normalize-path)
                                    (local.get $wrt-raw))
                              (unreachable)))
                    (local.set $wrt-path
                               (ref.cast (ref $Path)
                                         (call $string->path
                                               (ref.cast (ref $String)
                                                         (local.get $wrt-raw)))))))
               (if (i32.eqz (call $path-bytes-absolute?
                                  (struct.get $Path $bytes (local.get $wrt-path))))
                   (then (call $raise-complete-path-expected/who
                               (global.get $symbol:normalize-path)
                               (local.get $wrt-raw))
                         (unreachable)))
               (local.set $wrt (local.get $wrt-path))))
          (call $simplify-path
                (call $path->complete-path
                      (local.get $path-raw)
                      (local.get $wrt))
                (global.get $true)))

    (func $path-part-equal?
          (param $a (ref eq))
          (param $b (ref eq))
          (result   i32)

          (if (ref.eq (local.get $a) (local.get $b))
              (then (return (i32.const 1))))
          (if (i32.eqz (ref.test (ref $Path) (local.get $a)))
              (then (return (i32.const 0))))
          (if (i32.eqz (ref.test (ref $Path) (local.get $b)))
              (then (return (i32.const 0))))
          (ref.eq (call $bytes=?/2/checked
                        (struct.get $Path $bytes
                                    (ref.cast (ref $Path) (local.get $a)))
                        (struct.get $Path $bytes
                                    (ref.cast (ref $Path) (local.get $b))))
                  (global.get $true)))

    (func $path-parts-suffix-diff-size
          (param $a (ref eq)) ;; reversed path parts
          (param $b (ref eq)) ;; reversed path parts
          (result   i32)

          (local $a-node (ref $Pair))
          (local $b-node (ref $Pair))
          (local $size   i32)

          (local.set $size (i32.const 1))
          (block $done
                 (loop $loop
                       (br_if $done (ref.eq (local.get $a) (global.get $null)))
                       (br_if $done (ref.eq (local.get $b) (global.get $null)))
                       (local.set $a-node (ref.cast (ref $Pair) (local.get $a)))
                       (local.set $b-node (ref.cast (ref $Pair) (local.get $b)))
                       (br_if $done
                              (i32.eqz
                               (call $path-part-equal?
                                     (struct.get $Pair $a (local.get $a-node))
                                     (struct.get $Pair $a (local.get $b-node)))))
                       (local.set $a (struct.get $Pair $d (local.get $a-node)))
                       (local.set $b (struct.get $Pair $d (local.get $b-node)))
                       (local.set $size (i32.add (local.get $size) (i32.const 1)))
                       (br $loop)))
          (local.get $size))

    (func $path-parts-equal?
          (param $a (ref eq)) ;; reversed path parts
          (param $b (ref eq)) ;; reversed path parts
          (result   i32)

          (local $a-node (ref $Pair))
          (local $b-node (ref $Pair))

          (block $done
                 (loop $loop
                       (if (ref.eq (local.get $a) (global.get $null))
                           (then
                            (return
                             (if (result i32)
                                 (ref.eq (local.get $b) (global.get $null))
                                 (then (i32.const 1))
                                 (else (i32.const 0))))))
                       (if (ref.eq (local.get $b) (global.get $null))
                           (then (return (i32.const 0))))
                       (local.set $a-node (ref.cast (ref $Pair) (local.get $a)))
                       (local.set $b-node (ref.cast (ref $Pair) (local.get $b)))
                       (if (i32.eqz
                            (call $path-part-equal?
                                  (struct.get $Pair $a (local.get $a-node))
                                  (struct.get $Pair $a (local.get $b-node))))
                           (then (return (i32.const 0))))
                       (local.set $a (struct.get $Pair $d (local.get $a-node)))
                       (local.set $b (struct.get $Pair $d (local.get $b-node)))
                       (br $loop)))
          (i32.const 1))

    (func $build-path-from-reversed-prefix
          (param $who       (ref eq)) ;; symbol?
          (param $conv      (ref eq)) ;; (or/c 'unix 'windows)
          (param $parts-rev (ref eq)) ;; reversed path parts
          (param $size      i32)
          (result           (ref eq))

          (local $i      i32)
          (local $prefix (ref eq))
          (local $node   (ref $Pair))
          (local $result (ref eq))

          (local.set $i (i32.const 0))
          (local.set $prefix (global.get $null))
          (block $take-done
                 (loop $take-loop
                       (br_if $take-done (i32.ge_u (local.get $i) (local.get $size)))
                       (br_if $take-done (ref.eq (local.get $parts-rev) (global.get $null)))
                       (local.set $node (ref.cast (ref $Pair) (local.get $parts-rev)))
                       (local.set $prefix
                                  (struct.new $Pair
                                              (i32.const 0)
                                              (struct.get $Pair $a (local.get $node))
                                              (local.get $prefix)))
                       (local.set $parts-rev (struct.get $Pair $d (local.get $node)))
                       (local.set $i (i32.add (local.get $i) (i32.const 1)))
                       (br $take-loop)))
          (local.set $node (ref.cast (ref $Pair) (local.get $prefix)))
          (local.set $result
                     (call $path-part->path/convention
                           (local.get $who)
                           (local.get $conv)
                           (struct.get $Pair $a (local.get $node))))
          (local.set $prefix (struct.get $Pair $d (local.get $node)))
          (block $build-done
                 (loop $build-loop
                       (br_if $build-done (ref.eq (local.get $prefix) (global.get $null)))
                       (local.set $node (ref.cast (ref $Pair) (local.get $prefix)))
                       (local.set $result
                                  (call $path-join-bytes/convention
                                        (local.get $who)
                                        (local.get $conv)
                                        (local.get $result)
                                        (struct.get $Pair $a (local.get $node))))
                       (local.set $prefix (struct.get $Pair $d (local.get $node)))
                       (br $build-loop)))
          (local.get $result))

    ;; find-relative-path : (or/c path-string? path-for-some-system?) (or/c path-string? path-for-some-system?) [any/c] [any/c] [any/c] -> path-string?
    ;;   Keywordless form of Racket's #:more-than-root? (default #f),
    ;;   #:more-than-same? (default #t), and #:normalize-case? (default #t).
    (func $find-relative-path (type $Prim25)
          (param $base-raw            (ref eq)) ;; path-string? or path-for-some-system?
          (param $path-raw            (ref eq)) ;; path-string? or path-for-some-system?
          (param $more-than-root-raw  (ref eq)) ;; optional any/c, default #f
          (param $more-than-same-raw  (ref eq)) ;; optional any/c, default #t
          (param $normalize-case-raw  (ref eq)) ;; optional any/c, default #t
          (result                     (ref eq))

          (local $base-path (ref $Path))
          (local $path      (ref $Path))
          (local $conv      (ref eq))
          (local $base      (ref eq))
          (local $target    (ref eq))
          (local $base-node (ref $Pair))
          (local $path-node (ref $Pair))
          (local $part      (ref eq))
          (local $result    (ref eq))
          (local $has?      i32)
          (local $common-count       i32)
          (local $common-root?       i32)
          (local $more-than-root?    i32)
          (local $more-than-same?    i32)
          (local $normalize-case?    i32)
          (local $original-result    (ref eq))

          (local.set $base-path
                     (call $path-string->path/checked
                           (global.get $symbol:find-relative-path)
                           (local.get $base-raw)))
          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:find-relative-path)
                           (local.get $path-raw)))
          (local.set $conv (struct.get $Path $convention (local.get $base-path)))
          (if (i32.eqz (ref.eq (local.get $conv)
                               (struct.get $Path $convention (local.get $path))))
              (then (call $raise-argument-error1
                          (global.get $symbol:find-relative-path)
                          (global.get $string:path-for-some-system?)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $more-than-root?
                     (i32.and
                      (i32.eqz (ref.eq (local.get $more-than-root-raw)
                                       (global.get $missing)))
                      (i32.eqz (ref.eq (local.get $more-than-root-raw)
                                       (global.get $false)))))
          (local.set $more-than-same?
                     (i32.or
                      (ref.eq (local.get $more-than-same-raw)
                              (global.get $missing))
                      (i32.eqz (ref.eq (local.get $more-than-same-raw)
                                       (global.get $false)))))
          (local.set $normalize-case?
                     (i32.or
                      (ref.eq (local.get $normalize-case-raw)
                              (global.get $missing))
                      (i32.eqz (ref.eq (local.get $normalize-case-raw)
                                       (global.get $false)))))
          (local.set $original-result
                     (if (result (ref eq))
                         (ref.test (ref $String) (local.get $path-raw))
                         (then (local.get $path-raw))
                         (else (local.get $path))))
          (local.set $base
                     (call $explode-path
                           (if (result (ref eq))
                               (local.get $normalize-case?)
                               (then (call $normal-case-path (local.get $base-path)))
                               (else (local.get $base-path)))))
          (local.set $target
                     (call $explode-path
                           (if (result (ref eq))
                               (local.get $normalize-case?)
                               (then (call $normal-case-path (local.get $path)))
                               (else (local.get $path)))))
          (block $common-done
                 (loop $common-loop
                       (br_if $common-done (ref.eq (local.get $base) (global.get $null)))
                       (br_if $common-done (ref.eq (local.get $target) (global.get $null)))
                       (local.set $base-node (ref.cast (ref $Pair) (local.get $base)))
                       (local.set $path-node (ref.cast (ref $Pair) (local.get $target)))
                       (br_if $common-done
                              (i32.eqz
                               (call $path-part-equal?
                                     (struct.get $Pair $a (local.get $base-node))
                                     (struct.get $Pair $a (local.get $path-node)))))
                       (local.set $part (struct.get $Pair $a (local.get $base-node)))
                       (if (i32.and (i32.eqz (local.get $common-count))
                                    (ref.test (ref $Path) (local.get $part)))
                           (then
                            (local.set $common-root?
                                       (call $path-bytes-absolute?
                                             (struct.get $Path $bytes
                                                         (ref.cast (ref $Path)
                                                                   (local.get $part)))))))
                       (local.set $common-count
                                  (i32.add (local.get $common-count) (i32.const 1)))
                       (local.set $base (struct.get $Pair $d (local.get $base-node)))
                       (local.set $target (struct.get $Pair $d (local.get $path-node)))
                       (br $common-loop)))
          (if (i32.and
               (i32.and (local.get $more-than-root?)
                        (i32.and (local.get $common-root?)
                                 (i32.eq (local.get $common-count) (i32.const 1))))
               (i32.and (i32.eqz (ref.eq (local.get $base) (global.get $null)))
                        (i32.eqz (ref.eq (local.get $target) (global.get $null)))))
              (then (return (local.get $original-result))))
          (if (i32.and
               (i32.and (local.get $more-than-same?)
                        (ref.eq (local.get $base) (global.get $null)))
               (ref.eq (local.get $target) (global.get $null)))
              (then (return (local.get $original-result))))
          (local.set $has? (i32.const 0))
          (local.set $result (global.get $symbol:same))
          (block $base-done
                 (loop $base-loop
                       (br_if $base-done (ref.eq (local.get $base) (global.get $null)))
                       (local.set $base-node (ref.cast (ref $Pair) (local.get $base)))
                       (if (local.get $has?)
                           (then
                            (local.set $result
                                       (call $path-join-bytes/convention
                                             (global.get $symbol:find-relative-path)
                                             (local.get $conv)
                                             (local.get $result)
                                             (global.get $symbol:up))))
                           (else
                            (local.set $result
                                       (call $path-part->path/convention
                                             (global.get $symbol:find-relative-path)
                                             (local.get $conv)
                                             (global.get $symbol:up)))
                            (local.set $has? (i32.const 1))))
                       (local.set $base (struct.get $Pair $d (local.get $base-node)))
                       (br $base-loop)))
          (block $target-done
                 (loop $target-loop
                       (br_if $target-done (ref.eq (local.get $target) (global.get $null)))
                       (local.set $path-node (ref.cast (ref $Pair) (local.get $target)))
                       (local.set $part (struct.get $Pair $a (local.get $path-node)))
                       (if (local.get $has?)
                           (then
                            (local.set $result
                                       (call $path-join-bytes/convention
                                             (global.get $symbol:find-relative-path)
                                             (local.get $conv)
                                             (local.get $result)
                                             (local.get $part))))
                           (else
                            (local.set $result
                                       (call $path-part->path/convention
                                             (global.get $symbol:find-relative-path)
                                             (local.get $conv)
                                             (local.get $part)))
                            (local.set $has? (i32.const 1))))
                       (local.set $target (struct.get $Pair $d (local.get $path-node)))
                       (br $target-loop)))
          (if (local.get $has?)
              (then (return (local.get $result))))
          (call $path-part->path/convention
                (global.get $symbol:find-relative-path)
                (local.get $conv)
                (global.get $symbol:same)))

    ;; shrink-path-wrt : path? (listof path?) -> (or/c #f path?)
    ;;   Return the shortest suffix that distinguishes path from the non-identical other paths.
    (func $shrink-path-wrt (type $Prim2)
          (param $path-raw  (ref eq)) ;; path?
          (param $others    (ref eq)) ;; listof path?
          (result           (ref eq))

          (local $path      (ref $Path))
          (local $other     (ref $Path))
          (local $conv      (ref eq))
          (local $path-rev  (ref eq))
          (local $other-rev (ref eq))
          (local $node      (ref $Pair))
          (local $diff      i32)
          (local $size      i32)
          (local $any?      i32)

          (if (i32.eqz (ref.test (ref $Path) (local.get $path-raw)))
              (then (call $raise-path-argument-error1/write
                          (global.get $symbol:shrink-path-wrt)
                          (global.get $string:path?)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $path (ref.cast (ref $Path) (local.get $path-raw)))
          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (if (i32.eqz (ref.eq (local.get $conv) (global.get $system-path-convention)))
              (then (call $raise-argument-error1
                          (global.get $symbol:shrink-path-wrt)
                          (global.get $string:path?)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $path-rev (call $reverse (call $explode-path (local.get $path))))
          (local.set $size (i32.const 1))
          (local.set $any? (i32.const 0))
          (block $done
                 (loop $loop
                       (br_if $done (ref.eq (local.get $others) (global.get $null)))
                       (local.set $node (ref.cast (ref $Pair) (local.get $others)))
                       (if (i32.eqz (ref.test (ref $Path) (struct.get $Pair $a (local.get $node))))
                           (then (call $raise-argument-error1
                                       (global.get $symbol:shrink-path-wrt)
                                       (global.get $string:listof-path?)
                                       (local.get $others))
                                 (unreachable)))
                       (local.set $other (ref.cast (ref $Path) (struct.get $Pair $a (local.get $node))))
                       (if (i32.eqz (ref.eq (struct.get $Path $convention (local.get $other))
                                            (global.get $system-path-convention)))
                           (then (call $raise-argument-error1
                                       (global.get $symbol:shrink-path-wrt)
                                       (global.get $string:listof-path?)
                                       (local.get $others))
                                 (unreachable)))
                       (local.set $other-rev
                                  (call $reverse (call $explode-path (local.get $other))))
                       (if (i32.eqz (call $path-parts-equal?
                                          (local.get $path-rev)
                                          (local.get $other-rev)))
                           (then
                            (local.set $any? (i32.const 1))
                            (local.set $diff
                                       (call $path-parts-suffix-diff-size
                                             (local.get $other-rev)
                                             (local.get $path-rev)))
                            (if (i32.gt_u (local.get $diff) (local.get $size))
                                (then (local.set $size (local.get $diff))))))
                       (local.set $others (struct.get $Pair $d (local.get $node)))
                       (br $loop)))
          (if (i32.eqz (local.get $any?))
              (then (return (global.get $false))))
          (call $build-path-from-reversed-prefix
                (global.get $symbol:shrink-path-wrt)
                (local.get $conv)
                (local.get $path-rev)
                (local.get $size)))

    ;; normal-case-path : (or/c path-string? path-for-some-system?) -> path-for-some-system?
    ;;   Return Unix paths unchanged; for Windows, lowercase ASCII letters and use backslash separators.
    (func $normal-case-path (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string? or path-for-some-system?
          (result          (ref eq))

          (local $path    (ref $Path))
          (local $bytes   (ref $Bytes))
          (local $src     (ref $I8Array))
          (local $dst     (ref $I8Array))
          (local $conv    (ref eq))
          (local $len     i32)
          (local $i       i32)
          (local $b       i32)

          (local.set $path (ref.cast (ref $Path) (global.get $current-directory-path)))
          (if (ref.test (ref $Path) (local.get $path-raw))
              (then
               (local.set $path (ref.cast (ref $Path) (local.get $path-raw))))
              (else
               (local.set $path
                          (call $path-string->path/checked
                                (global.get $symbol:normal-case-path)
                                (local.get $path-raw)))))
          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (local.set $bytes (struct.get $Path $bytes (local.get $path)))
          (if (i32.eqz (ref.eq (local.get $conv) (global.get $symbol:windows)))
              (then (return (local.get $path))))
          (local.set $src (struct.get $Bytes $bs (local.get $bytes)))
          (local.set $len (array.len (local.get $src)))
          (local.set $dst (array.new $I8Array (i32.const 0) (local.get $len)))
          (local.set $i (i32.const 0))
          (block $done
                 (loop $loop
                       (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                       (local.set $b (array.get_u $I8Array (local.get $src) (local.get $i)))
                       (if (i32.eq (local.get $b) (i32.const 47))
                           (then (local.set $b (i32.const 92))))
                       (if (i32.and (i32.ge_u (local.get $b) (i32.const 65))
                                    (i32.le_u (local.get $b) (i32.const 90)))
                           (then (local.set $b (i32.add (local.get $b) (i32.const 32)))))
                       (array.set $I8Array (local.get $dst) (local.get $i) (local.get $b))
                       (local.set $i (i32.add (local.get $i) (i32.const 1)))
                       (br $loop)))
          (call $bytes->path
                (call $i8array->immutable-bytes (local.get $dst))
                (local.get $conv)))

    ;; reroot-path : (or/c path-string? path-for-some-system?) (or/c path-string? path-for-some-system?) -> path-for-some-system?
    ;;   Append the complete, cleansed, case-normalized path elements under root-path.
    ;;   Windows drive and UNC rerooting are not modeled beyond the represented path elements.
    (func $reroot-path (type $Prim2)
          (param $path-raw (ref eq)) ;; path-string? or path-for-some-system?
          (param $root-raw (ref eq)) ;; path-string? or path-for-some-system?
          (result          (ref eq))

          (local $root   (ref $Path))
          (local $conv   (ref eq))
          (local $parts  (ref eq))
          (local $node   (ref $Pair))
          (local $part   (ref eq))
          (local $result (ref eq))

          (local.set $root (ref.cast (ref $Path) (global.get $current-directory-path)))
          (if (ref.test (ref $Path) (local.get $root-raw))
              (then
               (local.set $root (ref.cast (ref $Path) (local.get $root-raw))))
              (else
               (local.set $root
                          (call $path-string->path/checked
                                (global.get $symbol:reroot-path)
                                (local.get $root-raw)))))
          (local.set $conv (struct.get $Path $convention (local.get $root)))
          (local.set $result (local.get $root))
          (local.set $parts
                     (call $explode-path
                           (call $normal-case-path
                                 (call $cleanse-path
                                       (call $path->complete-path
                                             (local.get $path-raw)
                                             (global.get $missing))))))
          (if (i32.eqz (ref.eq (local.get $parts) (global.get $null)))
              (then
               (local.set $node (ref.cast (ref $Pair) (local.get $parts)))
               (local.set $part (struct.get $Pair $a (local.get $node)))
               (if (ref.test (ref $Path) (local.get $part))
                   (then
                    (if (call $path-root-element?
                              (ref.cast (ref $Path) (local.get $part)))
                        (then
                         (local.set $parts (struct.get $Pair $d (local.get $node)))))))))
          (block $done
                 (loop $loop
                       (br_if $done (ref.eq (local.get $parts) (global.get $null)))
                       (local.set $node (ref.cast (ref $Pair) (local.get $parts)))
                       (local.set $part (struct.get $Pair $a (local.get $node)))
                       (local.set $result
                                  (call $path-join-bytes/convention
                                        (global.get $symbol:reroot-path)
                                        (local.get $conv)
                                        (local.get $result)
                                        (local.get $part)))
                       (local.set $parts (struct.get $Pair $d (local.get $node)))
                       (br $loop)))
          (local.get $result))

    (func $string-or-bytes->bytes/checked
          (param $who (ref eq)) ;; symbol?
          (param $v   (ref eq)) ;; (or/c string? bytes?)
          (result     (ref $Bytes))

          (if (ref.test (ref $Bytes) (local.get $v))
              (then (return (ref.cast (ref $Bytes) (local.get $v)))))
          (if (ref.test (ref $String) (local.get $v))
              (then
               (return
                (ref.cast (ref $Bytes)
                          (call $string->bytes/utf-8
                                (ref.cast (ref $String) (local.get $v))
                                (global.get $false)
                                (global.get $false)
                                (global.get $false))))))
          (call $raise-argument-error1
                (local.get $who)
                (global.get $string:string-or-bytes)
                (local.get $v))
          (unreachable))

    (func $bytes-slice/unchecked
          (param $bytes (ref $Bytes))
          (param $start i32)
          (param $end   i32)
          (result       (ref $Bytes))

          (struct.new $Bytes
                      (i32.const 0)
                      (i32.const 0)
                      (call $i8array-copy
                            (struct.get $Bytes $bs (local.get $bytes))
                            (local.get $start)
                            (local.get $end))))

    (func $path-extension-start
          (param $path-bs (ref $Bytes))
          (result         i32)

          (local $arr        (ref $I8Array))
          (local $len        i32)
          (local $elem-start i32)
          (local $i          i32)
          (local $idx        i32)

          (local.set $arr (struct.get $Bytes $bs (local.get $path-bs)))
          (local.set $len (array.len (local.get $arr)))
          (local.set $elem-start (i32.const 0))
          (local.set $i (local.get $len))
          (block $slash-done
                 (loop $slash-loop
                       (br_if $slash-done (i32.eqz (local.get $i)))
                       (local.set $idx (i32.sub (local.get $i) (i32.const 1)))
                       (if (i32.eq (array.get_u $I8Array (local.get $arr) (local.get $idx))
                                   (i32.const 47))
                           (then
                            (local.set $elem-start (local.get $i))
                            (br $slash-done)))
                       (local.set $i (local.get $idx))
                       (br $slash-loop)))

          (if (i32.eq (local.get $elem-start) (local.get $len))
              (then (return (local.get $len))))
          (if (i32.eq (i32.sub (local.get $len) (local.get $elem-start))
                      (i32.const 2))
              (then
               (if (i32.and
                    (i32.eq (array.get_u $I8Array (local.get $arr) (local.get $elem-start))
                            (i32.const 46))
                    (i32.eq (array.get_u $I8Array
                                         (local.get $arr)
                                         (i32.add (local.get $elem-start) (i32.const 1)))
                            (i32.const 46)))
                   (then (return (local.get $len))))))
          (local.set $i (local.get $len))
          (block $dot-done
                 (loop $dot-loop
                       (br_if $dot-done (i32.le_u (local.get $i) (local.get $elem-start)))
                       (local.set $idx (i32.sub (local.get $i) (i32.const 1)))
                       (if (i32.eq (array.get_u $I8Array (local.get $arr) (local.get $idx))
                                   (i32.const 46))
                           (then
                            (if (i32.gt_u (local.get $idx) (local.get $elem-start))
                                (then (return (local.get $idx)))
                                (else (return (local.get $len))))))
                       (local.set $i (local.get $idx))
                       (br $dot-loop)))
          (local.get $len))

    (func $path-suffix-start
          (param $path-bs (ref $Bytes))
          (result         i32)

          (local $arr        (ref $I8Array))
          (local $len        i32)
          (local $elem-start i32)
          (local $i          i32)
          (local $idx        i32)

          (local.set $arr (struct.get $Bytes $bs (local.get $path-bs)))
          (local.set $len (array.len (local.get $arr)))
          (local.set $elem-start (i32.const 0))
          (local.set $i (local.get $len))
          (block $slash-done
                 (loop $slash-loop
                       (br_if $slash-done (i32.eqz (local.get $i)))
                       (local.set $idx (i32.sub (local.get $i) (i32.const 1)))
                       (if (i32.eq (array.get_u $I8Array (local.get $arr) (local.get $idx))
                                   (i32.const 47))
                           (then
                            (local.set $elem-start (local.get $i))
                            (br $slash-done)))
                       (local.set $i (local.get $idx))
                       (br $slash-loop)))

          (if (i32.eq (local.get $elem-start) (local.get $len))
              (then (return (local.get $len))))
          (if (i32.eq (i32.sub (local.get $len) (local.get $elem-start))
                      (i32.const 2))
              (then
               (if (i32.and
                    (i32.eq (array.get_u $I8Array (local.get $arr) (local.get $elem-start))
                            (i32.const 46))
                    (i32.eq (array.get_u $I8Array
                                         (local.get $arr)
                                         (i32.add (local.get $elem-start) (i32.const 1)))
                            (i32.const 46)))
                   (then (return (local.get $len))))))
          (local.set $i (local.get $len))
          (block $dot-done
                 (loop $dot-loop
                       (br_if $dot-done (i32.le_u (local.get $i) (local.get $elem-start)))
                       (local.set $idx (i32.sub (local.get $i) (i32.const 1)))
                       (if (i32.eq (array.get_u $I8Array (local.get $arr) (local.get $idx))
                                   (i32.const 46))
                           (then (return (local.get $idx))))
                       (local.set $i (local.get $idx))
                       (br $dot-loop)))
          (local.get $len))

    (func $path-final-element-start
          (param $path-bs (ref $Bytes))
          (result         i32)

          (local $arr (ref $I8Array))
          (local $i   i32)
          (local $idx i32)

          (local.set $arr (struct.get $Bytes $bs (local.get $path-bs)))
          (local.set $i (array.len (local.get $arr)))
          (block $done
                 (loop $loop
                       (br_if $done (i32.eqz (local.get $i)))
                       (local.set $idx (i32.sub (local.get $i) (i32.const 1)))
                       (if (i32.eq (array.get_u $I8Array (local.get $arr) (local.get $idx))
                                   (i32.const 47))
                           (then (return (local.get $i))))
                       (local.set $i (local.get $idx))
                       (br $loop)))
          (i32.const 0))

    (func $path-byte-separator?
          (param $b    i32)
          (param $conv (ref eq))
          (result      i32)

          (if (i32.eq (local.get $b) (i32.const 47))
              (then (return (i32.const 1))))
          (if (ref.eq (local.get $conv) (global.get $symbol:windows))
              (then
               (if (i32.eq (local.get $b) (i32.const 92))
                   (then (return (i32.const 1))))))
          (i32.const 0))

    (func $path-final-element-start/convention
          (param $path-bs (ref $Bytes))
          (param $conv    (ref eq))
          (result         i32)

          (local $arr (ref $I8Array))
          (local $i   i32)
          (local $idx i32)

          (local.set $arr (struct.get $Bytes $bs (local.get $path-bs)))
          (local.set $i (array.len (local.get $arr)))
          (block $done
                 (loop $loop
                       (br_if $done (i32.eqz (local.get $i)))
                       (local.set $idx (i32.sub (local.get $i) (i32.const 1)))
                       (if (call $path-byte-separator?
                                 (array.get_u $I8Array (local.get $arr) (local.get $idx))
                                 (local.get $conv))
                           (then (return (local.get $i))))
                       (local.set $i (local.get $idx))
                       (br $loop)))
          (i32.const 0))

    (func $path-syntactic-directory?
          (param $path-bs (ref $Bytes))
          (param $conv    (ref eq))
          (result         i32)

          (local $arr        (ref $I8Array))
          (local $len        i32)
          (local $elem-start i32)
          (local $elem-len   i32)

          (local.set $arr (struct.get $Bytes $bs (local.get $path-bs)))
          (local.set $len (array.len (local.get $arr)))
          (if (i32.eqz (local.get $len))
              (then (return (i32.const 0))))
          (if (call $path-byte-separator?
                    (array.get_u $I8Array
                                 (local.get $arr)
                                 (i32.sub (local.get $len) (i32.const 1)))
                    (local.get $conv))
              (then (return (i32.const 1))))
          (local.set $elem-start
                     (call $path-final-element-start/convention
                           (local.get $path-bs)
                           (local.get $conv)))
          (local.set $elem-len (i32.sub (local.get $len) (local.get $elem-start)))
          (if (i32.eq (local.get $elem-len) (i32.const 1))
              (then
               (if (i32.eq (array.get_u $I8Array (local.get $arr) (local.get $elem-start))
                           (i32.const 46))
                   (then (return (i32.const 1))))))
          (if (i32.eq (local.get $elem-len) (i32.const 2))
              (then
               (if (i32.and
                    (i32.eq (array.get_u $I8Array (local.get $arr) (local.get $elem-start))
                            (i32.const 46))
                    (i32.eq (array.get_u $I8Array
                                         (local.get $arr)
                                         (i32.add (local.get $elem-start) (i32.const 1)))
                            (i32.const 46)))
                   (then (return (i32.const 1))))))
          (i32.const 0))

    ;; path-replace-extension : path-string? (or/c string? bytes?) -> path?
    ;;   Replace the final Unix/browser path-element extension.
    (func $path-replace-extension (type $Prim2)
          (param $path-raw (ref eq)) ;; path-string?
          (param $ext-raw  (ref eq)) ;; (or/c string? bytes?)
          (result          (ref eq))

          (local $path     (ref $Path))
          (local $path-bs  (ref $Bytes))
          (local $ext-bs   (ref $Bytes))
          (local $boundary i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:path-replace-extension)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $ext-bs
                     (call $string-or-bytes->bytes/checked
                           (global.get $symbol:path-replace-extension)
                           (local.get $ext-raw)))
          (local.set $boundary (call $path-extension-start (local.get $path-bs)))
          (call $bytes->path
                (call $bytes-append/2
                      (call $bytes-slice/unchecked
                            (local.get $path-bs)
                            (i32.const 0)
                            (local.get $boundary))
                      (local.get $ext-bs))
                (global.get $missing)))

    ;; path-replace-suffix : path-string? (or/c string? bytes?) -> path?
    ;;   Deprecated alias shape that treats a leading dot as a suffix separator.
    (func $path-replace-suffix (type $Prim2)
          (param $path-raw (ref eq)) ;; path-string?
          (param $ext-raw  (ref eq)) ;; (or/c string? bytes?)
          (result          (ref eq))

          (local $path     (ref $Path))
          (local $path-bs  (ref $Bytes))
          (local $ext-bs   (ref $Bytes))
          (local $boundary i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:path-replace-suffix)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $ext-bs
                     (call $string-or-bytes->bytes/checked
                           (global.get $symbol:path-replace-suffix)
                           (local.get $ext-raw)))
          (local.set $boundary (call $path-suffix-start (local.get $path-bs)))
          (call $bytes->path
                (call $bytes-append/2
                      (call $bytes-slice/unchecked
                            (local.get $path-bs)
                            (i32.const 0)
                            (local.get $boundary))
                      (local.get $ext-bs))
                (global.get $missing)))

    ;; path-add-extension : path-string? (or/c string? bytes?) [(or/c string? bytes?)] -> path?
    ;;   Add an extension, preserving an existing extension via sep; default sep = #"_".
    (func $path-add-extension (type $Prim23)
          (param $path-raw (ref eq)) ;; path-string?
          (param $ext-raw  (ref eq)) ;; (or/c string? bytes?)
          (param $sep-raw  (ref eq)) ;; optional (or/c string? bytes?), default = #"_"
          (result          (ref eq))

          (local $path      (ref $Path))
          (local $path-bs   (ref $Bytes))
          (local $ext-bs    (ref $Bytes))
          (local $sep-bs    (ref $Bytes))
          (local $prefix-bs (ref $Bytes))
          (local $suffix-bs (ref $Bytes))
          (local $boundary  i32)
          (local $len       i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:path-add-extension)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $ext-bs
                     (call $string-or-bytes->bytes/checked
                           (global.get $symbol:path-add-extension)
                           (local.get $ext-raw)))
          (local.set $sep-bs
                     (if (result (ref $Bytes))
                         (ref.eq (local.get $sep-raw) (global.get $missing))
                         (then (ref.cast (ref $Bytes) (global.get $bytes:non-empty)))
                         (else (call $string-or-bytes->bytes/checked
                                     (global.get $symbol:path-add-extension)
                                     (local.get $sep-raw)))))
          (local.set $len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (local.set $boundary (call $path-extension-start (local.get $path-bs)))
          (if (i32.eq (local.get $boundary) (local.get $len))
              (then
               (return
                (call $bytes->path
                      (call $bytes-append/2 (local.get $path-bs) (local.get $ext-bs))
                      (global.get $missing)))))
          (local.set $prefix-bs
                     (call $bytes-slice/unchecked
                           (local.get $path-bs)
                           (i32.const 0)
                           (local.get $boundary)))
          (local.set $suffix-bs
                     (call $bytes-slice/unchecked
                           (local.get $path-bs)
                           (i32.add (local.get $boundary) (i32.const 1))
                           (local.get $len)))
          (call $bytes->path
                (call $bytes-append/2
                      (call $bytes-append/2
                            (call $bytes-append/2
                                  (local.get $prefix-bs)
                                  (local.get $sep-bs))
                            (local.get $suffix-bs))
                      (local.get $ext-bs))
                (global.get $missing)))

    ;; path-add-suffix : path-string? (or/c string? bytes?) -> path?
    ;;   Deprecated alias shape that treats a leading dot as a suffix separator.
    (func $path-add-suffix (type $Prim2)
          (param $path-raw (ref eq)) ;; path-string?
          (param $ext-raw  (ref eq)) ;; (or/c string? bytes?)
          (result          (ref eq))

          (local $path      (ref $Path))
          (local $path-bs   (ref $Bytes))
          (local $ext-bs    (ref $Bytes))
          (local $prefix-bs (ref $Bytes))
          (local $suffix-bs (ref $Bytes))
          (local $boundary  i32)
          (local $len       i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:path-add-suffix)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $ext-bs
                     (call $string-or-bytes->bytes/checked
                           (global.get $symbol:path-add-suffix)
                           (local.get $ext-raw)))
          (local.set $len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (local.set $boundary (call $path-suffix-start (local.get $path-bs)))
          (if (i32.eq (local.get $boundary) (local.get $len))
              (then
               (return
                (call $bytes->path
                      (call $bytes-append/2 (local.get $path-bs) (local.get $ext-bs))
                      (global.get $missing)))))
          (local.set $prefix-bs
                     (call $bytes-slice/unchecked
                           (local.get $path-bs)
                           (i32.const 0)
                           (local.get $boundary)))
          (local.set $suffix-bs
                     (call $bytes-slice/unchecked
                           (local.get $path-bs)
                           (i32.add (local.get $boundary) (i32.const 1))
                           (local.get $len)))
          (call $bytes->path
                (call $bytes-append/2
                      (call $bytes-append/2
                            (call $bytes-append/2
                                  (local.get $prefix-bs)
                                  (global.get $bytes:non-empty))
                            (local.get $suffix-bs))
                      (local.get $ext-bs))
                (global.get $missing)))

    ;; path-get-extension : path-string? -> (or/c bytes? #f)
    ;;   Return the final path-element extension including the dot, or #f.
    (func $path-get-extension (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (local $path     (ref $Path))
          (local $path-bs  (ref $Bytes))
          (local $boundary i32)
          (local $len      i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:path-get-extension)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (local.set $boundary (call $path-extension-start (local.get $path-bs)))
          (if (i32.eq (local.get $boundary) (local.get $len))
              (then (return (global.get $false))))
          (call $bytes-slice/unchecked
                (local.get $path-bs)
                (local.get $boundary)
                (local.get $len)))

    ;; filename-extension : path-string? -> (or/c bytes? #f)
    ;;   Deprecated variant of path-get-extension that omits the dot and counts leading dots.
    (func $filename-extension (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (local $path     (ref $Path))
          (local $path-bs  (ref $Bytes))
          (local $boundary i32)
          (local $len      i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:filename-extension)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $len
                     (array.len
                      (struct.get $Bytes $bs (local.get $path-bs))))
          (local.set $boundary (call $path-suffix-start (local.get $path-bs)))
          (if (i32.eq (local.get $boundary) (local.get $len))
              (then (return (global.get $false))))
          (call $bytes-slice/unchecked
                (local.get $path-bs)
                (i32.add (local.get $boundary) (i32.const 1))
                (local.get $len)))

    ;; path-has-extension? : path-string? (or/c string? bytes?) -> boolean?
    ;;   Check whether the final path element ends with ext but is not exactly ext.
    (func $path-has-extension? (type $Prim2)
          (param $path-raw (ref eq)) ;; path-string?
          (param $ext-raw  (ref eq)) ;; (or/c string? bytes?)
          (result          (ref eq))

          (local $path       (ref $Path))
          (local $path-bs    (ref $Bytes))
          (local $ext-bs     (ref $Bytes))
          (local $path-arr   (ref $I8Array))
          (local $ext-arr    (ref $I8Array))
          (local $path-len   i32)
          (local $ext-len    i32)
          (local $elem-start i32)
          (local $elem-len   i32)
          (local $offset     i32)
          (local $i          i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:path-has-extension?)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $ext-bs
                     (call $string-or-bytes->bytes/checked
                           (global.get $symbol:path-has-extension?)
                           (local.get $ext-raw)))
          (local.set $path-arr (struct.get $Bytes $bs (local.get $path-bs)))
          (local.set $ext-arr (struct.get $Bytes $bs (local.get $ext-bs)))
          (local.set $path-len (array.len (local.get $path-arr)))
          (local.set $ext-len (array.len (local.get $ext-arr)))
          (if (i32.eqz (local.get $ext-len))
              (then (return (global.get $false))))
          (if (local.get $path-len)
              (then
               (if (i32.eq (array.get_u $I8Array
                                        (local.get $path-arr)
                                        (i32.sub (local.get $path-len) (i32.const 1)))
                           (i32.const 47))
                   (then (return (global.get $false))))))
          (local.set $elem-start (call $path-final-element-start (local.get $path-bs)))
          (local.set $elem-len (i32.sub (local.get $path-len) (local.get $elem-start)))
          (if (i32.ge_u (local.get $ext-len) (local.get $elem-len))
              (then (return (global.get $false))))
          (local.set $offset (i32.sub (local.get $path-len) (local.get $ext-len)))
          (local.set $i (i32.const 0))
          (block $done
                 (loop $loop
                       (br_if $done (i32.ge_u (local.get $i) (local.get $ext-len)))
                       (if (i32.ne
                            (array.get_u $I8Array
                                         (local.get $path-arr)
                                         (i32.add (local.get $offset) (local.get $i)))
                            (array.get_u $I8Array
                                         (local.get $ext-arr)
                                         (local.get $i)))
                           (then (return (global.get $false))))
                       (local.set $i (i32.add (local.get $i) (i32.const 1)))
                       (br $loop)))
          (global.get $true))

    ;; file-name-from-path : path-string? -> (or/c path? #f)
    ;;   Return the final path element, or #f for syntactic directories.
    (func $file-name-from-path (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string?
          (result          (ref eq))

          (local $path       (ref $Path))
          (local $path-bs    (ref $Bytes))
          (local $arr        (ref $I8Array))
          (local $len        i32)
          (local $elem-start i32)
          (local $elem-len   i32)

          (local.set $path
                     (call $path-string->path/checked
                           (global.get $symbol:file-name-from-path)
                           (local.get $path-raw)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $arr (struct.get $Bytes $bs (local.get $path-bs)))
          (local.set $len (array.len (local.get $arr)))
          (if (local.get $len)
              (then
               (if (i32.eq (array.get_u $I8Array
                                        (local.get $arr)
                                        (i32.sub (local.get $len) (i32.const 1)))
                           (i32.const 47))
                   (then (return (global.get $false))))))
          (local.set $elem-start (call $path-final-element-start (local.get $path-bs)))
          (local.set $elem-len (i32.sub (local.get $len) (local.get $elem-start)))
          (if (i32.eq (local.get $elem-len) (i32.const 1))
              (then
               (if (i32.eq (array.get_u $I8Array (local.get $arr) (local.get $elem-start))
                           (i32.const 46))
                   (then (return (global.get $false))))))
          (if (i32.eq (local.get $elem-len) (i32.const 2))
              (then
               (if (i32.and
                    (i32.eq (array.get_u $I8Array (local.get $arr) (local.get $elem-start))
                            (i32.const 46))
                    (i32.eq (array.get_u $I8Array
                                         (local.get $arr)
                                         (i32.add (local.get $elem-start) (i32.const 1)))
                            (i32.const 46)))
                   (then (return (global.get $false))))))
          (call $bytes->path
                (call $bytes-slice/unchecked
                      (local.get $path-bs)
                      (local.get $elem-start)
                      (local.get $len))
                (global.get $missing)))

    ;; split-path : (or/c path-string? path-for-some-system?) -> (values (or/c path-for-some-system? 'relative #f) (or/c path-for-some-system? 'up 'same) boolean?)
    ;;   Syntactically split a path into base, name, and must-be-directory? values.
    (func $split-path (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string? or path-for-some-system?
          (result          (ref eq))

          (local $path       (ref $Path))
          (local $path-bs    (ref $Bytes))
          (local $arr        (ref $I8Array))
          (local $conv       (ref eq))
          (local $base       (ref eq))
          (local $name       (ref eq))
          (local $dir?       (ref eq))
          (local $len        i32)
          (local $end        i32)
          (local $elem-start i32)
          (local $elem-len   i32)
          (local $i          i32)
          (local $idx        i32)

          (local.set $path (ref.cast (ref $Path) (global.get $current-directory-path)))
          (if (ref.test (ref $Path) (local.get $path-raw))
              (then
               (local.set $path (ref.cast (ref $Path) (local.get $path-raw))))
              (else
               (local.set $path
                          (call $path-string->path/checked
                                (global.get $symbol:split-path)
                                (local.get $path-raw)))))
          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $arr (struct.get $Bytes $bs (local.get $path-bs)))
          (local.set $len (array.len (local.get $arr)))
          (local.set $end (local.get $len))
          (local.set $dir? (global.get $false))
          (if (call $path-syntactic-directory? (local.get $path-bs) (local.get $conv))
              (then (local.set $dir? (global.get $true))))
          ;; Simple root path: base is #f and name is the root path.
          (if (i32.eq (local.get $len) (i32.const 1))
              (then
               (if (call $path-byte-separator?
                         (array.get_u $I8Array (local.get $arr) (i32.const 0))
                         (local.get $conv))
                   (then
                    (return (array.new_fixed $Values 3
                                              (global.get $false)
                                              (local.get $path)
                                              (global.get $true)))))))
          ;; Ignore one trailing separator when selecting the final element.
          (if (local.get $len)
              (then
               (if (call $path-byte-separator?
                         (array.get_u $I8Array
                                      (local.get $arr)
                                      (i32.sub (local.get $len) (i32.const 1)))
                         (local.get $conv))
                   (then (local.set $end (i32.sub (local.get $len) (i32.const 1)))))))
          (local.set $elem-start (i32.const 0))
          (local.set $i (local.get $end))
          (block $done
                 (loop $loop
                       (br_if $done (i32.eqz (local.get $i)))
                       (local.set $idx (i32.sub (local.get $i) (i32.const 1)))
                       (if (call $path-byte-separator?
                                 (array.get_u $I8Array (local.get $arr) (local.get $idx))
                                 (local.get $conv))
                           (then (local.set $elem-start (local.get $i))
                                 (br $done)))
                       (local.set $i (local.get $idx))
                       (br $loop)))
          (local.set $elem-len (i32.sub (local.get $end) (local.get $elem-start)))
          (local.set $base
                     (if (result (ref eq))
                         (i32.eqz (local.get $elem-start))
                         (then (global.get $symbol:relative))
                         (else
                          (call $bytes->path
                                (call $bytes-slice/unchecked
                                      (local.get $path-bs)
                                      (i32.const 0)
                                      (local.get $elem-start))
                                (local.get $conv)))))
          (local.set $name
                     (call $bytes->path
                           (call $bytes-slice/unchecked
                                 (local.get $path-bs)
                                 (local.get $elem-start)
                                 (local.get $end))
                           (local.get $conv)))
          (if (i32.eq (local.get $elem-len) (i32.const 1))
              (then
               (if (i32.eq (array.get_u $I8Array
                                        (local.get $arr)
                                        (local.get $elem-start))
                           (i32.const 46))
                   (then (local.set $name (global.get $symbol:same))))))
          (if (i32.eq (local.get $elem-len) (i32.const 2))
              (then
               (if (i32.and
                    (i32.eq (array.get_u $I8Array
                                         (local.get $arr)
                                         (local.get $elem-start))
                            (i32.const 46))
                    (i32.eq (array.get_u $I8Array
                                         (local.get $arr)
                                         (i32.add (local.get $elem-start) (i32.const 1)))
                            (i32.const 46)))
                   (then (local.set $name (global.get $symbol:up))))))
          (array.new_fixed $Values 3
                           (local.get $base)
                           (local.get $name)
                           (local.get $dir?)))

    ;; path-element? : any/c -> boolean?
    ;;   Recognize single-element path values for any represented path convention.
    ;; explode-path : (or/c path-string? path-for-some-system?) -> (listof (or/c path-for-some-system? 'up 'same))
    ;;   Return the non-empty syntactic path elements as a list.
    (func $explode-path (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string? or path-for-some-system?
          (result          (ref eq))

          (local $path       (ref $Path))
          (local $path-bs    (ref $Bytes))
          (local $arr        (ref $I8Array))
          (local $conv       (ref eq))
          (local $acc        (ref eq))
          (local $part       (ref eq))
          (local $len        i32)
          (local $start      i32)
          (local $i          i32)
          (local $part-len   i32)
          (local $b          i32)

          (local.set $path (ref.cast (ref $Path) (global.get $current-directory-path)))
          (local.set $acc (global.get $null))
          (if (ref.test (ref $Path) (local.get $path-raw))
              (then
               (local.set $path (ref.cast (ref $Path) (local.get $path-raw))))
              (else
               (local.set $path
                          (call $path-string->path/checked
                                (global.get $symbol:explode-path)
                                (local.get $path-raw)))))
          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $arr (struct.get $Bytes $bs (local.get $path-bs)))
          (local.set $len (array.len (local.get $arr)))
          (local.set $start (i32.const 0))
          (local.set $i (i32.const 0))
          (if (local.get $len)
              (then
               (if (call $path-byte-separator?
                         (array.get_u $I8Array (local.get $arr) (i32.const 0))
                         (local.get $conv))
                   (then
                    (local.set $acc
                               (struct.new $Pair
                                           (i32.const 0)
                                           (call $bytes->path
                                                 (call $bytes-slice/unchecked
                                                       (local.get $path-bs)
                                                       (i32.const 0)
                                                       (i32.const 1))
                                                 (local.get $conv))
                                           (local.get $acc)))
                    (local.set $start (i32.const 1))
                    (local.set $i (i32.const 1))))))
          (block $done
                 (loop $loop
                       (if (i32.lt_u (local.get $i) (local.get $len))
                           (then
                            (local.set $b (array.get_u $I8Array (local.get $arr) (local.get $i)))
                            (if (i32.eqz (call $path-byte-separator? (local.get $b) (local.get $conv)))
                                (then
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))))
                       (local.set $part-len (i32.sub (local.get $i) (local.get $start)))
                       (if (local.get $part-len)
                           (then
                            (local.set $part
                                       (call $bytes->path
                                             (call $bytes-slice/unchecked
                                                   (local.get $path-bs)
                                                   (local.get $start)
                                                   (local.get $i))
                                             (local.get $conv)))
                            (if (i32.eq (local.get $part-len) (i32.const 1))
                                (then
                                 (if (i32.eq (array.get_u $I8Array
                                                          (local.get $arr)
                                                          (local.get $start))
                                             (i32.const 46))
                                     (then (local.set $part (global.get $symbol:same))))))
                            (if (i32.eq (local.get $part-len) (i32.const 2))
                                (then
                                 (if (i32.and
                                      (i32.eq (array.get_u $I8Array
                                                           (local.get $arr)
                                                           (local.get $start))
                                              (i32.const 46))
                                      (i32.eq (array.get_u $I8Array
                                                           (local.get $arr)
                                                           (i32.add (local.get $start) (i32.const 1)))
                                              (i32.const 46)))
                                     (then (local.set $part (global.get $symbol:up))))))
                            (local.set $acc
                                       (struct.new $Pair
                                                   (i32.const 0)
                                                   (local.get $part)
                                                   (local.get $acc)))))
                       (if (i32.ge_u (local.get $i) (local.get $len))
                           (then (br $done)))
                       (local.set $i (i32.add (local.get $i) (i32.const 1)))
                       (local.set $start (local.get $i))
                       (br $loop)))
          (call $reverse (local.get $acc)))

    (func $path-element? (type $Prim1)
          (param $v (ref eq)) ;; any/c
          (result   (ref eq))

          (local $path      (ref $Path))
          (local $path-bs   (ref $Bytes))
          (local $arr       (ref $I8Array))
          (local $conv      (ref eq))
          (local $len       i32)
          (local $elem-len  i32)
          (local $i         i32)
          (local $b         i32)

          (if (i32.eqz (ref.test (ref $Path) (local.get $v)))
              (then (return (global.get $false))))
          (local.set $path (ref.cast (ref $Path) (local.get $v)))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (local.set $arr (struct.get $Bytes $bs (local.get $path-bs)))
          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (local.set $len (array.len (local.get $arr)))
          (local.set $elem-len (local.get $len))
          (if (i32.eqz (local.get $elem-len))
              (then (return (global.get $false))))
          (if (call $path-byte-separator?
                    (array.get_u $I8Array (local.get $arr) (i32.const 0))
                    (local.get $conv))
              (then (return (global.get $false))))
          (if (call $path-byte-separator?
                    (array.get_u $I8Array
                                 (local.get $arr)
                                 (i32.sub (local.get $elem-len) (i32.const 1)))
                    (local.get $conv))
              (then (local.set $elem-len
                               (i32.sub (local.get $elem-len) (i32.const 1)))))
          (if (i32.eqz (local.get $elem-len))
              (then (return (global.get $false))))
          (local.set $i (i32.const 0))
          (block $done
                 (loop $loop
                       (br_if $done (i32.ge_u (local.get $i) (local.get $elem-len)))
                       (local.set $b (array.get_u $I8Array (local.get $arr) (local.get $i)))
                       (if (call $path-byte-separator? (local.get $b) (local.get $conv))
                           (then (return (global.get $false))))
                       (local.set $i (i32.add (local.get $i) (i32.const 1)))
                       (br $loop)))
          (if (i32.eq (local.get $elem-len) (i32.const 1))
              (then
               (if (i32.eq (array.get_u $I8Array (local.get $arr) (i32.const 0))
                           (i32.const 46))
                   (then (return (global.get $false))))))
          (if (i32.eq (local.get $elem-len) (i32.const 2))
              (then
               (if (i32.and
                    (i32.eq (array.get_u $I8Array (local.get $arr) (i32.const 0))
                            (i32.const 46))
                    (i32.eq (array.get_u $I8Array (local.get $arr) (i32.const 1))
                            (i32.const 46)))
                   (then (return (global.get $false))))))
          (global.get $true))

    (func $path-element-trimmed-bytes/checked
          (param $who      (ref eq)) ;; symbol?
          (param $path-raw (ref eq)) ;; path-element?
          (result          (ref $Bytes))

          (local $path    (ref $Path))
          (local $bytes   (ref $Bytes))
          (local $arr     (ref $I8Array))
          (local $conv    (ref eq))
          (local $len     i32)
          (local $end     i32)

          (if (i32.eqz (ref.test (ref $Path) (local.get $path-raw)))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:path-element?)
                          (local.get $path-raw))
                    (unreachable)))
          (if (i32.eqz (ref.eq (call $path-element? (local.get $path-raw))
                               (global.get $true)))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:path-element?)
                          (local.get $path-raw))
                    (unreachable)))
          (local.set $path (ref.cast (ref $Path) (local.get $path-raw)))
          (local.set $bytes (struct.get $Path $bytes (local.get $path)))
          (local.set $arr (struct.get $Bytes $bs (local.get $bytes)))
          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (local.set $len (array.len (local.get $arr)))
          (local.set $end (local.get $len))
          (if (call $path-byte-separator?
                    (array.get_u $I8Array
                                 (local.get $arr)
                                 (i32.sub (local.get $len) (i32.const 1)))
                    (local.get $conv))
              (then (local.set $end (i32.sub (local.get $len) (i32.const 1)))))
          (call $bytes-slice/unchecked
                (local.get $bytes)
                (i32.const 0)
                (local.get $end)))

    ;; path-element->bytes : path-element? -> bytes?
    ;;   Convert a path element to bytes, without a trailing separator.
    (func $path-element->bytes (type $Prim1)
          (param $path-raw (ref eq)) ;; path-element?
          (result          (ref eq)) ;; bytes?

          (call $path-element-trimmed-bytes/checked
                (global.get $symbol:path-element->bytes)
                (local.get $path-raw)))

    ;; path-element->string : path-element? -> string?
    ;;   Convert a path element to a UTF-8 string, without a trailing separator.
    (func $path-element->string (type $Prim1)
          (param $path-raw (ref eq)) ;; path-element?
          (result          (ref eq)) ;; string?

          (call $bytes->string/utf-8/checked
                (call $path-element-trimmed-bytes/checked
                      (global.get $symbol:path-element->string)
                      (local.get $path-raw))))

    ;; path-only : path-string? -> (or/c path? #f)
    ;;   Return a path without its final element, or #f for single non-directory elements.
    (func $path-only (type $Prim1)
          (param $path-raw (ref eq)) ;; path-string? or path-for-some-system?
          (result          (ref eq))

          (local $path       (ref $Path))
          (local $path-bs    (ref $Bytes))
          (local $conv       (ref eq))
          (local $elem-start i32)

          (local.set $path (ref.cast (ref $Path) (global.get $current-directory-path)))
          (local.set $conv (global.get $system-path-convention))
          (if (ref.test (ref $Path) (local.get $path-raw))
              (then
               (local.set $path (ref.cast (ref $Path) (local.get $path-raw)))
               (local.set $conv (struct.get $Path $convention (local.get $path))))
              (else
               (if (i32.eqz (ref.test (ref $String) (local.get $path-raw)))
                   (then (call $raise-path-string-expected/who
                               (global.get $symbol:path-only)
                               (local.get $path-raw))
                         (unreachable)))
               (if (i32.eqz (ref.eq (call $non-empty-string-without-nuls
                                          (ref.cast (ref $String) (local.get $path-raw)))
                                    (global.get $true)))
                   (then (call $raise-path-string-expected/who
                               (global.get $symbol:path-only)
                               (local.get $path-raw))
                         (unreachable)))
               (local.set $path
                          (ref.cast (ref $Path)
                                    (call $string->path
                                          (ref.cast (ref $String) (local.get $path-raw)))))
               (local.set $conv (global.get $system-path-convention))))
          (local.set $path-bs (struct.get $Path $bytes (local.get $path)))
          (if (call $path-syntactic-directory?
                    (local.get $path-bs)
                    (local.get $conv))
              (then (return (local.get $path))))
          (local.set $elem-start
                     (call $path-final-element-start/convention
                           (local.get $path-bs)
                           (local.get $conv)))
          (if (i32.eqz (local.get $elem-start))
              (then (return (global.get $false))))
          (call $bytes->path
                (call $bytes-slice/unchecked
                      (local.get $path-bs)
                      (i32.const 0)
                      (local.get $elem-start))
                (local.get $conv)))))

;; path-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate basic and path manipulation helpers used by the monolithic runtime.
(define path-all-runtime-helpers
  (function-forms->runtime-helpers
   'path-all-runtime-helpers
   path-runtime-only-forms))

;; path-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate path helpers available in the standalone core runtime.
(define path-core-runtime-helpers
  (select-runtime-helpers
   path-all-runtime-helpers
   (append path-promoted-runtime-helper-names
           path-manipulation-promoted-runtime-helper-names)))

;; path-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate path helpers that still depend on monolithic runtime definitions.
(define path-runtime-only-helpers
  (remove-runtime-helpers
   path-all-runtime-helpers
   (append path-promoted-runtime-helper-names
           path-manipulation-promoted-runtime-helper-names)))

;; path-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given path helper names from the runtime helper index.
(define (path-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; path-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render basic path helpers in runtime assembly order.
(define (path-runtime-helper-forms helper-index)
  (path-helper-forms helper-index path-runtime-only-helper-names))

;; path-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted basic path helpers in runtime assembly order.
(define (path-core-runtime-helper-forms helper-index)
  (path-helper-forms helper-index path-promoted-runtime-helper-names))

;; path-manipulation-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render path manipulation helpers in runtime assembly order.
(define (path-manipulation-runtime-helper-forms helper-index)
  (path-helper-forms helper-index path-manipulation-runtime-only-helper-names))

;; path-manipulation-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted path manipulation helpers in runtime assembly order.
(define (path-manipulation-core-runtime-helper-forms helper-index)
  (path-helper-forms helper-index path-manipulation-promoted-runtime-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (check-equal?
   (map form-name path-display-formatting-runtime-only-forms)
   '($format/display:path))

  (define path-helper-index
    (make-core-runtime-helper-index
     (append path-core-runtime-helpers
             path-runtime-only-helpers)))

  (define path-core-helper-index
    (make-core-runtime-helper-index path-core-runtime-helpers))

  (check-equal? path-current-global-names
                '($system-path-convention
                  $current-directory-path
                  $current-directory-for-user-path
                  $current-load-relative-directory-path))

  (check-equal?
   (map core-runtime-helper-name path-core-runtime-helpers)
   (append path-promoted-runtime-helper-names
           path-manipulation-promoted-runtime-helper-names))

  (check-equal?
   (map form-name (path-core-runtime-helper-forms path-core-helper-index))
   path-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (path-manipulation-core-runtime-helper-forms path-core-helper-index))
   path-manipulation-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (path-runtime-helper-forms path-helper-index))
   path-runtime-only-helper-names)

  (check-equal?
   (map form-name (path-manipulation-runtime-helper-forms path-helper-index))
   path-manipulation-runtime-only-helper-names))
