#lang racket/base

(require racket/file
         racket/string
         rackunit
         "../pkgs/webracket-lib/compiler/webify/io-print-bridge.rkt"
         "test-module-support.rkt")

;; compose-inputs/no-aliases : (listof input?) symbol? -> composition?
;;   Compose extracted inputs without public aliases.
(define (compose-inputs/no-aliases inputs root)
  (define registry (webify-module-linklet-inputs->registry inputs))
  (webify-compose-module-registry/roots/composition
   registry
   (list root)
   #:define-export-aliases? #f
   #:serializable?-box     #f
   #:datum-intern?         #f
   #:target                #f
   #:allow-set!-undefined? #f
   #:unsafe-mode?          #f
   #:enforce-constant?     #t
   #:allow-inline?         #t
   #:no-prompt?            #f
   #:prim-knowns           test-prim-knowns
   #:primitives            test-primitives
   #:compiler-query        (lambda (v) #f)
   #:get-import-knowns     (lambda (key) (values #f #f #f))
   #:import-keys           #f))

(test-case "staged io/print provider seed resolves into registry-ready inputs"
  (define inputs (webify-io-print-inputs))
  (define registry (webify-module-linklet-inputs->registry inputs))
  (check-equal? (webify-module-registry-plan registry (list webify-io-print-root-name))
                (list webify-io-print-module-protocol-name
                      webify-io-print-adapter-name
                      webify-io-print-root-name)))

(test-case "staged io/print bridge provides private cells"
  (define composition
    (compose-inputs/no-aliases (webify-io-print-inputs) webify-io-print-root-name))
  (define alias-forms (webify-io-print-private-alias-forms composition))
  (check-equal? (map cadr alias-forms)
                (map webify-io-print-private-cell-symbol
                     webify-io-print-export-symbols))
  (for ([form (in-list alias-forms)])
    (check-match form `(define ,(? symbol?) ,(? symbol?)))))

(test-case "staged io/print provider seed runs through module-variable cells"
  (define composition
    (compose-inputs/no-aliases (webify-io-print-inputs) webify-io-print-root-name))
  (define source-dir (make-temporary-file "webracket-io-print-staged-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-io-print-staged-dest-~a" 'directory))
  (define source-path (build-path source-dir "io-print-staged.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-datum-program!
       source-path
       (webify-module-composition-with-tail
        composition
        `(,@(webify-io-print-private-alias-forms composition)
          (define provided-display
            (module-variable-ref ,(webify-io-print-private-cell-symbol 'display)))
          (define provided-write
            (module-variable-ref ,(webify-io-print-private-cell-symbol 'write)))
          (define provided-newline
            (module-variable-ref ,(webify-io-print-private-cell-symbol 'newline)))
          (define out (open-output-string))
          (provided-display "hello" out)
          (provided-newline out)
          (provided-write '(1 2) out)
          (provided-newline out)
          (provided-write '#(a b) out)
          (provided-newline out)
          (provided-write '#hash((a . 1) (b . 2)) out)
          (provided-newline out)
          (provided-write #\newline out)
          (provided-newline out)
          (provided-write #"bytes" out)
          (provided-newline out)
          (provided-write 'symbol out)
          (js-log (get-output-string out)))))
      (define-values (status output)
        (run-webracket (list "--no-stdlib"
                             "--no-io-format-provider"
                             "-r"
                             "--dest" (path->string dest-dir)
                             (path->string source-path))
                       source-dir
                       #:timeout-seconds 120
                       #:memory-mb 1024))
      (check-equal? status 0 output)
      (check-true (string-contains? output "hello\n(1 2)") output)
      (check-true (string-contains? output "#(a b)") output)
      (check-true (string-contains? output "#hash(") output)
      (check-true (string-contains? output "(a . 1)") output)
      (check-true (string-contains? output "(b . 2)") output)
      (check-true (string-contains? output "#\\newline") output)
      (check-true (string-contains? output "#\"bytes\"") output)
      (check-true (string-contains? output "symbol") output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(module+ main
  (void))
