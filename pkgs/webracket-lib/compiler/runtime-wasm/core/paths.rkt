#lang racket

(provide path-runtime-only-helpers
         path-runtime-only-helper-names)

(require "../core-helper.rkt")

;; path-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for basic path helpers.
(define path-runtime-only-helper-names
  '($raise-path-expected
    $path?
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
    $raise-bytes->path:bad-type
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

;; path-runtime-only-forms : (listof datum?)
;;   Enumerate basic path helpers used by the monolithic runtime.
(define path-runtime-only-forms
  '(
    (func $raise-path-expected (param $x (ref eq))
          (call $js-log (local.get $x))
          (unreachable))

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
              (then (call $raise-path-expected (local.get $path-raw))
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
              (then (call $raise-path-expected (local.get $path-raw))
                    (unreachable)))

          (local.set $path (ref.cast (ref $Path) (local.get $path-raw)))
          (local.set $conv (struct.get $Path $convention (local.get $path)))
          (if (i32.eqz (ref.eq (local.get $conv) (global.get $system-path-convention)))
              (then (call $raise-path-expected (local.get $path-raw))
                    (unreachable)))

          (local.set $bytes (struct.get $Path $bytes (local.get $path)))
          (call $bytes->string/utf-8/checked (local.get $bytes)))

    (func $path->bytes/current/checked
          (param $who      (ref eq)) ;; symbol?
          (param $path-raw (ref eq)) ;; path?
          (result          (ref $Bytes))

          (local $path (ref $Path))

          (if (i32.eqz (ref.test (ref $Path) (local.get $path-raw)))
              (then (call $raise-path-expected (local.get $path-raw))
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
              (then (call $raise-path-expected (local.get $path-raw))
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

    (func $raise-bytes->path:nul (param $bstr (ref eq))
          (call $js-log (local.get $bstr))
          (unreachable))

    (func $raise-bytes->path:bad-type (param $type (ref eq))
          (call $js-log (local.get $type))
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
              (then (call $raise-check-bytes (local.get $bstr-raw))
                    (unreachable)))
          (local.set $input-bytes (ref.cast (ref $Bytes) (local.get $bstr-raw)))
          ;; Reject byte strings that are empty or contain a NUL byte.
          (if (i32.eqz (ref.eq (call $non-empty-bytes-without-nuls (local.get $input-bytes))
                               (global.get $true)))
              (then (call $raise-bytes->path:nul (local.get $bstr-raw))
                    (unreachable)))
          ;; Normalize to an immutable byte string for storage.
          (local.set $bytes (ref.cast (ref $Bytes)
                                      (call $bytes->immutable-bytes (local.get $bstr-raw))))
          ;; Determine the path convention symbol.
          (if (ref.eq (local.get $type-raw) (global.get $missing))
              (then (nop)) ; the default is system path convention
              (else (if (i32.eqz (ref.test (ref $Symbol) (local.get $type-raw)))
                        (then (call $raise-check-symbol (local.get $type-raw)) (unreachable)))

                    (local.set $type (ref.cast (ref $Symbol) (local.get $type-raw)))
                    (if (i32.eqz (ref.eq (call $unix-or-windows (local.get $type))
                                         (global.get $true)))
                        (then (call $raise-bytes->path:bad-type (local.get $type-raw)) (unreachable)))
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
              (then (call $raise-check-string (local.get $str-raw))
                    (unreachable)))
          (local.set $str (ref.cast (ref $String) (local.get $str-raw)))
          (if (i32.eqz (ref.eq (call $non-empty-string-without-nuls (local.get $str))
                               (global.get $true)))
              (then (call $raise-path-expected (local.get $str-raw))
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
              (then (call $raise-check-string (local.get $str-raw))
                    (unreachable)))
          (if (ref.eq (local.get $false-on-non-element?) (global.get $missing))
              (then (local.set $false-on-non-element? (global.get $false))))
          (local.set $str (ref.cast (ref $String) (local.get $str-raw)))
          (if (i32.eqz (ref.eq (call $non-empty-string-without-nuls (local.get $str))
                               (global.get $true)))
              (then
               (if (ref.eq (local.get $false-on-non-element?) (global.get $false))
                   (then (call $raise-argument-error1
                               (global.get $symbol:string->path-element)
                               (global.get $string:path-element?)
                               (local.get $str-raw))
                         (unreachable))
                   (else (return (global.get $false))))))
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
              (then (call $raise-check-bytes (local.get $bstr-raw))
                    (unreachable)))
          (if (ref.eq (local.get $false-on-non-element?) (global.get $missing))
              (then (local.set $false-on-non-element? (global.get $false))))
          (local.set $bytes (ref.cast (ref $Bytes) (local.get $bstr-raw)))
          (if (i32.eqz (ref.eq (call $non-empty-bytes-without-nuls (local.get $bytes))
                               (global.get $true)))
              (then
               (if (ref.eq (local.get $false-on-non-element?) (global.get $false))
                   (then (call $raise-argument-error1
                               (global.get $symbol:bytes->path-element)
                               (global.get $string:path-element?)
                               (local.get $bstr-raw))
                         (unreachable))
                   (else (return (global.get $false))))))
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
              (then (call $raise-check-string (local.get $str-raw))
                    (unreachable)))
          (if (i32.eqz (ref.test (ref $Symbol) (local.get $kind-raw)))
              (then (call $raise-check-symbol (local.get $kind-raw))
                    (unreachable)))
          (local.set $str (ref.cast (ref $String) (local.get $str-raw)))
          (local.set $kind (ref.cast (ref $Symbol) (local.get $kind-raw)))
          (if (i32.eqz (ref.eq (call $non-empty-string-without-nuls (local.get $str))
                               (global.get $true)))
              (then (call $raise-path-expected (local.get $str-raw))
                    (unreachable)))
          (if (i32.eqz (ref.eq (call $unix-or-windows (local.get $kind))
                               (global.get $true)))
              (then (call $raise-bytes->path:bad-type (local.get $kind-raw))
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
                   (then (call $raise-path-expected (local.get $path-raw))
                         (unreachable)))
               (return (local.get $path))))

          (if (i32.eqz (ref.test (ref $String) (local.get $path-raw)))
              (then (call $raise-path-expected (local.get $path-raw))
                    (unreachable)))
          (local.set $str (ref.cast (ref $String) (local.get $path-raw)))
          (if (i32.eqz (ref.eq (call $non-empty-string-without-nuls (local.get $str))
                               (global.get $true)))
              (then (call $raise-path-expected (local.get $path-raw))
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
              (then (call $raise-path-expected (local.get $rel-raw))
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
              (then (call $raise-path-expected (local.get $part-raw))
                    (unreachable)))
          (local.set $str (ref.cast (ref $String) (local.get $part-raw)))
          (if (i32.eqz (ref.eq (call $non-empty-string-without-nuls (local.get $str))
                               (global.get $true)))
              (then (call $raise-path-expected (local.get $part-raw))
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
              (then (call $raise-path-expected (local.get $rel-raw))
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
              (then (call $raise-check-symbol (local.get $type-raw))
                    (unreachable)))
          (local.set $type (ref.cast (ref $Symbol) (local.get $type-raw)))
          (if (i32.eqz (ref.eq (call $unix-or-windows (local.get $type))
                               (global.get $true)))
              (then (call $raise-bytes->path:bad-type (local.get $type-raw))
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
                (global.get $missing)))))

;; path-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate basic path helpers used by the monolithic runtime.
(define path-runtime-only-helpers
  (function-forms->runtime-helpers
   'path-runtime-only-helpers
   path-runtime-only-forms))
