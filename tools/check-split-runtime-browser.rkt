#lang racket/base

;;; Check Split Runtime Browser
;;;

;; This regression-style check verifies the browser half of the compile-once
;; split-runtime workflow. It prewarms the stable runtime cache, compiles a
;; tiny browser program in the default split-runtime mode, routes generated
;; artifact requests through Playwright, and proves that both the program wasm
;; and runtime wasm are fetched and the program actually runs.


;;; Imports

(require json
         racket/cmdline
         racket/file
         racket/format
         racket/list
         racket/path
         racket/runtime-path
         racket/string
         racket/system
         (only-in "../pkgs/webracket-lib/compiler/runtime-wasm/split-runtime-cache.rkt"
                  split-runtime-boundary-cache-current?
                  split-runtime-core-cache-directory
                  split-runtime-core-cache-key-fingerprint
                  split-runtime-core-cache-wasm-path
                  split-runtime-request-cache-fingerprint
                  make-split-runtime-core-cache-key
                  make-split-runtime-core-only-cache-key)
         (only-in "../pkgs/webracket-lib/compiler/runtime-wasm/runtime-source.rkt"
                  runtime-source-fingerprint))


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

;; check-temp-dir : -> path?
;;   Return the repo-local parent for temporary check directories.
(define (check-temp-dir)
  (define dir (build-path repo-root "tmp"))
  (make-directory* dir)
  dir)


;;; Command-Line Configuration

(define source-file default-source-file)
(define expected-output-pattern "(^|\\n)42(\\n|$)")
(define keep-temp? #f)
(define force-prewarm? #f)
(define shared-runtime-url? #f)
(define shared-runtime-url "runtime.wasm")
(define core-only? #f)
(define provider-runtime? #f)
(define isolate-compiled-root? #f)
(define package-copy-check? #t)
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
  "Compile with --split-runtime-core-url runtime.wasm and verify no local content-addressed runtime file is produced."
  (set! shared-runtime-url? #t)]
 [("--split-runtime-core-only")
  "Use the core-helper-only split runtime strategy for prewarm and compile."
  (set! core-only? #t)]
 [("--split-runtime-provider-runtime")
  "For module sources, check the provider-fragment-in-runtime split path."
  (set! provider-runtime? #t)]
 [("--isolate-compiled-root")
  "Run subprocesses with a private PLTCOMPILEDROOTS; useful for cold-root checks."
  (set! isolate-compiled-root? #t)]
 [("--no-package-copy-check")
  "Skip the deploy-copy packaging regression check."
  (set! package-copy-check? #f)]
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

(when (and provider-runtime? core-only?)
  (raise-user-error 'check-split-runtime-browser
                    "use --split-runtime-provider-runtime or --split-runtime-core-only, not both"))


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

;; configured-racket-command : -> string?
;;   Return the Racket executable to use for child compiler processes.
(define (configured-racket-command)
  (or (env-ref* '("WEBRACKET_RACKET" "RACKET") #f)
      (path->string (find-system-path 'exec-file))
      "racket"))

;; ensure-racket-executable : -> path?
;;   Resolve the configured child Racket executable.
(define (ensure-racket-executable)
  (ensure-executable (configured-racket-command)))

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

;; webracket-module-source? : path-string? -> boolean?
;;   Check whether source uses the module bridge path.
(define (webracket-module-source? source)
  (with-handlers ([exn:fail? (lambda (_exn) #f)])
    (call-with-input-file source
      (lambda (in)
        (define first-line
          (read-line in 'any))
        (and (string? first-line)
             (regexp-match? #px"^#lang[ \t]+webracket/(base|full)([ \t].*)?$"
                            first-line))))))

;; copy-file/replace! : path-string? path-string? -> void?
;;   Copy src to dest, replacing any existing file.
(define (copy-file/replace! src dest)
  (copy-file src dest #t))

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

;; content-sidecar-paths : path-string? string? -> (listof path?)
;;   Return content-addressed Wasm sidecars with the given filename prefix.
(define (content-sidecar-paths dest-dir prefix)
  (define sidecar-rx
    (regexp
     (format "^~a-[0-9a-f]+\\.wasm$"
             (regexp-quote prefix))))
  (sort
   (for/list ([path (in-list (directory-list dest-dir #:build? #t))]
              #:when
              (regexp-match? sidecar-rx
                             (path->string (file-name-from-path path))))
     path)
   string<?
   #:key path->string))

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
    (build-path runtime-cache split-runtime-core-cache-directory))
  (if (directory-exists? cache-root)
      (sort
       (find-files
        (lambda (p)
          (and (file-exists? p)
               (equal? (path-get-extension p) #".wasm")
               (not (regexp-match? #rx"^\\.LOCK"
                                   (path->string (file-name-from-path p))))))
        cache-root)
       string<?
       #:key path->string)
      '()))

;; cached-runtime-wasm-snapshot : path-string? -> list?
;;   Return stable file metadata for cached runtime wasm artifacts.
(define (cached-runtime-wasm-snapshot runtime-cache)
  (for/list ([p (in-list (cached-runtime-wasm-files runtime-cache))])
    (list (path->string p)
          (file-size p)
          (file-or-directory-modify-seconds p))))

;; expected-split-runtime-core-cache-key : -> any/c
;;   Build the cache key that browser split-runtime prewarm should populate.
(define (expected-split-runtime-core-cache-key)
  (define runtime-fingerprint
    (runtime-source-fingerprint))
  (if core-only?
      (make-split-runtime-core-only-cache-key runtime-fingerprint)
      (make-split-runtime-core-cache-key
       #t
       (split-runtime-request-cache-fingerprint
        #:browser? #t
        #:runtime-source-fingerprint runtime-fingerprint
        #:active-ffi-foreigns '()
        #:active-ffi-imports-wat '()
        #:active-ffi-funcs-wat '()))))

;; expected-split-runtime-core-wasm-path : path-string? any/c -> path?
;;   Return the exact cache wasm path implied by a split-runtime cache key.
(define (expected-split-runtime-core-wasm-path runtime-cache core-cache-key)
  (split-runtime-core-cache-wasm-path
   runtime-cache
   (split-runtime-core-cache-key-fingerprint core-cache-key)))

;; same-file-bytes? : path-string? path-string? -> boolean?
;;   Check whether two files have identical bytes.
(define (same-file-bytes? a b)
  (and (file-exists? a)
       (file-exists? b)
       (equal? (file->bytes a)
               (file->bytes b))))

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
import path from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

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

async function fulfillStaticRequest(route, rootDir, defaultPage) {
  const root = path.resolve(rootDir);
  const rootPrefix = `${root}${path.sep}`;
  let pathname = "/";
  try {
    pathname = decodeURIComponent(new URL(route.request().url()).pathname);
  } catch (_err) {
    await route.fulfill({
      status: 400,
      contentType: "text/plain; charset=utf-8",
      body: "bad request",
    });
    return;
  }

  if (pathname === "/") {
    pathname = `/${defaultPage}`;
  }

  const filePath = path.resolve(root, `.${pathname}`);
  if (filePath !== root && !filePath.startsWith(rootPrefix)) {
    await route.fulfill({
      status: 403,
      contentType: "text/plain; charset=utf-8",
      body: "forbidden",
    });
    return;
  }

  try {
    const bytes = await fs.promises.readFile(filePath);
    await route.fulfill({
      status: 200,
      contentType: contentType(filePath),
      body: bytes,
    });
  } catch (_err) {
    await route.fulfill({
      status: 404,
      contentType: "text/plain; charset=utf-8",
      body: "not found",
    });
  }
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

function environmentBrowserLaunchFailure(err) {
  const text = [
    err && err.message,
    err && err.stack,
  ].filter(Boolean).join("\n");

  return /MachPortRendezvous|bootstrap_check_in|Permission denied \(1100\)|No usable sandbox|Operation not permitted|EPERM|EACCES/i.test(text);
}

function extractInlineModuleScript(html) {
  const match = html.match(/<script\b[^>]*\btype=["']module["'][^>]*>([\s\S]*?)<\/script>/i);
  if (!match) {
    fail("node-browser-shim-missing-script",
         "generated HTML does not contain an inline module script");
  }
  return match[1];
}

function fileResponse(bytes, filePath) {
  return new Response(bytes, {
    status: 200,
    statusText: "OK",
    headers: { "content-type": contentType(filePath) },
  });
}

async function runNodeBrowserShim() {
  const root = path.resolve(config.destDir);
  const rootPrefix = `${root}${path.sep}`;
  const htmlPath = path.resolve(root, config.htmlName);
  const html = await fs.promises.readFile(htmlPath, "utf8");
  const moduleSource = extractInlineModuleScript(html);
  const modulePath = path.join(root, ".webracket-browser-shim-entry.mjs");
  const fetchedNames = [config.htmlName];
  const consoleEntries = [];
  const originalFetch = globalThis.fetch;
  const originalLog = console.log;
  const originalError = console.error;

  globalThis.fetch = async (specifier) => {
    const spec = String(specifier);
    const url = new URL(spec, pathToFileURL(`${root}${path.sep}`).href);
    if (url.protocol !== "file:") {
      throw new Error(`node browser shim only supports local artifact fetches: ${spec}`);
    }

    const filePath = path.resolve(url.pathname);
    if (filePath !== root && !filePath.startsWith(rootPrefix)) {
      return new Response("forbidden", { status: 403, statusText: "Forbidden" });
    }

    try {
      const bytes = await fs.promises.readFile(filePath);
      fetchedNames.push(path.basename(filePath));
      return fileResponse(bytes, filePath);
    } catch (_err) {
      return new Response("not found", { status: 404, statusText: "Not Found" });
    }
  };

  console.log = (...args) => {
    const text = args.map((arg) => String(arg)).join(" ");
    consoleEntries.push({ type: "log", text });
    originalLog(...args);
  };
  console.error = (...args) => {
    const text = args.map((arg) => String(arg)).join(" ");
    consoleEntries.push({ type: "error", text });
    originalError(...args);
  };

  try {
    await fs.promises.writeFile(modulePath, moduleSource);
    await import(`${pathToFileURL(modulePath).href}?t=${Date.now()}`);
  } finally {
    globalThis.fetch = originalFetch;
    console.log = originalLog;
    console.error = originalError;
  }

  if (config.expectedOutput) {
    const text = consoleEntries.map((entry) => entry.text).join("\n");
    if (!(new RegExp(config.expectedOutput)).test(text)) {
      fail("node-browser-shim-expected-output-missing",
           "generated module output did not match expected output",
           {
             expected: config.expectedOutput,
             console: consoleEntries.map((entry) => `${entry.type}: ${entry.text}`).join("\n"),
           });
    }
  }

  const fetched = new Set(fetchedNames);
  for (const requiredName of [config.htmlName, config.programWasmName, config.runtimeWasmName]) {
    if (!fetched.has(requiredName)) {
      fail("node-browser-shim-missing-fetch",
           "generated module did not fetch an expected artifact",
           {
             requiredName,
             fetched: Array.from(fetched).sort().join(","),
           });
    }
  }

  report("PASS", "node-browser-shim-run", {
    fetched: Array.from(fetched).sort().join(","),
  });
}

async function main() {
  const timeoutMs = Number.isFinite(config.timeoutMs) ? config.timeoutMs : 45000;
  const { pkg: playwrightPkg, from: playwrightFrom } = await importPlaywright();
  report("PASS", "playwright-import", { from: playwrightFrom });

  const url = `http://webracket.local/${config.htmlName}`;
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
    await page.route("**/*", async (route) =>
      fulfillStaticRequest(route, config.destDir, config.htmlName));
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
    if (environmentBrowserLaunchFailure(err)) {
      report("WARN", "browser-launch-unavailable", {
        message: err && err.message ? err.message.split("\n")[0] : String(err),
      });
      await runNodeBrowserShim();
      return;
    }
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

;; write-node-script! : path-string? -> path?
;;   Materialize the embedded Node browser runner.
(define (write-node-script! temp-root)
  (define path
    (make-temporary-file "webracket-split-runtime-browser-~a.mjs"
                         #f
                         temp-root))
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

;; copy-artifact/filename! : path-string? path-string? -> path?
;;   Copy artifact into package-dir under its own filename and return the copy.
(define (copy-artifact/filename! artifact package-dir)
  (define target
    (build-path package-dir (file-name-from-path artifact)))
  (copy-file/replace! artifact target)
  target)

;; check-packaged-runtime-copy! :
;;   path-string? path-string? path-string? path-string? path-string? path-string? -> command-result?
;;   Copy deployable artifacts to a package directory and run the copied page.
(define (check-packaged-runtime-copy! node-path node-script temp-root html-path program-wasm runtime-wasm)
  (define package-dir (build-path temp-root "packaged-browser-output"))
  (make-directory* package-dir)
  (define package-html (build-path package-dir "index.html"))
  (copy-file/replace! html-path package-html)
  (define package-program-wasm
    (copy-artifact/filename! program-wasm package-dir))
  (define package-runtime-wasm
    (copy-artifact/filename! runtime-wasm package-dir))
  (define html (file->string package-html))
  (unless (regexp-match? (regexp-quote
                          (path->string (file-name-from-path package-program-wasm)))
                         html)
    (record-failure! "packaged HTML does not reference program wasm ~a"
                     (file-name-from-path package-program-wasm)))
  (unless (regexp-match? (regexp-quote
                          (path->string (file-name-from-path package-runtime-wasm)))
                         html)
    (record-failure! "packaged HTML does not reference runtime wasm ~a"
                     (file-name-from-path package-runtime-wasm)))
  (run-browser-check! node-path
                      node-script
                      package-dir
                      package-html
                      package-program-wasm
                      package-runtime-wasm))

;; check-missing-runtime-copy! :
;;   path-string? path-string? path-string? path-string? path-string? path-string? -> command-result?
;;   Prove that a package missing runtime.wasm fails on the runtime fetch.
(define (check-missing-runtime-copy! node-path node-script temp-root html-path program-wasm runtime-wasm)
  (define package-dir (build-path temp-root "packaged-missing-runtime"))
  (make-directory* package-dir)
  (define package-html (build-path package-dir "index.html"))
  (copy-file/replace! html-path package-html)
  (define package-program-wasm
    (copy-artifact/filename! program-wasm package-dir))
  (define package-runtime-wasm
    (build-path package-dir (file-name-from-path runtime-wasm)))
  (run-browser-check! node-path
                      node-script
                      package-dir
                      package-html
                      package-program-wasm
                      package-runtime-wasm))


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
  (define racket-exe (ensure-racket-executable))
  (define node-path (ensure-executable node-command))
  (unless (file-exists? source-file)
    (error 'check-split-runtime-browser
           "source file does not exist: ~a"
           source-file))
  (when (and provider-runtime?
             (not (webracket-module-source? source-file)))
    (raise-user-error
     'check-split-runtime-browser
     "--split-runtime-provider-runtime requires a #lang webracket/base or #lang webracket/full source: ~a"
     source-file))

  (define temp-root
    (make-temporary-file "webracket-split-runtime-browser-check-~a"
                         'directory
                         (check-temp-dir)))
  (define provider-cache (build-path temp-root "provider-cache"))
  (define runtime-cache  (build-path temp-root "runtime-provider-cache"))
  (define compiled-root  (build-path temp-root "compiled-root"))
  (define dest-dir       (build-path temp-root "dest"))
  (make-directory* provider-cache)
  (make-directory* runtime-cache)
  (make-directory* dest-dir)
  (when isolate-compiled-root?
    (make-directory* compiled-root)
    (putenv "PLTCOMPILEDROOTS" (path->string compiled-root)))

  (printf "Split runtime browser check\n")
  (printf "  source:        ~a\n" (path->string source-file))
  (printf "  temp:          ~a\n" (path->string temp-root))
  (printf "  compiled root: ~a\n"
          (if isolate-compiled-root?
              (path->string compiled-root)
              "normal environment"))
  (printf "  runtime mode:  ~a\n"
          (if shared-runtime-url?
              (format "shared url (~a)" shared-runtime-url)
              "materialized-runtime"))
  (printf "  split mode:    ~a\n"
          (cond
            [provider-runtime? "provider-runtime"]
            [core-only? "core-only"]
            [else "classified"]))
  (printf "  node:          ~a\n" (path->string node-path))
  (printf "  node_modules:  ~a\n" node-modules)
  (printf "  chrome:        ~a\n\n" (if (string=? chrome-executable "")
                                      "playwright-default"
                                      chrome-executable))

  (define shared-runtime-wasm
    (build-path dest-dir shared-runtime-url))
  (define provider-runtime-prewarm-dest
    (build-path temp-root "provider-runtime-prewarm"))
  (define provider-runtime-prewarm-wasm
    (split-runtime-generated-path provider-runtime-prewarm-dest
                                  source-file
                                  ".wasm"))
  (define-values (prewarm-result prewarm-args)
    (cond
      [provider-runtime?
       (make-directory* provider-runtime-prewarm-dest)
       (define args
         (append
          (list "-S" "pkgs" "tools/prewarm-staged-providers.rkt"
                "--mode" "provider-runtime"
                "--host" "browser"
                "--provider-cache-dir" (path->string provider-cache)
                "--runtime-provider-cache-dir" (path->string runtime-cache)
                "--runtime-wasm-out" (path->string provider-runtime-prewarm-wasm))
          (if force-prewarm? '("--force") '())
          (list "--source" (path->string source-file))))
       (values (run-command/capture repo-root racket-exe args) args)]
      [else
       (define args
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
       (values (run-command/capture repo-root racket-exe args) args)]))
  (define prewarm-log (build-path temp-root "prewarm.log"))
  (write-log! prewarm-log racket-exe prewarm-args prewarm-result)
  (unless (command-result-ok? prewarm-result)
    (record-failure! "prewarm command failed; see ~a" prewarm-log))
  (when provider-runtime?
    (unless (file-exists? provider-runtime-prewarm-wasm)
      (record-failure! "provider-runtime prewarm did not produce runtime wasm: ~a"
                       provider-runtime-prewarm-wasm))
    (when (and shared-runtime-url?
               (file-exists? provider-runtime-prewarm-wasm))
      (copy-file/replace! provider-runtime-prewarm-wasm shared-runtime-wasm)))

  (define cached-wasms-after-prewarm
    (cached-runtime-wasm-files runtime-cache))
  (when (null? cached-wasms-after-prewarm)
    (record-failure! "prewarm did not create a cached split-runtime wasm in ~a"
                     runtime-cache))
  (define expected-core-cache-key
    (and (not provider-runtime?)
         (expected-split-runtime-core-cache-key)))
  (define expected-runtime-wasm
    (and expected-core-cache-key
         (expected-split-runtime-core-wasm-path runtime-cache
                                                expected-core-cache-key)))
  (when (and expected-runtime-wasm
             (not (file-exists? expected-runtime-wasm)))
    (record-failure! "prewarm did not create expected cached split-runtime wasm: ~a"
                     expected-runtime-wasm))
  (when (and expected-core-cache-key
             (not core-only?)
             (not (split-runtime-boundary-cache-current?
                   runtime-cache
                   expected-core-cache-key)))
    (record-failure! "prewarm did not create current split-boundary metadata for expected runtime key"))
  (define cached-wasm-snapshot-after-prewarm
    (cached-runtime-wasm-snapshot runtime-cache))

  (define provider-runtime-cache-hit-prewarm-result
    (if provider-runtime?
        (let ()
          (define cache-hit-runtime-wasm
            (split-runtime-generated-path
             (build-path temp-root "provider-runtime-cache-hit-prewarm")
             source-file
             ".wasm"))
          (make-directory* (path-only cache-hit-runtime-wasm))
          (define cache-hit-args
            (list "-S" "pkgs" "tools/prewarm-staged-providers.rkt"
                  "--mode" "provider-runtime"
                  "--host" "browser"
                  "--provider-cache-dir" (path->string provider-cache)
                  "--runtime-provider-cache-dir" (path->string runtime-cache)
                  "--runtime-wasm-out" (path->string cache-hit-runtime-wasm)
                  "--source" (path->string source-file)
                  "--verbose"))
          (define result
            (run-command/capture repo-root racket-exe cache-hit-args))
          (define log
            (build-path temp-root "provider-runtime-prewarm-cache-hit.log"))
          (write-log! log racket-exe cache-hit-args result)
          (unless (command-result-ok? result)
            (record-failure! "provider-runtime cache-hit prewarm command failed; see ~a"
                             log))
          (unless (wasm-magic? cache-hit-runtime-wasm)
            (record-failure! "provider-runtime cache-hit prewarm did not export a valid runtime wasm: ~a"
                             cache-hit-runtime-wasm))
          (when (and (file-exists? provider-runtime-prewarm-wasm)
                     (file-exists? cache-hit-runtime-wasm)
                     (not (same-file-bytes? provider-runtime-prewarm-wasm
                                            cache-hit-runtime-wasm)))
            (record-failure! "provider-runtime cache-hit prewarm exported a different runtime wasm: ~a"
                             cache-hit-runtime-wasm))
          (unless (transcript-contains? result
                                        #rx"split-runtime-core:materialize-wasm-hit")
            (record-failure! "provider-runtime cache-hit prewarm did not report cached runtime materialization"))
          (when (transcript-contains? result
                                      #rx"split-runtime-core:assemble-wasm")
            (record-failure! "provider-runtime cache-hit prewarm assembled runtime wasm"))
          (when (transcript-contains? result
                                      #rx"provider-runtime-merge|provider-fragment-cache")
            (record-failure! "provider-runtime cache-hit prewarm rebuilt provider/runtime artifacts"))
          result)
        (command-result #t "" "" 0.0)))
  (define cached-wasm-snapshot-after-provider-runtime-cache-hit-prewarm
    (cached-runtime-wasm-snapshot runtime-cache))
  (when (and provider-runtime?
             (not (equal? cached-wasm-snapshot-after-provider-runtime-cache-hit-prewarm
                          cached-wasm-snapshot-after-prewarm)))
    (record-failure! "provider-runtime cache-hit prewarm changed cached runtime wasm artifacts"))

  (define compile-args
    (append
     (list "-S" "pkgs" "webracket.rkt"
           "--browser" "--timings"
           "--no-stdlib"
           "--provider-cache-dir" (path->string provider-cache)
           "--runtime-provider-cache-dir" (path->string runtime-cache))
     (if shared-runtime-url?
         (list "--split-runtime-core-url" shared-runtime-url)
         '())
     (if provider-runtime?
         '("--split-runtime-provider-runtime")
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
  (when (and provider-runtime?
             (transcript-contains? compile-result
                                   #rx"provider-runtime-merge|provider-fragment-cache"))
    (record-failure! "browser provider-runtime warm compile rebuilt provider/runtime artifacts"))
  (when (and (not shared-runtime-url?)
             (transcript-contains? compile-result
                                   #rx"split-runtime-core:reference-wasm-hit"))
    (record-failure! "browser materialized-runtime compile used reference mode"))
  (when (and shared-runtime-url?
             (transcript-contains? compile-result
                                   #rx"split-runtime-core:materialize-wasm-hit"))
    (record-failure! "browser shared-url compile wrote a runtime wasm file"))
  (define cached-wasm-snapshot-after-compile
    (cached-runtime-wasm-snapshot runtime-cache))
  (unless (equal? cached-wasm-snapshot-after-compile
                  cached-wasm-snapshot-after-provider-runtime-cache-hit-prewarm)
    (record-failure! "browser warm compile changed cached runtime wasm artifacts"))

  (define html-path (generated-path dest-dir source-file ".html"))
  (define program-wasm (generated-path dest-dir source-file ".wasm"))
  (define runtime-sidecar-wasms
    (content-sidecar-paths dest-dir "webracket-runtime"))
  (when (and (not shared-runtime-url?)
             (not (= (length runtime-sidecar-wasms) 1)))
    (record-failure! "browser materialized-runtime compile produced ~a runtime wasm files, expected exactly one: ~a"
                     (length runtime-sidecar-wasms)
                     runtime-sidecar-wasms))
  (define runtime-wasm
    (if shared-runtime-url?
        shared-runtime-wasm
        (and (= (length runtime-sidecar-wasms) 1)
             (car runtime-sidecar-wasms))))
  (for ([artifact (in-list (list html-path program-wasm runtime-wasm))])
    (unless (and artifact (file-exists? artifact))
      (record-failure! "missing generated artifact: ~a" artifact)))
  (when (and shared-runtime-url?
             (pair? runtime-sidecar-wasms))
    (record-failure! "shared-url compile unexpectedly produced runtime wasm files: ~a"
                     runtime-sidecar-wasms))
  (unless (wasm-magic? program-wasm)
    (record-failure! "program wasm is missing WebAssembly magic bytes: ~a" program-wasm))
  (unless (and runtime-wasm (wasm-magic? runtime-wasm))
    (record-failure! "runtime wasm is missing WebAssembly magic bytes: ~a" runtime-wasm))
  (when (and expected-runtime-wasm
             (file-exists? expected-runtime-wasm)
             (file-exists? runtime-wasm)
             (not (same-file-bytes? expected-runtime-wasm runtime-wasm)))
    (record-failure! "runtime wasm served to browser does not match expected cached runtime wasm: ~a"
                     runtime-wasm))
  (when (and provider-runtime?
             (file-exists? provider-runtime-prewarm-wasm)
             (file-exists? runtime-wasm)
             (not (same-file-bytes? provider-runtime-prewarm-wasm runtime-wasm)))
    (record-failure! "provider-runtime wasm served to browser does not match prewarmed runtime wasm: ~a"
                     runtime-wasm))
  (when (file-exists? html-path)
    (define html (file->string html-path))
    (unless (regexp-match? #rx"coreWasmUrl" html)
      (record-failure! "generated HTML does not contain the split runtime loader"))
    (unless (regexp-match? (regexp-quote (path->string (file-name-from-path runtime-wasm)))
                           html)
      (record-failure! "generated HTML does not reference runtime wasm ~a"
                       (file-name-from-path runtime-wasm))))

  (define node-script (write-node-script! temp-root))
  (define browser-result
    (run-browser-check! node-path node-script dest-dir html-path program-wasm runtime-wasm))
  (define browser-log (build-path temp-root "browser.log"))
  (write-log! browser-log node-path (list (path->string node-script) "<config-json>") browser-result)
  (unless (command-result-ok? browser-result)
    (record-failure! "browser run failed; see ~a" browser-log))
  (define browser-artifacts-present?
    (and (file-exists? html-path)
         (file-exists? program-wasm)
         (file-exists? runtime-wasm)))
  (define package-result
    (and package-copy-check?
         browser-artifacts-present?
         (check-packaged-runtime-copy! node-path
                                       node-script
                                       temp-root
                                       html-path
                                       program-wasm
                                       runtime-wasm)))
  (when (and package-copy-check? browser-artifacts-present?)
    (define package-log (build-path temp-root "browser-packaged-copy.log"))
    (write-log! package-log
                node-path
                (list (path->string node-script) "<config-json>")
                package-result)
    (unless (command-result-ok? package-result)
      (record-failure! "packaged browser run failed; see ~a" package-log)))
  (define missing-runtime-result
    (and package-copy-check?
         browser-artifacts-present?
         (check-missing-runtime-copy! node-path
                                      node-script
                                      temp-root
                                      html-path
                                      program-wasm
                                      runtime-wasm)))
  (when (and package-copy-check? browser-artifacts-present?)
    (define missing-runtime-log
      (build-path temp-root "browser-packaged-missing-runtime.log"))
    (write-log! missing-runtime-log
                node-path
                (list (path->string node-script) "<config-json>")
                missing-runtime-result)
    (when (command-result-ok? missing-runtime-result)
      (record-failure! "packaged browser run unexpectedly succeeded without runtime wasm; see ~a"
                       missing-runtime-log))
    (unless (transcript-contains? missing-runtime-result
                                  #rx"Failed to fetch core wasm")
      (record-failure! "missing-runtime package did not fail on the runtime wasm fetch; see ~a"
                       missing-runtime-log)))
  (with-handlers ([exn:fail? void])
    (delete-file node-script))

  (cond
    [(null? failures)
     (printf "ok: prewarm=~as~acompile=~as browser=~as~acached-runtime-wasms=~a\n"
             (format-seconds (command-result-wall-ms prewarm-result))
             (if provider-runtime?
                 (format " provider-runtime-cache-hit-prewarm=~as "
                         (format-seconds
                          (command-result-wall-ms
                           provider-runtime-cache-hit-prewarm-result)))
                 " ")
             (format-seconds (command-result-wall-ms compile-result))
             (format-seconds (command-result-wall-ms browser-result))
             (if package-copy-check?
                 (format " packaged-browser=~as "
                         (format-seconds
                          (command-result-wall-ms package-result)))
                 " ")
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
