#lang racket/base

;;; Check Split Runtime Browser
;;;

;; This regression-style check verifies the browser half of the compile-once
;; split-runtime workflow. It prewarms the stable runtime cache, compiles a
;; tiny browser program with `--split-runtime`, serves the generated directory,
;; and uses Playwright to prove that both the program wasm and runtime wasm are
;; fetched and the program actually runs.


;;; Imports

(require json
         racket/cmdline
         racket/file
         racket/format
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         racket/system)


;;; Repository Paths

;; repo-dir : path?
;;   Absolute path to the repository root.
(define-runtime-path repo-dir "..")
(define repo-root
  (simplify-path repo-dir))

;; default-source-file : path?
;;   Default no-stdlib source used by the browser split-runtime check.
(define default-source-file
  (build-path repo-root "test" "test-trivial.rkt"))


;;; Command-Line Configuration

(define source-file default-source-file)
(define expected-output-pattern "(^|\\n)42(\\n|$)")
(define keep-temp? #f)
(define force-prewarm? #f)
(define shared-runtime-url? #f)
(define shared-runtime-url "runtime.wasm")
(define core-only? #f)
(define node-command "node")
(define node-modules #f)
(define chrome-executable #f)
(define timeout-ms 45000)

;; env-ref* : (listof string?) (or/c string? #f) -> (or/c string? #f)
;;   Return the first non-empty environment variable value from names.
(define (env-ref* names fallback)
  (or (for/or ([name (in-list names)])
        (define value (and name (getenv name)))
        (and value (not (string=? value "")) value))
      fallback))

;; resolve-source-path : string? -> path?
;;   Resolve a user-provided source path relative to the repository root.
(define (resolve-source-path s)
  (define p (string->path s))
  (simplify-path
   (if (absolute-path? p)
       p
       (build-path repo-root p))))

;; positive-integer-string? : string? -> boolean?
;;   Check whether s is a positive exact integer in decimal notation.
(define (positive-integer-string? s)
  (define n (string->number s))
  (and (exact-integer? n) (positive? n)))

(command-line
 #:program "check-split-runtime-browser"
 #:once-each
 [("--source") path
  "Source file to compile/run; defaults to test/test-trivial.rkt."
  (set! source-file (resolve-source-path path))]
 [("--expect") pattern
  "JavaScript regular expression expected in browser console output; defaults to a line containing 42."
  (set! expected-output-pattern pattern)]
 [("--no-expect")
  "Only validate browser load/fetch success; do not validate console output."
  (set! expected-output-pattern #f)]
 [("--force-prewarm")
  "Force refresh of the staged provider/runtime cache during prewarm."
  (set! force-prewarm? #t)]
 [("--shared-runtime-url")
  "Compile with --split-runtime-core-url runtime.wasm and verify no per-program sidecar is produced."
  (set! shared-runtime-url? #t)]
 [("--split-runtime-core-only")
  "Use the core-helper-only split runtime strategy for prewarm and compile."
  (set! core-only? #t)]
 [("--keep-temp")
  "Keep the temporary check directory after a successful run."
  (set! keep-temp? #t)]
 [("--node") path
  "Node executable to use. Defaults to SPLIT_RUNTIME_BROWSER_NODE or node."
  (set! node-command path)]
 [("--node-modules") path
  "node_modules directory containing Playwright."
  (set! node-modules path)]
 [("--chrome-executable") path
  "Chromium/Chrome executable path. Defaults to smoke/browser environment variables when set."
  (set! chrome-executable path)]
 [("--timeout-ms") ms
  "Browser timeout in milliseconds."
  (unless (positive-integer-string? ms)
    (raise-user-error 'check-split-runtime-browser
                      "expected positive integer timeout, got ~a"
                      ms))
  (set! timeout-ms (string->number ms))])


;;; Subprocess Helpers

;; command-result : boolean? string? string? real? -> command-result?
;;   Captured subprocess result.
(struct command-result (ok? stdout stderr wall-ms) #:transparent)

;; ensure-executable : string? -> path?
;;   Resolve an executable from PATH or fail with a helpful error.
(define (ensure-executable name)
  (or (find-executable-path name)
      (error 'check-split-runtime-browser
             "required executable not found in PATH: ~a"
             name)))

;; run-command/capture : path-string? path-string? (listof string?) -> command-result?
;;   Run a command under `cwd`, capturing stdout/stderr and wall time in ms.
(define (run-command/capture cwd exe args)
  (define out (open-output-string))
  (define err (open-output-string))
  (define start-ms (current-inexact-milliseconds))
  (define ok?
    (parameterize ([current-directory cwd]
                   [current-output-port out]
                   [current-error-port err])
      (apply system* exe args)))
  (define end-ms (current-inexact-milliseconds))
  (command-result ok?
                  (get-output-string out)
                  (get-output-string err)
                  (- end-ms start-ms)))

;; write-log! : path-string? path-string? (listof string?) command-result? -> void?
;;   Save a command transcript for later inspection.
(define (write-log! path exe args result)
  (call-with-output-file path
    (lambda (out)
      (fprintf out "$ ~a\n\n"
               (string-join (cons (path->string exe) args) " "))
      (displayln ";;; stdout" out)
      (display (command-result-stdout result) out)
      (unless (or (string=? (command-result-stdout result) "")
                  (string-suffix? (command-result-stdout result) "\n"))
        (newline out))
      (displayln ";;; stderr" out)
      (display (command-result-stderr result) out))
    #:exists 'truncate/replace))

;; transcript-contains? : command-result? regexp? -> boolean?
;;   Check stdout and stderr for a regexp.
(define (transcript-contains? result rx)
  (regexp-match? rx
                 (string-append (command-result-stdout result)
                                "\n"
                                (command-result-stderr result))))

;; format-seconds : real? -> string?
;;   Format milliseconds as seconds.
(define (format-seconds ms)
  (~r (/ ms 1000.0) #:precision '(= 1)))


;;; Artifact Helpers

;; generated-path : path-string? path? string? -> path?
;;   Return a generated artifact path in `dest-dir`.
(define (generated-path dest-dir source ext)
  (build-path dest-dir
              (path-replace-extension (file-name-from-path source) ext)))

;; split-runtime-generated-path : path-string? path? string? -> path?
;;   Return a generated split-runtime sidecar artifact path in `dest-dir`.
(define (split-runtime-generated-path dest-dir source ext)
  (define base
    (path-replace-extension (file-name-from-path source) #""))
  (build-path dest-dir
              (string->path
               (format "~a.runtime~a"
                       (path->string base)
                       ext))))

;; wasm-magic? : path-string? -> boolean?
;;   Check whether path starts with the WebAssembly magic bytes.
(define (wasm-magic? path)
  (and (file-exists? path)
       (call-with-input-file path
         (lambda (in)
           (equal? (for/list ([_ (in-range 4)])
                     (read-byte in))
                   '(0 97 115 109))))))

;; cached-runtime-wasm-files : path-string? -> (listof path?)
;;   Return non-lock runtime wasm files in the stable split-runtime cache.
(define (cached-runtime-wasm-files runtime-cache)
  (define cache-root
    (build-path runtime-cache "split-runtime-core-v3"))
  (if (directory-exists? cache-root)
      (find-files
       (lambda (p)
         (and (file-exists? p)
              (equal? (path-get-extension p) #".wasm")
              (not (regexp-match? #rx"^\\.LOCK"
                                  (path->string (file-name-from-path p))))))
       cache-root)
      '()))

;; record-failure! : string? any/c ... -> void?
;;   Accumulate a formatted check failure.
(define failures '())
(define (record-failure! fmt . args)
  (set! failures (cons (apply format fmt args) failures)))


;;; Browser Runner

;; browser-run-script : string?
;;   Node/Playwright runner for generated browser split-runtime output.
(define browser-run-script
  #<<JS
import { createRequire } from "node:module";
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import process from "node:process";

const config = JSON.parse(process.argv[2] || "{}");

function fail(category, message, details = {}) {
  console.error(`FAIL ${category}: ${message}`);
  for (const [key, value] of Object.entries(details)) {
    if (value !== null && value !== undefined && value !== "") {
      console.error(`  ${key}: ${value}`);
    }
  }
  process.exit(2);
}

function report(kind, message, details = {}) {
  const parts = [`${kind}: ${message}`];
  for (const [key, value] of Object.entries(details)) {
    if (value !== null && value !== undefined && value !== "") {
      parts.push(`${key}=${value}`);
    }
  }
  console.log(parts.join(" "));
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function contentType(filePath) {
  switch (path.extname(filePath)) {
    case ".html": return "text/html; charset=utf-8";
    case ".js": return "text/javascript; charset=utf-8";
    case ".wasm": return "application/wasm";
    case ".wat": return "text/plain; charset=utf-8";
    default: return "application/octet-stream";
  }
}

function createStaticServer(rootDir, defaultPage) {
  const root = path.resolve(rootDir);
  const rootPrefix = `${root}${path.sep}`;
  return http.createServer((req, res) => {
    let pathname = "/";
    try {
      pathname = decodeURIComponent(new URL(req.url, "http://127.0.0.1").pathname);
    } catch (_err) {
      res.writeHead(400, { "content-type": "text/plain; charset=utf-8" });
      res.end("bad request");
      return;
    }

    if (pathname === "/") {
      pathname = `/${defaultPage}`;
    }

    const filePath = path.resolve(root, `.${pathname}`);
    if (filePath !== root && !filePath.startsWith(rootPrefix)) {
      res.writeHead(403, { "content-type": "text/plain; charset=utf-8" });
      res.end("forbidden");
      return;
    }

    fs.readFile(filePath, (err, bytes) => {
      if (err) {
        res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
        res.end("not found");
        return;
      }
      res.writeHead(200, { "content-type": contentType(filePath) });
      res.end(bytes);
    });
  });
}

async function withTimeout(label, timeoutMs, thunk) {
  let timeoutId = null;
  try {
    return await Promise.race([
      thunk(),
      new Promise((_, reject) => {
        timeoutId = setTimeout(
          () => reject(new Error(`timeout after ${timeoutMs}ms during ${label}`)),
          timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutId !== null) {
      clearTimeout(timeoutId);
    }
  }
}

async function importPlaywright() {
  const requireHere = createRequire(import.meta.url);
  try {
    return { pkg: requireHere("playwright"), from: "default" };
  } catch (err) {
    const nodeModules = config.nodeModules || "";
    if (!nodeModules) {
      fail("playwright-missing", "could not import Playwright", {
        defaultError: err && err.message,
      });
    }
    try {
      const requireFromLocal = createRequire(`${nodeModules}/_resolver.js`);
      return { pkg: requireFromLocal("playwright"), from: nodeModules };
    } catch (err2) {
      fail("playwright-missing", "could not import Playwright", {
        defaultError: err && err.message,
        nodeModules,
        nodeModulesError: err2 && err2.message,
      });
    }
  }
}

async function waitForConsoleMatch(consoleEntries, pageErrors, requestFailures, expected, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  const rx = expected ? new RegExp(expected) : null;

  while (Date.now() < deadline) {
    if (requestFailures.length > 0) {
      fail("request-failed", "browser request failed", {
        requestFailures: requestFailures.join("\n"),
        console: consoleEntries.map((entry) => `${entry.type}: ${entry.text}`).join("\n"),
      });
    }
    if (pageErrors.length > 0) {
      fail("page-error", "browser page raised an error", {
        pageErrors: pageErrors.join("\n"),
        console: consoleEntries.map((entry) => `${entry.type}: ${entry.text}`).join("\n"),
      });
    }
    if (!rx) {
      return;
    }

    const text = consoleEntries.map((entry) => entry.text).join("\n");
    if (rx.test(text)) {
      return;
    }
    await sleep(100);
  }

  fail("expected-output-missing", "browser console did not match expected output", {
    expected,
    console: consoleEntries.map((entry) => `${entry.type}: ${entry.text}`).join("\n"),
  });
}

async function waitForRequiredFetches(fetchedNames, pageErrors, requestFailures, requiredNames, timeoutMs) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    if (requestFailures.length > 0) {
      fail("request-failed", "browser request failed", {
        requestFailures: requestFailures.join("\n"),
      });
    }
    if (pageErrors.length > 0) {
      fail("page-error", "browser page raised an error", {
        pageErrors: pageErrors.join("\n"),
      });
    }

    const fetched = new Set(fetchedNames);
    const missing = requiredNames.filter((name) => !fetched.has(name));
    if (missing.length === 0) {
      return;
    }
    await sleep(100);
  }

  fail("missing-fetch", "generated page did not fetch an expected artifact", {
    requiredNames: requiredNames.join(","),
    fetched: Array.from(new Set(fetchedNames)).sort().join(","),
  });
}

async function main() {
  const timeoutMs = Number.isFinite(config.timeoutMs) ? config.timeoutMs : 45000;
  const { pkg: playwrightPkg, from: playwrightFrom } = await importPlaywright();
  report("PASS", "playwright-import", { from: playwrightFrom });

  const server = createStaticServer(config.destDir, config.htmlName);
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });

  const address = server.address();
  const url = `http://127.0.0.1:${address.port}/${config.htmlName}`;
  const fetchedNames = [];
  const requestFailures = [];
  const pageErrors = [];
  const consoleEntries = [];
  let browser = null;

  try {
    browser = await withTimeout("browser launch", timeoutMs, async () =>
      await playwrightPkg.chromium.launch({
        headless: true,
        executablePath: config.chromeExecutable || undefined,
      }));
    report("PASS", "browser-launch", { executablePath: config.chromeExecutable || "playwright-default" });

    const page = await browser.newPage();
    page.setDefaultTimeout(timeoutMs);
    page.on("console", (msg) => {
      consoleEntries.push({ type: msg.type(), text: msg.text() });
    });
    page.on("pageerror", (err) => {
      pageErrors.push(err && err.message ? err.message : String(err));
    });
    page.on("requestfailed", (request) => {
      const failure = request.failure();
      requestFailures.push(`${request.url()} ${failure ? failure.errorText : ""}`.trim());
    });
    page.on("response", (response) => {
      if (response.ok()) {
        fetchedNames.push(path.basename(new URL(response.url()).pathname));
      }
    });

    const response = await page.goto(url, { waitUntil: "load", timeout: timeoutMs });
    if (!response || !response.ok()) {
      fail("page-load-failed", "generated HTML did not load", {
        status: response && response.status(),
        url,
      });
    }

    await waitForConsoleMatch(consoleEntries,
                              pageErrors,
                              requestFailures,
                              config.expectedOutput || null,
                              timeoutMs);
    await waitForRequiredFetches(fetchedNames,
                                 pageErrors,
                                 requestFailures,
                                 [config.htmlName, config.programWasmName, config.runtimeWasmName],
                                 timeoutMs);
    await page.close();
  } catch (err) {
    fail("browser-run-failed",
         err && err.message ? err.message : String(err),
         {
           stack: err && err.stack,
           console: consoleEntries.map((entry) => `${entry.type}: ${entry.text}`).join("\n"),
         });
  } finally {
    if (browser) {
      await browser.close();
    }
    await new Promise((resolve) => server.close(resolve));
  }

  const fetched = new Set(fetchedNames);
  for (const requiredName of [config.htmlName, config.programWasmName, config.runtimeWasmName]) {
    if (!fetched.has(requiredName)) {
      fail("missing-fetch", "generated page did not fetch an expected artifact", {
        requiredName,
        fetched: Array.from(fetched).sort().join(","),
      });
    }
  }

  report("PASS", "browser-split-runtime-run", {
    url,
    fetched: Array.from(fetched).sort().join(","),
  });
}

main();
JS
)

;; write-node-script! : -> path?
;;   Materialize the embedded Node browser runner.
(define (write-node-script!)
  (define path
    (make-temporary-file "webracket-split-runtime-browser-~a.mjs"))
  (call-with-output-file path
    (lambda (out)
      (display browser-run-script out))
    #:exists 'truncate/replace)
  path)

;; run-browser-check! :
;;   path-string? path-string? path-string? path-string? path-string? -> command-result?
;;   Run the generated HTML in a headless browser and capture the transcript.
(define (run-browser-check! node-path node-script dest-dir html-path program-wasm runtime-wasm)
  (define config
    (jsexpr->string
     (hasheq 'destDir (path->string dest-dir)
             'htmlName (path->string (file-name-from-path html-path))
             'programWasmName (path->string (file-name-from-path program-wasm))
             'runtimeWasmName (path->string (file-name-from-path runtime-wasm))
             'expectedOutput (or expected-output-pattern (json-null))
             'nodeModules (or node-modules "")
             'chromeExecutable (or chrome-executable "")
             'timeoutMs timeout-ms)))
  (run-command/capture repo-root node-path (list (path->string node-script) config)))


;;; Defaults

;; executable-file? : path-string? -> boolean?
;;   Check whether path names an existing executable file.
(define (executable-file? p)
  (and p
       (file-exists? p)
       (with-handlers ([exn:fail? (lambda (_exn) #f)])
         (and (memq 'execute (file-or-directory-permissions p)) #t))))

;; candidate-headless-shells : path-string? -> (listof path?)
;;   Return cached Playwright headless-shell candidates under root.
(define (candidate-headless-shells root)
  (if (and root (directory-exists? root))
      (sort
       (find-files
        (lambda (p)
          (and (file-exists? p)
               (equal? (path->string (file-name-from-path p))
                       "chrome-headless-shell")
               (executable-file? p)))
        root)
       string<?
       #:key path->string)
      '()))

;; cached-playwright-headless-shell : -> (or/c string? #f)
;;   Return the newest cached Playwright headless shell when available.
(define (cached-playwright-headless-shell)
  (define override
    (getenv "PLAYWRIGHT_BROWSERS_PATH"))
  (define home
    (getenv "HOME"))
  (define roots
    (filter values
            (list override
                  (and home
                       (path->string
                        (build-path home "Library" "Caches" "ms-playwright"))))))
  (define candidates
    (append* (for/list ([root (in-list roots)])
               (candidate-headless-shells root))))
  (and (pair? candidates)
       (path->string (last candidates))))

;; default-chrome-executable : -> string?
;;   Choose an installed browser executable or let Playwright resolve one.
(define (default-chrome-executable)
  (or (cached-playwright-headless-shell)
      (let ([chrome "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"])
        (and (executable-file? chrome) chrome))
      ""))

;; configure-default-browser-tools! : -> void?
;;   Fill browser-tool defaults from the same environment conventions as smokes.
(define (configure-default-browser-tools!)
  (set! node-command
        (env-ref* '("SPLIT_RUNTIME_BROWSER_NODE"
                    "BROWSER_PREFLIGHT_NODE")
                  node-command))
  (unless node-modules
    (set! node-modules
          (env-ref* '("SPLIT_RUNTIME_BROWSER_NODE_MODULES"
                      "SMOKE_NODE_MODULES"
                      "BROWSER_PREFLIGHT_NODE_MODULES")
                    (path->string (build-path repo-root ".local-tools" "node_modules")))))
  (unless chrome-executable
    (set! chrome-executable
          (env-ref* '("SPLIT_RUNTIME_BROWSER_CHROME_EXECUTABLE"
                      "SMOKE_CHROME_EXECUTABLE"
                      "BROWSER_PREFLIGHT_CHROME_EXECUTABLE")
                    (default-chrome-executable)))))


;;; Main Check

;; run-check! : -> void?
;;   Prewarm, compile browser split output, and verify it runs in Playwright.
(define (run-check!)
  (configure-default-browser-tools!)
  (define racket-exe (ensure-executable "racket"))
  (define node-path (ensure-executable node-command))
  (unless (file-exists? source-file)
    (error 'check-split-runtime-browser
           "source file does not exist: ~a"
           source-file))

  (define temp-root
    (make-temporary-file "webracket-split-runtime-browser-check-~a" 'directory))
  (define provider-cache (build-path temp-root "provider-cache"))
  (define runtime-cache  (build-path temp-root "runtime-provider-cache"))
  (define compiled-root  (build-path temp-root "compiled-root"))
  (define dest-dir       (build-path temp-root "dest"))
  (make-directory* provider-cache)
  (make-directory* runtime-cache)
  (make-directory* compiled-root)
  (make-directory* dest-dir)
  (putenv "PLTCOMPILEDROOTS" (path->string compiled-root))

  (printf "Split runtime browser check\n")
  (printf "  source:        ~a\n" (path->string source-file))
  (printf "  temp:          ~a\n" (path->string temp-root))
  (printf "  compiled root: ~a\n" (path->string compiled-root))
  (printf "  runtime mode:  ~a\n"
          (if shared-runtime-url?
              (format "shared url (~a)" shared-runtime-url)
              "sidecar"))
  (printf "  split mode:    ~a\n" (if core-only? "core-only" "classified"))
  (printf "  node:          ~a\n" (path->string node-path))
  (printf "  node_modules:  ~a\n" node-modules)
  (printf "  chrome:        ~a\n\n" (if (string=? chrome-executable "")
                                      "playwright-default"
                                      chrome-executable))

  (define shared-runtime-wasm
    (build-path dest-dir shared-runtime-url))
  (define prewarm-args
    (append
     (list "-S" "pkgs" "tools/prewarm-staged-providers.rkt"
           "--provider-cache-dir" (path->string provider-cache)
           "--runtime-provider-cache-dir" (path->string runtime-cache)
           "--mode" "split-runtime"
           "--host" "browser")
     (if core-only?
         '("--split-runtime-core-only")
         '())
     (if shared-runtime-url?
         (list "--runtime-wasm-out" (path->string shared-runtime-wasm))
         '())
     (if force-prewarm? '("--force") '())))
  (define prewarm-result
    (run-command/capture repo-root racket-exe prewarm-args))
  (define prewarm-log (build-path temp-root "prewarm.log"))
  (write-log! prewarm-log racket-exe prewarm-args prewarm-result)
  (unless (command-result-ok? prewarm-result)
    (record-failure! "prewarm command failed; see ~a" prewarm-log))

  (define cached-wasms-after-prewarm
    (cached-runtime-wasm-files runtime-cache))
  (when (null? cached-wasms-after-prewarm)
    (record-failure! "prewarm did not create a cached split-runtime wasm in ~a"
                     runtime-cache))

  (define compile-args
    (append
     (list "-S" "pkgs" "webracket.rkt"
           "--browser" "--split-runtime" "--timings"
           "--no-stdlib"
           "--provider-cache-dir" (path->string provider-cache)
           "--runtime-provider-cache-dir" (path->string runtime-cache))
     (if shared-runtime-url?
         (list "--split-runtime-core-url" shared-runtime-url)
         '())
     (if core-only?
         '("--split-runtime-core-only")
         '())
     (list "--dest" (path->string dest-dir)
           (path->string source-file))))
  (define compile-result
    (run-command/capture repo-root racket-exe compile-args))
  (define compile-log (build-path temp-root "compile.log"))
  (write-log! compile-log racket-exe compile-args compile-result)

  (unless (command-result-ok? compile-result)
    (record-failure! "browser compile command failed; see ~a" compile-log))
  (cond
    [shared-runtime-url?
     (unless (transcript-contains? compile-result
                                   #rx"split-runtime-core:reference-wasm-hit")
       (record-failure! "browser shared-url compile did not reference the cached runtime wasm"))]
    [else
     (unless (transcript-contains? compile-result
                                   #rx"split-runtime-core:materialize-wasm-hit")
       (record-failure! "browser compile did not materialize the runtime wasm from cache"))])
  (when (transcript-contains? compile-result
                              #rx"split-runtime-core:assemble-wasm")
    (record-failure! "browser compile assembled the split runtime instead of using the cache"))
  (when (and (not shared-runtime-url?)
             (transcript-contains? compile-result
                                   #rx"split-runtime-core:reference-wasm-hit"))
    (record-failure! "browser sidecar compile used reference mode"))
  (when (and shared-runtime-url?
             (transcript-contains? compile-result
                                   #rx"split-runtime-core:materialize-wasm-hit"))
    (record-failure! "browser shared-url compile materialized a runtime sidecar"))

  (define html-path (generated-path dest-dir source-file ".html"))
  (define program-wasm (generated-path dest-dir source-file ".wasm"))
  (define runtime-sidecar-wasm (split-runtime-generated-path dest-dir source-file ".wasm"))
  (define runtime-wasm
    (if shared-runtime-url?
        shared-runtime-wasm
        runtime-sidecar-wasm))
  (for ([artifact (in-list (list html-path program-wasm runtime-wasm))])
    (unless (file-exists? artifact)
      (record-failure! "missing generated artifact: ~a" artifact)))
  (when (and shared-runtime-url?
             (file-exists? runtime-sidecar-wasm))
    (record-failure! "shared-url compile unexpectedly produced runtime sidecar: ~a"
                     runtime-sidecar-wasm))
  (unless (wasm-magic? program-wasm)
    (record-failure! "program wasm is missing WebAssembly magic bytes: ~a" program-wasm))
  (unless (wasm-magic? runtime-wasm)
    (record-failure! "runtime sidecar wasm is missing WebAssembly magic bytes: ~a" runtime-wasm))
  (when (file-exists? html-path)
    (define html (file->string html-path))
    (unless (regexp-match? #rx"coreWasmUrl" html)
      (record-failure! "generated HTML does not contain the split runtime loader"))
    (unless (regexp-match? (regexp-quote (path->string (file-name-from-path runtime-wasm)))
                           html)
      (record-failure! "generated HTML does not reference runtime wasm ~a"
                       (file-name-from-path runtime-wasm))))

  (define node-script (write-node-script!))
  (define browser-result
    (dynamic-wind
      void
      (lambda ()
        (run-browser-check! node-path node-script dest-dir html-path program-wasm runtime-wasm))
      (lambda ()
        (with-handlers ([exn:fail? void])
          (delete-file node-script)))))
  (define browser-log (build-path temp-root "browser.log"))
  (write-log! browser-log node-path (list (path->string node-script) "<config-json>") browser-result)
  (unless (command-result-ok? browser-result)
    (record-failure! "browser run failed; see ~a" browser-log))

  (cond
    [(null? failures)
     (printf "ok: prewarm=~as compile=~as browser=~as cached-runtime-wasms=~a\n"
             (format-seconds (command-result-wall-ms prewarm-result))
             (format-seconds (command-result-wall-ms compile-result))
             (format-seconds (command-result-wall-ms browser-result))
             (length cached-wasms-after-prewarm))
     (when keep-temp?
       (printf "kept temp: ~a\n" (path->string temp-root)))
     (unless keep-temp?
       (delete-directory/files temp-root))]
    [else
     (printf "failed: split runtime browser check\n")
     (for ([failure (in-list (reverse failures))])
       (printf "  - ~a\n" failure))
     (printf "kept temp: ~a\n" (path->string temp-root))
     (exit 1)]))

(module+ main
  (run-check!))
