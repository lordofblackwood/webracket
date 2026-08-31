#lang racket/base

(provide ffi-module-registry-row
         ffi-module-registry-row?
         ffi-module-registry-row-module
         ffi-module-registry-row-ffi-filename
         ffi-module-registry-row-ffi-path
         ffi-module-registry-rows
         module-provider->registry-rows
         module-provider->ffi-filename
         module-provider->ffi-filenames
         module-provider->ffi-path
         migrated-unsafe-ffi-modules)

(require racket/file
         racket/list
         racket/path
         racket/runtime-path)

(define-runtime-path ffi-root "../ffi")
(define-runtime-path browser-root "../../../browser")
(define-runtime-path js-root "../../../js")
(define-runtime-path unsafe-root "../../../webracket/unsafe")
(define-runtime-path jsxgraph-root "../../../jsxgraph")
(define-runtime-path xterm-root "../../../xterm")

(struct ffi-module-registry-row (module ffi-filename ffi-path)
  #:transparent)

;; path-basename-string : path-string? -> string?
;;   Return the final path element as a string.
(define (path-basename-string path)
  (path->string (file-name-from-path path)))

;; ffi-path->stem : path-string? -> string?
;;   Return a declaration filename without its `.ffi` suffix.
(define (ffi-path->stem path)
  (path->string
   (path-replace-extension
    (string->path (path-basename-string path))
    #"")))

;; module-file-exists? : path? string? -> boolean?
;;   Check whether the module file for an ffi stem exists.
(define (module-file-exists? root stem)
  (file-exists? (build-path root (string-append stem ".rkt"))))

;; ffi-stem->public-module : string? -> symbol?
;;   Derive the public module path for an ffi stem.
(define (ffi-stem->public-module stem)
  (cond
    [(member stem '("audio" "canvas" "document" "dom" "domrect"
                            "element" "event" "image" "media"
                            "websocket" "window"))
     (string->symbol (format "browser/~a" stem))]
    [(string=? stem "jsxgraph") 'jsxgraph]
    [(string=? stem "xtermjs") 'xterm]
    [else (string->symbol (format "js/~a" stem))]))

;; ffi-stem->public-root : string? -> path?
;;   Return the collection root for the public module mapped from stem.
(define (ffi-stem->public-root stem)
  (cond
    [(member stem '("audio" "canvas" "document" "dom" "domrect"
                            "element" "event" "image" "media"
                            "websocket" "window"))
     browser-root]
    [(string=? stem "jsxgraph") jsxgraph-root]
    [(string=? stem "xtermjs") xterm-root]
    [else js-root]))

;; ffi-stem->public-file-stem : string? -> string?
;;   Return the file stem for the public module mapped from stem.
(define (ffi-stem->public-file-stem stem)
  (cond
    [(or (string=? stem "jsxgraph")
         (string=? stem "xtermjs"))
     "main"]
    [else stem]))

;; ffi-stem->unsafe-module : string? -> symbol?
;;   Derive the unsafe module path for an ffi stem.
(define (ffi-stem->unsafe-module stem)
  (string->symbol (format "webracket/unsafe/~a" stem)))

;; ffi-path->module-registry-rows : path? -> (listof ffi-module-registry-row?)
;;   Generate registry rows for migrated modules backed by this declaration file.
(define (ffi-path->module-registry-rows ffi-path)
  (define stem         (ffi-path->stem ffi-path))
  (define ffi-filename (path-basename-string ffi-path))
  (append
   (if (module-file-exists? (ffi-stem->public-root stem)
                            (ffi-stem->public-file-stem stem))
       (list (ffi-module-registry-row (ffi-stem->public-module stem)
                                      ffi-filename
                                      ffi-path))
       '())
   (if (module-file-exists? unsafe-root stem)
       (list (ffi-module-registry-row (ffi-stem->unsafe-module stem)
                                      ffi-filename
                                      ffi-path))
       '())))

;; ffi-public-alias-rows : (listof ffi-module-registry-row?)
;;   Extra public modules backed by an existing aggregate `.ffi` declaration.
(define browser-aggregate-ffi-modules
  '(browser/dom
    web-easy
    web-pict
    webracket/unsafe/dom))

(define browser-aggregate-ffi-filenames
  '("audio.ffi"
    "canvas.ffi"
    "document.ffi"
    "dom.ffi"
    "domrect.ffi"
    "element.ffi"
    "event.ffi"
    "image.ffi"
    "media.ffi"
    "websocket.ffi"
    "window.ffi"))

(define dom-backed-public-modules
  '(clipboard
    compression-streams
    fetch
    fullscreen
    gamepad
    geolocation
    history
    indexed-db
    intersection-observer
    notifications
    resize-observer
    screen-orientation
    storage
    web-speech
    web-workers))

(define ffi-public-alias-rows
  (let ()
    (define (row module filename)
      (define path (build-path ffi-root filename))
      (and (file-exists? path)
           (ffi-module-registry-row module filename path)))
    (filter
     values
     (append
      (list (row 'js/iterator "array.ffi")
            (row 'device-orientation "device-orientation.ffi")
            (row 'file-system "file-system.ffi")
            (row 'streams "streams.ffi")
            (row 'web-midi "web-midi.ffi"))
      (for/list ([module (in-list dom-backed-public-modules)])
        (row module "dom.ffi"))
      ;; Aggregate facades used by migrated libraries such as `web-easy` and
      ;; `web-pict` imply the full browser binding family, not only `dom.ffi`.
      (for*/list ([module (in-list browser-aggregate-ffi-modules)]
                  [filename (in-list browser-aggregate-ffi-filenames)])
        (row module filename))))))

;; ffi-module-registry-rows : (listof ffi-module-registry-row?)
;;   Discover migrated module providers from `ffi/*.ffi` and existing modules.
(define ffi-module-registry-rows
  (sort
   (append ffi-public-alias-rows
           (append-map ffi-path->module-registry-rows
                       (find-files (lambda (path)
                                     (equal? (path-get-extension path) #".ffi"))
                                   ffi-root)))
   symbol<?
   #:key ffi-module-registry-row-module))

;; module-provider->registry-row : symbol? -> (or/c ffi-module-registry-row? #f)
;;   Find the registry row for a module provider.
(define (module-provider->registry-row module-name)
  (define rows (module-provider->registry-rows module-name))
  (and (pair? rows) (car rows)))

;; module-provider->registry-rows : symbol? -> (listof ffi-module-registry-row?)
;;   Find all registry rows for a module provider.
(define (module-provider->registry-rows module-name)
  (for/list ([row (in-list ffi-module-registry-rows)]
             #:when (eq? module-name (ffi-module-registry-row-module row)))
    row))

;; module-provider->ffi-filename : symbol? -> (or/c path-string? #f)
;;   Return the ffi bundle that a WebRacket module provider needs at runtime.
(define (module-provider->ffi-filename module-name)
  (define row (module-provider->registry-row module-name))
  (and row (ffi-module-registry-row-ffi-filename row)))

;; module-provider->ffi-filenames : symbol? -> (listof path-string?)
;;   Return every source `.ffi` bundle needed by a module provider.
(define (module-provider->ffi-filenames module-name)
  (remove-duplicates
   (for/list ([row (in-list (module-provider->registry-rows module-name))])
     (ffi-module-registry-row-ffi-filename row))
   equal?))

;; module-provider->ffi-path : symbol? -> (or/c path? #f)
;;   Return the source `.ffi` path for a WebRacket module provider.
(define (module-provider->ffi-path module-name)
  (define row (module-provider->registry-row module-name))
  (and row (ffi-module-registry-row-ffi-path row)))

;; migrated-unsafe-ffi-modules : -> (listof symbol?)
;;   List unsafe modules that are expected to match their `.ffi` declarations.
(define (migrated-unsafe-ffi-modules)
  (for/list ([row (in-list ffi-module-registry-rows)]
             #:do [(define module-name
                     (ffi-module-registry-row-module row))]
             #:when (regexp-match? #rx"^webracket/unsafe/"
                                   (symbol->string module-name)))
    module-name))
