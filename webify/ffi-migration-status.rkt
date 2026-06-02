#lang racket/base

(provide ffi-migration-status-row
         ffi-migration-status-row?
         ffi-migration-status-row-ffi-filename
         ffi-migration-status-row-unsafe-module
         ffi-migration-status-row-public-module
         ffi-migration-status-row-unsafe-module?
         ffi-migration-status-row-public-module?
         ffi-migration-status-row-bundle-inference?
         ffi-migration-status-row-dashboard?
         ffi-migration-status-row-status
         ffi-migration-status-rows
         write-ffi-migration-status-tsv)

(require racket/file
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         "../pkgs/webracket-lib/compiler/webify/ffi-module-registry.rkt"
         "goal1-dashboard.rkt")

(define-runtime-path ffi-root "../pkgs/webracket-lib/compiler/ffi")
(define-runtime-path browser-root "../pkgs/browser")
(define-runtime-path public-js-root "../pkgs/js")
(define-runtime-path unsafe-root "../pkgs/webracket/unsafe")

(struct ffi-migration-status-row
  (ffi-filename
   unsafe-module
   public-module
   unsafe-module?
   public-module?
   bundle-inference?
   dashboard?
   status)
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

;; ffi-declaration-paths : -> (listof path?)
;;   List declaration files in stable filename order.
(define (ffi-declaration-paths)
  (sort
   (find-files (lambda (path)
                 (equal? (path-get-extension path) #".ffi"))
               ffi-root)
   string<?
   #:key path-basename-string))

;; dashboard-covers-module? : symbol? -> boolean?
;;   Check whether any dashboard row names module-name as a covered library.
(define (dashboard-covers-module? module-name)
  (for/or ([c (in-list goal1-dashboard-cases)])
    (memq module-name (goal1-dashboard-case-libraries c))))

;; status-for : boolean? boolean? boolean? boolean? -> symbol?
;;   Classify a declaration file by current migration evidence.
(define (status-for unsafe? public? inference? dashboard?)
  (cond
    [(and unsafe? public? inference? dashboard?) 'migrated-covered]
    [(and unsafe? public? inference?)           'migrated-needs-dashboard]
    [(or unsafe? public? inference?)            'partial]
    [else                                      'unmigrated]))

;; ffi-path->migration-status-row : path? -> ffi-migration-status-row?
;;   Build one migration status row from a declaration path.
(define (ffi-path->migration-status-row ffi-path)
  (define stem         (ffi-path->stem ffi-path))
  (define ffi-filename (path-basename-string ffi-path))
  (define unsafe-module (string->symbol (format "webracket/unsafe/~a" stem)))
  (define public-root
    (cond
      [(member stem '("audio" "canvas" "document" "dom" "domrect"
                              "element" "event" "image" "media"
                              "websocket" "window"))
       "browser"]
      [else "js"]))
  (define public-module (string->symbol (format "~a/~a" public-root stem)))
  (define unsafe?       (file-exists? (build-path unsafe-root (string-append stem ".rkt"))))
  (define public-root-path (if (string=? public-root "browser")
                               browser-root
                               public-js-root))
  (define public?       (file-exists? (build-path public-root-path (string-append stem ".rkt"))))
  (define inference?    (or (module-provider->ffi-filename unsafe-module)
                            (module-provider->ffi-filename public-module)))
  (define dashboard?    (and (or (dashboard-covers-module? unsafe-module)
                                 (dashboard-covers-module? public-module))
                             #t))
  (ffi-migration-status-row
   ffi-filename
   unsafe-module
   public-module
   unsafe?
   public?
   (and inference? #t)
   dashboard?
   (status-for unsafe? public? inference? dashboard?)))

;; ffi-migration-status-rows : -> (listof ffi-migration-status-row?)
;;   Return status rows for all declaration files.
(define (ffi-migration-status-rows)
  (map ffi-path->migration-status-row (ffi-declaration-paths)))

;; bool->cell : any/c -> string?
;;   Render a boolean-ish value for TSV output.
(define (bool->cell v)
  (if v "yes" "no"))

;; write-ffi-migration-status-tsv : [output-port?] -> void?
;;   Write a compact TSV migration report.
(define (write-ffi-migration-status-tsv [out (current-output-port)])
  (displayln "ffi\tunsafe-module\tpublic-module\tunsafe\tpublic\tinference\tdashboard\tstatus" out)
  (for ([row (in-list (ffi-migration-status-rows))])
    (fprintf out "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
             (ffi-migration-status-row-ffi-filename row)
             (ffi-migration-status-row-unsafe-module row)
             (ffi-migration-status-row-public-module row)
             (bool->cell (ffi-migration-status-row-unsafe-module? row))
             (bool->cell (ffi-migration-status-row-public-module? row))
             (bool->cell (ffi-migration-status-row-bundle-inference? row))
             (bool->cell (ffi-migration-status-row-dashboard? row))
             (ffi-migration-status-row-status row))))

(module+ main
  (write-ffi-migration-status-tsv))
