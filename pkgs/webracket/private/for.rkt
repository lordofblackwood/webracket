#lang racket/base

(require racket/mpair
         (for-syntax racket/base))

(provide make-do-sequence
         make-sequence
         prop:gen-sequence
         prop:sequence
         sequence-via-prop?
         sequence-ref
         :sequence?
         :sequence-ref
         sequence?
         sequence-generate
         sequence-generate*
         struct:do-sequence
         do-sequence?
         do-sequence-ref
         do-sequence-set!
         in-range
         in-inclusive-range
         in-naturals
         in-list
         in-vector
         in-string
         in-bytes
         in-mlist
         check-mlist
         in-input-port-bytes
         in-input-port-chars
         in-port
         in-lines
         in-bytes-lines
         (rename-out [read-bytes-line/staged read-bytes-line])
         in-hash
         default-in-hash
         default-in-hash-keys
         default-in-hash-values
         default-in-hash-pairs
         in-hash-keys
         in-hash-values
         in-hash-pairs
         in-immutable-hash
         default-in-immutable-hash
         default-in-immutable-hash-keys
         default-in-immutable-hash-values
         default-in-immutable-hash-pairs
         in-immutable-hash-keys
         in-immutable-hash-values
         in-immutable-hash-pairs
         in-mutable-hash
         default-in-mutable-hash
         default-in-mutable-hash-keys
         default-in-mutable-hash-values
         default-in-mutable-hash-pairs
         in-mutable-hash-keys
         in-mutable-hash-values
         in-mutable-hash-pairs
         in-indexed
         in-sequences
         in-cycle
         in-parallel
         in-parallel-values
         in-directory
         in-values-sequence
         in-values*-sequence
         stop-before
         stop-after
         in-producer
         in-value
         check-sequences
         append-sequences
         :integer-gen
         :list-gen
         :mlist-gen
         :vector-gen
         :string-gen
         :bytes-gen
         :input-port-gen
         :hash-gen
         mutable?
         dir-list
         initial-state
         next-body
         grow-vector
         shrink-vector
         no-more
         raise-argument-error
         raise-arguments-error
         raise-range-error
         check-in-hash
         check-in-hash-keys
         check-in-hash-values
         check-in-hash-pairs
         check-in-immutable-hash
         check-in-immutable-hash-keys
         check-in-immutable-hash-values
         check-in-immutable-hash-pairs
         check-in-mutable-hash
         check-in-mutable-hash-keys
         check-in-mutable-hash-values
         check-in-mutable-hash-pairs
         check-bytes
         check-in-input-port-bytes
         check-in-input-port-chars
         check-in-port
         check-in-lines
         check-in-bytes-lines
         check-naturals
         check-range
         check-range-generic
         check-ranges
         normalise-inputs
         unsafe-normalise-inputs
         check-string
         check-vector
         check-list
         (for-syntax split-for-body))

;; A small WebRacket-owned subset of `racket/private/for`.
;;
;; The full Racket provider contains many sequence forms and stream helpers.
;; Goal 1 currently needs the generic protocol pieces that expanded `for` forms
;; import and the six-value `make-do-sequence` shape used by modules such as
;; `data/queue`.

;; split-for-body : syntax? syntax? -> syntax?
;;   Split a for-like body into pre-body forms and the final expression group.
(define-for-syntax (split-for-body stx body-stx)
  (define forms (syntax->list body-stx))
  (unless (and forms (pair? forms))
    (raise-syntax-error #f "expected at least one body expression" stx body-stx))
  (let loop ([prefix '()] [rest forms])
    (cond
      [(null? (cdr rest))
       #`((#,@(reverse prefix)) (#,(car rest)))]
      [else
       (loop (cons (car rest) prefix) (cdr rest))])))

(define-values (prop:gen-sequence sequence-via-prop? sequence-ref)
  (make-struct-type-property
   'sequence
   (lambda (v _struct-info)
     (unless (and (procedure? v)
                  (procedure-arity-includes? v 1))
       (raise-argument-error 'guard-for-prop:sequence
                             "(procedure-arity-includes/c 1)"
                             v))
     v)))

;; prop:sequence : struct-type-property?
;;   Public sequence property whose value maps a struct instance to a sequence.
(define-values (prop:sequence :sequence? :sequence-ref)
  (make-struct-type-property 'sequence))

(struct do-sequence (thunk))

;; do-sequence-ref : do-sequence? exact-nonnegative-integer? -> any/c
;;   Compatibility accessor for code that imports upstream struct accessors.
(define (do-sequence-ref seq index)
  (unless (do-sequence? seq)
    (raise-argument-error 'do-sequence-ref "do-sequence?" seq))
  (unless (equal? index 0)
    (raise-range-error 'do-sequence-ref "do-sequence" "" index seq 0 1))
  (do-sequence-thunk seq))

;; do-sequence-set! : do-sequence? exact-nonnegative-integer? any/c -> void?
;;   Reject mutation of staged do-sequence values.
(define (do-sequence-set! seq index value)
  (unless (do-sequence? seq)
    (raise-argument-error 'do-sequence-set! "do-sequence?" seq))
  (unless (equal? index 0)
    (raise-range-error 'do-sequence-set! "do-sequence" "" index seq 0 1))
  (raise-arguments-error 'do-sequence-set! "staged do-sequence values are immutable"))

;; make-do-sequence : (-> values) -> sequence?
;;   Wrap a sequence initiation thunk.
(define (make-do-sequence thunk)
  (unless (procedure? thunk)
    (raise-argument-error 'make-do-sequence "procedure?" thunk))
  (do-sequence thunk))

;; sequence? : any/c -> boolean?
;;   Recognize the sequence shapes covered by this staged provider.
(define (sequence? v)
  (or (exact-nonnegative-integer? v)
      (list? v)
      (vector? v)
      (string? v)
      (bytes? v)
      (or (mpair? v) (null? v))
      (input-port? v)
      (hash? v)
      (do-sequence? v)
      (and (sequence-via-prop? v) #t)
      (and (:sequence? v) #t)))

;; check-list : any/c -> void?
;;   Validate list sequences imported by expanded installed providers.
(define (check-list v)
  (unless (list? v)
    (raise-argument-error 'in-list "list?" v)))

;; in-list : list? -> sequence?
;;   Return a list sequence.
(define (in-list lst)
  (check-list lst)
  lst)

;; check-naturals : any/c -> void?
;;   Validate in-naturals start values.
(define (check-naturals start)
  (unless (exact-nonnegative-integer? start)
    (raise-argument-error 'in-naturals "exact-nonnegative-integer?" start)))

;; in-naturals : [exact-nonnegative-integer?] -> sequence?
;;   Return an infinite sequence of exact integers. Optional start defaults to 0.
(define (in-naturals [start 0])
  (check-naturals start)
  (make-do-sequence
   (lambda ()
     (values (lambda (pos) pos)
             add1
             start
             (lambda (_pos) #t)
             #f
             #f))))

;; check-range-generic : symbol? real? real? real? -> void?
;;   Validate generic range arguments.
(define (check-range-generic who start end step)
  (unless (real? start)
    (raise-argument-error who "real?" start))
  (unless (real? end)
    (raise-argument-error who "real?" end))
  (unless (real? step)
    (raise-argument-error who "real?" step)))

;; check-range : real? real? real? -> void?
;;   Validate in-range arguments.
(define (check-range start end step)
  (check-range-generic 'in-range start end step))

;; check-ranges : symbol? string? any/c exact-nonnegative-integer? exact-integer? exact-integer? exact-nonnegative-integer? -> void?
;;   Validate indexed vector/string/bytes sequence bounds.
(define (check-ranges who type-name vec start stop step len)
  (unless (exact-nonnegative-integer? start)
    (raise-argument-error who "exact-nonnegative-integer?" start))
  (unless (or (< start len) (= len start stop))
    (raise-argument-error who "valid start index" start))
  (unless (exact-integer? stop)
    (raise-argument-error who "exact-integer?" stop))
  (unless (and (<= -1 stop) (<= stop len))
    (raise-argument-error who "valid stop index" stop))
  (unless (and (exact-integer? step) (not (zero? step)))
    (raise-argument-error who "(and/c exact-integer? (not/c zero?))" step))
  (when (and (< start stop) (< step 0))
    (raise-arguments-error who
                           "starting index less than stopping index, but given a negative step"
                           "starting index" start
                           "stopping index" stop
                           "step" step))
  (when (and (< stop start) (> step 0))
    (raise-arguments-error who
                           "starting index more than stopping index, but given a positive step"
                           "starting index" start
                           "stopping index" stop
                           "step" step)))

;; range-position-active? : real? real? real? boolean? -> boolean?
;;   Check whether a generated numeric range position is active.
(define (range-position-active? pos end step inclusive?)
  (cond
    [(zero? step) #t]
    [(positive? step) (if inclusive? (<= pos end) (< pos end))]
    [else (if inclusive? (>= pos end) (> pos end))]))

;; numeric-range-sequence : symbol? real? real? real? boolean? -> sequence?
;;   Build a numeric range sequence.
(define (numeric-range-sequence who start end step inclusive?)
  (if inclusive?
      (check-range-generic who start end step)
      (check-range start end step))
  (make-do-sequence
   (lambda ()
     (values (lambda (pos) pos)
             (lambda (pos) (+ pos step))
             start
             (lambda (pos) (range-position-active? pos end step inclusive?))
             #f
             #f))))

;; in-range : real? [real?] [real?] -> sequence?
;;   Return a numeric range. Optional one-arg form means start=0; step defaults to 1.
(define in-range
  (case-lambda
    [(end) (numeric-range-sequence 'in-range 0 end 1 #f)]
    [(start end) (numeric-range-sequence 'in-range start end 1 #f)]
    [(start end step) (numeric-range-sequence 'in-range start end step #f)]))

;; in-inclusive-range : real? real? [real?] -> sequence?
;;   Return a numeric range that includes end when exactly reached. Optional step defaults to 1.
(define in-inclusive-range
  (case-lambda
    [(start end) (numeric-range-sequence 'in-inclusive-range start end 1 #t)]
    [(start end step) (numeric-range-sequence 'in-inclusive-range start end step #t)]))

;; check-mlist : any/c -> void?
;;   Validate mutable-list sequences imported by expanded installed providers.
(define (check-mlist v)
  (unless (or (mpair? v) (null? v))
    (raise-argument-error 'in-mlist "(or/c mpair? null?)" v)))

;; check-in-hash : any/c -> void?
;;   Validate generic hash sequences imported by installed providers.
(define (check-in-hash v)
  (unless (hash? v)
    (raise-argument-error 'in-hash "hash?" v)))

;; check-in-hash-keys : any/c -> void?
;;   Validate generic hash-key sequences imported by installed providers.
(define (check-in-hash-keys v)
  (unless (hash? v)
    (raise-argument-error 'in-hash-keys "hash?" v)))

;; check-in-hash-values : any/c -> void?
;;   Validate generic hash-value sequences imported by installed providers.
(define (check-in-hash-values v)
  (unless (hash? v)
    (raise-argument-error 'in-hash-values "hash?" v)))

;; check-in-hash-pairs : any/c -> void?
;;   Validate generic hash-pair sequences imported by installed providers.
(define (check-in-hash-pairs v)
  (unless (hash? v)
    (raise-argument-error 'in-hash-pairs "hash?" v)))

;; check-in-immutable-hash : any/c -> void?
;;   Validate immutable hash sequences imported by installed providers.
(define (check-in-immutable-hash v)
  (unless (and (hash? v) (immutable? v))
    (raise-argument-error 'in-immutable-hash "(and/c hash? immutable?)" v)))

;; check-in-immutable-hash-keys : any/c -> void?
;;   Validate immutable hash-key sequences imported by installed providers.
(define (check-in-immutable-hash-keys v)
  (unless (and (hash? v) (immutable? v))
    (raise-argument-error 'in-immutable-hash-keys "(and/c hash? immutable?)" v)))

;; check-in-immutable-hash-values : any/c -> void?
;;   Validate immutable hash-value sequences imported by installed providers.
(define (check-in-immutable-hash-values v)
  (unless (and (hash? v) (immutable? v))
    (raise-argument-error 'in-immutable-hash-values "(and/c hash? immutable?)" v)))

;; check-in-immutable-hash-pairs : any/c -> void?
;;   Validate immutable hash-pair sequences imported by installed providers.
(define (check-in-immutable-hash-pairs v)
  (unless (and (hash? v) (immutable? v))
    (raise-argument-error 'in-immutable-hash-pairs "(and/c hash? immutable?)" v)))

;; check-bytes : any/c -> void?
;;   Validate byte-string sequences imported by expanded code.
(define (check-bytes v)
  (unless (bytes? v)
    (raise-argument-error 'in-bytes "bytes?" v)))

;; check-vector : any/c -> void?
;;   Validate vector sequences imported by expanded code.
(define (check-vector v)
  (unless (vector? v)
    (raise-argument-error 'in-vector "vector?" v)))

;; check-string : any/c -> void?
;;   Validate string sequences imported by expanded code.
(define (check-string v)
  (unless (string? v)
    (raise-argument-error 'in-string "string?" v)))

;; normalise-inputs : symbol? string? predicate? procedure? any/c exact-nonnegative-integer? (or/c exact-integer? #f) exact-integer? -> values
;;   Validate indexed sequence inputs and return vec, start, resolved stop, and step.
(define (normalise-inputs who type-name vector? unsafe-vector-length vec start stop step)
  (unless (vector? vec)
    (raise-argument-error who (string-append type-name "?") vec))
  (define len (unsafe-vector-length vec))
  (define stop* (if stop stop len))
  (check-ranges who type-name vec start stop* step len)
  (values vec start stop* step))

;; unsafe-normalise-inputs : procedure? any/c exact-nonnegative-integer? (or/c exact-integer? #f) exact-integer? -> values
;;   Resolve indexed sequence defaults without validation.
(define (unsafe-normalise-inputs unsafe-vector-length vec start stop step)
  (values vec start (or stop (unsafe-vector-length vec)) step))

;; indexed-position-active? : exact-integer? exact-integer? exact-integer? -> boolean?
;;   Check whether an indexed sequence position is active.
(define (indexed-position-active? pos end step)
  (if (positive? step) (< pos end) (> pos end)))

;; indexed-sequence : procedure? exact-nonnegative-integer? exact-integer? exact-integer? -> sequence?
;;   Build a sequence over indexed data.
(define (indexed-sequence ref start end step)
  (make-do-sequence
   (lambda ()
     (values ref
             (lambda (pos) (+ pos step))
             start
             (lambda (pos) (indexed-position-active? pos end step))
             #f
             #f))))

;; byte-stop : bytes? (or/c exact-integer? #f) -> exact-integer?
;;   Resolve #f stop to the byte string length.
(define (byte-stop bstr stop)
  (if stop stop (bytes-length bstr)))

;; check-in-bytes : bytes? exact-nonnegative-integer? (or/c exact-integer? #f) exact-integer? -> void?
;;   Validate in-bytes arguments.
(define (check-in-bytes bstr start stop step)
  (unless (bytes? bstr)
    (raise-argument-error 'in-bytes "bytes?" bstr))
  (unless (exact-nonnegative-integer? start)
    (raise-argument-error 'in-bytes "exact-nonnegative-integer?" start))
  (unless (or (not stop) (exact-integer? stop))
    (raise-argument-error 'in-bytes "(or/c exact-integer? #f)" stop))
  (unless (and (exact-integer? step) (not (zero? step)))
    (raise-argument-error 'in-bytes "(and/c exact-integer? (not/c zero?))" step)))

;; in-bytes : bytes? [exact-nonnegative-integer?] [(or/c exact-integer? #f)] [nonzero-exact-integer?] -> sequence?
;;   Return a byte sequence. Optional start defaults to 0, stop to length, step to 1.
(define (in-bytes bstr [start 0] [stop #f] [step 1])
  (check-in-bytes bstr start stop step)
  (define end (byte-stop bstr stop))
  (let loop ([i start])
    (cond
      [(if (positive? step) (< i end) (> i end))
       (cons (bytes-ref bstr i) (loop (+ i step)))]
      [else null])))

;; in-vector : vector? [exact-nonnegative-integer?] [(or/c exact-integer? #f)] [nonzero-exact-integer?] -> sequence?
;;   Return a vector sequence. Optional start defaults to 0, stop to length, step to 1.
(define (in-vector vec [start 0] [stop #f] [step 1])
  (check-vector vec)
  (define-values (_vec _start end _step)
    (normalise-inputs 'in-vector "vector" vector? vector-length vec start stop step))
  (indexed-sequence (lambda (pos) (vector-ref vec pos)) start end step))

;; in-string : string? [exact-nonnegative-integer?] [(or/c exact-integer? #f)] [nonzero-exact-integer?] -> sequence?
;;   Return a string sequence. Optional start defaults to 0, stop to length, step to 1.
(define (in-string str [start 0] [stop #f] [step 1])
  (check-string str)
  (define-values (_str _start end _step)
    (normalise-inputs 'in-string "string" string? string-length str start stop step))
  (indexed-sequence (lambda (pos) (string-ref str pos)) start end step))

;; in-mlist : (or/c mpair? null?) -> sequence?
;;   Return a mutable-list sequence.
(define (in-mlist lst)
  (check-mlist lst)
  (make-do-sequence
   (lambda ()
     (values mcar
             #f
             mcdr
             lst
             mpair?
             #f
             #f))))

;; check-input-port : symbol? any/c -> void?
;;   Validate input-port sequence arguments.
(define (check-input-port who in)
  (unless (input-port? in)
    (raise-argument-error who "input-port?" in)))

;; check-in-input-port-bytes : any/c -> void?
;;   Validate byte-port sequence arguments.
(define (check-in-input-port-bytes in)
  (check-input-port 'in-input-port-bytes in))

;; in-input-port-bytes : input-port? -> sequence?
;;   Return a byte-reading sequence.
(define (in-input-port-bytes in)
  (check-in-input-port-bytes in)
  (in-producer (lambda () (read-byte in)) eof))

;; check-in-input-port-chars : any/c -> void?
;;   Validate char-port sequence arguments.
(define (check-in-input-port-chars in)
  (check-input-port 'in-input-port-chars in))

;; in-input-port-chars : input-port? -> sequence?
;;   Return a character-reading sequence.
(define (in-input-port-chars in)
  (check-in-input-port-chars in)
  (in-producer (lambda () (read-char in)) eof))

;; check-in-port : procedure? input-port? -> void?
;;   Validate in-port arguments.
(define (check-in-port reader in)
  (unless (and (procedure? reader) (procedure-arity-includes? reader 1))
    (raise-argument-error 'in-port "(procedure-arity-includes/c 1)" reader))
  (check-input-port 'in-port in))

;; in-port : [procedure?] [input-port?] -> sequence?
;;   Return a sequence by reading from in until eof. Reader defaults to read.
(define in-port
  (case-lambda
    [() (in-port read (current-input-port))]
    [(reader) (in-port reader (current-input-port))]
    [(reader in)
     (check-in-port reader in)
     (in-producer (lambda () (reader in)) eof)]))

;; check-read-line-mode : symbol? any/c -> void?
;;   Validate read-line modes used by port sequences.
(define (check-read-line-mode who mode)
  (unless (memq mode '(linefeed return return-linefeed any any-one))
    (raise-argument-error who
                          "(or/c 'linefeed 'return 'return-linefeed 'any 'any-one)"
                          mode)))

;; check-in-lines : any/c any/c -> void?
;;   Validate in-lines arguments.
(define (check-in-lines in mode)
  (check-input-port 'in-lines in)
  (check-read-line-mode 'in-lines mode))

;; in-lines : [input-port?] [symbol?] -> sequence?
;;   Return a line-reading sequence. Optional mode defaults to 'any.
(define in-lines
  (case-lambda
    [() (in-lines (current-input-port) 'any)]
    [(in) (in-lines in 'any)]
    [(in mode)
     (check-in-lines in mode)
     (in-producer (lambda () (read-line in mode)) eof)]))

;; read-bytes-line/staged : input-port? symbol? -> (or/c bytes? eof-object?)
;;   Read one line as bytes using the available string-port reader.
(define (read-bytes-line/staged in mode)
  (define line (read-line in mode))
  (if (eof-object? line)
      eof
      (string->bytes/utf-8 line)))

;; check-in-bytes-lines : any/c any/c -> void?
;;   Validate in-bytes-lines arguments.
(define (check-in-bytes-lines in mode)
  (check-input-port 'in-bytes-lines in)
  (check-read-line-mode 'in-bytes-lines mode))

;; in-bytes-lines : [input-port?] [symbol?] -> sequence?
;;   Return a bytes-line sequence. Optional mode defaults to 'any.
(define in-bytes-lines
  (case-lambda
    [() (in-bytes-lines (current-input-port) 'any)]
    [(in) (in-bytes-lines in 'any)]
    [(in mode)
     (check-in-bytes-lines in mode)
     (in-producer (lambda () (read-bytes-line/staged in mode)) eof)]))

;; maybe-bad-index : any/c -> any/c
;;   Placeholder for Racket's weak/concurrent hash bad-index value.
(define (maybe-bad-index v)
  v)

;; default-in-hash : any/c
;;   Default bad-index placeholder used by expanded in-hash code.
(define default-in-hash (maybe-bad-index #f))

;; default-in-hash-keys : any/c
;;   Default bad-index placeholder used by expanded in-hash-keys code.
(define default-in-hash-keys (maybe-bad-index #f))

;; default-in-hash-values : any/c
;;   Default bad-index placeholder used by expanded in-hash-values code.
(define default-in-hash-values (maybe-bad-index #f))

;; default-in-hash-pairs : any/c
;;   Default bad-index placeholder used by expanded in-hash-pairs code.
(define default-in-hash-pairs (maybe-bad-index #f))

;; in-hash : hash? [any/c] -> sequence?
;;   Return a two-value hash sequence. The optional bad-index value is accepted but ignored.
(define (in-hash ht [bad-index-v default-in-hash])
  (check-in-hash ht)
  ht)

;; in-hash-keys : hash? [any/c] -> sequence?
;;   Return a sequence of hash keys. The optional bad-index value is accepted but ignored.
(define (in-hash-keys ht [bad-index-v default-in-hash-keys])
  (check-in-hash-keys ht)
  (hash-keys ht))

;; in-hash-values : hash? [any/c] -> sequence?
;;   Return a sequence of hash values. The optional bad-index value is accepted but ignored.
(define (in-hash-values ht [bad-index-v default-in-hash-values])
  (check-in-hash-values ht)
  (hash-values ht))

;; in-hash-pairs : hash? [any/c] -> sequence?
;;   Return a sequence of key-value pairs. The optional bad-index value is accepted but ignored.
(define (in-hash-pairs ht [bad-index-v default-in-hash-pairs])
  (check-in-hash-pairs ht)
  (map (lambda (key) (cons key (hash-ref ht key))) (hash-keys ht)))

;; check-mutable-hash : symbol? any/c -> void?
;;   Validate mutable hash variants.
(define (check-mutable-hash who ht)
  (unless (and (hash? ht) (not (immutable? ht)))
    (raise-argument-error who "(and/c hash? (not/c immutable?))" ht)))

;; check-in-mutable-hash : any/c -> void?
;;   Validate mutable hash sequences imported by installed providers.
(define (check-in-mutable-hash ht)
  (check-mutable-hash 'in-mutable-hash ht))

;; check-in-mutable-hash-keys : any/c -> void?
;;   Validate mutable hash-key sequences imported by installed providers.
(define (check-in-mutable-hash-keys ht)
  (check-mutable-hash 'in-mutable-hash-keys ht))

;; check-in-mutable-hash-values : any/c -> void?
;;   Validate mutable hash-value sequences imported by installed providers.
(define (check-in-mutable-hash-values ht)
  (check-mutable-hash 'in-mutable-hash-values ht))

;; check-in-mutable-hash-pairs : any/c -> void?
;;   Validate mutable hash-pair sequences imported by installed providers.
(define (check-in-mutable-hash-pairs ht)
  (check-mutable-hash 'in-mutable-hash-pairs ht))

;; default-in-immutable-hash : any/c
;;   Default bad-index placeholder used by expanded in-immutable-hash code.
(define default-in-immutable-hash (maybe-bad-index #f))

;; default-in-immutable-hash-keys : any/c
;;   Default bad-index placeholder used by expanded in-immutable-hash-keys code.
(define default-in-immutable-hash-keys (maybe-bad-index #f))

;; default-in-immutable-hash-values : any/c
;;   Default bad-index placeholder used by expanded in-immutable-hash-values code.
(define default-in-immutable-hash-values (maybe-bad-index #f))

;; default-in-immutable-hash-pairs : any/c
;;   Default bad-index placeholder used by expanded in-immutable-hash-pairs code.
(define default-in-immutable-hash-pairs (maybe-bad-index #f))

;; default-in-mutable-hash : any/c
;;   Default bad-index placeholder used by expanded in-mutable-hash code.
(define default-in-mutable-hash (maybe-bad-index #f))

;; default-in-mutable-hash-keys : any/c
;;   Default bad-index placeholder used by expanded in-mutable-hash-keys code.
(define default-in-mutable-hash-keys (maybe-bad-index #f))

;; default-in-mutable-hash-values : any/c
;;   Default bad-index placeholder used by expanded in-mutable-hash-values code.
(define default-in-mutable-hash-values (maybe-bad-index #f))

;; default-in-mutable-hash-pairs : any/c
;;   Default bad-index placeholder used by expanded in-mutable-hash-pairs code.
(define default-in-mutable-hash-pairs (maybe-bad-index #f))

;; in-immutable-hash : immutable-hash? [any/c] -> sequence?
;;   Return a two-value immutable-hash sequence.
(define (in-immutable-hash ht [bad-index-v default-in-immutable-hash])
  (check-in-immutable-hash ht)
  (in-hash ht bad-index-v))

;; in-immutable-hash-keys : immutable-hash? [any/c] -> sequence?
;;   Return immutable-hash keys.
(define (in-immutable-hash-keys ht [bad-index-v default-in-immutable-hash-keys])
  (check-in-immutable-hash-keys ht)
  (in-hash-keys ht bad-index-v))

;; in-immutable-hash-values : immutable-hash? [any/c] -> sequence?
;;   Return immutable-hash values.
(define (in-immutable-hash-values ht [bad-index-v default-in-immutable-hash-values])
  (check-in-immutable-hash-values ht)
  (in-hash-values ht bad-index-v))

;; in-immutable-hash-pairs : immutable-hash? [any/c] -> sequence?
;;   Return immutable-hash key-value pairs.
(define (in-immutable-hash-pairs ht [bad-index-v default-in-immutable-hash-pairs])
  (check-in-immutable-hash-pairs ht)
  (in-hash-pairs ht bad-index-v))

;; in-mutable-hash : mutable-hash? [any/c] -> sequence?
;;   Return a two-value mutable-hash sequence.
(define (in-mutable-hash ht [bad-index-v default-in-mutable-hash])
  (check-in-mutable-hash ht)
  (in-hash ht bad-index-v))

;; in-mutable-hash-keys : mutable-hash? [any/c] -> sequence?
;;   Return mutable-hash keys.
(define (in-mutable-hash-keys ht [bad-index-v default-in-mutable-hash-keys])
  (check-in-mutable-hash-keys ht)
  (in-hash-keys ht bad-index-v))

;; in-mutable-hash-values : mutable-hash? [any/c] -> sequence?
;;   Return mutable-hash values.
(define (in-mutable-hash-values ht [bad-index-v default-in-mutable-hash-values])
  (check-in-mutable-hash-values ht)
  (in-hash-values ht bad-index-v))

;; in-mutable-hash-pairs : mutable-hash? [any/c] -> sequence?
;;   Return mutable-hash key-value pairs.
(define (in-mutable-hash-pairs ht [bad-index-v default-in-mutable-hash-pairs])
  (check-in-mutable-hash-pairs ht)
  (in-hash-pairs ht bad-index-v))

;; thunk->make-sequence-values : symbol? (-> values) -> values
;;   Normalize a make-do-sequence thunk to the seven-value protocol.
(define (thunk->make-sequence-values who thunk)
  (define vals (call-with-values thunk list))
  (case (length vals)
    [(6)
     (apply values
            (list (list-ref vals 0)
                  #f
                  (list-ref vals 1)
                  (list-ref vals 2)
                  (list-ref vals 3)
                  (list-ref vals 4)
                  (list-ref vals 5)))]
    [(7) (apply values vals)]
    [else
     (raise-arguments-error who
                            "sequence initiation thunk returned the wrong number of values"
                            "expected" "6 or 7"
                            "received" (length vals))]))

;; make-sequence : symbol? any/c -> values
;;   Initiate a supported sequence for expanded `for` forms.
(define (make-sequence who v)
  (cond
    [(exact-nonnegative-integer? v)
     (values (lambda (pos) pos)
             #f
             add1
             0
             (lambda (pos) (< pos v))
             #f
             #f)]
    [(list? v)
     (values car
             #f
             cdr
             v
             pair?
             #f
             #f)]
    [(or (mpair? v) (null? v))
     (values mcar
             #f
             mcdr
             v
             mpair?
             #f
             #f)]
    [(vector? v)
     (values (lambda (pos) (vector-ref v pos))
             #f
             add1
             0
             (lambda (pos) (< pos (vector-length v)))
             #f
             #f)]
    [(string? v)
     (values (lambda (pos) (string-ref v pos))
             #f
             add1
             0
             (lambda (pos) (< pos (string-length v)))
             #f
             #f)]
    [(bytes? v)
     (values (lambda (pos) (bytes-ref v pos))
             #f
             add1
             0
             (lambda (pos) (< pos (bytes-length v)))
             #f
             #f)]
    [(input-port? v)
     (make-sequence who (in-input-port-bytes v))]
    [(hash? v)
     (values (lambda (pos) (hash-iterate-key+value v pos))
             #f
             (lambda (pos) (hash-iterate-next v pos))
             (hash-iterate-first v)
             values
             #f
             #f)]
    [(do-sequence? v)
     (thunk->make-sequence-values who (do-sequence-thunk v))]
    [(sequence-via-prop? v)
     (thunk->make-sequence-values who (lambda () ((sequence-ref v) v)))]
    [(:sequence? v)
     (make-sequence who ((:sequence-ref v) v))]
    [else
     (raise-argument-error who "sequence?" v)]))

;; :integer-gen : exact-nonnegative-integer? -> values
;;   Upstream-compatible generator entry for natural-number sequences.
(define (:integer-gen n)
  (make-sequence ':integer-gen n))

;; :list-gen : list? -> values
;;   Upstream-compatible generator entry for list sequences.
(define (:list-gen lst)
  (make-sequence ':list-gen lst))

;; :mlist-gen : (or/c mpair? null?) -> values
;;   Upstream-compatible generator entry for mutable-list sequences.
(define (:mlist-gen lst)
  (make-sequence ':mlist-gen (in-mlist lst)))

;; :vector-gen : vector? exact-nonnegative-integer? exact-integer? exact-integer? -> values
;;   Upstream-compatible generator entry for vector subsequences.
(define (:vector-gen vec start stop step)
  (make-sequence ':vector-gen (in-vector vec start stop step)))

;; :string-gen : string? exact-nonnegative-integer? exact-integer? exact-integer? -> values
;;   Upstream-compatible generator entry for string subsequences.
(define (:string-gen str start stop step)
  (make-sequence ':string-gen (in-string str start stop step)))

;; :bytes-gen : bytes? exact-nonnegative-integer? exact-integer? exact-integer? -> values
;;   Upstream-compatible generator entry for byte-string subsequences.
(define (:bytes-gen bstr start stop step)
  (make-sequence ':bytes-gen (in-bytes bstr start stop step)))

;; :input-port-gen : input-port? -> values
;;   Upstream-compatible generator entry for input-port byte sequences.
(define (:input-port-gen in)
  (make-sequence ':input-port-gen (in-input-port-bytes in)))

;; :hash-gen : hash? procedure? procedure? procedure? [any/c] -> values
;;   Upstream-compatible generator entry for hash iterator sequences.
(define (:hash-gen ht pos->vals first-pos next-pos [bad-index-v #f])
  (check-in-hash ht)
  (values (lambda (pos) (pos->vals ht pos))
          #f
          (lambda (pos) (next-pos ht pos))
          (first-pos ht)
          values
          #f
          #f))

;; mutable? : any/c -> boolean?
;;   Internal helper used by upstream hash sequence predicates.
(define (mutable? v)
  (not (immutable? v)))

;; grow-vector : vector? -> vector?
;;   Double a vector, preserving existing elements for for/vector builders.
(define (grow-vector vec)
  (define n (vector-length vec))
  (define new-vec (make-vector (* 2 n)))
  (vector-copy! new-vec 0 vec 0 n)
  new-vec)

;; shrink-vector : vector? exact-nonnegative-integer? -> vector?
;;   Copy the first i elements into a right-sized vector.
(define (shrink-vector vec i)
  (define new-vec (make-vector i))
  (vector-copy! new-vec 0 vec 0 i)
  new-vec)

;; no-more : -> none/c
;;   Raise the error used by exhausted generated sequences.
(define (no-more)
  (raise-arguments-error 'sequence-generate "sequence has no more values"))

;; sequence-position-active? : any/c (any/c -> any/c) -> boolean?
;;   Check whether a sequence position should produce another element.
(define (sequence-position-active? pos pos-cont?)
  (pos-cont? pos))

;; sequence-position-values : procedure? any/c (or/c #f procedure?) -> list?
;;   Extract one element's values as a list, respecting val-cont? when supplied.
(define (sequence-position-values pos->vals pos val-cont?)
  (define vals (call-with-values (lambda () (pos->vals pos)) list))
  (cond
    [(and val-cont? (not (apply val-cont? vals))) #f]
    [else vals]))

;; sequence-early-position : any/c (or/c #f procedure?) -> any/c
;;   Apply make-do-sequence's early-next-pos hook, or keep the position.
(define (sequence-early-position pos pre-pos-next)
  (if pre-pos-next (pre-pos-next pos) pos))

;; sequence-generate : sequence? -> (values (-> boolean?) (-> any))
;;   Return stateful thunks that test for and produce the next sequence element.
(define (sequence-generate seq)
  (unless (sequence? seq)
    (raise-argument-error 'sequence-generate "sequence?" seq))
  (define-values (pos->vals pre-pos-next pos-next init pos-cont? val-cont? all-cont?)
    (make-sequence 'sequence-generate seq))
  (define pos init)
  (define cached? #f)
  (define cached-values #f)
  (define exhausted? #f)
  (define stop-after-cached? #f)
  (define (fill-cache!)
    (unless cached?
      (let loop ()
        (cond
          [exhausted?
           (set! cached-values #f)
           (set! cached? #t)]
          [(not (sequence-position-active? pos pos-cont?))
           (set! exhausted? #t)
           (set! cached-values #f)
           (set! cached? #t)]
          [else
           (define current-pos pos)
           (define vals (sequence-position-values pos->vals current-pos val-cont?))
           (cond
             [vals
              (define early-pos (sequence-early-position current-pos pre-pos-next))
              (define continue-after?
                (if all-cont? (apply all-cont? early-pos vals) #t))
              (when continue-after?
                (set! pos (pos-next early-pos)))
              (set! cached-values vals)
              (set! stop-after-cached? (not continue-after?))
              (set! cached? #t)]
             [else
              (define early-pos (sequence-early-position current-pos pre-pos-next))
              (set! pos (pos-next early-pos))
              (loop)])]))))
  (define (more?)
    (fill-cache!)
    (not exhausted?))
  (define (next)
    (fill-cache!)
    (cond
      [exhausted?
       (raise-arguments-error 'sequence-generate "sequence is exhausted")]
      [else
       (define vals cached-values)
       (set! cached? #f)
       (when stop-after-cached?
         (set! exhausted? #t)
         (set! stop-after-cached? #f))
       (apply values vals)]))
  (values more? next))

;; sequence-generate* : sequence? -> (values (or/c list? #f) (-> values))
;;   Return the first element values and a thunk for the rest of the sequence.
(define (sequence-generate* seq)
  (define-values (more? next) (sequence-generate seq))
  (define first-values (and (more?) (call-with-values next list)))
  (values first-values
          (lambda ()
            (sequence-generate* (make-do-sequence
                                 (lambda ()
                                   (define-values (more?/rest next/rest)
                                     (values more? next))
                                   (values (lambda (_pos)
                                             (apply values
                                                    (call-with-values next/rest list)))
                                           (lambda (_pos) _pos)
                                           #t
                                           (lambda (_pos) (more?/rest))
                                           #f
                                           #f)))))))

;; in-indexed : sequence? -> sequence?
;;   Return a two-value sequence of element and index.
(define (in-indexed seq)
  (unless (sequence? seq)
    (raise-argument-error 'in-indexed "sequence?" seq))
  (make-do-sequence
   (lambda ()
     (define-values (more? next) (sequence-generate seq))
     (values (lambda (pos)
               (values (car pos) (cdr pos)))
             (lambda (pos)
               (and (more?) (cons (next) (+ (cdr pos) 1))))
             (and (more?) (cons (next) 0))
             values
             (lambda (value index) #t)
             (lambda (pos value index) #t)))))

;; stop-value? : any/c any/c -> boolean?
;;   Decide whether an in-producer value stops the sequence.
(define (stop-value? stop value)
  (cond
    [(not stop) #f]
    [(procedure? stop) (stop value)]
    [else (eq? stop value)]))

;; in-producer : procedure? [any/c any/c ...] -> sequence?
;;   Return a sequence that repeatedly calls producer; stop defaults to no stop.
(define (in-producer producer [stop #f] . args)
  (unless (procedure? producer)
    (raise-argument-error 'in-producer "procedure?" producer))
  (make-do-sequence
   (lambda ()
     (define (produce) (apply producer args))
     (values values
             (lambda (_pos) (produce))
             (produce)
             (lambda (pos) (not (stop-value? stop pos)))
             #f
             #f))))

;; in-value : any/c -> sequence?
;;   Return a one-element sequence.
(define (in-value v)
  (list v))

;; check-sequences : symbol? (listof any/c) -> void?
;;   Validate sequence arguments.
(define (check-sequences who seqs)
  (for-each (lambda (seq)
              (unless (sequence? seq)
                (raise-argument-error who "sequence?" seq)))
            seqs))

;; append-sequences : (listof sequence?) boolean? -> sequence?
;;   Append sequences, cycling back to the start when cyclic? is true.
(define (append-sequences seqs cyclic?)
  (define (seqs->state rest)
    (cond
      [(pair? rest)
       (define-values (more? next) (sequence-generate (car rest)))
       (if (more?)
           (list* more? next (cdr rest))
           (seqs->state (cdr rest)))]
      [cyclic? (seqs->state seqs)]
      [else #f]))
  (make-do-sequence
   (lambda ()
     (values (lambda (state) ((cadr state)))
             (lambda (state)
               (if (and (pair? state) (not ((car state))))
                   (seqs->state (cddr state))
                   state))
             (seqs->state seqs)
             values
             #f
             #f))))

;; in-sequences : sequence? ... -> sequence?
;;   Return a sequence that appends the input sequences.
(define (in-sequences . seqs)
  (check-sequences 'in-sequences seqs)
  (if (and (pair? seqs) (null? (cdr seqs)))
      (car seqs)
      (append-sequences seqs #f)))

;; in-cycle : sequence? ... -> sequence?
;;   Return a cycling sequence over the input sequences.
(define (in-cycle . seqs)
  (check-sequences 'in-cycle seqs)
  (append-sequences seqs #t))

;; in-parallel : sequence? ... -> sequence?
;;   Return a sequence that produces one value from each input sequence.
(define (in-parallel . seqs)
  (check-sequences 'in-parallel seqs)
  (cond
    [(null? seqs) null]
    [(null? (cdr seqs)) (car seqs)]
    [else
     (make-do-sequence
      (lambda ()
        (define generators
          (map (lambda (seq)
                 (define-values (more? next) (sequence-generate seq))
                 (cons more? next))
               seqs))
        (values (lambda (_pos)
                  (apply values
                         (map (lambda (generator) ((cdr generator)))
                              generators)))
                (lambda (pos) pos)
                #t
                (lambda (_pos)
                  (andmap (lambda (generator) ((car generator)))
                          generators))
                (lambda vals #t)
                (lambda (pos . vals) #t))))]))

;; check-parallel-values-arguments : (listof any/c) -> (values list? list?)
;;   Split in-parallel-values arguments into sequences and value counts.
(define (check-parallel-values-arguments args)
  (let loop ([rest args] [seqs null] [counts null])
    (cond
      [(null? rest) (values (reverse seqs) (reverse counts))]
      [(not (exact-nonnegative-integer? (car rest)))
       (raise-argument-error 'in-parallel-values "exact-nonnegative-integer?" (car rest))]
      [(null? (cdr rest))
       (raise-arguments-error 'in-parallel-values "missing a sequence after its result count"
                              "result count" (car rest))]
      [(not (sequence? (cadr rest)))
       (raise-argument-error 'in-parallel-values "sequence?" (cadr rest))]
      [else (loop (cddr rest)
                  (cons (cadr rest) seqs)
                  (cons (car rest) counts))])))

;; take-values : symbol? exact-nonnegative-integer? list? -> list?
;;   Validate and return the values promised by an in-parallel-values count.
(define (take-values who count vals)
  (unless (= count (length vals))
    (raise-arguments-error who
                           "sequence produced the wrong number of values"
                           "expected" count
                           "received" (length vals)))
  vals)

;; in-parallel-values : exact-nonnegative-integer? sequence? ... -> sequence?
;;   Combine sequences in parallel while preserving each sequence's value count.
(define (in-parallel-values . args)
  (define-values (seqs counts) (check-parallel-values-arguments args))
  (cond
    [(null? seqs) null]
    [(null? (cdr seqs)) (car seqs)]
    [else
     (make-do-sequence
      (lambda ()
        (define generators
          (map (lambda (seq count)
                 (define-values (more? next) (sequence-generate seq))
                 (list more? next count))
               seqs
               counts))
        (values (lambda (_pos)
                  (apply values
                         (apply append
                                (map (lambda (generator)
                                       (take-values 'in-parallel-values
                                                    (caddr generator)
                                                    (call-with-values (cadr generator) list)))
                                     generators))))
                (lambda (pos) pos)
                #t
                (lambda (_pos)
                  (andmap (lambda (generator) ((car generator)))
                          generators))
                (lambda vals #t)
                (lambda (pos . vals) #t))))]))

;; sorted-paths : (listof path?) -> (listof path?)
;;   Sort paths without importing racket/list's `sort`, which lowers as sort.1.
(define (sorted-paths paths)
  (define (insert path sorted)
    (cond
      [(null? sorted) (list path)]
      [(path<? path (car sorted)) (cons path sorted)]
      [else (cons (car sorted) (insert path (cdr sorted)))]))
  (let loop ([rest paths] [sorted null])
    (cond
      [(null? rest) sorted]
      [else (loop (cdr rest) (insert (car rest) sorted))])))

;; dir-list : path-string? path-string? list? -> list?
;;   Return d's immediate children, sorted and prefixed for in-directory state.
(define (dir-list full-d d acc)
  (append (map (lambda (f) (build-path d f))
               (sorted-paths (directory-list full-d)))
          acc))

;; next-body : list? path-string? path-string? procedure? -> list?
;;   Advance an in-directory traversal, descending when use-dir? permits it.
(define (next-body state d init-dir use-dir?)
  (define full-d (path->complete-path d init-dir))
  (if (and (directory-exists? full-d)
           (use-dir? full-d))
      (dir-list full-d d (cdr state))
      (cdr state)))

;; initial-state : (or/c #f path-string?) path-string? -> list?
;;   Build the initial in-directory traversal state.
(define (initial-state orig-dir init-dir)
  (if orig-dir
      (dir-list (path->complete-path orig-dir init-dir) orig-dir null)
      (sorted-paths (directory-list init-dir))))

;; in-directory : [(or/c #f path-string?)] [(complete-path? -> any/c)] -> sequence?
;;   Recursively traverse a directory. Optional dir defaults to #f and use-dir? defaults to always true.
(define in-directory
  (case-lambda
    [() (in-directory #f (lambda (_dir) #t))]
    [(orig-dir) (in-directory orig-dir (lambda (_dir) #t))]
    [(orig-dir use-dir?)
     (unless (or (not orig-dir) (path-string? orig-dir))
       (raise-argument-error 'in-directory "(or/c #f path-string?)" orig-dir))
     (unless (procedure? use-dir?)
       (raise-argument-error 'in-directory "procedure?" use-dir?))
     (make-do-sequence
      (lambda ()
        (define init-dir (current-directory))
        (values car
                (lambda (state) (next-body state (car state) init-dir use-dir?))
                (initial-state orig-dir init-dir)
                pair?
                #f
                #f)))]))

;; next-values : (-> boolean?) (-> values) -> (or/c list? #f)
;;   Pull the next sequence element as a list of values.
(define (next-values more? next)
  (and (more?) (call-with-values next list)))

;; generated-value-list-sequence : sequence? (list? -> list?) -> sequence?
;;   Build a sequence by transforming each generated element's value list.
(define (generated-value-list-sequence seq transform)
  (define-values (more? next) (sequence-generate seq))
  (define (advance)
    (define vals (next-values more? next))
    (and vals (cons #t (transform vals))))
  (define (continue-values? . _vals) #t)
  (define (continue-position+values? _pos . _vals) #t)
  (make-do-sequence
   (lambda ()
     (values (lambda (state) (apply values (cdr state)))
             (lambda (_state) (advance))
             (advance)
             pair?
             continue-values?
             continue-position+values?))))

;; in-values-sequence : sequence? -> sequence?
;;   Convert each element's values into one list value.
(define (in-values-sequence seq)
  (unless (sequence? seq)
    (raise-argument-error 'in-values-sequence "sequence?" seq))
  (generated-value-list-sequence seq list))

;; in-values*-sequence : sequence? -> sequence?
;;   Like in-values-sequence, but leave a single non-list value unwrapped.
(define (in-values*-sequence seq)
  (unless (sequence? seq)
    (raise-argument-error 'in-values*-sequence "sequence?" seq))
  (generated-value-list-sequence
   seq
   (lambda (vals)
     (cond
       [(and (null? (cdr vals)) (not (list? (car vals)))) vals]
       [else (list vals)]))))

;; check-stop-sequence : symbol? any/c any/c -> void?
;;   Validate common stop-before/stop-after arguments.
(define (check-stop-sequence who seq pred)
  (unless (sequence? seq)
    (raise-argument-error who "sequence?" seq))
  (unless (procedure? pred)
    (raise-argument-error who "procedure?" pred)))

;; stopped-sequence : symbol? sequence? procedure? boolean? -> sequence?
;;   Build a sequence that stops before or after the matching element.
(define (stopped-sequence who seq pred include-matching?)
  (check-stop-sequence who seq pred)
  (define-values (more? next) (sequence-generate seq))
  (define (advance)
    (define vals (next-values more? next))
    (cond
      [(not vals) #f]
      [(apply pred vals) (and include-matching? (cons #t vals))]
      [else (cons #f vals)]))
  (define (continue-values? . _vals) #t)
  (define (continue-position+values? _pos . _vals) #t)
  (make-do-sequence
   (lambda ()
     (values (lambda (state) (apply values (cdr state)))
             (lambda (state)
               (and (not (car state)) (advance)))
             (advance)
             pair?
             continue-values?
             continue-position+values?))))

;; stop-before : sequence? procedure? -> sequence?
;;   Stop before the first element whose values satisfy pred.
(define (stop-before seq pred)
  (stopped-sequence 'stop-before seq pred #f))

;; stop-after : sequence? procedure? -> sequence?
;;   Include the first element whose values satisfy pred, then stop.
(define (stop-after seq pred)
  (stopped-sequence 'stop-after seq pred #t))
