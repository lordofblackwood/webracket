#lang racket/base

;;; Shared provider-cache mechanics.
;;;
;;; This module owns cache plumbing only: parameters, file naming, fingerprinted
;;; reads/writes, locks, and verbose logging. Provider-specific fingerprints,
;;; staged-provider lowering, and module-resolution policy stay with their
;;; domain modules.

(provide current-provider-cache-dir
         current-provider-cache-force?
         current-provider-cache-verbose?
         provider-cache-path
         path-fingerprint
         read-provider-cache
         write-provider-cache!
         call-with-provider-cache-lock
         call-with-provider-cache-lock/try
         provider-cache-log
         provider-cache-symbol-segment
         provider-cache-string-segment
         cached-fingerprint-valid?
         write-cache-fingerprint!)

(require (only-in racket/file
                  call-with-file-lock/timeout
                  make-directory*
                  make-lock-file-name)
         (only-in racket/match match)
         (only-in racket/path path-only))

(define default-provider-cache-root
  (build-path (find-system-path 'temp-dir) "webracket-regexp-provider-cache"))

(define current-provider-cache-dir
  (make-parameter default-provider-cache-root))

(define current-provider-cache-force?
  (make-parameter #f))

(define current-provider-cache-verbose?
  (make-parameter #f))

;; provider-cache-path : path-string? ... -> path?
;;   Build a path below the current provider-cache root.
(define (provider-cache-path . elems)
  (apply build-path (current-provider-cache-dir) elems))

;; path-fingerprint : symbol? exact-integer? (listof path?) -> any/c
;;   Fingerprint files using path, size, and mtime.
(define (path-fingerprint tag version paths)
  `(,tag
    ,version
    ,@(for/list ([path (in-list (sort (map simplify-path paths)
                                      string<?
                                      #:key path->string))])
        (list (path->string path)
              (file-size path)
              (file-or-directory-modify-seconds path)))))

;; read-provider-cache : path? any/c -> (or/c any/c #f)
;;   Read a provider cache payload when its fingerprint matches.
(define (read-provider-cache cache-path fingerprint)
  (and (not (current-provider-cache-force?))
       (file-exists? cache-path)
       (with-handlers ([exn:fail? (lambda (_exn) #f)])
         (match (call-with-input-file cache-path read)
           [`(,cached-fingerprint ,payload)
            (and (equal? cached-fingerprint fingerprint) payload)]
           [_ #f]))))

;; write-provider-cache! : path? any/c any/c -> void?
;;   Write one fingerprinted provider cache payload.
(define (write-provider-cache! cache-path fingerprint payload)
  (make-directory* (path-only cache-path))
  (call-with-output-file cache-path
    (lambda (out)
      (write (list fingerprint payload) out)
      (newline out))
    #:exists 'truncate/replace))

;; call-with-provider-cache-lock : path? (-> any/c) [#:mode symbol?] -> any/c
;;   Serialize expensive provider cache materialization across worker processes.
(define (call-with-provider-cache-lock cache-path thunk #:mode [mode 'exclusive])
  (make-directory* (path-only cache-path))
  (define lock-path (make-lock-file-name cache-path))
  (call-with-file-lock/timeout
   cache-path
   mode
   thunk
   (lambda ()
     (error 'provider-cache
            "timed out waiting for provider cache lock: ~a"
            lock-path))
   #:lock-file lock-path
   #:max-delay 300))

;; call-with-provider-cache-lock/try : path? (-> any/c) [#:mode symbol?] -> (or/c any/c #f)
;;   Run thunk only when the cache lock is immediately available.
;;
;; This is deliberately non-blocking: cache maintenance must never wait behind
;; a compiler process, and a #f result means that the entry was left alone.
(define (call-with-provider-cache-lock/try cache-path thunk #:mode [mode 'exclusive])
  (make-directory* (path-only cache-path))
  (define lock-path (make-lock-file-name cache-path))
  (call-with-file-lock/timeout
   cache-path
   mode
   thunk
   (lambda () #f)
   #:lock-file lock-path
   #:delay 0
   #:max-delay 0))

;; provider-cache-log : string? any/c ... -> void?
;;   Print provider cache diagnostics in verbose mode.
(define (provider-cache-log fmt . args)
  (when (current-provider-cache-verbose?)
    (apply fprintf (current-error-port)
           (string-append "provider-cache: " fmt "\n")
           args)))

;; provider-cache-symbol-segment : symbol? -> string?
;;   Make a conservative filename segment for provider report cache rows.
(define (provider-cache-symbol-segment name)
  (provider-cache-string-segment (symbol->string name)))

;; provider-cache-string-segment : string? -> string?
;;   Make a conservative filename segment for arbitrary cache keys.
(define (provider-cache-string-segment str)
  (regexp-replace*
   #rx"[^A-Za-z0-9_.-]"
   str
   "_"))

;; cached-fingerprint-valid? : path? any/c -> boolean?
;;   Check whether a sidecar fingerprint file matches the current source.
(define (cached-fingerprint-valid? path fingerprint)
  (and (file-exists? path)
       (with-handlers ([exn:fail? (lambda (_exn) #f)])
         (equal? (call-with-input-file path read) fingerprint))))

;; write-cache-fingerprint! : path? any/c -> void?
;;   Write a sidecar source fingerprint next to a generated artifact.
(define (write-cache-fingerprint! path fingerprint)
  (call-with-output-file path
    (lambda (out) (write fingerprint out) (newline out))
    #:exists 'truncate/replace))
