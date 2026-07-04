#lang racket

(provide runtime-source-fingerprint)

(require racket/runtime-path)

(define-runtime-path runtime-wasm-path "../runtime-wasm.rkt")
(define-runtime-path priminfo-path "../private/priminfo.rkt")
(define-runtime-path parameters-path "../private/parameters.rkt")
(define-runtime-path structs-path "../private/structs.rkt")
(define-runtime-path wasm-data-path "../private/wasm-data.rkt")
(define-runtime-path wasm-utils-path "../private/wasm-utils.rkt")
(define-runtime-path immediates-path "../private/immediates.rkt")
(define-runtime-path constants-path "constants.rkt")
(define-runtime-path core-helper-path "core-helper.rkt")
(define-runtime-path core-runtime-path "core-runtime.rkt")
(define-runtime-path entry-initializers-path "entry-initializers.rkt")
(define-runtime-path entry-support-path "entry-support.rkt")
(define-runtime-path function-declarations-path "function-declarations.rkt")
(define-runtime-path js-imports-path "js-imports.rkt")
(define-runtime-path module-forms-path "module-forms.rkt")
(define-runtime-path runtime-analysis-path "runtime-analysis.rkt")
(define-runtime-path runtime-ffi-path "runtime-ffi.rkt")
(define-runtime-path runtime-helper-index-path "runtime-helper-index.rkt")
(define-runtime-path runtime-primitives-path "runtime-primitives.rkt")
(define-runtime-path runtime-source-path "runtime-source.rkt")
(define-runtime-path shared-types-path "shared-types.rkt")
(define-runtime-path core-booleans-path "core/booleans.rkt")
(define-runtime-path core-boxes-path "core/boxes.rkt")
(define-runtime-path core-bytes-path "core/bytes.rkt")
(define-runtime-path core-characters-path "core/characters.rkt")
(define-runtime-path core-checkers-path "core/checkers.rkt")
(define-runtime-path core-closures-path "core/closures.rkt")
(define-runtime-path core-control-flow-path "core/control-flow.rkt")
(define-runtime-path core-equality-path "core/equality.rkt")
(define-runtime-path core-exceptions-path "core/exceptions.rkt")
(define-runtime-path core-events-path "core/events.rkt")
(define-runtime-path core-fasl-path "core/fasl.rkt")
(define-runtime-path core-ffi-path "core/ffi.rkt")
(define-runtime-path core-filesystem-path "core/filesystem.rkt")
(define-runtime-path core-fixnums-path "core/fixnums.rkt")
(define-runtime-path core-flonums-path "core/flonums.rkt")
(define-runtime-path core-formatting-path "core/formatting.rkt")
(define-runtime-path core-hashes-path "core/hashes.rkt")
(define-runtime-path core-immutable-hashes-path "core/immutable-hashes.rkt")
(define-runtime-path core-immediates-path "core/immediates.rkt")
(define-runtime-path core-impersonators-path "core/impersonators.rkt")
(define-runtime-path core-io-handlers-path "core/io-handlers.rkt")
(define-runtime-path core-keywords-path "core/keywords.rkt")
(define-runtime-path core-lists-path "core/lists.rkt")
(define-runtime-path core-linklet-instances-path "core/linklet-instances.rkt")
(define-runtime-path core-linklets-path "core/linklets.rkt")
(define-runtime-path core-locations-path "core/locations.rkt")
(define-runtime-path core-locks-path "core/locks.rkt")
(define-runtime-path core-loggers-path "core/loggers.rkt")
(define-runtime-path core-memory-map-path "core/memory-map.rkt")
(define-runtime-path core-mlists-path "core/mlists.rkt")
(define-runtime-path core-mutable-hashes-path "core/mutable-hashes.rkt")
(define-runtime-path core-namespaces-path "core/namespaces.rkt")
(define-runtime-path core-numbers-path "core/numbers.rkt")
(define-runtime-path core-parameters-path "core/parameters.rkt")
(define-runtime-path core-paths-path "core/paths.rkt")
(define-runtime-path core-ports-path "core/ports.rkt")
(define-runtime-path core-procedures-path "core/procedures.rkt")
(define-runtime-path core-random-path "core/random.rkt")
(define-runtime-path core-realms-path "core/realms.rkt")
(define-runtime-path core-regexps-path "core/regexps.rkt")
(define-runtime-path core-runtime-constants-path "core/runtime-constants.rkt")
(define-runtime-path core-reflection-path "core/reflection.rkt")
(define-runtime-path core-security-path "core/security.rkt")
(define-runtime-path core-semaphores-path "core/semaphores.rkt")
(define-runtime-path core-stencil-vectors-path "core/stencil-vectors.rkt")
(define-runtime-path core-strings-path "core/strings.rkt")
(define-runtime-path core-symbols-path "core/symbols.rkt")
(define-runtime-path core-system-path "core/system.rkt")
(define-runtime-path core-syntax-path "core/syntax.rkt")
(define-runtime-path core-threads-path "core/threads.rkt")
(define-runtime-path core-time-path "core/time.rkt")
(define-runtime-path core-treelists-path "core/treelists.rkt")
(define-runtime-path core-unsafe-path "core/unsafe.rkt")
(define-runtime-path core-vectors-path "core/vectors.rkt")
(define-runtime-path core-wills-path "core/wills.rkt")

;; runtime-source-paths : (listof path?)
;;   Enumerate source files that can affect generated runtime WAT.
(define runtime-source-paths
  (list runtime-wasm-path
        priminfo-path
        parameters-path
        structs-path
        wasm-data-path
        wasm-utils-path
        immediates-path
        constants-path
        core-helper-path
        core-runtime-path
        entry-initializers-path
        entry-support-path
        function-declarations-path
        js-imports-path
        module-forms-path
        runtime-analysis-path
        runtime-ffi-path
        runtime-helper-index-path
        runtime-primitives-path
        runtime-source-path
        shared-types-path
        core-booleans-path
        core-boxes-path
        core-bytes-path
        core-characters-path
        core-checkers-path
        core-closures-path
        core-control-flow-path
        core-equality-path
        core-exceptions-path
        core-events-path
        core-fasl-path
        core-ffi-path
        core-filesystem-path
        core-fixnums-path
        core-flonums-path
        core-formatting-path
        core-hashes-path
        core-immutable-hashes-path
        core-immediates-path
        core-impersonators-path
        core-io-handlers-path
        core-keywords-path
        core-lists-path
        core-linklet-instances-path
        core-linklets-path
        core-locations-path
        core-locks-path
        core-loggers-path
        core-memory-map-path
        core-mlists-path
        core-mutable-hashes-path
        core-namespaces-path
        core-numbers-path
        core-parameters-path
        core-paths-path
        core-ports-path
        core-procedures-path
        core-random-path
        core-realms-path
        core-regexps-path
        core-runtime-constants-path
        core-reflection-path
        core-security-path
        core-semaphores-path
        core-stencil-vectors-path
        core-strings-path
        core-symbols-path
        core-syntax-path
        core-threads-path
        core-time-path
        core-treelists-path
        core-unsafe-path
        core-vectors-path
        core-wills-path))

;; path-fingerprint : path? -> list?
;;   Return stable metadata used to invalidate runtime analysis caches.
(define (path-fingerprint path)
  (list (path->string path)
        (file-size path)
        (file-or-directory-modify-seconds path)))

;; runtime-source-fingerprint : -> list?
;;   Fingerprint runtime generator source files for stable-analysis caching.
(define (runtime-source-fingerprint)
  `(runtime-source
    2
    ,@(for/list ([path (in-list runtime-source-paths)])
        (path-fingerprint path))))

(module+ test
  (require rackunit)

  ;; contains-path-suffix? : list? string? -> boolean?
  ;;   Check whether fingerprint names include a path with the given suffix.
  (define (contains-path-suffix? fingerprint suffix)
    (for/or ([entry (in-list (cddr fingerprint))])
      (define path-string
        (list->string
         (for/list ([ch (in-string (first entry))])
           (if (char=? ch #\\) #\/ ch))))
      (string-suffix? path-string suffix)))

  (define fingerprint (runtime-source-fingerprint))

  (check-match fingerprint
    `(runtime-source 2 ,_ ...))
  (check-true (contains-path-suffix? fingerprint "runtime-wasm.rkt"))
  (check-true (contains-path-suffix? fingerprint "entry-support.rkt"))
  (check-true (contains-path-suffix? fingerprint "js-imports.rkt"))
  (check-true (contains-path-suffix? fingerprint "runtime-ffi.rkt"))
  (check-true (contains-path-suffix? fingerprint "runtime-primitives.rkt"))
  (check-true (contains-path-suffix? fingerprint "runtime-source.rkt"))
  (check-true (contains-path-suffix? fingerprint "shared-types.rkt"))
  (check-true (contains-path-suffix? fingerprint "core/strings.rkt")))
