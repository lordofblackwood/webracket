#lang racket

(require racket/list
         racket/match
         racket/port
         racket/string)

;; check-treelist-shape-smoke.rkt : -> void
;;   Run the compiler-private treelist shape smoke and fail on invalid shapes.

(define tools-dir
  (or (and (find-system-path 'run-file)
           (path-only (find-system-path 'run-file)))
      (current-load-relative-directory)
      (error 'check-treelist-shape-smoke "missing tool directory")))
(define repo-root (simplify-path (build-path tools-dir "..")))
(define webracket-file (build-path repo-root "webracket.rkt"))
(define smoke-file (build-path repo-root "tools" "treelist-shape-internal-smoke.rkt"))
(define smoke-base
  (path-replace-extension smoke-file #""))
(define racket-bin
  (or (find-executable-path "racket")
      (error 'check-treelist-shape-smoke "could not find racket executable")))

(define generated-smoke-files
  (list (path-replace-extension smoke-base #".wat")
        (path-replace-extension smoke-base #".wasm")
        (path-replace-extension smoke-base #".js")
        (path-replace-extension smoke-base #".wasm.map.sexp")))

(for ([p generated-smoke-files])
  (when (file-exists? p)
    (with-handlers ([exn:fail:filesystem?
                     (λ (e)
                       (unless (regexp-match? #rx"cannot delete file" (exn-message e))
                         (raise e)))])
      (delete-file p))))

(define-values (proc in out err)
  (parameterize ([current-directory repo-root])
    (subprocess #f #f #f
                racket-bin
                "-l" "errortrace"
                "-t" (path->string webracket-file)
                "--"
                "--internal-bind-treelist-debug-shape"
                "-r" (path->string smoke-file))))

(define stdout-text (port->string in))
(define stderr-text (port->string err))
(define combined-text (string-append stdout-text stderr-text))
(subprocess-wait proc)
(define status (subprocess-status proc))

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
