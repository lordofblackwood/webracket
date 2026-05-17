#lang racket/base

(require racket/file
         racket/list
         rackunit
         "regexp-provider.rkt"
         "test-module-support.rkt")

;; linklet-export-external-names : any/c -> (listof symbol?)
;;   Extract external export names from a linklet datum.
(define (linklet-export-external-names datum)
  (check-match datum `(linklet ,_ ,_ . ,_))
  (define exports (caddr datum))
  (for/list ([export (in-list exports)])
    (cond
      [(symbol? export) export]
      [(and (list? export) (= (length export) 2) (symbol? (cadr export)))
       (cadr export)]
      [else
       (fail-check (format "unexpected regexp export shape: ~s" export))])))

;; contains-symbol? : any/c symbol? -> boolean?
;;   Check whether v contains the symbol s.
(define (contains-symbol? v s)
  (let loop ([v v])
    (cond
      [(syntax? v) (loop (syntax->datum v))]
      [(symbol? v) (eq? v s)]
      [(pair? v)   (or (loop (car v)) (loop (cdr v)))]
      [(vector? v) (for/or ([e (in-vector v)]) (loop e))]
      [else        #f])))

(when (file-exists? webify-regexp-main-source)
  (test-case "Racket CS regexp layer demods to one linklet"
    (define out-dir (make-temporary-file "webracket-regexp-demod-~a" 'directory))
    (dynamic-wind
      void
      (lambda ()
        (define-values (status output out-rktl)
          (webify-regexp-demod! #:cache-root out-dir #:force? #t))
        (check-equal? status 0 output)
        (check-true (file-exists? out-rktl))
        (define datum (call-with-input-file out-rktl read))
        (check-equal? (car datum) 'linklet)
        (check-equal? (cadr datum) '())
        (check-true (positive? (length (cdddr datum))))
        (check-equal? (sort (linklet-export-external-names datum) symbol<?)
                      (sort webify-regexp-export-symbols symbol<?))
        (define-values (cell-only-webified _cell-only-exports _cell-only-exports-info)
          (run-first-slice-top-level datum #:define-export-aliases? #f))
        (check-false (contains-symbol? cell-only-webified 'unsafe-struct))
        (define cell-only-wat (wat-string (comp cell-only-webified)))
        (check-true (positive? (string-length cell-only-wat)))
        (define-values (public-webified _public-exports _public-exports-info)
          (run-first-slice-top-level datum))
        (check-false (contains-symbol? public-webified 'unsafe-struct))
        (define public-wat (wat-string (comp public-webified)))
        (check-true (positive? (string-length public-wat))))
      (lambda ()
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files out-dir))))))

(module+ main
  (void))
