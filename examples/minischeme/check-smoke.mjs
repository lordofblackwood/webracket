#!/usr/bin/env node

import { createRequire } from "node:module";
import process from "node:process";

const baseUrl = process.env.MINISCHEME_SMOKE_BASE_URL;
const nodeModules = process.env.MINISCHEME_SMOKE_NODE_MODULES;
const executablePath = process.env.MINISCHEME_SMOKE_EXECUTABLE;
const timeoutMs = Number.parseInt(process.env.MINISCHEME_SMOKE_TIMEOUT_MS ?? "30000", 10);

if (!baseUrl) {
  throw new Error("MINISCHEME_SMOKE_BASE_URL is required");
}

if (!nodeModules) {
  throw new Error("MINISCHEME_SMOKE_NODE_MODULES is required");
}

if (!executablePath) {
  throw new Error("MINISCHEME_SMOKE_EXECUTABLE is required");
}

const require = createRequire(new URL("./__smoke__.cjs", import.meta.url));
const { chromium } = require(`${nodeModules}/playwright`);

const browser = await chromium.launch({ executablePath, headless: true });

try {
  const page = await browser.newPage();
  const url = `${baseUrl}/generated/minischeme-page.html`;

  console.log(`START browser ${url}`);
  await page.goto(url, { waitUntil: "networkidle", timeout: timeoutMs });
  await page.waitForSelector("#status[data-state=\"ready\"]", { timeout: timeoutMs });

  const textareas = page.locator("textarea");
  const source = textareas.nth(0);
  const output = textareas.nth(1);
  await source.fill("(+ 1 2)");
  await page.getByRole("button", { name: "Run" }).click();

  await page.waitForFunction(() => {
    const areas = Array.from(document.querySelectorAll("textarea"));
    if (areas.length < 2) {
      return false;
    }
    return typeof areas[1].value === "string" && areas[1].value.includes("=> 3");
  }, { timeout: timeoutMs });

  const status = await page.locator("#status").getAttribute("data-state");
  const outputValue = await output.inputValue();
  if (status !== "ready") {
    throw new Error(`expected ready status, got ${JSON.stringify(status)}`);
  }
  if (!outputValue.includes("=> 3")) {
    throw new Error(`expected output to contain => 3, got ${JSON.stringify(outputValue)}`);
  }

  console.log("PASS browser minischeme");
} finally {
  await browser.close();
}
