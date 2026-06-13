#!/usr/bin/env node

import process from "node:process";
import { createRequire } from "node:module";
import path from "node:path";

function splitRequestedExamples(raw) {
  if (!raw) return null;
  const items = String(raw)
    .split(/[,\s]+/)
    .map((item) => item.trim())
    .filter(Boolean);
  return items.length === 0 ? null : new Set(items);
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function loadPlaywright(localNodeModules) {
  const requireHere = createRequire(import.meta.url);
  try {
    return requireHere("playwright");
  } catch (_err) {
    if (!localNodeModules) return null;
  }

  try {
    const requireFromLocal = createRequire(path.resolve(localNodeModules, "_resolver.js"));
    return requireFromLocal("playwright");
  } catch (_err) {
    return null;
  }
}

async function loadErrorGuardInstaller() {
  return import(new URL("../lib/web-easy/smoke/playwright-error-guard.mjs", import.meta.url).href);
}

function normalizeText(text) {
  return String(text || "").replace(/\s+/g, " ").trim();
}

async function waitForBodyText(page, expectedText, timeoutMs) {
  await page.waitForFunction(
    (needle) => String(document.body.innerText || "").replace(/\s+/g, " ").trim().includes(needle),
    expectedText,
    { timeout: timeoutMs }
  );
}

const EXAMPLE_SPECS = [
  {
    name: "hello-world-2",
    relativeUrl: "examples/hello-world-2/generated/hello-world.html",
    async check(page, timeoutMs) {
      await waitForBodyText(page, "Hello, WebRacket!", timeoutMs);
      await waitForBodyText(page, "This page was compiled from Racket to WebAssembly.", timeoutMs);
    },
  },
  {
    name: "hello-world-3",
    relativeUrl: "examples/hello-world-3/generated/hello-world-3.html",
    async check(page, timeoutMs) {
      await waitForBodyText(page, "Hello, WebRacket!", timeoutMs);
      await waitForBodyText(page, "This page was compiled from Racket to WebAssembly.", timeoutMs);
    },
  },
  {
    name: "console-bridge",
    relativeUrl: "examples/console-bridge/generated/console-bridge.html",
    async check(page, timeoutMs) {
      await page.waitForFunction(
        () =>
          typeof globalThis.WR === "object" &&
          typeof globalThis.WR.names === "function" &&
          typeof globalThis.WR.help === "function" &&
          Array.isArray(globalThis.WR.names()) &&
          globalThis.WR.names().length >= 1,
        undefined,
        { timeout: timeoutMs }
      );

      const names = await page.evaluate(() => globalThis.WR.names());
      assert(Array.isArray(names), "console-bridge: WR.names() did not return an array");
      assert(names.includes("current-counter"), "console-bridge: current-counter missing from WR.names()");
    },
  },
  {
    name: "xtermjs-demo",
    relativeUrl: "examples/xtermjs-demo/generated/xtermjs-demo.html",
    async check(page, timeoutMs) {
      await page.waitForSelector(".title", { timeout: timeoutMs });
      await page.waitForSelector(".terminal-container .xterm", { timeout: timeoutMs });

      const titleText = normalizeText(await page.locator(".title").textContent());
      assert(
        titleText === "Interactive xterm.js demo",
        `xtermjs-demo: unexpected title text: ${titleText}`
      );

      const hintText = normalizeText(await page.locator(".hint").textContent());
      assert(
        hintText.includes("toggle themes via the links command."),
        "xtermjs-demo: hint text did not appear"
      );
    },
  },
];

async function runExample(browser, installPlaywrightErrorGuard, baseUrl, timeoutMs, spec) {
  const page = await browser.newPage();
  const guard = installPlaywrightErrorGuard(page);
  const label = `legacy example ${spec.name}`;
  try {
    const mark = guard.mark();
    await page.goto(`${baseUrl}/${spec.relativeUrl}`, { waitUntil: "domcontentloaded" });
    await spec.check(page, timeoutMs);
    await page.waitForTimeout(300);
    guard.assertSince(mark, label);
    console.log(`PASS ${spec.name}`);
  } catch (err) {
    const detail = err && err.message ? err.message : String(err);
    throw new Error(`${spec.name}: ${detail}`);
  } finally {
    await page.close();
  }
}

async function main() {
  const baseUrl = process.env.LEGACY_EXAMPLES_BASE_URL || "http://127.0.0.1:9878";
  const timeoutMs = Number(process.env.LEGACY_EXAMPLES_TIMEOUT_MS || "20000");
  const localNodeModules = process.env.LEGACY_EXAMPLES_NODE_MODULES || "";
  const requestedExamples = splitRequestedExamples(process.env.LEGACY_EXAMPLES || "");

  const playwrightPkg = await loadPlaywright(localNodeModules);
  if (!playwrightPkg) {
    console.error("Playwright is not installed.");
    console.error("Install with one of:");
    console.error("  npm install --save-dev playwright");
    console.error("  npm --prefix .local-tools install --save-dev playwright");
    process.exit(2);
  }

  const { installPlaywrightErrorGuard } = await loadErrorGuardInstaller();
  const { chromium } = playwrightPkg;
  const browser = await chromium.launch({ headless: true });

  try {
    const specs = requestedExamples
      ? EXAMPLE_SPECS.filter((spec) => requestedExamples.has(spec.name))
      : EXAMPLE_SPECS;

    if (requestedExamples && specs.length !== requestedExamples.size) {
      const known = new Set(EXAMPLE_SPECS.map((spec) => spec.name));
      const unknown = [...requestedExamples].filter((name) => !known.has(name));
      throw new Error(`Unknown legacy example name(s): ${unknown.join(", ")}`);
    }

    for (const spec of specs) {
      await runExample(browser, installPlaywrightErrorGuard, baseUrl, timeoutMs, spec);
    }
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error("Legacy example browser check failed.");
  console.error(err && err.message ? err.message : String(err));
  process.exit(1);
});
