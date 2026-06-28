import fs from "node:fs";
import path from "node:path";

function getCacheRoots() {
  const override = process.env.PLAYWRIGHT_BROWSERS_PATH || "";
  if (override) {
    return [override];
  }
  return [path.join(process.env.HOME || "", "Library", "Caches", "ms-playwright")];
}

function isExecutable(filePath) {
  try {
    const stat = fs.statSync(filePath);
    return stat.isFile() && (stat.mode & 0o111) !== 0;
  } catch (_err) {
    return false;
  }
}

export function findCachedPlaywrightHeadlessShell() {
  for (const cacheRoot of getCacheRoots()) {
    if (!cacheRoot || !fs.existsSync(cacheRoot)) {
      continue;
    }

    const entries = fs.readdirSync(cacheRoot, { withFileTypes: true });
    const candidates = [];
    for (const entry of entries) {
      if (!entry.isDirectory() || !entry.name.startsWith("chromium_headless_shell-")) {
        continue;
      }

      const root = path.join(cacheRoot, entry.name);
      const armPath = path.join(root, "chrome-headless-shell-mac-arm64", "chrome-headless-shell");
      const x64Path = path.join(root, "chrome-headless-shell-mac-x64", "chrome-headless-shell");
      if (isExecutable(armPath)) {
        candidates.push(armPath);
      }
      if (isExecutable(x64Path)) {
        candidates.push(x64Path);
      }
    }

    if (candidates.length > 0) {
      candidates.sort();
      return candidates[candidates.length - 1];
    }
  }

  return null;
}
