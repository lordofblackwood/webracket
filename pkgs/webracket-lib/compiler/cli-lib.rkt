#lang racket

;; This file centralizes the user-facing compiler CLI surface.
;; It parses the ordinary `webracket.rkt` flags into a shared compile-config
;; structure, handles the non-compile reporting commands, and gives both the
;; direct CLI path and the long-lived compile server one place to agree on
;; request shape and compile behavior.

(require racket/format
         racket/match
         "driver.rkt"
         (only-in "webify/provider-slices.rkt"
                  provider-slice-report-lines)
         (only-in "webify/regexp-provider.rkt"
                  webify-regexp-default-cache-root))

(provide (struct-out webracket-cli-command)
         (struct-out webracket-compile-config)
         compile-config->datum
         datum->compile-config
         parse-webracket-cli
         run-webracket-cli-command
         run-webracket-compile)

(struct webracket-cli-command
  (kind    ; symbol describing the requested top-level action
   payload ; command-specific payload, often a compile-config
   )
  #:transparent)

(struct webracket-compile-config
  (run-after                              ; run the generated Node host after compilation
   verbose-mode                           ; enable verbose compiler and provider-cache logging
   wat-filename                           ; explicit .wat output path, or #f for default
   wasm-filename                          ; explicit .wasm output path, or #f for default
   host-filename                          ; explicit host-file output path, or #f for default
   dest-dir                               ; destination directory for default outputs
   label-map-forms                        ; include heavyweight form entries in the label map
   dump-passes-dir                        ; directory for compiler pass dumps, or #f
   dump-passes-limit                      ; maximum number of pass dumps, or #f for default
   timings?                               ; print timing tables during compilation
   alpha-rename-profile?                  ; print alpha-rename pass diagnostics
   simplify-profile?                      ; print simplify-LFE diagnostics
   pretty-wat?                            ; pretty-print emitted WAT
   enable-cc-analysis?                    ; enable the new closure-conversion analysis
   enable-simplify?                       ; enable the early simplify pass
   module-bridge-elide-public-cells?      ; expose safe public bridge exports as plain values
   tree-shake?                            ; remove unused runtime primitives
   tree-shake-report                      ; optional runtime primitive reachability report path
   letrec-strategy                        ; letrec lowering strategy symbol
   print-top-level-results?               ; print top-level results for script-style runs
   internal-bind-treelist-debug-shape?    ; internal treelist shape debug hook
   internal-bind-immutable-hash-debug-shape? ; internal immutable-hash shape debug hook
   console-bridge?                        ; install the browser console bridge
   browser                                ; target browser host generation
   nodejs                                 ; target Node host generation
   link-flags                             ; reserved linker flags from the legacy surface
   ffi-files                              ; extra .ffi files to merge into the compile
   vfs-preloads                           ; VFS preload specs for the generated host
   vfs-mounts                             ; VFS mount specs for the generated host
   source-filename                        ; source program to compile
   stdlib?                                ; include the legacy stdlib wrapper for script-style input
   stdlib-io-format-provider?             ; compose the staged io/format provider for script-style input
   expander-read-provider?                ; compose the staged expander/read provider
   expander-read-syntax-provider?         ; compose the staged read-syntax provider
   webracket-module-bridge?               ; force #lang webracket/* through the module bridge
   provider-substitutions?                ; route selected racket/* imports to WebRacket shims
   provider-cache-dir                     ; provider-cache root override, or #f for default
   clear-provider-cache?                  ; clear the provider cache before compiling
   force-provider-cache-refresh?          ; rebuild provider-cache entries even on fingerprint hits
   )
  #:transparent)

;; compile-config->datum : webracket-compile-config? -> datum?
;;   Encode cfg as a network-safe association list.
(define (compile-config->datum cfg)
  `((run-after . ,(webracket-compile-config-run-after cfg))
    (verbose-mode . ,(webracket-compile-config-verbose-mode cfg))
    (wat-filename . ,(webracket-compile-config-wat-filename cfg))
    (wasm-filename . ,(webracket-compile-config-wasm-filename cfg))
    (host-filename . ,(webracket-compile-config-host-filename cfg))
    (dest-dir . ,(webracket-compile-config-dest-dir cfg))
    (label-map-forms . ,(webracket-compile-config-label-map-forms cfg))
    (dump-passes-dir . ,(webracket-compile-config-dump-passes-dir cfg))
    (dump-passes-limit . ,(webracket-compile-config-dump-passes-limit cfg))
    (timings? . ,(webracket-compile-config-timings? cfg))
    (alpha-rename-profile? . ,(webracket-compile-config-alpha-rename-profile? cfg))
    (simplify-profile? . ,(webracket-compile-config-simplify-profile? cfg))
    (pretty-wat? . ,(webracket-compile-config-pretty-wat? cfg))
    (enable-cc-analysis? . ,(webracket-compile-config-enable-cc-analysis? cfg))
    (enable-simplify? . ,(webracket-compile-config-enable-simplify? cfg))
    (module-bridge-elide-public-cells? . ,(webracket-compile-config-module-bridge-elide-public-cells? cfg))
    (tree-shake? . ,(webracket-compile-config-tree-shake? cfg))
    (tree-shake-report . ,(webracket-compile-config-tree-shake-report cfg))
    (letrec-strategy . ,(webracket-compile-config-letrec-strategy cfg))
    (print-top-level-results? . ,(webracket-compile-config-print-top-level-results? cfg))
    (internal-bind-treelist-debug-shape? . ,(webracket-compile-config-internal-bind-treelist-debug-shape? cfg))
    (internal-bind-immutable-hash-debug-shape? . ,(webracket-compile-config-internal-bind-immutable-hash-debug-shape? cfg))
    (console-bridge? . ,(webracket-compile-config-console-bridge? cfg))
    (browser . ,(webracket-compile-config-browser cfg))
    (nodejs . ,(webracket-compile-config-nodejs cfg))
    (link-flags . ,(webracket-compile-config-link-flags cfg))
    (ffi-files . ,(webracket-compile-config-ffi-files cfg))
    (vfs-preloads . ,(webracket-compile-config-vfs-preloads cfg))
    (vfs-mounts . ,(webracket-compile-config-vfs-mounts cfg))
    (source-filename . ,(webracket-compile-config-source-filename cfg))
    (stdlib? . ,(webracket-compile-config-stdlib? cfg))
    (stdlib-io-format-provider? . ,(webracket-compile-config-stdlib-io-format-provider? cfg))
    (expander-read-provider? . ,(webracket-compile-config-expander-read-provider? cfg))
    (expander-read-syntax-provider? . ,(webracket-compile-config-expander-read-syntax-provider? cfg))
    (webracket-module-bridge? . ,(webracket-compile-config-webracket-module-bridge? cfg))
    (provider-substitutions? . ,(webracket-compile-config-provider-substitutions? cfg))
    (provider-cache-dir . ,(webracket-compile-config-provider-cache-dir cfg))
    (clear-provider-cache? . ,(webracket-compile-config-clear-provider-cache? cfg))
    (force-provider-cache-refresh? . ,(webracket-compile-config-force-provider-cache-refresh? cfg))))

;; datum->compile-config : datum? -> webracket-compile-config?
;;   Decode a compile configuration from an association list.
(define (datum->compile-config datum)
  (define (ref key)
    (define a (assq key datum))
    (unless a
      (error 'datum->compile-config "missing key: ~a" key))
    (cdr a))
  (webracket-compile-config
   (ref 'run-after)
   (ref 'verbose-mode)
   (ref 'wat-filename)
   (ref 'wasm-filename)
   (ref 'host-filename)
   (ref 'dest-dir)
   (ref 'label-map-forms)
   (ref 'dump-passes-dir)
   (ref 'dump-passes-limit)
   (ref 'timings?)
   (ref 'alpha-rename-profile?)
   (ref 'simplify-profile?)
   (ref 'pretty-wat?)
   (ref 'enable-cc-analysis?)
   (ref 'enable-simplify?)
   (ref 'module-bridge-elide-public-cells?)
   (ref 'tree-shake?)
   (ref 'tree-shake-report)
   (ref 'letrec-strategy)
   (ref 'print-top-level-results?)
   (ref 'internal-bind-treelist-debug-shape?)
   (ref 'internal-bind-immutable-hash-debug-shape?)
   (ref 'console-bridge?)
   (ref 'browser)
   (ref 'nodejs)
   (ref 'link-flags)
   (ref 'ffi-files)
   (ref 'vfs-preloads)
   (ref 'vfs-mounts)
   (ref 'source-filename)
   (ref 'stdlib?)
   (ref 'stdlib-io-format-provider?)
   (ref 'expander-read-provider?)
   (ref 'expander-read-syntax-provider?)
   (ref 'webracket-module-bridge?)
   (ref 'provider-substitutions?)
   (ref 'provider-cache-dir)
   (ref 'clear-provider-cache?)
   (ref 'force-provider-cache-refresh?)))

;; parse-webracket-cli : [vector?] -> webracket-cli-command?
;;   Parse argv into a compile command or a local report/listing command.
(define (parse-webracket-cli [argv (current-command-line-arguments)])
  (define run-after #f)
  (define verbose-mode #f)
  (define wat-filename #f)
  (define wasm-filename #f)
  (define host-filename #f)
  (define dest-dir #f)
  (define label-map-forms #f)
  (define dump-passes-dir #f)
  (define dump-passes-limit #f)
  (define timings? #f)
  (define alpha-rename-profile? #f)
  (define simplify-profile? #f)
  (define pretty-wat? #f)
  (define list-primitives? #f)
  (define list-provider-slices? #f)
  (define enable-cc-analysis? #f)
  (define enable-simplify? #f)
  (define module-bridge-elide-public-cells? #f)
  (define tree-shake? #t)
  (define tree-shake-report #f)
  (define letrec-strategy 'waddell)
  (define print-top-level-results? #f)
  (define internal-bind-treelist-debug-shape? #f)
  (define internal-bind-immutable-hash-debug-shape? #f)
  (define console-bridge? #f)
  (define browser #f)
  (define nodejs #t)
  (define link-flags '())
  (define ffi-files '())
  (define vfs-preloads '())
  (define vfs-mounts '())
  (define source-filename #f)
  (define stdlib? #f)
  (define stdlib-io-format-provider? #t)
  (define expander-read-provider? #f)
  (define expander-read-syntax-provider? #f)
  (define webracket-module-bridge? #f)
  (define provider-substitutions? #t)
  (define provider-cache-dir #f)
  (define clear-provider-cache? #f)
  (define force-provider-cache-refresh? #f)
  (define provider-cache-report? #f)
  (define server-command #f)

  (define (normalize-vfs-preload-path-for-duplicates path)
    (regexp-replace #px"/+$" path ""))

  (define (duplicate-vfs-target? entries path)
    (define norm-path (normalize-vfs-preload-path-for-duplicates path))
    (for/or ([existing (in-list entries)])
      (equal? norm-path
              (normalize-vfs-preload-path-for-duplicates
               (hash-ref existing 'path)))))

  (define (vfs-subpath-or-same? path maybe-parent)
    (define p (normalize-vfs-preload-path-for-duplicates path))
    (define parent (normalize-vfs-preload-path-for-duplicates maybe-parent))
    (define parent-prefix (if (equal? parent "/") "/" (string-append parent "/")))
    (or (equal? p parent)
        (string-prefix? p parent-prefix)))

  (define (add-vfs-preload-entry! entry)
    (define path (hash-ref entry 'path))
    (when (duplicate-vfs-target? vfs-preloads path)
      (error 'webracket (format "duplicate VFS preload target path: ~a" path)))
    (when (for/or ([mount (in-list vfs-mounts)])
            (vfs-subpath-or-same? path (hash-ref mount 'path)))
      (error 'webracket (format "VFS preload target is inside mounted backend: ~a" path)))
    (set! vfs-preloads (cons entry vfs-preloads)))

  (define (add-vfs-mount-entry! entry)
    (define path (hash-ref entry 'path))
    (when (duplicate-vfs-target? vfs-mounts path)
      (error 'webracket (format "duplicate VFS mount target path: ~a" path)))
    (when (for/or ([preload (in-list vfs-preloads)])
            (vfs-subpath-or-same? (hash-ref preload 'path) path))
      (error 'webracket (format "VFS mount target contains preload target: ~a" path)))
    (set! vfs-mounts (cons entry vfs-mounts)))

  (define (validate-vfs-preload-path! who path)
    (when (string=? path "")
      (error who "VFS preload target path is empty"))
    (unless (regexp-match? #px"^/" path)
      (error who (format "VFS preload target path must be absolute, got: ~a" path)))
    (when (regexp-match? #rx#"\0" path)
      (error who (format "VFS preload target path contains NUL: ~a" path))))

  (define (validate-vfs-base64-source! who source)
    (unless (regexp-match? #px"^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$" source)
      (error who (format "VFS preload base64 source is invalid: ~a" source))))

  (define (parse-vfs-preload who kind spec)
    (match (regexp-match #px"^([^=]+)=(.*)$" spec)
      [(list _ path source)
       (validate-vfs-preload-path! who path)
       (when (and (string=? source "")
                  (not (memq kind '(text base64))))
         (error who (format "VFS preload source is empty: ~a" spec)))
       (when (eq? kind 'base64)
         (validate-vfs-base64-source! who source))
       (hasheq 'path path 'kind kind 'source source)]
      [_ (error who (format "expected VFS=SOURCE, got: ~a" spec))]))

  (define (add-vfs-preload! kind spec)
    (add-vfs-preload-entry! (parse-vfs-preload 'webracket kind spec)))

  (define (add-vfs-mkdir! path)
    (validate-vfs-preload-path! 'webracket path)
    (add-vfs-preload-entry! (hasheq 'path path 'kind 'directory 'source #t)))

  (define (infer-vfs-tar-compression kind source)
    (and (memq kind '(file url))
         (regexp-match? #px"(?i:(\\.tar\\.gz|\\.tgz))$" source)
         'gzip))

  (define (add-vfs-tar-mount! kind spec #:compression [compression #f])
    (define entry (parse-vfs-preload 'webracket kind spec))
    (define source (hash-ref entry 'source))
    (define effective-compression
      (or compression (infer-vfs-tar-compression kind source)))
    (define mount-entry
      (hasheq 'path (hash-ref entry 'path)
              'kind 'tar
              'source-kind kind
              'source source))
    (add-vfs-mount-entry!
     (if effective-compression
         (hash-set mount-entry 'compression effective-compression)
         mount-entry)))

  (define positional-filenames
    (command-line
     #:program "webracket"
     #:argv argv
     #:once-each
     [("-r" "--run") "Run the program after compilation."
                     (set! run-after #t)]
     [("-v" "--verbose") "Compile with verbose messages"
                         (set! verbose-mode #t)]
     [("--wat-file") filename "Filename for the wat file"
                      (set! wat-filename filename)]
     [("--wasm-file") filename "Filename for the wasm file"
                       (set! wasm-filename filename)]
     [("--host-file") filename "Filename for the host file"
                       (set! host-filename filename)]
     [("--dest") dirname "Write default outputs under <dir>"
                 (set! dest-dir dirname)]
     [("--label-map-forms") "Include heavyweight (form ...) entries in .wasm.map.sexp"
                            (set! label-map-forms #t)]
     [("--no-label-map-forms") "Omit (form ...) entries in .wasm.map.sexp (default)"
                               (set! label-map-forms #f)]
     [("--dump-passes") dir "Write per-pass dumps to directory <dir>"
                        (set! dump-passes-dir dir)]
     [("--dump-passes-limit") n "Dump at most <n> passes (0 means no dumps)"
                               (define maybe-n (string->number n))
                               (unless (and maybe-n (exact-integer? maybe-n) (>= maybe-n 0))
                                 (error 'webracket
                                        (format "--dump-passes-limit expects an exact nonnegative integer, got: ~a" n)))
                               (set! dump-passes-limit maybe-n)]
     [("--timings") "Print timing breakdown for compilation steps"
                    (set! timings? #t)]
     [("--alpha-rename-profile")
      "Print alpha-rename/pass1 counters and helper timings"
      (set! alpha-rename-profile? #t)]
     [("--simplify-profile")
      "Print simplify-LFE rule and shape diagnostics"
      (set! simplify-profile? #t)]
     [("--pretty-wat") "Write .wat with pretty formatting"
                       (set! pretty-wat? #t)]
     [("--no-pretty-wat") "Write .wat without pretty formatting (default)"
                          (set! pretty-wat? #f)]
     [("--list-primitives") "Print the list of all primitives and exit"
                            (set! list-primitives? #t)]
     [("--list-provider-slices") "Print original-Racket provider slices and exit"
                                 (set! list-provider-slices? #t)]
     [("--server-start") "Run the local compile server in the foreground"
                         (set! server-command 'start)]
     [("--server-status") "Print local compile server status and exit"
                          (set! server-command 'status)]
     [("--server-stop") "Stop the local compile server and exit"
                        (set! server-command 'stop)]
     [("--enable-cc-analysis") "Enable the new closure-conversion analysis"
                               (set! enable-cc-analysis? #t)]
     [("--enable-simplify") "Run the early simplify-LFE pass"
                            (set! enable-simplify? #t)]
     [("--module-bridge-elide-public-cells")
      "Expose safe module-bridge public exports as plain values"
      (set! module-bridge-elide-public-cells? #t)]
     [("--tree-shake") "Tree shake runtime primitives (default)"
                       (set! tree-shake? #t)]
     [("--no-tree-shake") "Do not tree shake runtime primitives"
                          (set! tree-shake? #f)]
     [("--tree-shake-report") filename
                              "Write the runtime primitive report to <filename>"
                              (set! tree-shake-report filename)]
     [("--letrec-basic") "Use the basic letrec lowering strategy"
                         (set! letrec-strategy 'basic)]
     [("--letrec-waddell") "Use the Waddell letrec lowering strategy"
                           (set! letrec-strategy 'waddell)]
     [("--letrec-scc") "Use the SCC letrec lowering strategy (default)"
                       (set! letrec-strategy 'scc)]
     [("--print-top-level-results")
      "Print each top-level expression result with print; useful for script-style tests"
      (set! print-top-level-results? #t)]
     [("--internal-bind-treelist-debug-shape")
      "Enable compiler recognition of the private treelist shape hook for internal smokes"
      (set! internal-bind-treelist-debug-shape? #t)]
     [("--internal-bind-immutable-hash-debug-shape")
      "Enable compiler recognition of the private immutable hash shape hook for internal smokes"
      (set! internal-bind-immutable-hash-debug-shape? #t)]
     [("--console-bridge") "Install the browser console bridge as globalThis.WR"
                           (set! console-bridge? #t)]
     [("--no-console-bridge") "Do not install the browser console bridge (default)"
                              (set! console-bridge? #f)]
     [("--stdlib") "Include the legacy standard library"
                   (set! stdlib? #t)]
     [("--no-stdlib") "Do not include the legacy standard library (default)"
                      (set! stdlib? #f)]
     [("--io-format-provider" "--stdlib-io-format-provider")
      "Compose staged original-Racket io/format provider (default for script-style input)"
      (set! stdlib-io-format-provider? #t)]
     [("--no-io-format-provider" "--no-stdlib-io-format-provider")
      "Disable staged original-Racket io/format provider for debugging"
      (set! stdlib-io-format-provider? #f)]
     [("--expander-read-provider")
      "Compose staged original-Racket expander/read provider with Webify-owned aliases"
      (set! expander-read-provider? #t)]
     [("--no-expander-read-provider")
      "Disable staged original-Racket expander/read provider (default)"
      (set! expander-read-provider? #f)]
     [("--expander-read-syntax-provider")
      "Compose private staged original-Racket read-syntax provider"
      (set! expander-read-syntax-provider? #t)]
     [("--no-expander-read-syntax-provider")
      "Disable private staged original-Racket read-syntax provider (default)"
      (set! expander-read-syntax-provider? #f)]
     [("--webracket-module-bridge")
      "Force #lang webracket/base or full through the module bridge"
      (set! webracket-module-bridge? #t)]
     [("--no-provider-substitutions")
      "Disable Goal 1 racket/* -> webracket/* provider substitutions for diagnostics"
      (set! provider-substitutions? #f)]
     [("--provider-substitutions")
      "Enable Goal 1 provider substitutions (default)"
      (set! provider-substitutions? #t)]
     [("--provider-cache-dir") dirname
                               "Use <dirname> for provider-slice caches"
                               (set! provider-cache-dir dirname)]
     [("--provider-cache-report")
      "Print installed-provider report cache entries and exit"
      (set! provider-cache-report? #t)]
     [("--clear-provider-cache") "Delete the provider cache directory before compiling"
                                 (set! clear-provider-cache? #t)]
     [("--force-provider-cache-refresh")
      "Regenerate provider cache artifacts even when fingerprints match"
      (set! force-provider-cache-refresh? #t)]
     #:once-any
     [("-b" "--browser") "Generate code for browser."
                         (set! nodejs #f)
                         (set! browser #t)]
     [("-n" "--node") "Generate code for Node.js"
                      (set! browser #f)
                      (set! nodejs #t)]
     #:multi
     [("-l" "--link-flags") lf
                            "Add a flag <lf> for the linker"
                            (set! link-flags (cons lf link-flags))]
     #:multi
     [("--ffi") ffi-file
                "Add .ffi file"
                (set! ffi-files (cons ffi-file ffi-files))]
     [("--vfs-file") spec
                     "Preload Node host file into VFS as VFS=SOURCE"
                     (add-vfs-preload! 'file spec)]
     [("--vfs-url") spec
                    "Preload URL into VFS as VFS=SOURCE"
                    (add-vfs-preload! 'url spec)]
     [("--vfs-text") spec
                     "Preload inline text into VFS as VFS=TEXT"
                     (add-vfs-preload! 'text spec)]
     [("--vfs-base64") spec
                       "Preload inline base64 bytes into VFS as VFS=BASE64"
                       (add-vfs-preload! 'base64 spec)]
     [("--vfs-mkdir") path
                      "Preload empty VFS directory"
                      (add-vfs-mkdir! path)]
     [("--vfs-dir") spec
                    "Preload Node host directory into VFS as VFS=SOURCE"
                    (add-vfs-preload! 'directory spec)]
     [("--vfs-tar-file") spec
                         "Mount Node host tar into VFS as VFS=SOURCE"
                         (add-vfs-tar-mount! 'file spec)]
     [("--vfs-tar-url") spec
                        "Mount tar URL into VFS as VFS=SOURCE"
                        (add-vfs-tar-mount! 'url spec)]
     #:args filenames
     filenames))

  (define (ensure-no-positional-filenames! who)
    (unless (null? positional-filenames)
      (error who "does not accept source filenames")))

  (cond
    [list-primitives?
     (webracket-cli-command 'list-primitives (reverse ffi-files))]
    [list-provider-slices?
     (webracket-cli-command 'list-provider-slices #f)]
    [provider-cache-report?
     (webracket-cli-command 'provider-cache-report provider-cache-dir)]
    [server-command
     (ensure-no-positional-filenames! 'webracket)
     (webracket-cli-command
      (case server-command
        [(start)  'server-start]
        [(status) 'server-status]
        [(stop)   'server-stop])
      #f)]
    [else
     (unless (= (length positional-filenames) 1)
       (error 'webracket
              (format "expected exactly one source filename, got ~a"
                      (length positional-filenames))))
     (set! source-filename (car positional-filenames))
     (webracket-cli-command
      'compile
      (webracket-compile-config
       run-after
       verbose-mode
       wat-filename
       wasm-filename
       host-filename
       dest-dir
       label-map-forms
       dump-passes-dir
       dump-passes-limit
       timings?
       alpha-rename-profile?
       simplify-profile?
       pretty-wat?
       enable-cc-analysis?
       enable-simplify?
       module-bridge-elide-public-cells?
       tree-shake?
       tree-shake-report
       letrec-strategy
       print-top-level-results?
       internal-bind-treelist-debug-shape?
       internal-bind-immutable-hash-debug-shape?
       console-bridge?
       browser
       nodejs
       (reverse link-flags)
       ffi-files
       (reverse vfs-preloads)
       (reverse vfs-mounts)
       source-filename
       stdlib?
       stdlib-io-format-provider?
       expander-read-provider?
       expander-read-syntax-provider?
       webracket-module-bridge?
       provider-substitutions?
       provider-cache-dir
       clear-provider-cache?
       force-provider-cache-refresh?))]))

;; run-webracket-compile : webracket-compile-config? -> (values exact-integer? any/c compilation-output-paths?)
;;   Run one compile using the shared driver path.
(define (run-webracket-compile cfg)
  (define output-paths
    (resolve-compilation-output-paths
     (webracket-compile-config-source-filename cfg)
     (webracket-compile-config-wat-filename cfg)
     (webracket-compile-config-wasm-filename cfg)
     (webracket-compile-config-host-filename cfg)
     (webracket-compile-config-dest-dir cfg)
     (webracket-compile-config-nodejs cfg)))
  (define-values (exit-code compile-timings)
    (drive-compilation #:filename (webracket-compile-config-source-filename cfg)
                       #:wat-filename (webracket-compile-config-wat-filename cfg)
                       #:wasm-filename (webracket-compile-config-wasm-filename cfg)
                       #:host-filename (webracket-compile-config-host-filename cfg)
                       #:dest-dir (webracket-compile-config-dest-dir cfg)
                       #:label-map-forms? (webracket-compile-config-label-map-forms cfg)
                       #:dump-passes-dir (webracket-compile-config-dump-passes-dir cfg)
                       #:dump-passes-limit (webracket-compile-config-dump-passes-limit cfg)
                       #:timings? (webracket-compile-config-timings? cfg)
                       #:alpha-rename-profile? (webracket-compile-config-alpha-rename-profile? cfg)
                       #:simplify-profile? (webracket-compile-config-simplify-profile? cfg)
                       #:pretty-wat? (webracket-compile-config-pretty-wat? cfg)
                       #:verbose? (webracket-compile-config-verbose-mode cfg)
                       #:browser? (webracket-compile-config-browser cfg)
                       #:node? (webracket-compile-config-nodejs cfg)
                       #:letrec-strategy (webracket-compile-config-letrec-strategy cfg)
                       #:enable-cc-analysis? (webracket-compile-config-enable-cc-analysis? cfg)
                       #:enable-simplify? (webracket-compile-config-enable-simplify? cfg)
                       #:module-bridge-elide-public-cells?
                       (webracket-compile-config-module-bridge-elide-public-cells? cfg)
                       #:tree-shake? (webracket-compile-config-tree-shake? cfg)
                       #:tree-shake-report (webracket-compile-config-tree-shake-report cfg)
                       #:print-top-level-results? (webracket-compile-config-print-top-level-results? cfg)
                       #:internal-bind-treelist-debug-shape?
                       (webracket-compile-config-internal-bind-treelist-debug-shape? cfg)
                       #:internal-bind-immutable-hash-debug-shape?
                       (webracket-compile-config-internal-bind-immutable-hash-debug-shape? cfg)
                       #:console-bridge? (webracket-compile-config-console-bridge? cfg)
                       #:vfs-preloads (webracket-compile-config-vfs-preloads cfg)
                       #:vfs-mounts (webracket-compile-config-vfs-mounts cfg)
                       #:run-after? (webracket-compile-config-run-after cfg)
                       #:ffi-files (webracket-compile-config-ffi-files cfg)
                       #:stdlib? (webracket-compile-config-stdlib? cfg)
                       #:stdlib-io-format-provider? (webracket-compile-config-stdlib-io-format-provider? cfg)
                       #:expander-read-provider? (webracket-compile-config-expander-read-provider? cfg)
                       #:expander-read-syntax-provider?
                       (webracket-compile-config-expander-read-syntax-provider? cfg)
                       #:webracket-module-bridge?
                       (webracket-compile-config-webracket-module-bridge? cfg)
                       #:provider-substitutions?
                       (webracket-compile-config-provider-substitutions? cfg)
                       #:provider-cache-dir
                       (or (webracket-compile-config-provider-cache-dir cfg)
                           webify-regexp-default-cache-root)
                       #:clear-provider-cache?
                       (webracket-compile-config-clear-provider-cache? cfg)
                       #:force-provider-cache-refresh?
                       (webracket-compile-config-force-provider-cache-refresh? cfg)))
  (values exit-code compile-timings output-paths))

;; run-webracket-cli-command : webracket-cli-command? -> exact-integer?
;;   Execute one parsed command locally and return the exit code.
(define (run-webracket-cli-command command)
  (match (webracket-cli-command-kind command)
    ['list-primitives
     (for ([name (in-list (list-available-primitives
                           #:ffi-files (webracket-cli-command-payload command)))])
       (displayln name))
     0]
    ['list-provider-slices
     (for ([line (in-list (provider-slice-report-lines))])
       (displayln line))
     0]
    ['provider-cache-report
     (current-provider-cache-dir
      (path->complete-path
       (if (webracket-cli-command-payload command)
           (string->path (webracket-cli-command-payload command))
           webify-regexp-default-cache-root)))
     (for ([entry (in-list (provider-report-cache-entries))])
       (match-define (list path size mtime) entry)
       (printf "~a\t~a\t~a\n" path size mtime))
     0]
    ['compile
     (define-values (exit-code _compile-timings _output-paths)
       (run-webracket-compile (webracket-cli-command-payload command)))
     exit-code]
    [else
     (error 'run-webracket-cli-command
            "unsupported command kind: ~a"
            (webracket-cli-command-kind command))]))
