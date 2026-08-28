#lang racket/base

;;; Wasm Frame Source
;;;
;; This command maps browser WebAssembly stack frames back to WebRacket's
;; generated labels and source-map entries. It reads the `.wasm` binary
;; directly, including the function-name subsection of the custom `name`
;; section and function exports, so it does not depend on parsing WAT text.
;;
;; Example:
;;
;;   racket tools/wasm-frame-source.rkt \
;;     local/geometry-page.wasm \
;;     local/geometry-page.wasm.map.sexp \
;;     'wasm-function[6785]:0x260d1e'


;;; Imports

(require racket/cmdline
         racket/file
         racket/format
         racket/list
         racket/match
         racket/path
         racket/port
         racket/string)


;;; Data Records

(struct byte-reader (bytes [pos #:mutable] limit) #:transparent)
(struct code-range (index size-start body-start end) #:transparent)
(struct wasm-info (function-count imported-function-count names code-ranges)
  #:transparent)
(struct map-entry (label src line col span same-as form) #:transparent)
(struct frame-query (raw index offset label) #:transparent)
(struct mapped-function (index label entry) #:transparent)


;;; Byte Reading

;; make-byte-reader : bytes? [exact-nonnegative-integer? exact-nonnegative-integer?] -> byte-reader?
;;   Build a bounded reader over bs.
(define (make-byte-reader bs [start 0] [limit (bytes-length bs)])
  (byte-reader bs start limit))

;; reader-done? : byte-reader? -> boolean?
;;   Check whether r has consumed its bounded range.
(define (reader-done? r)
  (>= (byte-reader-pos r) (byte-reader-limit r)))

;; ensure-readable! : byte-reader? exact-nonnegative-integer? -> void?
;;   Raise an error unless r has n more bytes.
(define (ensure-readable! r n)
  (when (> (+ (byte-reader-pos r) n) (byte-reader-limit r))
    (error 'wasm-frame-source
           "truncated wasm binary near byte offset 0x~x"
           (byte-reader-pos r))))

;; read-u8 : byte-reader? -> exact-nonnegative-integer?
;;   Read one unsigned byte.
(define (read-u8 r)
  (ensure-readable! r 1)
  (define pos (byte-reader-pos r))
  (set-byte-reader-pos! r (add1 pos))
  (bytes-ref (byte-reader-bytes r) pos))

;; read-uleb : byte-reader? -> exact-nonnegative-integer?
;;   Read an unsigned LEB128 integer.
(define (read-uleb r)
  (let loop ([shift 0]
             [result 0])
    (define b (read-u8 r))
    (define value (bitwise-and b #x7f))
    (define next-result
      (bitwise-ior result (arithmetic-shift value shift)))
    (if (zero? (bitwise-and b #x80))
        next-result
        (loop (+ shift 7) next-result))))

;; skip-leb! : byte-reader? -> void?
;;   Skip one signed or unsigned LEB128 integer.
(define (skip-leb! r)
  (let loop ()
    (define b (read-u8 r))
    (unless (zero? (bitwise-and b #x80))
      (loop))))

;; read-slice : byte-reader? exact-nonnegative-integer? -> bytes?
;;   Read n bytes as a fresh bytes value.
(define (read-slice r n)
  (ensure-readable! r n)
  (define start (byte-reader-pos r))
  (define end (+ start n))
  (set-byte-reader-pos! r end)
  (subbytes (byte-reader-bytes r) start end))

;; read-name : byte-reader? -> string?
;;   Read one WebAssembly UTF-8 name.
(define (read-name r)
  (define len (read-uleb r))
  (bytes->string/utf-8 (read-slice r len) #\?))

;; make-subreader : byte-reader? exact-nonnegative-integer? -> byte-reader?
;;   Consume size bytes from r and return a reader for that payload.
(define (make-subreader r size)
  (ensure-readable! r size)
  (define start (byte-reader-pos r))
  (define end (+ start size))
  (set-byte-reader-pos! r end)
  (make-byte-reader (byte-reader-bytes r) start end))


;;; Wasm Section Parsing

;; skip-ref-type! : byte-reader? -> void?
;;   Skip a reftype or abbreviated heap type in a table/global type.
(define (skip-ref-type! r)
  (define tag (read-u8 r))
  (when (or (= tag #x63) (= tag #x64))
    (skip-leb! r)))

;; skip-val-type! : byte-reader? -> void?
;;   Skip one WebAssembly value type.
(define (skip-val-type! r)
  (skip-ref-type! r))

;; skip-limits! : byte-reader? -> void?
;;   Skip a WebAssembly limits record.
(define (skip-limits! r)
  (define flags (read-uleb r))
  (void (read-uleb r))
  (unless (zero? (bitwise-and flags #x01))
    (void (read-uleb r)))
  (unless (zero? (bitwise-and flags #x08))
    (void (read-uleb r))))

;; skip-import-desc! : byte-reader? exact-nonnegative-integer? -> boolean?
;;   Skip one import descriptor and report whether it was a function import.
(define (skip-import-desc! r kind)
  (case kind
    [(0)
     (void (read-uleb r))
     #t]
    [(1)
     (skip-ref-type! r)
     (skip-limits! r)
     #f]
    [(2)
     (skip-limits! r)
     #f]
    [(3)
     (skip-val-type! r)
     (void (read-u8 r))
     #f]
    [(4)
     (void (read-u8 r))
     (void (read-uleb r))
     #f]
    [else
     (error 'wasm-frame-source
            "unsupported wasm import descriptor kind: ~a"
            kind)]))

;; parse-import-section! : byte-reader? hash? -> exact-nonnegative-integer?
;;   Parse imports and return the number of imported functions.
(define (parse-import-section! payload import-names)
  (define count (read-uleb payload))
  (for/fold ([function-index 0])
            ([_ (in-range count)])
    (define module-name (read-name payload))
    (define field-name  (read-name payload))
    (define kind        (read-u8 payload))
    (cond
      [(skip-import-desc! payload kind)
       (hash-set! import-names
                  function-index
                  (format "import:~a/~a" module-name field-name))
       (add1 function-index)]
      [else
       function-index])))

;; parse-function-section! : byte-reader? -> exact-nonnegative-integer?
;;   Parse the function section and return the number of defined functions.
(define (parse-function-section! payload)
  (define count (read-uleb payload))
  (for ([_ (in-range count)])
    (void (read-uleb payload)))
  count)

;; parse-code-section! : byte-reader? exact-nonnegative-integer? hash? -> exact-nonnegative-integer?
;;   Parse code bodies and record absolute byte ranges for each defined function.
(define (parse-code-section! payload imported-function-count code-ranges)
  (define count (read-uleb payload))
  (for ([body-index (in-range count)])
    (define size-start (byte-reader-pos payload))
    (define body-size  (read-uleb payload))
    (define body-start (byte-reader-pos payload))
    (define body-end   (+ body-start body-size))
    (when (> body-end (byte-reader-limit payload))
      (error 'wasm-frame-source
             "function body at index ~a extends past code section"
             (+ imported-function-count body-index)))
    (hash-set! code-ranges
               (+ imported-function-count body-index)
               (code-range (+ imported-function-count body-index)
                           size-start
                           body-start
                           body-end))
    (set-byte-reader-pos! payload body-end))
  count)

;; parse-export-section! : byte-reader? hash? -> void?
;;   Parse function exports as a fallback source of function names.
(define (parse-export-section! payload export-names)
  (define count (read-uleb payload))
  (for ([_ (in-range count)])
    (define export-name (read-name payload))
    (define kind        (read-u8 payload))
    (define index       (read-uleb payload))
    (when (= kind 0)
      (define old-name (hash-ref export-names index #f))
      (when (or (not old-name)
                (and (function-name->generated-label export-name)
                     (not (function-name->generated-label old-name))))
        (hash-set! export-names index export-name)))))

;; parse-function-name-subsection! : byte-reader? hash? -> void?
;;   Parse WebAssembly's name-map for functions.
(define (parse-function-name-subsection! payload names)
  (define count (read-uleb payload))
  (for ([_ (in-range count)])
    (define index (read-uleb payload))
    (define name  (read-name payload))
    (hash-set! names index name)))

;; parse-name-section! : byte-reader? hash? -> void?
;;   Parse custom `name` section subsections that are useful for frames.
(define (parse-name-section! payload names)
  (let loop ()
    (unless (reader-done? payload)
      (define subsection-id (read-u8 payload))
      (define subsection    (make-subreader payload (read-uleb payload)))
      (when (= subsection-id 1)
        (parse-function-name-subsection! subsection names))
      (loop))))

;; parse-custom-section! : byte-reader? hash? -> void?
;;   Parse the custom `name` section when present.
(define (parse-custom-section! payload names)
  (define custom-name (read-name payload))
  (when (string=? custom-name "name")
    (parse-name-section! payload names)))

;; parse-wasm-bytes : bytes? -> wasm-info?
;;   Parse enough module metadata to map browser function indexes to names.
(define (parse-wasm-bytes bs)
  (unless (and (>= (bytes-length bs) 8)
               (bytes=? (subbytes bs 0 4) #"\0asm"))
    (error 'wasm-frame-source "not a WebAssembly binary"))
  (define r (make-byte-reader bs 8))
  (define import-names (make-hash))
  (define export-names (make-hash))
  (define names        (make-hash))
  (define code-ranges  (make-hash))
  (define imported-function-count 0)
  (define defined-function-count #f)
  (define code-function-count #f)
  (let loop ()
    (unless (reader-done? r)
      (define section-id (read-u8 r))
      (define payload    (make-subreader r (read-uleb r)))
      (case section-id
        [(0)
         (parse-custom-section! payload names)]
        [(2)
         (set! imported-function-count
               (parse-import-section! payload import-names))]
        [(3)
         (set! defined-function-count
               (parse-function-section! payload))]
        [(7)
         (parse-export-section! payload export-names)]
        [(10)
         (set! code-function-count
               (parse-code-section! payload
                                    imported-function-count
                                    code-ranges))]
        [else
         (void)])
      (loop)))
  (for ([(index name) (in-hash export-names)])
    (define old-name (hash-ref names index #f))
    (when (or (not old-name)
              (and (function-name->generated-label name)
                   (not (function-name->generated-label old-name))))
      (hash-set! names index name)))
  (for ([(index name) (in-hash import-names)])
    (unless (hash-has-key? names index)
      (hash-set! names index name)))
  (define defined-count
    (or defined-function-count code-function-count 0))
  (wasm-info (+ imported-function-count defined-count)
             imported-function-count
             names
             code-ranges))

;; parse-wasm-file : path-string? -> wasm-info?
;;   Parse wasm metadata from path.
(define (parse-wasm-file path)
  (parse-wasm-bytes (file->bytes path)))


;;; Label Map Parsing

;; normalize-label-map-text : string? -> string?
;;   Rewrite unreadable printed path tokens into readable string literals.
(define (normalize-label-map-text text)
  (regexp-replace* #px"#<path:([^>]+)>"
                   text
                   (lambda (_ path)
                     (format "~s" path))))

;; parse-src-token : any/c -> string?
;;   Decode one source token from the emitted label map.
(define (parse-src-token token)
  (cond
    [(path? token)   (path->string token)]
    [(string? token) token]
    [(symbol? token) (symbol->string token)]
    [else            (~a token)]))

;; sexp->entry : any/c -> (or/c map-entry? #f)
;;   Parse one `(label ...)` s-expression from a `.wasm.map.sexp` file.
(define (sexp->entry stx)
  (match stx
    [`(label ,label (src ,src ,line ,col ,span) . ,rest)
     (define same-as
       (for/first ([field (in-list rest)])
         (match field
           [`(same-as ,target) target]
           [_ #f])))
     (define form
       (for/first ([field (in-list rest)])
         (match field
           [`(form ,value) value]
           [_ #f])))
     (map-entry label
                (parse-src-token src)
                line
                col
                span
                same-as
                form)]
    [_ #f]))

;; parse-label-map : path-string? -> (hash/c string? map-entry?)
;;   Parse a `.wasm.map.sexp` file into a table keyed by generated label.
(define (parse-label-map map-path)
  (define table (make-hash))
  (define normalized-text
    (normalize-label-map-text (file->string map-path)))
  (define label-map
    (with-input-from-string normalized-text read))
  (match label-map
    [`(wasm-label-map . ,entries)
     (for ([entry-sexp (in-list entries)])
       (define entry (sexp->entry entry-sexp))
       (when entry
         (hash-set! table (map-entry-label entry) entry)))]
    [_ (error 'wasm-frame-source
              "unexpected label map format in ~a"
              map-path)])
  table)


;;; Frame Parsing

;; parse-nonnegative-integer : string? [exact-positive-integer?] -> exact-nonnegative-integer?
;;   Parse s in the given radix.
(define (parse-nonnegative-integer s [radix 10])
  (define n (string->number s radix))
  (unless (and (exact-integer? n) (>= n 0))
    (error 'wasm-frame-source "expected nonnegative integer, got: ~a" s))
  n)

;; parse-offset : string? -> exact-nonnegative-integer?
;;   Parse a decimal or 0x-prefixed offset.
(define (parse-offset s)
  (match (regexp-match #px"^0x([0-9A-Fa-f]+)$" s)
    [(list _ hex)
     (parse-nonnegative-integer hex 16)]
    [#f
     (parse-nonnegative-integer s)]))

;; parse-frame-query : string? -> frame-query?
;;   Parse a browser wasm stack frame, a bare function index, offset, or label.
(define (parse-frame-query raw)
  (define s (string-trim raw))
  (cond
    [(regexp-match #px"wasm-function\\[([0-9]+)\\](?::(0x[0-9A-Fa-f]+|[0-9]+))?" s)
     => (lambda (m)
          (frame-query raw
                       (parse-nonnegative-integer (list-ref m 1))
                       (and (list-ref m 2)
                            (parse-offset (list-ref m 2)))
                       #f))]
    [(regexp-match #px"^([0-9]+)(?::(0x[0-9A-Fa-f]+|[0-9]+))?$" s)
     => (lambda (m)
          (frame-query raw
                       (parse-nonnegative-integer (list-ref m 1))
                       (and (list-ref m 2)
                            (parse-offset (list-ref m 2)))
                       #f))]
    [(regexp-match #px"\\blabel\\.[0-9]+\\b" s)
     => (lambda (m)
          (frame-query raw #f #f (car m)))]
    [(regexp-match #px"^0x([0-9A-Fa-f]+)$" s)
     (frame-query raw #f (parse-offset s) #f)]
    [else
     (error 'wasm-frame-source
            "could not parse frame argument: ~a"
            raw)]))


;;; Lookup Helpers

;; normalize-function-name : string? -> string?
;;   Drop a WAT-style leading `$` when present.
(define (normalize-function-name name)
  (if (string-prefix? name "$")
      (substring name 1)
      name))

;; function-name->generated-label : (or/c string? #f) -> (or/c string? #f)
;;   Extract `label.N` from a wasm function name.
(define (function-name->generated-label name)
  (and name
       (match (regexp-match #px"^\\$?(label\\.[0-9]+)$" name)
         [(list _ label) label]
         [#f #f])))

;; function-name-for-index : wasm-info? exact-nonnegative-integer? -> (or/c string? #f)
;;   Look up a wasm function name by index.
(define (function-name-for-index info index)
  (hash-ref (wasm-info-names info) index #f))

;; generated-label-for-index : wasm-info? exact-nonnegative-integer? -> (or/c string? #f)
;;   Look up the generated label for index when its function has one.
(define (generated-label-for-index info index)
  (function-name->generated-label (function-name-for-index info index)))

;; function-indexes-for-label : wasm-info? string? -> (listof exact-nonnegative-integer?)
;;   Find all function indexes whose name is label.
(define (function-indexes-for-label info label)
  (sort
   (for/list ([(index name) (in-hash (wasm-info-names info))]
              #:when (equal? (function-name->generated-label name) label))
     index)
   <))

;; source-known? : map-entry? -> boolean?
;;   Check whether entry names a concrete source location.
(define (source-known? entry)
  (not (string=? (map-entry-src entry) "unknown")))

;; format-offset : exact-nonnegative-integer? -> string?
;;   Render n as a hexadecimal byte offset.
(define (format-offset n)
  (format "0x~x" n))

;; format-location : map-entry? -> string?
;;   Render one parsed entry as `path:line:col` or `unknown`.
(define (format-location entry)
  (if (source-known? entry)
      (format "~a:~a:~a"
              (map-entry-src entry)
              (map-entry-line entry)
              (map-entry-col entry))
      "unknown"))

;; code-range-for-index : wasm-info? exact-nonnegative-integer? -> (or/c code-range? #f)
;;   Look up the recorded body range for a defined function.
(define (code-range-for-index info index)
  (hash-ref (wasm-info-code-ranges info) index #f))

;; offset-in-function? : code-range? exact-nonnegative-integer? -> boolean?
;;   Check whether offset lies inside range's body record.
(define (offset-in-function? range offset)
  (and (<= (code-range-size-start range) offset)
       (< offset (code-range-end range))))

;; offset-in-body? : code-range? exact-nonnegative-integer? -> boolean?
;;   Check whether offset lies inside range's instruction/body bytes.
(define (offset-in-body? range offset)
  (and (<= (code-range-body-start range) offset)
       (< offset (code-range-end range))))

;; function-index-at-offset : wasm-info? exact-nonnegative-integer? -> (or/c exact-nonnegative-integer? #f)
;;   Find the function body containing a module byte offset.
(define (function-index-at-offset info offset)
  (for/first ([range (in-list (hash-values (wasm-info-code-ranges info)))]
              #:when (offset-in-function? range offset))
    (code-range-index range)))

;; mapped-functions : wasm-info? (hash/c string? map-entry?) -> (listof mapped-function?)
;;   Pair source-map entries with the functions named by generated labels.
(define (mapped-functions info label-map)
  (sort
   (for/list ([(index name) (in-hash (wasm-info-names info))]
              #:do [(define label (function-name->generated-label name))
                    (define entry (and label (hash-ref label-map label #f)))]
              #:when entry)
     (mapped-function index label entry))
   <
   #:key mapped-function-index))

;; take-at-most : list? exact-nonnegative-integer? -> list?
;;   Take up to n values from xs.
(define (take-at-most xs n)
  (take xs (min n (length xs))))

;; nearest-mapped-functions : wasm-info? (hash/c string? map-entry?) exact-nonnegative-integer?
;;                            exact-nonnegative-integer? -> (values list? list?)
;;   Find nearest source-map-backed functions before and after index.
(define (nearest-mapped-functions info label-map index count)
  (define functions (mapped-functions info label-map))
  (define before
    (take-at-most
     (reverse
      (filter (lambda (mf) (< (mapped-function-index mf) index))
              functions))
     count))
  (define after
    (take-at-most
     (filter (lambda (mf) (> (mapped-function-index mf) index))
             functions)
     count))
  (values before after))


;;; Reporting

;; print-entry : map-entry? boolean? -> void?
;;   Print a source-map entry.
(define (print-entry entry show-form?)
  (printf "source-map: present\n")
  (printf "source: ~a\n" (format-location entry))
  (printf "span: ~a\n" (map-entry-span entry))
  (define same-as (map-entry-same-as entry))
  (when same-as
    (printf "same-as: ~a\n" same-as))
  (when (and show-form? (map-entry-form entry))
    (printf "form: ~a\n" (map-entry-form entry)))
  (unless (source-known? entry)
    (printf "diagnostic: source-map entry is present, but its source is unknown\n")))

;; print-mapped-neighbor : symbol? mapped-function? -> void?
;;   Print one nearest source-map neighbor.
(define (print-mapped-neighbor side mf)
  (printf "  ~a: wasm-function[~a] ~a -> ~a\n"
          side
          (mapped-function-index mf)
          (mapped-function-label mf)
          (format-location (mapped-function-entry mf))))

;; maybe-print-nearest : wasm-info? hash? exact-nonnegative-integer? exact-nonnegative-integer? -> void?
;;   Print nearest source-map-backed functions when requested.
(define (maybe-print-nearest info label-map index nearest-count)
  (when (> nearest-count 0)
    (define-values (before after)
      (nearest-mapped-functions info label-map index nearest-count))
    (when (or (pair? before) (pair? after))
      (printf "nearest-source-map-by-function-index:\n")
      (for ([mf (in-list before)])
        (print-mapped-neighbor 'before mf))
      (for ([mf (in-list after)])
        (print-mapped-neighbor 'after mf)))))

;; print-code-range : wasm-info? exact-nonnegative-integer? (or/c exact-nonnegative-integer? #f) -> void?
;;   Print code-body range and offset diagnostics when available.
(define (print-code-range info index offset)
  (define range (code-range-for-index info index))
  (when range
    (printf "code-range: ~a-~a (body: ~a-~a)\n"
            (format-offset (code-range-size-start range))
            (format-offset (code-range-end range))
            (format-offset (code-range-body-start range))
            (format-offset (code-range-end range))))
  (when offset
    (printf "browser-offset: ~a\n" (format-offset offset))
    (cond
      [(and range (offset-in-body? range offset))
       (printf "offset-status: inside function body\n")]
      [(and range (offset-in-function? range offset))
       (printf "offset-status: inside function body record\n")]
      [else
       (printf "offset-status: not inside this function's binary body range\n")])))

;; print-label-report : string? wasm-info? hash? boolean? exact-nonnegative-integer? path-string? -> void?
;;   Print source-map information for label.
(define (print-label-report label info label-map show-form? nearest-count map-path)
  (printf "generated-label: ~a\n" label)
  (define indexes (function-indexes-for-label info label))
  (cond
    [(pair? indexes)
     (printf "function-index: ~a\n"
             (string-join (map number->string indexes) ", "))]
    [else
     (printf "function-index: not found in wasm name section\n")])
  (define entry (hash-ref label-map label #f))
  (cond
    [entry
     (print-entry entry show-form?)]
    [else
     (printf "source-map: missing\n")
     (printf "diagnostic: generated label ~a was not found in ~a\n"
             label
             (path->string (simplify-path (path->complete-path map-path))))
     (when (pair? indexes)
       (maybe-print-nearest info label-map (car indexes) nearest-count))]))

;; print-index-report : frame-query? wasm-info? hash? boolean? exact-nonnegative-integer? path-string? -> void?
;;   Print wasm function and source-map information for a function-index query.
(define (print-index-report query info label-map show-form? nearest-count map-path)
  (define index (frame-query-index query))
  (printf "function-index: ~a\n" index)
  (cond
    [(>= index (wasm-info-function-count info))
     (printf "diagnostic: function index is outside module range 0..~a\n"
             (max 0 (sub1 (wasm-info-function-count info))))]
    [else
     (define name (function-name-for-index info index))
     (printf "wasm-name: ~a\n" (or name "<unnamed>"))
     (print-code-range info index (frame-query-offset query))
     (define label (function-name->generated-label name))
     (cond
       [label
        (printf "generated-label: ~a\n" label)
        (define entry (hash-ref label-map label #f))
        (cond
          [entry
           (print-entry entry show-form?)
           (unless (source-known? entry)
             (maybe-print-nearest info label-map index nearest-count))]
          [else
           (printf "source-map: missing\n")
           (printf "diagnostic: wasm function ~a is named ~a, but ~a has no matching label entry\n"
                   index
                   label
                   (path->string (simplify-path (path->complete-path map-path))))
           (maybe-print-nearest info label-map index nearest-count)])]
       [else
        (printf "generated-label: none\n")
        (printf "source-map: skipped\n")
        (printf "diagnostic: wasm function name does not have WebRacket label.N shape\n")])]))

;; print-offset-report : frame-query? wasm-info? hash? boolean? exact-nonnegative-integer? path-string? -> void?
;;   Print the function enclosing an offset-only query.
(define (print-offset-report query info label-map show-form? nearest-count map-path)
  (define offset (frame-query-offset query))
  (printf "module-offset: ~a\n" (format-offset offset))
  (define index (function-index-at-offset info offset))
  (cond
    [index
     (print-index-report
      (frame-query (frame-query-raw query) index offset #f)
      info
      label-map
      show-form?
      nearest-count
      map-path)]
    [else
     (printf "diagnostic: offset is not inside a recorded function body\n")]))

;; print-frame-report : frame-query? wasm-info? hash? boolean? exact-nonnegative-integer? path-string? -> void?
;;   Print one complete report for query.
(define (print-frame-report query info label-map show-form? nearest-count map-path)
  (printf "frame: ~a\n" (frame-query-raw query))
  (cond
    [(frame-query-index query)
     (print-index-report query info label-map show-form? nearest-count map-path)]
    [(frame-query-label query)
     (print-label-report (frame-query-label query)
                         info
                         label-map
                         show-form?
                         nearest-count
                         map-path)]
    [(frame-query-offset query)
     (print-offset-report query info label-map show-form? nearest-count map-path)]
    [else
     (error 'wasm-frame-source "empty frame query")]))


;;; Command-Line Entry Point

(module+ main
  (define show-form? #f)
  (define nearest-count 1)

  (define-values (wasm-path map-path frame-args)
    (command-line
     #:program "wasm-frame-source"
     #:once-each
     [("--show-form") "Print the recorded source form when available."
                      (set! show-form? #t)]
     [("--nearest") count
                    "Print up to count nearest source-mapped function neighbors."
                    (set! nearest-count (parse-nonnegative-integer count))]
     [("--no-nearest") "Do not print nearest source-map neighbors."
                       (set! nearest-count 0)]
     #:args (wasm-path map-path . frames)
     (values wasm-path map-path frames)))

  (when (null? frame-args)
    (error 'wasm-frame-source
           "usage: racket tools/wasm-frame-source.rkt <program.wasm> <program.wasm.map.sexp> <frame> ..."))

  (define info      (parse-wasm-file wasm-path))
  (define label-map (parse-label-map map-path))
  (define queries   (map parse-frame-query frame-args))

  (for ([query (in-list queries)]
        [i     (in-naturals)])
    (when (> i 0)
      (newline))
    (print-frame-report query
                        info
                        label-map
                        show-form?
                        nearest-count
                        map-path)))


;;; Tests

(module+ test
  (require rackunit)

  ;; encode-uleb : exact-nonnegative-integer? -> bytes?
  ;;   Encode n as unsigned LEB128.
  (define (encode-uleb n)
    (list->bytes
     (let loop ([n n])
       (define b (bitwise-and n #x7f))
       (define rest (arithmetic-shift n -7))
       (if (zero? rest)
           (list b)
           (cons (bitwise-ior b #x80) (loop rest))))))

  ;; encode-name : string? -> bytes?
  ;;   Encode s as a WebAssembly name.
  (define (encode-name s)
    (define bs (string->bytes/utf-8 s))
    (bytes-append (encode-uleb (bytes-length bs)) bs))

  ;; section : exact-nonnegative-integer? bytes? -> bytes?
  ;;   Encode one WebAssembly section.
  (define (section id payload)
    (bytes-append (bytes id)
                  (encode-uleb (bytes-length payload))
                  payload))

  ;; sample-wasm-bytes : -> bytes?
  ;;   Build a tiny wasm binary with one imported function and two label funcs.
  (define (sample-wasm-bytes)
    (define type-section
      (section 1 (bytes #x01 #x60 #x00 #x00)))
    (define import-section
      (section 2
               (bytes-append (bytes #x01)
                             (encode-name "env")
                             (encode-name "host")
                             (bytes #x00 #x00))))
    (define function-section
      (section 3 (bytes #x02 #x00 #x00)))
    (define export-section
      (section 7
               (bytes-append (bytes #x02)
                             (encode-name "label.101")
                             (bytes #x00 #x01)
                             (encode-name "label.103")
                             (bytes #x00 #x02))))
    (define code-section
      (section 10 (bytes #x02 #x02 #x00 #x0b #x02 #x00 #x0b)))
    (define function-names
      (bytes-append (bytes #x02)
                    (bytes #x00) (encode-name "host")
                    (bytes #x01) (encode-name "label.101")))
    (define name-subsection
      (bytes-append (bytes #x01)
                    (encode-uleb (bytes-length function-names))
                    function-names))
    (define name-section
      (section 0 (bytes-append (encode-name "name") name-subsection)))
    (bytes-append #"\0asm\1\0\0\0"
                  type-section
                  import-section
                  function-section
                  export-section
                  code-section
                  name-section))

  (define temp-dir
    (make-temporary-file "wasm-frame-source-test-~a" 'directory))
  (define wasm-path (build-path temp-dir "program.wasm"))
  (define map-path  (build-path temp-dir "program.wasm.map.sexp"))

  (void
   (call-with-output-file wasm-path
     (lambda (out)
       (write-bytes (sample-wasm-bytes) out)
       (void))
     #:exists 'truncate/replace))
  (call-with-output-file map-path
    (lambda (out)
      (displayln "(wasm-label-map" out)
      (displayln " (label \"label.101\" (src \"/tmp/source.rkt\" 12 3 5))" out)
      (displayln " (label \"label.103\" (src unknown 0 0 0)))" out))
    #:exists 'truncate/replace)

  (define info (parse-wasm-file wasm-path))
  (define label-map (parse-label-map map-path))

  (check-equal? (wasm-info-function-count info) 3)
  (check-equal? (function-name-for-index info 0) "host")
  (check-equal? (generated-label-for-index info 1) "label.101")
  (check-equal? (generated-label-for-index info 2) "label.103")
  (check-equal? (format-location (hash-ref label-map "label.101"))
                "/tmp/source.rkt:12:3")

  (define present-output
    (with-output-to-string
      (lambda ()
        (print-frame-report
         (parse-frame-query "wasm-function[1]:0x28")
         info
         label-map
         #f
         1
         map-path))))
  (check-true (string-contains? present-output "generated-label: label.101"))
  (check-true (string-contains? present-output "source-map: present"))

  (define missing-output
    (with-output-to-string
      (lambda ()
        (print-frame-report
         (parse-frame-query "label.999")
         info
         label-map
         #f
         1
         map-path))))
  (check-true (string-contains? missing-output "source-map: missing")))
