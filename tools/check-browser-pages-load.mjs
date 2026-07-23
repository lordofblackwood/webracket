#!/usr/bin/env node

import { createRequire } from "node:module";
import process from "node:process";
import { findCachedPlaywrightHeadlessShell } from "./find-playwright-headless-shell.mjs";

function parsePositiveInt(value, fallback) {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function resolveBrowserExecutablePath(explicitPath) {
  if (explicitPath) {
    return explicitPath;
  }
  return findCachedPlaywrightHeadlessShell() || "";
}

function loadPlaywright() {
  const requireHere = createRequire(import.meta.url);
  try {
    return requireHere("playwright");
  } catch (_err) {
    const localNodeModules = process.env.SMOKE_NODE_MODULES || "";
    if (localNodeModules) {
      const requireFromLocal = createRequire(`${localNodeModules}/_resolver.js`);
      return requireFromLocal("playwright");
    }
    throw _err;
  }
}

function formatRequestFailure(entry) {
  return `${entry.method} ${entry.url} ${entry.failureText || "request failed"}`;
}

async function main() {
  const baseUrl = process.env.SMOKE_BASE_URL || "http://127.0.0.1:9989";
  const tests = (process.env.SMOKE_TESTS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const perPageTimeoutMs = parsePositiveInt(process.env.SMOKE_TEST_TIMEOUT_MS, 45000);
  const settleMs = parsePositiveInt(process.env.SMOKE_LOAD_SETTLE_MS, 1500);
  const chromeExecutable = process.env.SMOKE_CHROME_EXECUTABLE || "";

  if (tests.length === 0) {
    console.error("SMOKE_TESTS is required.");
    process.exit(2);
  }

  const { chromium } = loadPlaywright();
  const executablePath = resolveBrowserExecutablePath(chromeExecutable);
  const browser = await chromium.launch({
    headless: true,
    executablePath: executablePath || undefined,
  });

  try {
    for (const testPage of tests) {
      console.log(`START ${testPage}`);
      const page = await browser.newPage();
      const pageErrors = [];
      const requestFailures = [];
      const consoleMessages = [];

      page.setDefaultTimeout(perPageTimeoutMs);
      page.on("pageerror", (err) => pageErrors.push(err));
      page.on("requestfailed", (request) => {
        const failure = request.failure ? request.failure() : null;
        requestFailures.push({
          method: request.method(),
          url: request.url(),
          failureText: failure?.errorText ?? null,
        });
      });
      page.on("console", (msg) => {
        consoleMessages.push(`${msg.type ? msg.type() : "log"}: ${msg.text()}`);
      });

      try {
        await page.goto(`${baseUrl}/${testPage}`, {
          waitUntil: "domcontentloaded",
          timeout: perPageTimeoutMs,
        });
        await page.waitForLoadState("load", { timeout: perPageTimeoutMs });
        await page.waitForTimeout(settleMs);

        if (pageErrors.length > 0) {
          throw pageErrors[0];
        }
        if (requestFailures.length > 0) {
          throw new Error(
            `request failures: ${requestFailures.map(formatRequestFailure).join("; ")}`
          );
        }

        const snapshot = await page.evaluate(() => ({
          title: document.title,
          readyState: document.readyState,
          bodyTextLength: document.body ? document.body.innerText.length : 0,
        }));
        if (snapshot.readyState !== "complete") {
          throw new Error(`page did not reach complete readyState: ${JSON.stringify(snapshot)}`);
        }

        console.log(`PASS ${testPage}`);
      } catch (err) {
        console.error(`FAIL ${testPage}`);
        if (consoleMessages.length > 0) {
          console.error("CONSOLE");
          for (const line of consoleMessages.slice(-12)) {
            console.error(`  ${line}`);
          }
        }
        if (requestFailures.length > 0) {
          console.error("REQUESTFAIL");
          for (const failure of requestFailures.slice(-12)) {
            console.error(`  ${formatRequestFailure(failure)}`);
          }
        }
        console.error(err && err.stack ? err.stack : String(err));
        process.exitCode = 1;
      } finally {
        await page.close();
      }
    }
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exit(1);
});
