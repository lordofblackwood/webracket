#lang racket

;;; Check Treelist Shape Smoke
;;;

;; This tool runs a private WebRacket treelist shape smoke and validates the
;; emitted internal shape payload. It fits into runtime-layout debugging: the
;; companion smoke program runs under WebRacket, raises a structured payload,
;; and this host-side checker verifies that key treelist shapes look valid.
;;
;; Invoke it from the repository root:
;;
;;   racket tools/check-treelist-shape-smoke.rkt
;;
;; It prints nothing on success. If the payload is missing or a shape invariant
;; fails, it reports the captured compiler/runtime output and exits non-zero.


;;; Imports

;; The checker launches WebRacket as a subprocess, parses the raised payload,
;; and validates it with simple match/list helpers.

(require racket/list
         racket/file
         racket/match
         racket/port
         racket/string)


;;; Smoke Runner

;; This section locates the repository, materializes a temporary copy of the
;; internal smoke source, and runs it through the WebRacket command-line driver.

;; check-treelist-shape-smoke.rkt : -> void
;;   Run the compiler-private treelist shape smoke and fail on invalid shapes.

(define tools-dir
  (or (and (find-system-path 'run-file)
           (path-only (find-system-path 'run-file)))
      (current-load-relative-directory)
      (error 'check-treelist-shape-smoke "missing tool directory")))
(define repo-root (simplify-path (build-path tools-dir "..")))
(define webracket-file (build-path repo-root "webracket.rkt"))
(define smoke-template (build-path repo-root "tools" "treelist-shape-internal-smoke.rkt"))
(define racket-bin
  (or (find-executable-path "racket")
      (error 'check-treelist-shape-smoke "could not find racket executable")))

(define-values (stdout-text stderr-text status)
  (let* ([temp-dir (make-temporary-file "webracket-treelist-shape-~a" 'directory)]
         [temp-smoke-file (build-path temp-dir "treelist-shape-internal-smoke.rkt")])
    (dynamic-wind
      void
      (λ ()
        (copy-file smoke-template temp-smoke-file)
        (define-values (proc in out err)
          (parameterize ([current-directory repo-root])
            (subprocess #f #f #f
                        racket-bin
                        "-l" "errortrace"
                        "-t" (path->string webracket-file)
                        "--"
                        "--internal-bind-treelist-debug-shape"
                        "-r" (path->string temp-smoke-file))))
        (define stdout-text (port->string in))
        (define stderr-text (port->string err))
        (subprocess-wait proc)
        (values stdout-text stderr-text (subprocess-status proc)))
      (λ ()
        (when (directory-exists? temp-dir)
          (delete-directory/files temp-dir))))))

(define combined-text (string-append stdout-text stderr-text))


;;; Payload Parsing

;; The internal smoke raises its result so this checker can extract and parse a
;; single shape payload without relying on normal program output.

(define smoke-rx #px"treelist-shape-smoke: (\\(.*\\))")
(define smoke-match (regexp-match smoke-rx combined-text))
(unless smoke-match
  (display stdout-text)
  (display stderr-text (current-error-port))
  (error 'check-treelist-shape-smoke
         "failed to capture shape payload from internal smoke"))

(define payload-text (second smoke-match))
(define payload
  (with-input-from-string payload-text read))


;;; Shape Checks

;; These checks validate a mix of small, large, append-heavy, and nested
;; treelists. The exact set is intentionally narrow but covers the layout
;; invariants most likely to regress.

(define (shape-ref name)
  (define hit (assoc name payload))
  (unless hit
    (error 'check-treelist-shape-smoke "missing shape entry for ~a" name))
  (second hit))

(define (shape-valid-bit shape)
  (list-ref shape 5))

(define (expect-valid! name)
  (define shape (shape-ref name))
  (unless (= (shape-valid-bit shape) 1)
    (error 'check-treelist-shape-smoke
           "shape ~a failed validation: ~s" name shape)))

(for ([entry payload])
  (match entry
    [(list name shape)
     (unless (= (shape-valid-bit shape) 1)
       (error 'check-treelist-shape-smoke
              "shape ~a failed validation: ~s" name shape))]))

(define (expect-size-height-nodes! name size height nodes)
  (define shape (shape-ref name))
  (match shape
    [(list got-size got-height got-nodes _relaxed _unary valid-bit _max-child)
     (unless (and (= got-size size)
                  (= got-height height)
                  (= got-nodes nodes)
                  (= valid-bit 1))
       (error 'check-treelist-shape-smoke
              "unexpected shape for ~a: expected size/height/nodes ~s, got ~s"
              name
              (list size height nodes)
              shape))]))

(expect-size-height-nodes! 'add-10000          10000 2 324)
(expect-size-height-nodes! 'cons-10000         10000 2 324)
(expect-size-height-nodes! 'append-medium       2000 2 66)
(expect-size-height-nodes! 'taller-left         2001 2 68)
(expect-size-height-nodes! 'taller-right        2001 2 66)
(expect-size-height-nodes! 'append-after-split  2000 2 66)
(expect-size-height-nodes! 'reverse-relaxed     2000 2 66)

(printf "treelist shape smoke ok\n")
(for ([name '(add-10000 cons-10000 append-medium taller-left taller-right append-after-split reverse-relaxed)])
  (printf "  ~a ~s\n" name (shape-ref name)))
