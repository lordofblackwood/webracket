#lang racket/base

(require racket/cmdline
         racket/list
         racket/string
         "../test/numbers/cases.rkt"
         "check-number-tower-cs.rkt")

;; parse-symbol-list : string? -> (listof symbol?)
;;   Parse a comma-separated command-line symbol list.
(define (parse-symbol-list s)
  (filter values
          (for/list ([part (in-list (string-split s ","))])
            (define trimmed (string-trim part))
            (and (not (string=? trimmed ""))
                 (string->symbol trimmed)))))

;; print-source-summary : -> void?
;;   Print the source manifest and generated port accounting.
(define (print-source-summary)
  (for ([source (in-list number-port-sources)])
    (define source-id (number-port-source-id source))
    (define cases
      (select-number-port-cases #:sources (list source-id)
                                #:include-non-gates? #t))
    (define skips
      (select-number-port-skips #:sources (list source-id)))
    (printf "~a cases=~a skips=~a path=~a\n"
            source-id
            (length cases)
            (length skips)
            (number-port-source-path source))))

;; main : -> void?
;;   Run the source-backed number port oracle.
(define (main)
  (define cs-path (default-racket-cs-path))
  (define webracket-racket-path (default-webracket-racket-path))
  (define sources '())
  (define groups '())
  (define ids '())
  (define include-non-gates? #f)
  (define list-sources? #f)
  (define list-groups? #f)
  (define list-cases? #f)
  (command-line
   #:program "check-numbers-cs"
   #:once-each
   [("--cs") path "Racket CS executable path"
             (set! cs-path path)]
   [("--webracket-racket") path "Racket executable for WebRacket compilation"
                           (set! webracket-racket-path path)]
   [("--all") "Run recorded non-gating generated cases as well as gates"
              (set! include-non-gates? #t)]
   [("--list-sources") "List upstream source accounting and exit"
                       (set! list-sources? #t)]
   [("--list-groups") "List number port groups and exit"
                      (set! list-groups? #t)]
   [("--list-cases") "List selected cases and exit"
                     (set! list-cases? #t)]
   #:multi
   [("--source") source "Run one source id or a comma-separated source list"
                (set! sources (append sources (parse-symbol-list source)))]
   [("--group") group "Run one group or a comma-separated group list"
               (set! groups (append groups (parse-symbol-list group)))]
   [("--case") id "Run one case id or a comma-separated case id list"
              (set! ids (append ids (parse-symbol-list id)))])
  (cond
    [list-sources?
     (print-source-summary)]
    [list-groups?
     (for ([group (in-list (number-port-groups))])
       (printf "~a\n" group))]
    [else
     (define selected-cases
       (select-number-port-cases #:sources sources
                                 #:groups groups
                                 #:ids ids
                                 #:include-non-gates? include-non-gates?))
     (when list-cases?
       (for ([c (in-list selected-cases)])
         (printf "~a ~a source=~a line=~a gate=~a\n"
                 (number-port-case-group c)
                 (number-port-case-id c)
                 (number-port-case-source c)
                 (number-port-case-line c)
                 (number-port-case-gate? c))))
     (unless list-cases?
       (define summary
         (run-number-tower-cases
          (number-port-cases->number-tower-cases selected-cases)
          #:cs-path cs-path
          #:webracket-racket-path webracket-racket-path))
       (print-number-tower-summary summary)
       (when (positive? (summary-failure-count summary))
         (exit 1)))]))

(module+ main
  (main))
