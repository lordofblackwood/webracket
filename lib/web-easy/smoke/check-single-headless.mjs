#!/usr/bin/env node

import path from "node:path";
import { createRequire } from "node:module";
import process from "node:process";
import { installPlaywrightErrorGuard } from "./playwright-error-guard.mjs";
import { smokeChromiumLaunchOptions } from "./playwright-launch-options.mjs";

async function waitForPassFail(page, timeoutMs) {
  const result = await page.waitForFunction(
    () => {
      const el = document.getElementById("status");
      if (!el) return null;
      const text = (el.textContent || "").trim();
      if (text.startsWith("PASS")) return { ok: true, text };
      if (text.startsWith("FAIL")) return { ok: false, text };
      return null;
    },
    { timeout: timeoutMs }
  );

  return result.jsonValue();
}

async function installWebMidiFixture(page) {
  if (process.env.SMOKE_WEB_MIDI_FAKE !== "1") {
    return;
  }

  await page.addInitScript(() => {
    class FixtureMIDIInput extends EventTarget {
      constructor(id) {
        super();
        this.id = id;
        this.type = "input";
        this.name = "Fixture Input";
        this.manufacturer = "WebRacket smoke";
        this.version = "1";
        this.state = "connected";
        this.connection = "closed";
      }

      open() {
        this.connection = "open";
        return new Promise(resolve => {
          setTimeout(() => {
            const event = new Event("midimessage");
            Object.defineProperty(event, "data", {
              value: new Uint8Array([0x90, 60, 100])
            });
            this.dispatchEvent(event);
            resolve(this);
          }, 20);
        });
      }

      close() {
        this.connection = "closed";
        return Promise.resolve(this);
      }
    }

    class FixtureMIDIOutput extends EventTarget {
      constructor(id) {
        super();
        this.id = id;
        this.type = "output";
        this.name = "Fixture Output";
        this.manufacturer = "WebRacket smoke";
        this.version = "1";
        this.state = "connected";
        this.connection = "closed";
        this.sent = [];
      }

      open() {
        this.connection = "open";
        return Promise.resolve(this);
      }

      close() {
        this.connection = "closed";
        return Promise.resolve(this);
      }

      send(data, timestamp) {
        if (!(data instanceof Uint8Array) || data.length === 0) {
          throw new TypeError("Fixture MIDIOutput requires a nonempty Uint8Array");
        }
        this.sent.push({ data: Array.from(data), timestamp });
      }
    }

    class FixtureMIDIAccess extends EventTarget {
      constructor() {
        super();
        this.input = new FixtureMIDIInput("fixture-input");
        this.output = new FixtureMIDIOutput("fixture-output");
        this.inputs = new Map([[this.input.id, this.input]]);
        this.outputs = new Map([[this.output.id, this.output]]);
        this.sysexEnabled = false;
        setTimeout(() => {
          const event = new Event("statechange");
          Object.defineProperty(event, "port", { value: this.input });
          this.dispatchEvent(event);
        }, 5);
      }
    }

    globalThis.MIDIInput = FixtureMIDIInput;
    globalThis.MIDIOutput = FixtureMIDIOutput;
    Object.defineProperty(globalThis.navigator, "requestMIDIAccess", {
      configurable: true,
      value: () => Promise.resolve(new FixtureMIDIAccess())
    });
  });
}

async function installDeviceOrientationFixture(page) {
  if (process.env.SMOKE_DEVICE_ORIENTATION_FAKE !== "1") {
    return;
  }

  await page.addInitScript(() => {
    class FixtureDeviceOrientationEvent extends Event {
      constructor(type, init = {}) {
        super(type);
        this.absolute = init.absolute === true;
        this.alpha = init.alpha ?? null;
        this.beta = init.beta ?? null;
        this.gamma = init.gamma ?? null;
        this.webkitCompassHeading = init.webkitCompassHeading ?? null;
        this.webkitCompassAccuracy = init.webkitCompassAccuracy ?? null;
      }

      static requestPermission(absolute) {
        return Promise.resolve(absolute === true ? "granted" : "denied");
      }
    }

    class FixtureDeviceMotionEvent extends Event {
      constructor(type, init = {}) {
        super(type);
        this.acceleration = init.acceleration ?? null;
        this.accelerationIncludingGravity = init.accelerationIncludingGravity ?? null;
        this.rotationRate = init.rotationRate ?? null;
        this.interval = init.interval ?? 0;
      }

      static requestPermission() {
        setTimeout(() => {
          globalThis.dispatchEvent(new FixtureDeviceOrientationEvent(
            "deviceorientation",
            {
              alpha: 12.5,
              beta: -45,
              gamma: 18,
              webkitCompassHeading: 271.5,
              webkitCompassAccuracy: 3
            }
          ));
          globalThis.dispatchEvent(new FixtureDeviceOrientationEvent(
            "deviceorientationabsolute",
            { absolute: true, alpha: 272, beta: 0, gamma: 0 }
          ));
          globalThis.dispatchEvent(new FixtureDeviceMotionEvent(
            "devicemotion",
            {
              acceleration: { x: 1, y: null, z: -2 },
              accelerationIncludingGravity: { x: 9.8, y: 0, z: 1 },
              rotationRate: { alpha: 0.5, beta: -1, gamma: 3 },
              interval: 16
            }
          ));
          setTimeout(() => {
            globalThis.dispatchEvent(new FixtureDeviceOrientationEvent(
              "deviceorientationabsolute",
              { absolute: true, alpha: 273, beta: 0, gamma: 0 }
            ));
            globalThis.dispatchEvent(new FixtureDeviceMotionEvent(
              "devicemotion",
              {
                acceleration: { x: 2, y: 2, z: 2 },
                accelerationIncludingGravity: { x: 10, y: 10, z: 10 },
                rotationRate: { alpha: 4, beta: 4, gamma: 4 },
                interval: 16
              }
            ));
            globalThis.dispatchEvent(new FixtureDeviceOrientationEvent(
              "deviceorientation",
              { alpha: 99, beta: 0, gamma: 0 }
            ));
          }, 20);
        }, 20);
        return Promise.resolve("granted");
      }
    }

    Object.defineProperty(globalThis, "DeviceOrientationEvent", {
      configurable: true,
      writable: true,
      value: FixtureDeviceOrientationEvent
    });
    Object.defineProperty(globalThis, "DeviceMotionEvent", {
      configurable: true,
      writable: true,
      value: FixtureDeviceMotionEvent
    });
  });
}

async function main() {
  const baseUrl = process.env.SMOKE_BASE_URL || "http://127.0.0.1:8765";
  const testPage = process.env.SMOKE_TEST_PAGE || "";
  const timeoutMs = Number(process.env.SMOKE_TIMEOUT_MS || "120000");
  const localNodeModules = process.env.SMOKE_NODE_MODULES || "";

  if (!testPage) {
    console.error("SMOKE_TEST_PAGE is required.");
    process.exit(2);
  }

  let playwrightPkg = null;
  const requireHere = createRequire(import.meta.url);
  try {
    playwrightPkg = requireHere("playwright");
  } catch (_err) {
    if (localNodeModules) {
      try {
        const requireFromLocal = createRequire(path.join(localNodeModules, "_resolver.js"));
        playwrightPkg = requireFromLocal("playwright");
      } catch (_err2) {
        playwrightPkg = null;
      }
    }
  }

  if (!playwrightPkg) {
    console.error("Playwright is not installed.");
    console.error("Install with one of:");
    console.error("  npm install --save-dev playwright");
    console.error("  npm --prefix .local-tools install --save-dev playwright");
    process.exit(2);
  }

  const { chromium } = playwrightPkg;
  const browser = await chromium.launch(smokeChromiumLaunchOptions());
  const page = await browser.newPage();
  await installWebMidiFixture(page);
  await installDeviceOrientationFixture(page);
  const guard = installPlaywrightErrorGuard(page);

  try {
    const mark = guard.mark();
    await page.goto(`${baseUrl}/${testPage}`, { waitUntil: "domcontentloaded" });

    const status = page.locator("#status");
    await status.waitFor({ timeout: timeoutMs });

    let finalResult = null;
    try {
      finalResult = await waitForPassFail(page, timeoutMs);
    } catch (err) {
      const isTimeout =
        err &&
        ((typeof err.name === "string" && err.name.includes("Timeout")) ||
         (typeof err.message === "string" && err.message.includes("Timeout")));
      if (!isTimeout) {
        throw err;
      }
      console.warn(`Single-page runner: timeout waiting for #status on ${testPage}; retrying once.`);
      finalResult = await waitForPassFail(page, timeoutMs);
    }

    const { ok, text } = finalResult;
    guard.assertSince(mark, `Single-page run (${testPage})`);
    console.log(text);

    await browser.close();
    process.exit(ok ? 0 : 1);
  } catch (err) {
    await browser.close();
    console.error("Single-page headless smoke run failed.");
    console.error(err && err.message ? err.message : String(err));
    process.exit(1);
  }
}

main();
