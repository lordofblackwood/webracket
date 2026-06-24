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
    (set! timeout-ms (string->number ms))])

  (define node-path
    (find-executable-path node-command))
  (unless node-path
    (eprintf "FAIL node-missing: could not find Node executable: ~a\n" node-command)
    (exit 2))

  (printf "INFO node-command: ~a\n" node-path)
  (printf "INFO node-modules: ~a\n" node-modules)
  (printf "INFO chrome-executable: ~a\n" chrome-executable)
  (flush-output)
  (flush-output (current-error-port))

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
