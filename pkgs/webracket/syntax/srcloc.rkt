#lang racket/base

(provide source-location?
         source-location-list?
         source-location-vector?
         check-source-location!
         build-source-location
         build-source-location-list
         build-source-location-vector
         build-source-location-syntax
         source-location-known?
         source-location-source
         source-location-line
         source-location-column
         source-location-position
         source-location-span
         source-location-end
         update-source-location
         source-location->string
         source-location->prefix)

;; A small, format-free substitute for `syntax/srcloc`. The installed module is
;; mostly self-contained, but its compiled linklet keeps ambient `format`
;; references that are not currently exposed as ordinary provider imports.

;; process-source-location : any/c procedure? procedure? symbol? -> any/c
;;   Dispatch over the supported source-location representations.
(define (process-source-location x good bad name)
  (cond
    [(not x)      (process-elements x good bad name #f #f #f #f #f)]
    [(srcloc? x)  (process-elements x good bad name
                                    (srcloc-source x)
                                    (srcloc-line x)
                                    (srcloc-column x)
                                    (srcloc-position x)
                                    (srcloc-span x))]
    [(or (null? x) (pair? x)) (process-list x good bad name)]
    [(vector? x)  (process-vector x good bad name)]
    [(syntax? x)  (process-elements x good bad name
                                    (syntax-source x)
                                    (syntax-line x)
                                    (syntax-column x)
                                    (syntax-position x)
                                    (syntax-span x))]
    [else         (bad name x)]))

;; process-elements : any/c procedure? procedure? symbol? any/c any/c any/c any/c any/c -> any/c
;;   Validate line/column/position/span shape before calling good.
(define (process-elements x good bad name src line col pos span)
  (cond
    [(and line (not (exact-positive-integer? line))) (bad name x)]
    [(and col (not (exact-nonnegative-integer? col))) (bad name x)]
    [(and col (not line)) (bad name x)]
    [(and pos (not (exact-positive-integer? pos))) (bad name x)]
    [(and span (not (exact-nonnegative-integer? span))) (bad name x)]
    [else (good x src line col pos span)]))

;; process-list : any/c procedure? procedure? symbol? -> any/c
;;   Validate and unpack list source locations.
(define (process-list x good bad name)
  (cond
    [(and (list? x) (= (length x) 5))
     (apply process-elements x good bad name x)]
    [else (bad name x)]))

;; process-vector : any/c procedure? procedure? symbol? -> any/c
;;   Validate and unpack vector source locations.
(define (process-vector x good bad name)
  (cond
    [(= (vector-length x) 5)
     (process-elements x good bad name
                       (vector-ref x 0)
                       (vector-ref x 1)
                       (vector-ref x 2)
                       (vector-ref x 3)
                       (vector-ref x 4))]
    [else (bad name x)]))

;; source-location? : any/c -> boolean?
;;   Recognize accepted source-location values.
(define (source-location? x)
  (process-source-location x
                           (lambda (_x _src _line _col _pos _span) #t)
                           (lambda (_name _x) #f)
                           'source-location?))

;; source-location-list? : any/c -> boolean?
;;   Recognize list source-location values.
(define (source-location-list? x)
  (process-list x
                (lambda (_x _src _line _col _pos _span) #t)
                (lambda (_name _x) #f)
                'source-location-list?))

;; source-location-vector? : any/c -> boolean?
;;   Recognize vector source-location values.
(define (source-location-vector? x)
  (and (vector? x)
       (process-vector x
                       (lambda (_x _src _line _col _pos _span) #t)
                       (lambda (_name _x) #f)
                       'source-location-vector?)))

;; check-source-location! : symbol? any/c -> void?
;;   Raise when x is not an accepted source-location value.
(define (check-source-location! name x)
  (process-source-location x
                           (lambda (_x _src _line _col _pos _span) (void))
                           (lambda (_name bad-value)
                             (raise-argument-error name
                                                   "source-location?"
                                                   bad-value))
                           name))

;; accessor : symbol? procedure? -> procedure?
;;   Build a source-location accessor.
(define ((accessor name select) x)
  (process-source-location x
                           (lambda (_x src line col pos span)
                             (select src line col pos span))
                           (lambda (_name bad-value)
                             (raise-argument-error name
                                                   "source-location?"
                                                   bad-value))
                           name))

;; source-location-known? : any/c -> boolean?
;;   Report whether a source location has source, line, column, or position.
(define source-location-known?
  (accessor 'source-location-known?
            (lambda (src line col pos _span)
              (and (or src line col pos) #t))))

;; source-location-source : any/c -> any/c
;;   Return the source component.
(define source-location-source
  (accessor 'source-location-source
            (lambda (src _line _col _pos _span) src)))

;; source-location-line : any/c -> any/c
;;   Return the line component.
(define source-location-line
  (accessor 'source-location-line
            (lambda (_src line _col _pos _span) line)))

;; source-location-column : any/c -> any/c
;;   Return the column component.
(define source-location-column
  (accessor 'source-location-column
            (lambda (_src _line col _pos _span) col)))

;; source-location-position : any/c -> any/c
;;   Return the position component.
(define source-location-position
  (accessor 'source-location-position
            (lambda (_src _line _col pos _span) pos)))

;; source-location-span : any/c -> any/c
;;   Return the span component.
(define source-location-span
  (accessor 'source-location-span
            (lambda (_src _line _col _pos span) span)))

;; source-location-end : any/c -> any/c
;;   Return position plus span when both are available.
(define source-location-end
  (accessor 'source-location-end
            (lambda (_src _line _col pos span)
              (and pos span (+ pos span)))))

(define dont-update (string->uninterned-symbol "Don't update!"))

;; update-source-location : any/c [#:source any/c] [#:line any/c] [#:column any/c] [#:position any/c] [#:span any/c] -> any/c
;;   Replace selected source-location fields.
(define (update-source-location x
                                #:source [src dont-update]
                                #:line [line dont-update]
                                #:column [col dont-update]
                                #:position [pos dont-update]
                                #:span [span dont-update])
  (process-source-location
   x
   (lambda (old old-src old-line old-col old-pos old-span)
     (define new-src  (if (eq? src dont-update) old-src src))
     (define new-line (if (eq? line dont-update) old-line line))
     (define new-col  (if (eq? col dont-update) old-col col))
     (define new-pos  (if (eq? pos dont-update) old-pos pos))
     (define new-span (if (eq? span dont-update) old-span span))
     (if (and (eq? new-src old-src)
              (eq? new-line old-line)
              (eq? new-col old-col)
              (eq? new-pos old-pos)
              (eq? new-span old-span))
         old
         (rebuild old new-src new-line new-col new-pos new-span)))
   (lambda (_name bad-value)
     (raise-argument-error 'update-source-location "source-location?" bad-value))
   'update-source-location))

;; rebuild : any/c any/c any/c any/c any/c any/c -> any/c
;;   Rebuild a source location preserving the original representation when possible.
(define (rebuild x src line col pos span)
  (cond
    [(syntax? x)
     (define disarmed (syntax-disarm x #f))
     (syntax-rearm
      (datum->syntax disarmed
                     (syntax-e disarmed)
                     (list src line col pos span)
                     disarmed
                     disarmed)
      x)]
    [(srcloc? x) (make-srcloc src line col pos span)]
    [(vector? x) (vector src line col pos span)]
    [(or (list? x) src line col pos span) (list src line col pos span)]
    [else #f]))

;; combine-source-locations : list? procedure? procedure? symbol? -> any/c
;;   Combine source locations from left to right.
(define (combine-source-locations locs good bad name)
  (define (loop loc src line col pos span rest)
    (cond
      [(null? rest) (good loc src line col pos span)]
      [else
       (process-source-location
        (car rest)
        (lambda (_loc2 src2 line2 col2 pos2 span2)
          (combine-two src line col pos span
                       src2 line2 col2 pos2 span2
                       (lambda (merged-src merged-line merged-col merged-pos merged-span)
                         (loop #f
                               merged-src
                               merged-line
                               merged-col
                               merged-pos
                               merged-span
                               (cdr rest)))))
        bad
        name)]))
  (cond
    [(null? locs) (process-source-location #f good bad name)]
    [else
     (process-source-location
      (car locs)
      (lambda (loc src line col pos span)
        (loop loc src line col pos span (cdr locs)))
      bad
      name)]))

;; combine-two : any/c any/c any/c any/c any/c any/c any/c any/c any/c any/c procedure? -> any/c
;;   Merge two unpacked source locations.
(define (combine-two src1 line1 col1 pos1 span1 src2 line2 col2 pos2 span2 good)
  (cond
    [(and src1 src2 (equal? src1 src2))
     (define-values (line col)
       (cond
         [(and line1 line2)
          (cond
            [(< line1 line2) (values line1 col1)]
            [(> line1 line2) (values line2 col2)]
            [else           (values line1 (if (and col1 col2) (min col1 col2) (or col1 col2)))])]
         [line1 (values line1 col1)]
         [line2 (values line2 col2)]
         [else  (values #f #f)]))
     (define-values (pos span)
       (cond
         [(and pos1 pos2)
          (define start (min pos1 pos2))
          (define end
            (cond
              [(and span1 span2) (max (+ pos1 span1) (+ pos2 span2))]
              [span1            (+ pos1 span1)]
              [span2            (+ pos2 span2)]
              [else             #f]))
          (values start (and end (- end start)))]
         [pos1 (values pos1 span1)]
         [pos2 (values pos2 span2)]
         [else (values #f #f)]))
     (good src1 line col pos span)]
    [else (good #f #f #f #f #f)]))

;; build-source-location : any/c ... -> any/c
;;   Combine source locations, producing an srcloc when needed.
(define (build-source-location . locs)
  (combine-source-locations locs
                            (lambda (old src line col pos span)
                              (if (srcloc? old) old (make-srcloc src line col pos span)))
                            (lambda (name bad-value)
                              (raise-argument-error name "source-location?" bad-value))
                            'build-source-location))

;; build-source-location-list : any/c ... -> list?
;;   Combine source locations, producing a list.
(define (build-source-location-list . locs)
  (combine-source-locations locs
                            (lambda (old src line col pos span)
                              (if (list? old) old (list src line col pos span)))
                            (lambda (name bad-value)
                              (raise-argument-error name "source-location?" bad-value))
                            'build-source-location-list))

;; build-source-location-vector : any/c ... -> vector?
;;   Combine source locations, producing a vector.
(define (build-source-location-vector . locs)
  (combine-source-locations locs
                            (lambda (old src line col pos span)
                              (if (vector? old) old (vector src line col pos span)))
                            (lambda (name bad-value)
                              (raise-argument-error name "source-location?" bad-value))
                            'build-source-location-vector))

;; build-source-location-syntax : any/c ... -> syntax?
;;   Combine source locations, producing a syntax object.
(define (build-source-location-syntax . locs)
  (combine-source-locations locs
                            (lambda (old src line col pos span)
                              (cond
                                [(syntax? old) old]
                                [(or (list? old) (vector? old)) (datum->syntax #f null old)]
                                [else (datum->syntax #f null (vector src line col pos span))]))
                            (lambda (name bad-value)
                              (raise-argument-error name "source-location?" bad-value))
                            'build-source-location-syntax))

;; any->display-string : any/c string? -> string?
;;   Convert common source values to strings without depending on `format`.
(define (any->display-string v default)
  (cond
    [(not v) default]
    [(string? v) v]
    [(path? v) (path->string v)]
    [(symbol? v) (symbol->string v)]
    [else default]))

;; position-suffix : any/c any/c any/c any/c -> string?
;;   Render the line/column or position/span suffix.
(define (position-suffix line col pos span)
  (cond
    [line
     (if col
         (string-append ":" (number->string line) ":" (number->string col))
         (string-append ":" (number->string line)))]
    [pos
     (if span
         (string-append "::" (number->string pos) "-" (number->string (+ pos span)))
         (string-append "::" (number->string pos)))]
    [else ""]))

;; source-location->string : any/c [string?] -> string?
;;   Render a source location as a compact string.
(define (source-location->string x [default ""])
  (process-source-location
   x
   (lambda (_x src line col pos span)
     (string-append (any->display-string src default)
                    (position-suffix line col pos span)))
   (lambda (name bad-value)
     (raise-argument-error name "source-location?" bad-value))
   'source-location->string))

;; source-location->prefix : any/c [string?] -> string?
;;   Render a source-location prefix with a trailing colon when non-empty.
(define (source-location->prefix x [default ""])
  (define str (source-location->string x default))
  (if (string=? str "") "" (string-append str ": ")))
