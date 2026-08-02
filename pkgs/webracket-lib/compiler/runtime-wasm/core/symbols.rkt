#lang racket

(provide symbol-runtime-string-constants
         symbol-core-runtime-helpers
         symbol-runtime-only-helpers
         symbol-public-runtime-only-helper-names
         symbol-public-runtime-helper-forms
         symbol-gensym-runtime-only-helper-names
         symbol-gensym-core-runtime-helper-forms
         symbol-gensym-runtime-helper-forms
         symbol-gensym-global-forms
         symbol-gensym-global-names
         symbol-table-global-forms
         symbol-table-core-runtime-helper-forms
         core-runtime-symbol-constant-converter-name
         core-runtime-symbol-constant-converter-form
         symbol-table-initializer-runtime-only-helper-names
         symbol-table-initializer-runtime-helper-forms
         symbol-table-runtime-helper-forms
         symbol-table-runtime-only-helper-names)

(require "../core-helper.rkt"
         "../../private/wasm-utils.rkt")

;; symbol-global-form-name : datum? -> symbol?
;;   Return the Wasm global name declared by a symbol support global form.
(define (symbol-global-form-name form)
  (match form
    [`(global ,name . ,_) name]
    [_ (error 'symbol-global-form-name
              "expected global form, got: ~s"
              form)]))

;; symbol-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by symbol helpers and symbol contract checks.
(define symbol-runtime-string-constants
  '((symbol? "symbol?")
    (symbol-or-string? "(or/c symbol? string?)")
    (symbol-table-full "WebRacket symbol table insertion failed")
    (g       "g")))

;; symbol-table-global-forms : (listof datum?)
;;   Declare the global symbol interning table.
(define symbol-table-global-forms
  '(
         ;; The symbol table from strings to symbols.
         ;; Used to intern symbols.
         (global $the-symbol-table (mut (ref null $SymbolTable)) (ref.null $SymbolTable))))

;; symbol-gensym-global-forms : (listof datum?)
;;   Declare global state for generated uninterned symbols.
(define symbol-gensym-global-forms
  '(
         (global $gensym-counter (mut i32) (i32.const 0))))

;; symbol-gensym-global-names : (listof symbol?)
;;   Enumerate gensym globals shared by split modules.
(define symbol-gensym-global-names
  (map symbol-global-form-name symbol-gensym-global-forms))

;; symbol-table-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for symbol table helpers.
(define symbol-table-runtime-only-helper-names
  '($make-symbol-table
    $symbol-table-find
    $raise-symbol-table-insert:table-full
    $symbol-table-insert
    $symbol-table-resize
    $maybe-resize-symbol-table))

;; symbol-table-initializer-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for symbol table initializer helpers.
(define symbol-table-initializer-runtime-only-helper-names
  '($initialize-the-symbol-table))

;; symbol-table-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate symbol table helpers used by the monolithic runtime.
(define symbol-table-runtime-only-helpers
  (function-forms->runtime-helpers
   'symbol-table-runtime-only-helpers
   '(
     (func $make-symbol-table (result (ref $SymbolTable))
           (local $entries  (ref $Array))
           ;; Initial capacity is 16, so total entries = 2 * 16 = 32
           (local.set $entries
                      (array.new $Array (global.get $missing) (i32.const 1024))) ; todo: was 32 - was 1024
           (struct.new $SymbolTable
                       (local.get $entries)  ;; $entries
                       (i32.const 0)))       ;; $count

     (func $symbol-table-find ; returns $missing for "not found"
           (param $table (ref $SymbolTable))
           (param $key   (ref $String))
           (result       (ref eq))

           (local $entries  (ref $Array))
           (local $capacity i32)
           (local $hash     i32)
           (local $index    i32)
           (local $step     i32)
           (local $slot     i32)
           (local $k        (ref eq))
           ;; Get the entries array and capacity
           (local.set $entries  (struct.get $SymbolTable $entries (local.get $table)))
           (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
           ;; Compute hash and initial index
           (local.set $hash  (call $string-hash/i32 (local.get $key)))
           (local.set $index (i32.rem_u (local.get $hash) (local.get $capacity)))
           (local.set $step  (i32.const 0))

           (block $not-found
                  (loop $probe
                        ;; Stop probing if we've gone through every slot
                        (br_if $not-found (i32.ge_u (local.get $step) (local.get $capacity)))
                        ;; Compute probe slot: (index + step) % capacity
                        (local.set $slot (i32.rem_u (i32.add (local.get $index) (local.get $step))
                                                    (local.get $capacity)))
                        ;; Load key at 2 * slot
                        (local.set $k
                                   (array.get $Array
                                              (local.get $entries)
                                              (i32.shl (local.get $slot) (i32.const 1))))
                        ;; If slot is unused, stop
                        (br_if $not-found
                               (ref.eq (local.get $k) (global.get $missing)))
                        ;; If match, return value at index + 1
                        (if #;(or (ref.eq (local.get $k) (local.get $key))
                                  (call $string=?/i32 (local.get $k) (local.get $key)))
                            (call $string=?/i32 (local.get $k) (local.get $key))
                            (then
                             (return ; returns value at slot 2*slot+1.
                              (array.get $Array
                                         (local.get $entries)
                                         (i32.add (i32.shl (local.get $slot) (i32.const 1))
                                                  (i32.const 1))))))
                        ;; Try next slot
                        (local.set $step (i32.add (local.get $step) (i32.const 1)))
                        (br $probe)))
           ;; Not found
           (global.get $missing))

     (func $raise-symbol-table-insert:table-full
           (drop (call $raise
                       (call $make-exn:fail:out-of-memory
                             (global.get $string:symbol-table-full)
                             (call $current-continuation-marks
                                   (global.get $missing)))
                       (global.get $true)))
           (unreachable))

     (func $symbol-table-insert
           (param $table (ref $SymbolTable))
           (param $key   (ref $String))  ;; must be interned or immutable
           (param $val   (ref eq))

           (local $entries  (ref $Array))
           (local $capacity i32)
           (local $hash     i32)
           (local $index    i32)
           (local $step     i32)
           (local $k        (ref eq))
           (local $slot     i32)
           ;; Possibly resize before inserting
           (local.set $table    (call $maybe-resize-symbol-table (local.get $table)))
           ;; Get updated entries array and capacity
           (local.set $entries  (struct.get $SymbolTable $entries (local.get $table)))
           (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
           ;; Compute hash and initial index
           (local.set $hash     (call $string-hash/i32 (local.get $key))) ;
           (local.set $index    (i32.rem_u (local.get $hash) (local.get $capacity)))
           (local.set $step     (i32.const 0))

           (block $done
                  (block $full
                         (loop $probe
                               ;; Stop if probing exceeds capacity (should never happen if resize worked)
                               (br_if $full (i32.ge_u (local.get $step) (local.get $capacity)))
                               ;; Compute probe index and actual slot (2 * index)
                               (local.set $slot (i32.shl (i32.rem_u (i32.add (local.get $index) (local.get $step))
                                                                    (local.get $capacity))
                                                         (i32.const 1))) ;; multiply by 2
                               ;; Load key from slot
                               (local.set $k (array.get $Array (local.get $entries) (local.get $slot)))
                               ;; Empty slot - insert
                               (if (ref.eq (local.get $k) (global.get $missing))
                                   (then
                                    (array.set $Array (local.get $entries) (local.get $slot) (local.get $key))
                                    (array.set $Array (local.get $entries)
                                               (i32.add (local.get $slot) (i32.const 1))
                                               (local.get $val))
                                    (struct.set $SymbolTable $count
                                                (local.get $table)
                                                (i32.add (struct.get $SymbolTable $count (local.get $table)) (i32.const 1)))
                                    (br $done)))
                               ;; Key match - update value
                               (if (call $string=?/i32 (local.get $k) (local.get $key))
                                   (then (array.set $Array (local.get $entries)
                                                    (i32.add (local.get $slot) (i32.const 1))
                                                    (local.get $val))
                                         (br $done)))
                               ;; Otherwise, try next probe
                               (local.set $step (i32.add (local.get $step) (i32.const 1)))
                               (br $probe)))
                  ;; Failed to insert - table full (should not happen if resizing is correct)
                  (call $raise-symbol-table-insert:table-full)))

     (func $symbol-table-resize
           (param $table (ref $SymbolTable))
           (result (ref $SymbolTable))

           (local $old-entries (ref $Array))
           (local $old-cap     i32)
           (local $new-cap     i32)
           (local $new-array   (ref $Array))
           (local $new-table   (ref $SymbolTable))
           (local $i           i32)
           (local $len         i32)
           (local $key         (ref eq))
           (local $val         (ref eq))

           ;; Get old table size and entries
           (local.set $old-entries (struct.get $SymbolTable $entries (local.get $table)))
           (local.set $old-cap     (i32.div_u (array.len (local.get $old-entries)) (i32.const 2)))
           (local.set $new-cap     (i32.mul (local.get $old-cap) (i32.const 2)))
           ;; Allocate new entries array with (2 * new-capacity) slots filled with $missing
           (local.set $new-array (array.new $Array (global.get $missing)
                                            (i32.mul (local.get $new-cap) (i32.const 2))))
           ;; Create new empty table with count = 0
           (local.set $new-table (struct.new $SymbolTable (local.get $new-array) (i32.const 0)))
           ;; Reinsert old entries
           (local.set $i (i32.const 0))
           (local.set $len (array.len (local.get $old-entries)))
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                        ;; Get key and value
                        (local.set $key (array.get $Array (local.get $old-entries) (local.get $i)))
                        (local.set $val (array.get $Array (local.get $old-entries) (i32.add (local.get $i) (i32.const 1))))
                        ;; Insert if key is not $missing (i.e. dummy)
                        (if (ref.test (ref $String) (local.get $key))
                            (then (call $symbol-table-insert
                                        (local.get $new-table)
                                        (ref.cast (ref $String) (local.get $key))
                                        (local.get $val))))
                        ;; Step to next pair
                        (local.set $i (i32.add (local.get $i) (i32.const 2)))
                        (br $loop)))
           ; Store changes in the original table
           (struct.set $SymbolTable $entries (local.get $table) (local.get $new-array))
           (struct.set $SymbolTable $count   (local.get $table) (struct.get $SymbolTable $count
                                                                            (local.get $new-table)))
           (local.get $table))

     (func $maybe-resize-symbol-table
           (param $table    (ref $SymbolTable))
           (result          (ref $SymbolTable))

           (local $entries  (ref $Array))
           (local $capacity i32)
           (local $count    i32)
           ;; Get fields
           (local.set $entries  (struct.get $SymbolTable $entries (local.get $table)))
           (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
           (local.set $count    (struct.get $SymbolTable $count (local.get $table)))
           ;; Resize if count >= capacity / 2
           (if (i32.ge_u (local.get $count)
                         (i32.shr_u (local.get $capacity) (i32.const 1)))
               (then (return (call $symbol-table-resize (local.get $table)))))
           ;; Otherwise return unchanged
           (local.get $table)))))

;; symbol-table-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate symbol table helpers available to the standalone core runtime.
(define symbol-table-core-runtime-helpers
  (append
   (select-runtime-helpers symbol-table-runtime-only-helpers
                           '($make-symbol-table
                             $symbol-table-find))
   (list
    (core-runtime-helper
     '$raise-symbol-table-insert:table-full
     "$raise-symbol-table-insert:table-full"
     (lambda ()
       '(func $raise-symbol-table-insert:table-full
              (unreachable)))))
   (select-runtime-helpers symbol-table-runtime-only-helpers
                           '($symbol-table-insert
                             $symbol-table-resize
                             $maybe-resize-symbol-table))))

;; symbol-table-initializer-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate symbol table initializer helpers used by the monolithic runtime.
(define symbol-table-initializer-runtime-only-helpers
  (function-forms->runtime-helpers
   'symbol-table-initializer-runtime-only-helpers
   '(
     (func $initialize-the-symbol-table
           (if (ref.is_null (global.get $the-symbol-table))
               (then (global.set $the-symbol-table (call $make-symbol-table))))))))

;; core-runtime-symbol-constant-converter-name : symbol?
;;   Name the private core helper used to intern runtime-owned symbol constants.
(define core-runtime-symbol-constant-converter-name
  '$core-runtime-string->symbol/checked)

;; core-runtime-symbol-constant-converter-form : datum?
;;   Intern an immutable string in the core symbol table without public argument checks.
(define core-runtime-symbol-constant-converter-form
  '(func $core-runtime-string->symbol/checked
         (param $str (ref $String))
         (result     (ref $Symbol))

         (local $existing (ref eq))
         (local $sym      (ref $Symbol))

         (local.set $existing (call $symbol-table-find
                                    (ref.as_non_null (global.get $the-symbol-table))
                                    (local.get $str)))
         (if (ref.test (ref $Symbol) (local.get $existing))
             (then (return (ref.cast (ref $Symbol) (local.get $existing)))))
         (local.set $sym (struct.new $Symbol
                                     (i32.const 0)
                                     (local.get $str)
                                     (i32.const 0)
                                     (global.get $null)))
         (call $symbol-table-insert
               (ref.as_non_null (global.get $the-symbol-table))
               (local.get $str)
               (local.get $sym))
         (local.get $sym)))

;; symbol-table-core-runtime-helper-forms : -> (listof datum?)
;;   Render private symbol table helpers for the standalone core runtime.
(define (symbol-table-core-runtime-helper-forms)
  (core-runtime-helper-forms
   (append symbol-table-core-runtime-helpers
           symbol-table-initializer-runtime-only-helpers)))

;; symbol-public-runtime-only-forms : (listof datum?)
;;   Enumerate public symbol helpers used by the monolithic runtime.
(define symbol-public-runtime-only-forms
  `(
         ;;;
         ;;; 4.7 SYMBOLS
         ;;;

         ;; https://docs.racket-lang.org/reference/symbols.html

         ;; (type $Symbol
         ;;       (sub $Heap
         ;;            (struct
         ;;              (field $hash          (mut i32))         ;; cached hash
         ;;              (field $name          (ref $String))     ;; symbol name (string)
         ;;              (field $unreadable?   i32)                ;; unreadable symbol marker
         ;;              (field $property-list (mut (ref eq))))))  ;; user-defined properties


         (func $symbol? (type $Prim1) (param $x (ref eq)) (result (ref eq))
               (if (result (ref eq)) (ref.test (ref $Symbol) (local.get $x))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $raise-symbol-expected/who
               (param $who (ref eq))
               (param $x   (ref eq))
               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:symbol?)
                     (local.get $x))
               (unreachable))

         (func $raise-string-expected/who
               (param $who (ref eq))
               (param $x   (ref eq))
               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:string?)
                     (local.get $x))
               (unreachable))

         (func $symbol=? (type $Prim2)
               (param $a (ref eq)) (param $b (ref eq))
               (result (ref eq))
               (if (i32.eqz (ref.test (ref $Symbol) (local.get $a)))
                   (then (call $raise-symbol-expected/who
                               (global.get $symbol:symbol=?)
                               (local.get $a))
                         (unreachable)))
               (if (i32.eqz (ref.test (ref $Symbol) (local.get $b)))
                   (then (call $raise-symbol-expected/who
                               (global.get $symbol:symbol=?)
                               (local.get $b))
                         (unreachable)))
               (if (result (ref eq))
                   (ref.eq (local.get $a) (local.get $b))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $symbol=?/i32 (param $a (ref eq)) (param $b (ref eq)) (result i32)
               (ref.eq (local.get $a) (local.get $b)))


         (func $raise-symbol->string:bad-argument (param $v (ref eq))
               (call $raise-symbol-expected/who
                     (global.get $symbol:symbol->string)
                     (local.get $v)))

         (func $symbol->string (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (local $sym (ref $Symbol))
               (local $name (ref $String))

               ;; Check that input is a symbol
               (if (ref.test (ref $Symbol) (local.get $v))
                   (then
                    ;; Cast to $Symbol
                    (local.set $sym (ref.cast (ref $Symbol) (local.get $v)))
                    ;; Extract name field
                    (local.set $name (struct.get $Symbol $name (local.get $sym)))
                    ;; Return a fresh mutable copy
                    (return (call $string-copy (local.get $name))))
                   (else
                    ;; Not a symbol, raise error
                    (call $raise-symbol->string:bad-argument (local.get $v))))
               (unreachable))


         (func $symbol->immutable-string (type $Prim1)
               (param  $v (ref eq))
               (result (ref eq))

               (local $sym  (ref $Symbol))
               (local $name (ref $String))
               (local $src  (ref $I32Array))
               (local $dst  (ref $I32Array))
               (local $len  i32)

               (if (ref.test (ref $Symbol) (local.get $v))
                   (then
                    (local.set $sym  (ref.cast (ref $Symbol) (local.get $v)))
                    (local.set $name (struct.get $Symbol $name (local.get $sym)))
                    ;; Already immutable? Return as-is.
                    (if (i32.eq (struct.get $String $immutable (local.get $name)) (i32.const 1))
                        (then (return (local.get $name)))
                        (else
                         ;; Copy codepoints with i32array-copy [0, len)
                         (local.set $src (struct.get $String $codepoints (local.get $name)))
                         (local.set $len (array.len (local.get $src)))
                         (local.set $dst (call $i32array-copy
                                               (local.get $src) (i32.const 0) (local.get $len)))
                         ;; Build fresh immutable string (hash=0, immutable=1)
                         (return
                          (struct.new $String (i32.const 0) (i32.const 1) (local.get $dst))))))
                   (else
                    (call $raise-symbol-expected/who
                          (global.get $symbol:symbol->immutable-string)
                          (local.get $v))
                    (unreachable)))
               (unreachable))


         (func $raise-string->symbol:bad-argument
               (param $v (ref eq))
               (call $raise-string-expected/who
                     (global.get $symbol:string->symbol)
                     (local.get $v)))

         (func $string->symbol (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))  ; An (ref $Symbol)

               (if (ref.test (ref $String) (local.get $v))
                   (then (return
                          (call $string->symbol/checked
                                (ref.cast (ref $String) (local.get $v)))))
                   (else (call $raise-string->symbol:bad-argument (local.get $v))))
               (unreachable))

         (func $string->symbol/checked
               (param $str (ref $String))
               (result     (ref $Symbol))

               (local $existing (ref eq))
               (local $sym      (ref $Symbol))
               ;; Look up the string in the symbol table
               (local.set $existing (call $symbol-table-find
                                          (ref.as_non_null (global.get $the-symbol-table))
                                          (local.get $str)))
               ;; If found, return it (cast to (ref $Symbol))
               (if (ref.test (ref $Symbol) (local.get $existing))
                   (then (return (ref.cast (ref $Symbol) (local.get $existing)))))
               ;; Otherwise, construct a new interned symbol
               (local.set $sym (struct.new $Symbol
                                           (i32.const 0)        ;; hash = 0 (not computed)
                                           (local.get $str)     ;; name
                                           (i32.const 0)        ;; interned symbols are readable
                                           (global.get $null))) ;; empty property list
               ;; Insert it into the symbol table
               (call $symbol-table-insert
                     (ref.as_non_null (global.get $the-symbol-table))
                     (local.get $str)
                     (local.get $sym))
               ;; Return the new symbol
               (local.get $sym))

         (func $raise-string->uninterned-symbol:bad-argument
               (param $v (ref eq))
               (call $raise-string-expected/who
                     (global.get $symbol:string->uninterned-symbol)
                     (local.get $v)))

         (func $string->uninterned-symbol (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq)) ; An (ref $Symbol)

               (if (ref.test (ref $String) (local.get $v))
                   (then (return
                          (call $string->uninterned-symbol/checked
                                (ref.cast (ref $String) (local.get $v)))))
                   (else (call $raise-string->uninterned-symbol:bad-argument (local.get $v))))
               (unreachable))

         (func $string->uninterned-symbol/checked
               (param $str (ref $String))
               (result     (ref $Symbol))

               (struct.new $Symbol
                           (i32.const 0)            ;; hash = 0 (deferred)
                           (local.get $str)         ;; name
                           (i32.const 0)            ;; readable, but not interned
                           (global.get $null)))     ;; empty property list

         ;; string->unreadable-symbol : string? -> symbol?
         ;;   Create a non-interned symbol marked as unreadable.
         (func $string->unreadable-symbol (type $Prim1)
               (param $v (ref eq)) ;; source string
               (result   (ref eq))
               (if (ref.test (ref $String) (local.get $v))
                   (then (return
                          (struct.new $Symbol
                                      (i32.const 0)
                                      (ref.cast (ref $String) (local.get $v))
                                      (i32.const 1)
                                      (global.get $null)))))
               (call $raise-string-expected/who
                     (global.get $symbol:string->unreadable-symbol)
                     (local.get $v))
               (unreachable))

         (func $symbol-interned? (type $Prim1)
               (param $sym (ref eq))
               (result     (ref eq))

               (local $str   (ref $String))
               (local $found (ref eq))

               ;; Check that it's a symbol
               (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
                   (then (call $raise-symbol-expected/who
                               (global.get $symbol:symbol-interned?)
                               (local.get $sym))))
               (local.set $str   (struct.get $Symbol $name (ref.cast (ref $Symbol)   (local.get $sym))))
               (local.set $found (call $symbol-table-find
                                       (ref.as_non_null (global.get $the-symbol-table)) (local.get $str)))
               ;; If found symbol == input symbol => interned
               (if (result (ref eq)) (ref.eq (local.get $found) (local.get $sym))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $symbol-unreadable? (type $Prim1)
               (param $sym (ref eq))
               (result     (ref eq))

               (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
                   (then (call $raise-symbol-expected/who
                               (global.get $symbol:symbol-unreadable?)
                               (local.get $sym))))
               (if (result (ref eq))
                   (struct.get $Symbol $unreadable?
                               (ref.cast (ref $Symbol) (local.get $sym)))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $symbol<? (type $Prim>=1)
               (param $a    (ref eq))
               (param $rest (ref eq))
               (result      (ref eq))

               (local $prev-str  (ref $String))
               (local $curr-str  (ref $String))
               (local $rest-list (ref eq))
               (local $pair      (ref $Pair))
               (local $next      (ref eq))

               ;; Type check: the first argument must be a symbol
               (if (i32.eqz (ref.test (ref $Symbol) (local.get $a)))
                   (then (call $raise-symbol-expected/who
                               (global.get $symbol:symbol<?)
                               (local.get $a))))

               ;; Extract the name of the first symbol and prepare to iterate over the rest
               (local.set $prev-str (struct.get $Symbol $name (ref.cast (ref $Symbol) (local.get $a))))
               (local.set $rest-list (local.get $rest))

               ;; With a single argument, the result is #t
               (if (ref.eq (local.get $rest-list) (global.get $null))
                   (then (return (global.get $true))))

               (loop $loop
                     (if (ref.eq (local.get $rest-list) (global.get $null))
                         (then (return (global.get $true))))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $rest-list)))
                         (then (call $raise-pair-expected (local.get $rest-list))
                               (unreachable)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $rest-list)))
                     (local.set $next (struct.get $Pair $a (local.get $pair)))
                     ;; Ensure each remaining argument is a symbol
                     (if (i32.eqz (ref.test (ref $Symbol) (local.get $next)))
                         (then (call $raise-symbol-expected/who
                                     (global.get $symbol:symbol<?)
                                     (local.get $next))))
                     (local.set $curr-str
                                (struct.get $Symbol $name
                                            (ref.cast (ref $Symbol) (local.get $next))))
                    (if (ref.eq (call $string<?/2 (local.get $prev-str) (local.get $curr-str))
                                 (global.get $false))
                         (then (return (global.get $false))))
                     (local.set $prev-str (local.get $curr-str))
                     (local.set $rest-list (struct.get $Pair $d (local.get $pair)))
                     (br $loop))
               (unreachable))

     ))

;; symbol-gensym-runtime-only-forms : (listof datum?)
;;   Enumerate gensym helpers used by the monolithic runtime.
(define symbol-gensym-runtime-only-forms
  `(

         (func $make-gensym-name
               (param $prefix (ref $String))
               (result        (ref $String))

               (local $n     i32)
               (local $n-str (ref $String))
               ;; Get current counter
               (local.set $n (global.get $gensym-counter))
               ;; Increment counter
               (global.set $gensym-counter (i32.add (local.get $n) (i32.const 1)))
               ;; Convert counter to string
               (local.set $n-str
                          (ref.cast (ref $String)
                                    (call $number->string
                                          ; convert $n from an i32 to a fixnum
                                          (ref.i31 (i32.shl (local.get $n) (i32.const 1)))
                                          ,(Imm 10))))
               ;; Append prefix and number string
               (ref.cast (ref $String)
                         (call $string-append/2 (local.get $prefix) (local.get $n-str))))

         (func $gensym (type $Prim01)
               (param $base (ref eq)) ;; optional base (string or symbol), default = "g"
               (result      (ref eq))

               (if (result (ref eq))
                   (ref.eq (local.get $base) (global.get $missing))
                   (then (call $gensym:0))
                   (else (call $gensym:1 (local.get $base)))))


         (func $gensym:0 (result (ref $Symbol))
               ;; Use "g" as default prefix
               (call $gensym:1 (ref.cast (ref $String) (global.get $string:g))))

         (func $raise-gensym:bad-base
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:gensym)
                     (global.get $string:symbol-or-string?)
                     (local.get $x)))

         (func $gensym:1 (param $base (ref eq)) (result (ref $Symbol))
               (local $prefix (ref null $String))
               (local $name   (ref $String))

               ;; Convert symbol -> string if needed
               (if (ref.test (ref $Symbol) (local.get $base))
                   (then
                    (local.set $prefix
                               (struct.get $Symbol $name
                                           (ref.cast (ref $Symbol) (local.get $base)))))
                   (else
                    (if (ref.test (ref $String) (local.get $base))
                        (then (local.set $prefix
                                         (ref.cast (ref $String) (local.get $base))))
                        (else (call $raise-gensym:bad-base (local.get $base))
                              (unreachable)))))
               ;; Generate name string
               (local.set $name (call $make-gensym-name (ref.as_non_null (local.get $prefix))))
               ;; Return new uninterned symbol
               (struct.new $Symbol
                           (i32.const 0)        ;; hash = 0
                           (local.get $name)    ;; name
                           (i32.const 0)        ;; gensyms are uninterned, not unreadable
                           (global.get $null))) ;; empty property list

     ))

;; symbol-public-runtime-only-helpers : (listof core-runtime-helper?)
;;   Register public symbol helpers used by the monolithic runtime.
(define symbol-public-runtime-only-helpers
  (function-forms->runtime-helpers
   'symbol-public-runtime-only-helpers
   symbol-public-runtime-only-forms))

;; symbol-gensym-runtime-only-helpers : (listof core-runtime-helper?)
;;   Register gensym helpers used by the monolithic runtime.
(define symbol-gensym-runtime-only-helpers
  (function-forms->runtime-helpers
   'symbol-gensym-runtime-only-helpers
   symbol-gensym-runtime-only-forms))

;; symbol-core-runtime-helper-names : (listof symbol?)
;;   Name symbol helpers available in the standalone core runtime.
(define symbol-core-runtime-helper-names
  (append
   '($symbol?
     $symbol=?
     $symbol=?/i32
     $symbol->immutable-string
     $string->uninterned-symbol/checked)
   (map core-runtime-helper-name symbol-gensym-runtime-only-helpers)))

;; symbol-all-runtime-helpers : (listof core-runtime-helper?)
;;   Register symbol table, public symbol, and gensym helpers.
(define symbol-all-runtime-helpers
  (append symbol-table-runtime-only-helpers
          symbol-table-initializer-runtime-only-helpers
          symbol-public-runtime-only-helpers
          symbol-gensym-runtime-only-helpers))

;; symbol-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate symbol helpers available in the standalone core runtime.
(define symbol-core-runtime-helpers
  (select-runtime-helpers symbol-all-runtime-helpers
                          symbol-core-runtime-helper-names))

;; symbol-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate symbol helpers that still depend on monolithic runtime globals.
(define symbol-runtime-only-helpers
  (remove-runtime-helpers symbol-all-runtime-helpers
                          symbol-core-runtime-helper-names))

;; symbol-public-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for public symbol helpers.
(define symbol-public-runtime-only-helper-names
  (map core-runtime-helper-name symbol-public-runtime-only-helpers))

;; symbol-gensym-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for gensym helpers.
(define symbol-gensym-runtime-only-helper-names
  (map core-runtime-helper-name
       (remove-runtime-helpers symbol-gensym-runtime-only-helpers
                               symbol-core-runtime-helper-names)))

;; symbol-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given symbol helper names from the runtime helper index.
(define (symbol-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; symbol-table-initializer-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render symbol table initializer helpers in runtime assembly order.
(define (symbol-table-initializer-runtime-helper-forms helper-index)
  (symbol-helper-forms helper-index symbol-table-initializer-runtime-only-helper-names))

;; symbol-table-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render symbol table helpers in runtime assembly order.
(define (symbol-table-runtime-helper-forms helper-index)
  (symbol-helper-forms helper-index symbol-table-runtime-only-helper-names))

;; symbol-public-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render public symbol helpers in runtime assembly order.
(define (symbol-public-runtime-helper-forms helper-index)
  (symbol-helper-forms helper-index symbol-public-runtime-only-helper-names))

;; symbol-gensym-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted gensym helpers in runtime assembly order.
(define (symbol-gensym-core-runtime-helper-forms helper-index)
  (symbol-helper-forms helper-index
                       (map core-runtime-helper-name symbol-gensym-runtime-only-helpers)))

;; symbol-gensym-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render gensym helpers in runtime assembly order.
(define (symbol-gensym-runtime-helper-forms helper-index)
  (symbol-helper-forms helper-index symbol-gensym-runtime-only-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define symbol-helper-index
    (make-core-runtime-helper-index
     (append symbol-core-runtime-helpers
             symbol-runtime-only-helpers)))

  (define symbol-core-helper-index
    (make-core-runtime-helper-index symbol-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name symbol-core-runtime-helpers)
   symbol-core-runtime-helper-names)

  (check-equal?
   (map form-name
        (symbol-table-initializer-runtime-helper-forms symbol-helper-index))
   symbol-table-initializer-runtime-only-helper-names)

  (check-equal?
   (map form-name (symbol-table-runtime-helper-forms symbol-helper-index))
   symbol-table-runtime-only-helper-names)

  (check-equal?
   (map form-name (symbol-public-runtime-helper-forms symbol-helper-index))
   symbol-public-runtime-only-helper-names)

  (check-equal?
   (map form-name (symbol-gensym-core-runtime-helper-forms symbol-core-helper-index))
   (map core-runtime-helper-name symbol-gensym-runtime-only-helpers))

  (check-equal?
   (map form-name (symbol-gensym-runtime-helper-forms symbol-helper-index))
   symbol-gensym-runtime-only-helper-names))
