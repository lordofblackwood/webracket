#lang racket/base

(require racket/file
         racket/path
         racket/string
         racket/system)

;; find-repo-root : path? -> path?
;;   Find the checkout root that contains `webracket.rkt`.
(define (find-repo-root start)
  (let loop ([dir (simplify-path start)])
    (cond
      [(file-exists? (build-path dir "webracket.rkt"))
       dir]
      [else
       (define parent (path-only dir))
       (unless parent
         (error 'test-web-easy-module-bridge
                "could not find repository root containing webracket.rkt"))
       (loop (path->complete-path parent))])))

;; repo-racket-executable : path? -> path?
;;   Prefer the adjacent Racket checkout with machine-independent linklet tools.
(define (repo-racket-executable repo-root)
  (define candidate
    (build-path repo-root ".." "racket" "racket" "bin" "racket"))
  (cond
    [(file-exists? candidate) candidate]
    [else
     (or (find-executable-path "racket")
         (error 'test-web-easy-module-bridge
                "could not find a racket executable"))]))

;; env-with-collections : path? -> environment-variables?
;;   Build a subprocess environment for the package-root collection layout.
(define (env-with-collections repo-root)
  (define env (environment-variables-copy (current-environment-variables)))
  (define racket-collects
    (build-path repo-root ".." "racket" "racket" "collects"))
  (define collects
    (string-append
     (path->string (build-path repo-root "pkgs"))
     ":"
     (path->string racket-collects)))
  (environment-variables-set! env #"PLTCOLLECTS" (string->bytes/utf-8 collects))
  (environment-variables-set! env #"PLTCOMPILEDROOTS" #"/private/tmp/webracket-raco-compiled-92")
  env)

;; validate-wasm-output : string? path? -> void?
;;   Validate generated Wasm so browser compile errors are caught by the smoke.
(define (validate-wasm-output label wasm-path)
  (define wasm-tools (find-executable-path "wasm-tools"))
  (unless wasm-tools
    (error 'test-web-easy-module-bridge
           "could not find wasm-tools for validation"))
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define status
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr])
      (system*/exit-code wasm-tools "validate" (path->string wasm-path))))
  (unless (zero? status)
    (error 'test-web-easy-module-bridge
           (format "~a generated invalid Wasm (~a): ~a~a"
                   label
                   status
                   (get-output-string stdout)
                   (get-output-string stderr)))))

;; compile-web-easy-smoke : path? path? string? string? -> void
;;   Compile a small module-bridge program and reject exact wide FFI call types.
(define (compile-web-easy-smoke repo-root racket-exe label source-text)
  (printf "compiling ~a module bridge smoke\n" label)
  (flush-output)
  (define base (make-temporary-file (format "webracket-~a-~a" label "~a") 'directory))
  (define source-path (build-path base "main.rkt"))
  (define wasm-path   (build-path base "main.wasm"))
  (define wat-path    (build-path base "main.wat"))
  (define host-path   (build-path base "main.js"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out) (display source-text out))
        #:exists 'truncate/replace)
      (define stdout (open-output-string))
      (define stderr (open-output-string))
      (define status
        (parameterize ([current-directory repo-root]
                       [current-output-port stdout]
                       [current-error-port stderr]
                       [current-environment-variables (env-with-collections repo-root)])
          (system*/exit-code
           racket-exe
           (path->string (build-path repo-root "webracket.rkt"))
           "--browser"
           "--no-stdlib"
           "--webracket-module-bridge"
           "--wasm-file" (path->string wasm-path)
           "--wat-file"  (path->string wat-path)
           "--host-file" (path->string host-path)
           (path->string source-path))))
      (define output
        (string-append (get-output-string stdout)
                       (get-output-string stderr)))
      (unless (zero? status)
        (error 'test-web-easy-module-bridge
               (format "~a compile failed (~a): ~a" label status output)))
      (unless (file-exists? wat-path)
        (error 'test-web-easy-module-bridge
               (format "~a compile did not produce WAT output" label)))
      (unless (file-exists? wasm-path)
        (error 'test-web-easy-module-bridge
               (format "~a compile did not produce Wasm output" label)))
      (validate-wasm-output label wasm-path)
      (define wat (file->string wat-path))
      (when (regexp-match? #rx"\\$Prim(7|8|9|10)" wat)
        (error 'test-web-easy-module-bridge
               (format "~a generated exact wide FFI primitive types" label))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files base)))))

;; compile-web-easy-example : path? path? path-string? -> void
;;   Compile a package example through the module bridge.
(define (compile-web-easy-example repo-root racket-exe example-relative-path)
  (define example-path (apply build-path repo-root example-relative-path))
  (define label
    (path->string
     (path-replace-extension
      (file-name-from-path example-path)
      #"")))
  (compile-web-easy-smoke
   repo-root
   racket-exe
   label
   (file->string example-path)))

(module+ main
  (define repo-root
    (find-repo-root (or (current-load-relative-directory)
                        (current-directory))))
  (define racket-exe (repo-racket-executable repo-root))
  (compile-web-easy-example
   repo-root
   racket-exe
   '("pkgs" "web-easy" "examples" "hello-world.rkt"))
  (compile-web-easy-example
   repo-root
   racket-exe
   '("pkgs" "web-easy" "examples" "single-counter.rkt"))
  (compile-web-easy-smoke
   repo-root
   racket-exe
   "web-easy-dom-like"
   "#lang webracket/base
(require web-easy/private/dom-like)
(define r (render (Div \"hi\")))
(js-log (renderer? r))
"))
