#lang racket

(provide time-core-runtime-helpers
         time-core-runtime-helper-forms
         time-runtime-only-helpers
         time-runtime-string-constants
         time-date-runtime-symbol-constants
         time-clock-runtime-symbol-constants
         time-runtime-only-helper-names
         time-runtime-helper-forms)

(require "../core-helper.rkt")

;; time-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by date and time helpers.
(define time-runtime-string-constants
  '((date?  "date?")
    (date*? "date*?")
    (integer-in-0-60 "(integer-in 0 60)")
    (integer-in-0-59 "(integer-in 0 59)")
    (integer-in-0-23 "(integer-in 0 23)")
    (integer-in-1-31 "(integer-in 1 31)")
    (integer-in-1-12 "(integer-in 1 12)")
    (integer-in-0-6  "(integer-in 0 6)")
    (integer-in-0-365 "(integer-in 0 365)")
    (integer-in-0-999999999 "(integer-in 0 999999999)")
    (process-milliseconds-scope "(or/c #f thread? 'subprocesses)")
    (UTC    "UTC")
    (local  "local")))

;; time-date-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by date predicates, constructors, and accessors.
(define time-date-runtime-symbol-constants
  '(date?
    date
    make-date
    date*?
    date*
    make-date*
    date-second
    date-minute
    date-hour
    date-day
    date-month
    date-year
    date-week-day
    date-year-day
    date-dst?
    date-time-zone-offset
    date*-nanosecond
    date*-time-zone-name))

;; time-clock-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by current-time and seconds->date helpers.
(define time-clock-runtime-symbol-constants
  '(current-seconds
    current-inexact-milliseconds
    current-milliseconds
    current-process-milliseconds
    current-gc-milliseconds
    subprocesses
    seconds->date
    current-date))

;; time-runtime-only-forms : (listof datum?)
;;   Enumerate date and time helpers used by the monolithic runtime.
(define time-runtime-only-forms
  '(
    ;; date? : any/c -> boolean?
    ;;   Recognize WebRacket date and date* records.
    (func $date? (type $Prim1)
          (param $v (ref eq))
          (result   (ref eq))
          (if (result (ref eq))
              (ref.test (ref $Date) (local.get $v))
              (then (global.get $true))
              (else (global.get $false))))

    ;; date*? : any/c -> boolean?
    ;;   Recognize WebRacket date* records.
    (func $date*? (type $Prim1)
          (param $v (ref eq))
          (result   (ref eq))
          (if (result (ref eq))
              (ref.test (ref $DateStar) (local.get $v))
              (then (global.get $true))
              (else (global.get $false))))

    ;; exact-fixnum-in-range? : any/c i32 i32 -> i32
    ;;   Validate the fixnum subset used by date range fields.
    (func $exact-fixnum-in-range?
          (param $v    (ref eq))
          (param $low  i32)
          (param $high i32)
          (result      i32)
          (local $raw i32)
          (local $n   i32)
          (if (i32.eqz (ref.test (ref i31) (local.get $v)))
              (then (return (i32.const 0))))
          (local.set $raw (i31.get_s (ref.cast (ref i31) (local.get $v))))
          (if (i32.ne (i32.and (local.get $raw) (i32.const 1)) (i32.const 0))
              (then (return (i32.const 0))))
          (local.set $n (i32.shr_s (local.get $raw) (i32.const 1)))
          (i32.and (i32.ge_s (local.get $n) (local.get $low))
                   (i32.le_s (local.get $n) (local.get $high))))

    ;; ensure-date-range-field : symbol? string? any/c i32 i32 -> any/c
    ;;   Check a date range field and return it unchanged.
    (func $ensure-date-range-field
          (param $who      (ref eq))
          (param $expected (ref eq))
          (param $v        (ref eq))
          (param $low      i32)
          (param $high     i32)
          (result          (ref eq))
          (if (i32.eqz (call $exact-fixnum-in-range?
                             (local.get $v)
                             (local.get $low)
                             (local.get $high)))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (local.get $expected)
                          (local.get $v))
                    (unreachable)))
          (local.get $v))

    ;; ensure-date-exact-integer-field : symbol? any/c -> any/c
    ;;   Check a date field documented as exact-integer?.
    (func $ensure-date-exact-integer-field
          (param $who (ref eq))
          (param $v   (ref eq))
          (result     (ref eq))
          (if (ref.eq (call $exact-integer? (local.get $v)) (global.get $false))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:exact-integer?)
                          (local.get $v))
                    (unreachable)))
          (local.get $v))

    ;; ensure-date-boolean-field : symbol? any/c -> boolean?
    ;;   Check the date dst? field.
    (func $ensure-date-boolean-field
          (param $who (ref eq))
          (param $v   (ref eq))
          (result     (ref eq))
          (if (ref.eq (call $boolean? (local.get $v)) (global.get $false))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:boolean?)
                          (local.get $v))
                    (unreachable)))
          (local.get $v))

    ;; make-date/checked : fields -> date?
    ;;   Construct a date after validation.
    (func $make-date/checked
          (param $who              (ref eq))
          (param $second           (ref eq))
          (param $minute           (ref eq))
          (param $hour             (ref eq))
          (param $day              (ref eq))
          (param $month            (ref eq))
          (param $year             (ref eq))
          (param $week-day         (ref eq))
          (param $year-day         (ref eq))
          (param $dst?             (ref eq))
          (param $time-zone-offset (ref eq))
          (result                  (ref eq))
          (struct.new $Date
                      (i32.const 0)
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-0-60) (local.get $second) (i32.const 0) (i32.const 60))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-0-59) (local.get $minute) (i32.const 0) (i32.const 59))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-0-23) (local.get $hour) (i32.const 0) (i32.const 23))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-1-31) (local.get $day) (i32.const 1) (i32.const 31))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-1-12) (local.get $month) (i32.const 1) (i32.const 12))
                      (call $ensure-date-exact-integer-field (local.get $who) (local.get $year))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-0-6) (local.get $week-day) (i32.const 0) (i32.const 6))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-0-365) (local.get $year-day) (i32.const 0) (i32.const 365))
                      (call $ensure-date-boolean-field (local.get $who) (local.get $dst?))
                      (call $ensure-date-exact-integer-field (local.get $who) (local.get $time-zone-offset))))

    ;; make-date*/checked : fields -> date*?
    ;;   Construct a date* after validation, copying the zone name to an
    ;;   immutable string as specified by the Reference.
    (func $make-date*/checked
          (param $who              (ref eq))
          (param $second           (ref eq))
          (param $minute           (ref eq))
          (param $hour             (ref eq))
          (param $day              (ref eq))
          (param $month            (ref eq))
          (param $year             (ref eq))
          (param $week-day         (ref eq))
          (param $year-day         (ref eq))
          (param $dst?             (ref eq))
          (param $time-zone-offset (ref eq))
          (param $nanosecond       (ref eq))
          (param $time-zone-name   (ref eq))
          (result                  (ref eq))
          (if (i32.eqz (ref.test (ref $String) (local.get $time-zone-name)))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:string?)
                          (local.get $time-zone-name))
                    (unreachable)))
          (struct.new $DateStar
                      (i32.const 0)
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-0-60) (local.get $second) (i32.const 0) (i32.const 60))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-0-59) (local.get $minute) (i32.const 0) (i32.const 59))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-0-23) (local.get $hour) (i32.const 0) (i32.const 23))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-1-31) (local.get $day) (i32.const 1) (i32.const 31))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-1-12) (local.get $month) (i32.const 1) (i32.const 12))
                      (call $ensure-date-exact-integer-field (local.get $who) (local.get $year))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-0-6) (local.get $week-day) (i32.const 0) (i32.const 6))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-0-365) (local.get $year-day) (i32.const 0) (i32.const 365))
                      (call $ensure-date-boolean-field (local.get $who) (local.get $dst?))
                      (call $ensure-date-exact-integer-field (local.get $who) (local.get $time-zone-offset))
                      (call $ensure-date-range-field (local.get $who) (global.get $string:integer-in-0-999999999) (local.get $nanosecond) (i32.const 0) (i32.const 999999999))
                      (ref.cast (ref $String)
                                (call $string->immutable-string (local.get $time-zone-name)))))

    ;; date : fields -> date?
    ;;   Rest-style primitive because WebRacket does not yet have exact
    ;;   fixed primitive shapes for arity 10.
    (func $date (type $Prim>=0)
          (param $args (ref eq)) ;; argument array
          (result      (ref eq))
          (local $argv (ref $Array))
          (local.set $argv (call $make-array (i32.const 0) (global.get $null)))
          (if (ref.test (ref $Args) (local.get $args))
              (then
               (local.set $argv
                          (call $list->array
                                (call $rest-arguments->list
                                      (ref.cast (ref $Args) (local.get $args))
                                      (i32.const 0)))))
              (else
               (local.set $argv (call $list->array (local.get $args)))))
          (if (i32.ne (array.len (local.get $argv)) (i32.const 10))
              (then (call $raise-arity-mismatch/name+given
                          (global.get $symbol:date)
                          (array.len (local.get $argv)))
                    (unreachable)))
          (call $make-date/checked
                (global.get $symbol:date)
                (array.get $Array (local.get $argv) (i32.const 0))
                (array.get $Array (local.get $argv) (i32.const 1))
                (array.get $Array (local.get $argv) (i32.const 2))
                (array.get $Array (local.get $argv) (i32.const 3))
                (array.get $Array (local.get $argv) (i32.const 4))
                (array.get $Array (local.get $argv) (i32.const 5))
                (array.get $Array (local.get $argv) (i32.const 6))
                (array.get $Array (local.get $argv) (i32.const 7))
                (array.get $Array (local.get $argv) (i32.const 8))
                (array.get $Array (local.get $argv) (i32.const 9))))

    ;; make-date : fields -> date?
    ;;   Alias for the `date` constructor.
    (func $make-date (type $Prim>=0)
          (param $args (ref eq))
          (result      (ref eq))
          (return_call $date (local.get $args)))

    ;; date* : fields -> date*?
    ;;   Rest-style primitive because WebRacket does not yet have exact
    ;;   fixed primitive shapes for arity 12.
    (func $date* (type $Prim>=0)
          (param $args (ref eq)) ;; argument array
          (result      (ref eq))
          (local $argv (ref $Array))
          (local.set $argv (call $make-array (i32.const 0) (global.get $null)))
          (if (ref.test (ref $Args) (local.get $args))
              (then
               (local.set $argv
                          (call $list->array
                                (call $rest-arguments->list
                                      (ref.cast (ref $Args) (local.get $args))
                                      (i32.const 0)))))
              (else
               (local.set $argv (call $list->array (local.get $args)))))
          (if (i32.ne (array.len (local.get $argv)) (i32.const 12))
              (then (call $raise-arity-mismatch/name+given
                          (global.get $symbol:date*)
                          (array.len (local.get $argv)))
                    (unreachable)))
          (call $make-date*/checked
                (global.get $symbol:date*)
                (array.get $Array (local.get $argv) (i32.const 0))
                (array.get $Array (local.get $argv) (i32.const 1))
                (array.get $Array (local.get $argv) (i32.const 2))
                (array.get $Array (local.get $argv) (i32.const 3))
                (array.get $Array (local.get $argv) (i32.const 4))
                (array.get $Array (local.get $argv) (i32.const 5))
                (array.get $Array (local.get $argv) (i32.const 6))
                (array.get $Array (local.get $argv) (i32.const 7))
                (array.get $Array (local.get $argv) (i32.const 8))
                (array.get $Array (local.get $argv) (i32.const 9))
                (array.get $Array (local.get $argv) (i32.const 10))
                (array.get $Array (local.get $argv) (i32.const 11))))

    ;; make-date* : fields -> date*?
    ;;   Alias for the `date*` constructor.
    (func $make-date* (type $Prim>=0)
          (param $args (ref eq))
          (result      (ref eq))
          (return_call $date* (local.get $args)))

    (func $ensure-date
          (param $who (ref eq))
          (param $v   (ref eq))
          (result     (ref $Date))
          (if (i32.eqz (ref.test (ref $Date) (local.get $v)))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:date?)
                          (local.get $v))
                    (unreachable)))
          (ref.cast (ref $Date) (local.get $v)))

    (func $ensure-date*
          (param $who (ref eq))
          (param $v   (ref eq))
          (result     (ref $DateStar))
          (if (i32.eqz (ref.test (ref $DateStar) (local.get $v)))
              (then (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:date*?)
                          (local.get $v))
                    (unreachable)))
          (ref.cast (ref $DateStar) (local.get $v)))

    (func $date-second           (type $Prim1) (param $v (ref eq)) (result (ref eq)) (struct.get $Date $second           (call $ensure-date (global.get $symbol:date-second)           (local.get $v))))
    (func $date-minute           (type $Prim1) (param $v (ref eq)) (result (ref eq)) (struct.get $Date $minute           (call $ensure-date (global.get $symbol:date-minute)           (local.get $v))))
    (func $date-hour             (type $Prim1) (param $v (ref eq)) (result (ref eq)) (struct.get $Date $hour             (call $ensure-date (global.get $symbol:date-hour)             (local.get $v))))
    (func $date-day              (type $Prim1) (param $v (ref eq)) (result (ref eq)) (struct.get $Date $day              (call $ensure-date (global.get $symbol:date-day)              (local.get $v))))
    (func $date-month            (type $Prim1) (param $v (ref eq)) (result (ref eq)) (struct.get $Date $month            (call $ensure-date (global.get $symbol:date-month)            (local.get $v))))
    (func $date-year             (type $Prim1) (param $v (ref eq)) (result (ref eq)) (struct.get $Date $year             (call $ensure-date (global.get $symbol:date-year)             (local.get $v))))
    (func $date-week-day         (type $Prim1) (param $v (ref eq)) (result (ref eq)) (struct.get $Date $week-day         (call $ensure-date (global.get $symbol:date-week-day)         (local.get $v))))
    (func $date-year-day         (type $Prim1) (param $v (ref eq)) (result (ref eq)) (struct.get $Date $year-day         (call $ensure-date (global.get $symbol:date-year-day)         (local.get $v))))
    (func $date-dst?             (type $Prim1) (param $v (ref eq)) (result (ref eq)) (struct.get $Date $dst?             (call $ensure-date (global.get $symbol:date-dst?)             (local.get $v))))
    (func $date-time-zone-offset (type $Prim1) (param $v (ref eq)) (result (ref eq)) (struct.get $Date $time-zone-offset (call $ensure-date (global.get $symbol:date-time-zone-offset) (local.get $v))))
    (func $date*-nanosecond      (type $Prim1) (param $v (ref eq)) (result (ref eq)) (struct.get $DateStar $nanosecond   (call $ensure-date* (global.get $symbol:date*-nanosecond)     (local.get $v))))
    (func $date*-time-zone-name  (type $Prim1) (param $v (ref eq)) (result (ref eq)) (struct.get $DateStar $time-zone-name (call $ensure-date* (global.get $symbol:date*-time-zone-name) (local.get $v))))

    ;; real->f64/date : symbol? real? -> f64
    ;;   Convert a date/time real argument to a host double.
    (func $real->f64/date
          (param $who (ref eq))
          (param $v   (ref eq))
          (result     f64)
          (local $f64  f64)
          (if (ref.test (ref $Flonum) (local.get $v))
              (then
               (local.set $f64
                          (struct.get $Flonum $v
                                      (ref.cast (ref $Flonum) (local.get $v))))
               (if (f64.ne (local.get $f64) (local.get $f64))
                   (then (call $raise-inexact->exact:no-exact-representation
                               (local.get $v))
                         (unreachable)))
               (if (f64.eq (local.get $f64) (f64.const +inf))
                   (then (call $raise-inexact->exact:no-exact-representation
                               (local.get $v))
                         (unreachable)))
               (if (f64.eq (local.get $f64) (f64.const -inf))
                   (then (call $raise-inexact->exact:no-exact-representation
                               (local.get $v))
                         (unreachable)))
               (return (local.get $f64))))
          (if (call $exact-rational?/i32 (local.get $v))
              (then (return (call $exact-rational->f64 (local.get $v)))))
          (call $raise-expected-real (local.get $who) (local.get $v))
          (unreachable))

    ;; current-inexact-milliseconds : -> flonum?
    ;;   Return Date.now(), including any fractional milliseconds.
    (func $current-inexact-milliseconds (type $Prim0)
          (result (ref eq))
          (struct.new $Flonum
                      (i32.const 0)
                      (call $js-current-inexact-milliseconds)))

    ;; current-milliseconds : -> exact-integer?
    ;;   Return a fixnum-wrapped millisecond count, matching Racket's
    ;;   "coerced to a fixnum" contract on small-fixnum platforms.
    (func $current-milliseconds (type $Prim0)
          (result (ref eq))
          (ref.i31 (call $js-current-milliseconds-bits)))

    ;; current-seconds : -> exact-integer?
    ;;   Return whole seconds since the Unix epoch.
    (func $current-seconds (type $Prim0)
          (result (ref eq))
          (ref.i31
           (i32.shl
            (i32.trunc_f64_s
             (f64.div (call $js-current-inexact-milliseconds)
                      (f64.const 1000)))
            (i32.const 1))))

    ;; current-process-milliseconds : [(or/c #f thread? 'subprocesses)] -> exact-integer?
    ;;   Browser JavaScript does not expose Racket-style process CPU time;
    ;;   use the wall-clock fixnum value as a bootstrap approximation for
    ;;   accepted scopes.
    (func $current-process-milliseconds (type $Prim01)
          (param $scope (ref eq)) ;; optional: #f, thread?, or 'subprocesses
          (result (ref eq))
          (if (i32.and
               (i32.and
                (i32.eqz (ref.eq (local.get $scope) (global.get $missing)))
                (i32.eqz (ref.eq (local.get $scope) (global.get $false))))
               (i32.and
                (i32.eqz (ref.test (ref $Thread) (local.get $scope)))
                (i32.eqz (ref.eq (local.get $scope) (global.get $symbol:subprocesses)))))
              (then (call $raise-argument-error1
                          (global.get $symbol:current-process-milliseconds)
                          (global.get $string:process-milliseconds-scope)
                          (local.get $scope))
                    (unreachable)))
          (return_call $current-milliseconds))

    ;; current-gc-milliseconds : -> exact-integer?
    ;;   JS GC accounting is not available to WebAssembly modules.
    (func $current-gc-milliseconds (type $Prim0)
          (result (ref eq))
          (global.get $zero))

    ;; seconds->date : real? [any/c] -> date*?
    ;;   Use the JavaScript Date implementation to decompose wall-clock
    ;;   seconds. The timezone-name field is precise for UTC and a stable
    ;;   "local" placeholder for local time until WebRacket has a richer
    ;;   timezone/rktio layer.
    (func $seconds->date (type $Prim12)
          (param $secs        (ref eq)) ;; real?
          (param $local-time? (ref eq)) ;; optional any/c; default #t
          (result             (ref eq))
          (local $secs-f64 f64)
          (local $local    i32)
          (local.set $secs-f64
                     (call $real->f64/date
                           (global.get $symbol:seconds->date)
                           (local.get $secs)))
          (local.set $local
                     (if (result i32)
                         (ref.eq (local.get $local-time?) (global.get $false))
                         (then (i32.const 0))
                         (else (i32.const 1))))
          (call $make-date*/checked
                (global.get $symbol:seconds->date)
                (ref.i31 (i32.shl (call $js-date-field (local.get $secs-f64) (local.get $local) (i32.const 0)) (i32.const 1)))
                (ref.i31 (i32.shl (call $js-date-field (local.get $secs-f64) (local.get $local) (i32.const 1)) (i32.const 1)))
                (ref.i31 (i32.shl (call $js-date-field (local.get $secs-f64) (local.get $local) (i32.const 2)) (i32.const 1)))
                (ref.i31 (i32.shl (call $js-date-field (local.get $secs-f64) (local.get $local) (i32.const 3)) (i32.const 1)))
                (ref.i31 (i32.shl (call $js-date-field (local.get $secs-f64) (local.get $local) (i32.const 4)) (i32.const 1)))
                (ref.i31 (i32.shl (call $js-date-field (local.get $secs-f64) (local.get $local) (i32.const 5)) (i32.const 1)))
                (ref.i31 (i32.shl (call $js-date-field (local.get $secs-f64) (local.get $local) (i32.const 6)) (i32.const 1)))
                (ref.i31 (i32.shl (call $js-date-field (local.get $secs-f64) (local.get $local) (i32.const 7)) (i32.const 1)))
                (if (result (ref eq))
                    (i32.eqz (local.get $local))
                    (then (global.get $false))
                    (else (if (result (ref eq))
                              (i32.eqz (call $js-date-field (local.get $secs-f64) (local.get $local) (i32.const 8)))
                              (then (global.get $false))
                              (else (global.get $true)))))
                (ref.i31 (i32.shl (call $js-date-field (local.get $secs-f64) (local.get $local) (i32.const 9)) (i32.const 1)))
                (ref.i31 (i32.shl (call $js-date-field (local.get $secs-f64) (local.get $local) (i32.const 10)) (i32.const 1)))
                (if (result (ref eq))
                    (i32.eqz (local.get $local))
                    (then (global.get $string:UTC))
                    (else (global.get $string:local)))))

    ;; current-date : -> date*?
    ;;   Equivalent to `(seconds->date (* 0.001 (current-inexact-milliseconds)))`.
    (func $current-date (type $Prim0)
          (result (ref eq))
          (call $seconds->date
                (struct.new $Flonum
                            (i32.const 0)
                            (f64.div (call $js-current-inexact-milliseconds)
                                     (f64.const 1000)))
                (global.get $true)))))

;; time-all-runtime-helper-names : (listof symbol?)
;;   Preserve the full runtime emission order for time helpers.
(define time-all-runtime-helper-names
  (for/list ([form (in-list time-runtime-only-forms)])
    (cadr form)))

;; time-core-runtime-helper-names : (listof symbol?)
;;   Name time helpers available in the standalone core runtime.
(define time-core-runtime-helper-names
  time-all-runtime-helper-names)

;; time-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime-only time helper emission order.
(define time-runtime-only-helper-names
  (remove* time-core-runtime-helper-names
           time-all-runtime-helper-names))

;; time-all-runtime-helpers : (listof core-runtime-helper?)
;;   Register all date and time helpers.
(define time-all-runtime-helpers
  (function-forms->runtime-helpers
   'time-all-runtime-helpers
   time-runtime-only-forms))

;; time-core-runtime-helpers : (listof core-runtime-helper?)
;;   Register time helpers available in the standalone core runtime.
(define time-core-runtime-helpers
  (select-runtime-helpers time-all-runtime-helpers
                          time-core-runtime-helper-names))

;; time-runtime-only-helpers : (listof core-runtime-helper?)
;;   Register date and time helpers that still depend on monolithic runtime definitions.
(define time-runtime-only-helpers
  (remove-runtime-helpers time-all-runtime-helpers
                          time-core-runtime-helper-names))

;; time-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted time helpers in runtime assembly order.
(define (time-core-runtime-helper-forms helper-index)
  (for/list ([name (in-list time-core-runtime-helper-names)])
    (core-runtime-helper-form helper-index name)))

;; time-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render date and time helpers in runtime assembly order.
(define (time-runtime-helper-forms helper-index)
  (for/list ([name (in-list time-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define time-helper-index
    (make-core-runtime-helper-index
     (append time-core-runtime-helpers
             time-runtime-only-helpers)))

  (define time-core-helper-index
    (make-core-runtime-helper-index time-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name time-core-runtime-helpers)
   time-core-runtime-helper-names)

  (check-equal?
   (map form-name (time-core-runtime-helper-forms time-core-helper-index))
   time-core-runtime-helper-names)

  (check-equal?
   (map form-name (time-runtime-helper-forms time-helper-index))
   time-runtime-only-helper-names))
