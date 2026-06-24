#lang racket/base

;;; Check Browser Harness
;;;

;; This tool is a reusable preflight for WebRacket browser smoke tests. It
;; checks that the local Node/Playwright/Chromium stack is usable before a
;; larger harness spends time compiling examples or DOM tests. The root examples
;; batch calls it from `examples/check-root-examples.sh`, and other browser
;; harnesses can use it for the same "is the browser lab bench ready?" check.
;;
;; Invoke it directly with Racket:
;;
;;   racket tools/check-browser-harness.rkt
;;
;; Common options:
;;
;;   racket tools/check-browser-harness.rkt \
;;     --node /path/to/node \
;;     --node-modules /path/to/node_modules \
;;     --chrome-executable /path/to/chrome \
;;     --timeout-ms 30000
;;
;; The tool prints INFO/PASS/FAIL lines that identify the Node executable,
;; Playwright import path, browser launch result, blank-page evaluation, and a
;; tiny local HTTP server page-load smoke. It exits with 0 when the browser
;; harness is usable and non-zero when Node, Playwright, browser launch, or page
;; loading fails.


;;; Imports

;; The tool stays in `racket/base` and uses small standard libraries for JSON
;; config serialization, command-line parsing, paths, temporary files, and
;; process execution. Browser control itself is delegated to the embedded Node
;; script below.

(require json
         racket/cmdline
         racket/file
         racket/format
         racket/path
         racket/runtime-path
         racket/string
         racket/system)


;;; Racket-Side Configuration Helpers

;; These helpers collect the same environment conventions used by the browser
;; smoke harnesses. They let this preflight work as a standalone tool while
;; still fitting into `examples/check-root-examples.sh` and related scripts.

;; env-ref* : (listof string?) (or/c string? #f) -> (or/c string? #f)
;;   Return the first non-empty environment variable value from names.
(define (env-ref* names fallback)
  (or (for/or ([name (in-list names)])
        (define value (and name (getenv name)))
        (and value (not (string=? value "")) value))
      fallback))

;; default-node-modules : path? -> string?
;;   Match the local Playwright install convention used by example smokes.
(define (default-node-modules root-dir)
  (path->string (build-path root-dir ".local-tools" "node_modules")))


;;; Architecture Checks

;; Browser launch failures on macOS can be caused by running the preflight under
;; a translated x86_64 Racket while the browser harness is otherwise native
;; arm64. In that shape Chrome may abort inside macOS application registration
;; before Playwright gets a usable page. These helpers classify that case before
;; attempting a browser launch.

;; command-output/status : path-string? string? ... -> (values exact-integer? string?)
;;   Run a small diagnostic command and capture combined stdout/stderr.
(define (command-output/status exe . args)
  (define out (open-output-string))
  (define err (open-output-string))
  (define status
    (parameterize ([current-output-port out]
                   [current-error-port err])
      (apply system*/exit-code exe args)))
  (values status
          (string-append (get-output-string out)
                         (get-output-string err))))

;; host-machine-architecture : -> (or/c string? #f)
;;   Return the host machine architecture from `uname -m` when available.
(define (host-machine-architecture)
  (define uname-path
    (find-executable-path "uname"))
  (and uname-path
       (let-values ([(status output)
                     (command-output/status uname-path "-m")])
         (and (zero? status)
              (string-trim output)))))

;; node-architecture : path-string? -> (or/c string? #f)
;;   Ask Node what architecture it is actually running as.
(define (node-architecture node-path)
  (let-values ([(status output)
                (command-output/status node-path "-p" "process.arch")])
    (and (zero? status)
         (string-trim output))))

;; translated-racket-browser-risk? : string? string? symbol? -> boolean?
;;   Detect the known bad launcher shape for local Chrome/Playwright smokes.
(define (translated-racket-browser-risk? host-arch node-arch racket-arch)
  (and (eq? (system-type 'os) 'macosx)
       (eq? racket-arch 'x86_64)
       (or (equal? host-arch "arm64")
           (equal? node-arch "arm64"))))


;;; Embedded Node/Playwright Preflight

;; Playwright is a JavaScript library, so the actual browser launch and page
;; smoke live in a small Node module. Racket passes it a JSON config and treats
;; its exit code as the preflight result.

;; browser-preflight-script : string?
;;   Node/Playwright preflight body. Racket owns CLI/defaults; Node owns
;;   Playwright import and Chromium launch because Playwright is a JS library.
(define browser-preflight-script
  #<<JS
import { createRequire } from "node:module";
import http from "node:http";
import process from "node:process";

const config = JSON.parse(process.argv[2] || "{}");

function report(kind, message, details = {}) {
  const parts = [`${kind}: ${message}`];
  for (const [key, value] of Object.entries(details)) {
    if (value !== null && value !== undefined && value !== "") {
      parts.push(`${key}=${value}`);
    }
  }
  console.log(parts.join(" "));
}

function fail(category, message, details = {}) {
  console.error(`FAIL ${category}: ${message}`);
  for (const [key, value] of Object.entries(details)) {
    if (value !== null && value !== undefined && value !== "") {
      console.error(`  ${key}: ${value}`);
    }
  }
  process.exit(2);
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

async function main() {
  const timeoutMs = Number.isFinite(config.timeoutMs) ? config.timeoutMs : 30000;
  report("INFO", "node", { execPath: process.execPath, version: process.version });

  const requireHere = createRequire(import.meta.url);
  let playwrightPkg = null;
  let playwrightFrom = null;

  try {
    playwrightPkg = requireHere("playwright");
    playwrightFrom = "default";
  } catch (err) {
    const nodeModules = config.nodeModules || "";
    if (nodeModules) {
      try {
        const requireFromLocal = createRequire(`${nodeModules}/_resolver.js`);
        playwrightPkg = requireFromLocal("playwright");
        playwrightFrom = nodeModules;
      } catch (err2) {
        fail("playwright-missing",
             "could not import Playwright",
             {
               defaultError: err && err.message,
               nodeModules,
               nodeModulesError: err2 && err2.message,
             });
      }
    } else {
      fail("playwright-missing",
           "could not import Playwright",
           { defaultError: err && err.message });
    }
  }

  report("PASS", "playwright-import", { from: playwrightFrom });

  const { chromium } = playwrightPkg;
  let browser = null;
  let server = null;

  try {
    browser = await withTimeout("browser launch", timeoutMs, async () =>
      await chromium.launch({
        headless: true,
        executablePath: config.chromeExecutable || undefined,
      }));
    report("PASS", "browser-launch", { executablePath: config.chromeExecutable || "playwright-default" });

    const page = await browser.newPage();
    page.setDefaultTimeout(timeoutMs);
    const arithmetic = await page.evaluate(() => 1 + 1);
    if (arithmetic !== 2) {
      fail("page-evaluate-failed", "unexpected evaluation result", { result: arithmetic });
    }
    await page.close();
    report("PASS", "blank-page-evaluate");

    server = http.createServer((_req, res) => {
      res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
      res.end("webracket-browser-harness-ok");
    });

    await new Promise((resolve, reject) => {
      server.once("error", reject);
      server.listen(0, "127.0.0.1", resolve);
    });

    const address = server.address();
    const url = `http://127.0.0.1:${address.port}/`;
    const serverPage = await browser.newPage();
    serverPage.setDefaultTimeout(timeoutMs);
    await serverPage.goto(url, { waitUntil: "load" });
    const bodyText = await serverPage.textContent("body");
    await serverPage.close();
    if (bodyText !== "webracket-browser-harness-ok") {
      fail("server-page-mismatch", "local server body mismatch", { url, bodyText });
    }
    report("PASS", "local-server-page", { url });
    report("PASS", "browser-harness-ready");
  } catch (err) {
    fail("browser-launch-or-smoke-failed",
         err && err.message ? err.message : String(err),
         { stack: err && err.stack });
  } finally {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
    if (browser) {
      await browser.close();
    }
  }
}

main();
JS
)

(define-runtime-path tools-dir ".")


;;; Temporary Script Materialization

;; The embedded Node program is written to a temporary `.mjs` file so Node can
;; run it as a normal ES module. The main entry point deletes the temporary file
;; after the child process exits.

;; write-node-script! : -> path?
;;   Materialize the Node preflight body into a temporary module file.
(define (write-node-script!)
  (define path
    (make-temporary-file "webracket-browser-preflight-~a.mjs"))
  (call-with-output-file path
    (lambda (out)
      (display browser-preflight-script out))
    #:exists 'truncate/replace)
  path)


;;; Command-Line Validation Helpers

;; These helpers keep option parsing strict enough that failures are classified
;; before launching Node. Browser/runtime failures are left to the Node
;; preflight, where Playwright can provide better error details.

;; positive-integer-string? : string? -> boolean?
;;   Check whether s is a positive exact integer in decimal notation.
(define (positive-integer-string? s)
  (define n (string->number s))
  (and (exact-integer? n) (positive? n)))


;;; Command-Line Entry Point

;; The main program resolves defaults, validates the Node executable, writes the
;; embedded preflight module, and relays the Node process exit code. The printed
;; INFO/PASS/FAIL lines are intentionally simple so shell harnesses can show
;; them directly when classifying browser-toolchain failures.

(module+ main
  (define root-dir
    (simplify-path (build-path tools-dir "..")))

  (define node-command
    (env-ref* '("BROWSER_PREFLIGHT_NODE") "node"))
  (define node-modules
    (env-ref* '("BROWSER_PREFLIGHT_NODE_MODULES"
                "SMOKE_NODE_MODULES"
                "ROOT_EXAMPLES_NODE_MODULES")
              (default-node-modules root-dir)))
  (define chrome-executable
    (env-ref* '("BROWSER_PREFLIGHT_CHROME_EXECUTABLE"
                "SMOKE_CHROME_EXECUTABLE"
                "ROOT_EXAMPLES_EXECUTABLE")
              "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))
  (define timeout-ms 30000)
  (define allow-arch-mismatch? #f)

  (command-line
   #:program "check-browser-harness.rkt"
   #:once-each
   [("--node") path
    "Node executable to use. Defaults to BROWSER_PREFLIGHT_NODE or node."
    (set! node-command path)]
   [("--node-modules") path
    "node_modules directory containing Playwright."
    (set! node-modules path)]
   [("--chrome-executable") path
    "Chromium/Chrome executable path. Defaults to existing smoke env vars."
    (set! chrome-executable path)]
   [("--timeout-ms") ms
    "Per-step browser timeout in milliseconds."
    (unless (positive-integer-string? ms)
      (raise-user-error 'check-browser-harness
                        "expected positive integer timeout, got ~a"
                        ms))
    (set! timeout-ms (string->number ms))]
   [("--allow-arch-mismatch")
    "Continue even when the launcher architecture is known to be suspicious."
    (set! allow-arch-mismatch? #t)])

  (define node-path
    (find-executable-path node-command))
  (unless node-path
    (eprintf "FAIL node-missing: could not find Node executable: ~a\n" node-command)
    (exit 2))

  (define racket-arch
    (system-type 'arch))
  (define host-arch
    (host-machine-architecture))
  (define node-arch
    (node-architecture node-path))
  (printf "INFO node-command: ~a\n" node-path)
  (printf "INFO node-modules: ~a\n" node-modules)
  (printf "INFO chrome-executable: ~a\n" chrome-executable)
  (printf "INFO racket-arch: ~a\n" racket-arch)
  (printf "INFO host-arch: ~a\n" (or host-arch "unknown"))
  (printf "INFO node-arch: ~a\n" (or node-arch "unknown"))
  (flush-output)
  (flush-output (current-error-port))

  (when (and (not allow-arch-mismatch?)
             (translated-racket-browser-risk? host-arch node-arch racket-arch))
    (eprintf "FAIL architecture-mismatch: browser preflight is running under translated x86_64 Racket on arm64 macOS\n")
    (eprintf "  racket-arch: ~a\n" racket-arch)
    (eprintf "  host-arch: ~a\n" (or host-arch "unknown"))
    (eprintf "  node-arch: ~a\n" (or node-arch "unknown"))
    (eprintf "  fix: run with a native arm64 Racket and an isolated PLTCOMPILEDROOTS\n")
    (exit 2))

  (define node-script (write-node-script!))
  (define config
    (jsexpr->string
     (hasheq 'nodeModules node-modules
             'chromeExecutable chrome-executable
             'timeoutMs timeout-ms)))

  (define exit-code
    (dynamic-wind
      void
      (lambda ()
        (system*/exit-code node-path node-script config))
      (lambda ()
        (with-handlers ([exn:fail? void])
          (delete-file node-script)))))

  (exit exit-code))
