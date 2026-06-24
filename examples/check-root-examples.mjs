#!/usr/bin/env node

import { createRequire } from "node:module";
import process from "node:process";

const EXAMPLES = [
  {
    id: "hello-world-2",
    page: "examples/hello-world-2/generated/hello-world.html",
    probe: async (page) => {
      await page.waitForFunction(() =>
        document.querySelector("h1") && document.querySelector("p"));
      const result = await page.evaluate(() => ({
        title: document.querySelector("h1")?.textContent ?? null,
        paragraph: document.querySelector("p")?.textContent ?? null,
      }));
      if (result.title !== "Hello, WebRacket!" ||
          result.paragraph !== "This page was compiled from Racket to WebAssembly.") {
        throw new Error(`hello-world-2 mismatch: ${JSON.stringify(result)}`);
      }
    },
  },
  {
    id: "hello-world-3",
    page: "examples/hello-world-3/generated/hello-world-3.html",
    probe: async (page) => {
      await page.waitForFunction(() =>
        document.querySelector("h1") && document.querySelector("p"));
      const result = await page.evaluate(() => ({
        title: document.querySelector("h1")?.textContent ?? null,
        paragraph: document.querySelector("p")?.textContent ?? null,
      }));
      if (result.title !== "Hello, WebRacket!" ||
          result.paragraph !== "This page was compiled from Racket to WebAssembly.") {
        throw new Error(`hello-world-3 mismatch: ${JSON.stringify(result)}`);
      }
    },
  },
  {
    id: "console-bridge",
    page: "examples/console-bridge/generated/console-bridge.html",
    probe: async (page) => {
      await page.waitForFunction(() => typeof globalThis.WR === "function");
      const result = await page.evaluate(() => ({
        names: globalThis.WR.names(),
      }));
      const expected = ["counter", "current-counter", "explode!", "increment!"];
      if (JSON.stringify([...result.names].sort()) !== JSON.stringify([...expected].sort())) {
        throw new Error(`console-bridge mismatch: ${JSON.stringify(result)}`);
      }
    },
  },
  {
    id: "xtermjs-demo",
    page: "examples/xtermjs-demo/generated/xtermjs-demo.html",
    probe: async (page) => {
      await page.waitForFunction(() =>
        document.querySelector(".xterm") &&
        document.querySelector(".title"));
      const result = await page.evaluate(() => ({
        title: document.querySelector(".title")?.textContent ?? null,
        xtermCount: document.querySelectorAll(".xterm").length,
      }));
      if (result.title !== "Interactive xterm.js demo" || result.xtermCount < 1) {
        throw new Error(`xtermjs-demo mismatch: ${JSON.stringify(result)}`);
      }
    },
  },
  {
    id: "pict",
    page: "examples/pict/generated/pict.html",
    probe: async (page) => {
      await expectStatus(page, "ready");
    },
  },
  {
    id: "space-invaders",
    page: "examples/space-invaders/generated/space-invaders.html",
    probe: async (page) => {
      await expectStatus(page, "ready");
    },
  },
  {
    id: "snake",
    page: "examples/snake/generated/snake.html",
    probe: async (page) => {
      await expectStatus(page, "ready");
    },
  },
  {
    id: "snake2",
    page: "examples/snake2/generated/snake2.html",
    probe: async (page) => {
      await expectStatus(page, "ready");
    },
  },
  {
    id: "mathjax4",
    page: "examples/mathjax4/generated/mathjax.html",
    probe: async (page) => {
      await expectStatus(page, "ready");
    },
  },
  {
    id: "minischeme",
    page: "examples/minischeme/generated/minischeme-page.html",
    probe: async (page) => {
      await page.waitForFunction(() =>
        document.body?.textContent.includes("Status: ready") &&
        Array.from(document.querySelectorAll("textarea")).some((el) =>
          el.hasAttribute("readonly") && (el.value || "").includes("MiniScheme ready.")));
      const inputs = page.locator("textarea");
      if (await inputs.count() < 2) {
        throw new Error("minischeme page did not render expected textareas");
      }
      await inputs.nth(0).fill("(+ 1 2)");
      const runButton = page.getByRole("button", { name: "Run" });
      if (await runButton.count() !== 1) {
        throw new Error("minischeme Run button not found uniquely");
      }
      await runButton.click();
      await page.waitForFunction(() =>
        Array.from(document.querySelectorAll("textarea")).some((el) =>
          (el.getAttribute("readonly") !== null) && (el.value || "").includes("=> 3")));
    },
    diagnose: async (page) => await page.evaluate(() => ({
      status: document.querySelector("#status")
        ? {
            state: document.querySelector("#status").getAttribute("data-state"),
            text: document.querySelector("#status").textContent,
            outerHTML: document.querySelector("#status").outerHTML,
          }
        : null,
      textareas: Array.from(document.querySelectorAll("textarea")).map((el, index) => ({
        index,
        readonly: el.hasAttribute("readonly"),
        value: el.value,
        placeholder: el.getAttribute("placeholder"),
      })),
      buttons: Array.from(document.querySelectorAll("button")).map((el, index) => ({
        index,
        text: el.textContent,
        disabled: el.disabled,
      })),
      bodyText: document.body ? document.body.textContent.slice(0, 1200) : null,
      location: window.location.href,
    })),
  },
  {
    id: "matrix-rain",
    page: "examples/matrix-rain/generated/matrix-rain.html",
    probe: async (page) => {
      await expectStatus(page, "ready");
    },
  },
  {
    id: "raco",
    page: "examples/raco/generated/tiles.html",
    probe: async (page) => {
      await expectStatus(page, "ready");
    },
  },
];

function parseFilter(value) {
  return new Set(
    String(value || "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean));
}

function parseTimeoutMs(value, fallback) {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

async function withTimeout(label, timeoutMs, thunk) {
  let timeoutId = null;
  try {
    return await Promise.race([
      thunk(),
      new Promise((_, reject) => {
        timeoutId = setTimeout(() => {
          reject(new Error(`Timeout after ${timeoutMs}ms while running ${label}`));
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutId !== null) {
      clearTimeout(timeoutId);
    }
  }
}

async function expectStatus(page, expectedState) {
  await page.waitForFunction(
    (state) => {
      const node = document.querySelector("#status");
      if (!node) return false;
      const value = node.getAttribute("data-state");
      return value === state || value === "error";
    },
    expectedState);

  const result = await page.evaluate(() => ({
    state: document.querySelector("#status")?.getAttribute("data-state") ?? null,
    text: document.querySelector("#status")?.textContent ?? null,
  }));

  if (result.state !== expectedState) {
    throw new Error(`status mismatch: ${JSON.stringify(result)}`);
  }
}

function formatConsoleEntry(entry) {
  const parts = [entry.type.toUpperCase()];
  if (entry.location) {
    const { url = "", lineNumber = 0, columnNumber = 0 } = entry.location;
    if (url) {
      parts.push(`${url}:${lineNumber}:${columnNumber}`);
    }
  }
  parts.push(entry.text);
  return parts.join(" ");
}

async function reportFailure({ page, spec, err, consoleEntries, pageErrors, requestFailures }) {
  const recentConsole = consoleEntries.slice(-12).map(formatConsoleEntry);
  const recentPageErrors = pageErrors.slice(-6).map((entry) =>
    entry && entry.stack ? entry.stack : String(entry));
  const recentRequestFailures = requestFailures.slice(-6).map((entry) =>
    `${entry.method} ${entry.url} ${entry.failureText || "request failed"}`);

  console.error(`FAIL ${spec.id}`);
  console.error(`URL ${page.url() || spec.page}`);
  if (recentConsole.length > 0) {
    console.error("CONSOLE");
    for (const line of recentConsole) {
      console.error(`  ${line}`);
    }
  }
  if (recentPageErrors.length > 0) {
    console.error("PAGEERROR");
    for (const line of recentPageErrors) {
      console.error(`  ${line}`);
    }
  }
  if (recentRequestFailures.length > 0) {
    console.error("REQUESTFAIL");
    for (const line of recentRequestFailures) {
      console.error(`  ${line}`);
    }
  }
  if (spec.diagnose) {
    try {
      console.error("DIAGNOSTIC");
      console.error(JSON.stringify(await spec.diagnose(page), null, 2));
    } catch (diagnosticErr) {
      console.error(`DIAGNOSTIC failed: ${diagnosticErr && diagnosticErr.message ? diagnosticErr.message : String(diagnosticErr)}`);
    }
  }
  console.error(err && err.stack ? err.stack : String(err));
}

async function main() {
  const baseUrl = process.env.SMOKE_BASE_URL || "http://127.0.0.1:9987";
  const filter = parseFilter(process.env.ROOT_EXAMPLES_FILTER);
  const perTestTimeoutMs = parseTimeoutMs(process.env.ROOT_EXAMPLES_TEST_TIMEOUT_MS, 120000);
  const chromeExecutable = process.env.SMOKE_CHROME_EXECUTABLE || "";

  const selected = EXAMPLES.filter((spec) => filter.size === 0 || filter.has(spec.id));
  if (selected.length === 0) {
    console.error("No examples selected.");
    process.exit(2);
  }

  const requireHere = createRequire(import.meta.url);
  let playwrightPkg = null;

  try {
    playwrightPkg = requireHere("playwright");
  } catch (_err) {
    const localNodeModules = process.env.SMOKE_NODE_MODULES || "";
    if (localNodeModules) {
      try {
        const requireFromLocal = createRequire(`${localNodeModules}/_resolver.js`);
        playwrightPkg = requireFromLocal("playwright");
      } catch (_err2) {
        playwrightPkg = null;
      }
    }
  }

  if (!playwrightPkg) {
    console.error("Playwright is not installed.");
    process.exit(2);
  }

  const { chromium } = playwrightPkg;
  let browser = null;

  try {
    browser = await chromium.launch({
      headless: true,
      executablePath: chromeExecutable || undefined,
    });

    for (const spec of selected) {
      console.log(`START ${spec.id}`);
      const page = await browser.newPage();
      const consoleEntries = [];
      const pageErrors = [];
      const requestFailures = [];

      page.setDefaultTimeout(perTestTimeoutMs);
      page.on("console", (msg) => {
        const location = msg.location ? msg.location() : null;
        consoleEntries.push({
          type: msg.type ? msg.type() : "log",
          text: msg.text(),
          location,
        });
      });
      page.on("pageerror", (err) => pageErrors.push(err));
      page.on("requestfailed", (request) => {
        const failure = request.failure ? request.failure() : null;
        requestFailures.push({
          url: request.url(),
          method: request.method(),
          failureText: failure?.errorText ?? null,
        });
      });

      try {
        await withTimeout(spec.id, perTestTimeoutMs, async () => {
          await page.goto(`${baseUrl}/${spec.page}`, { waitUntil: "load" });
          await spec.probe(page);
          if (pageErrors.length > 0) {
            throw pageErrors[0];
          }
        });
        console.log(`PASS ${spec.id}`);
      } catch (err) {
        await reportFailure({ page, spec, err, consoleEntries, pageErrors, requestFailures });
        throw err;
      } finally {
        await page.close();
      }
    }
  } catch (err) {
    console.error("Root examples runner failed.");
    console.error(err && err.message ? err.message : String(err));
    process.exitCode = 1;
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

main();
