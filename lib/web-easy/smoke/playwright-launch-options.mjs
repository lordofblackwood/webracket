import process from "node:process";

export function smokeChromiumLaunchOptions() {
  const launchOptions = { headless: true };
  const browserChannel = process.env.SMOKE_BROWSER_CHANNEL || "";
  const browserExecutablePath = process.env.SMOKE_BROWSER_EXECUTABLE_PATH || "";

  if (browserChannel) {
    launchOptions.channel = browserChannel;
  }
  if (browserExecutablePath) {
    launchOptions.executablePath = browserExecutablePath;
  }

  return launchOptions;
}
