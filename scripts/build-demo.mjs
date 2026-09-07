import { spawnSync } from "node:child_process";
import { cp, rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const demo = fileURLToPath(new URL("../demo/", import.meta.url));
const result = spawnSync("flutter", ["build", "web", "--release", "--no-web-resources-cdn"], { cwd: demo, stdio: "inherit" });
if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);
const output = new URL("../public/flutter-demo/", import.meta.url);
await rm(output, { recursive: true, force: true });
await cp(new URL("../demo/build/web/", import.meta.url), output, { recursive: true });
console.log("Rebuilt the website-owned demo. Commit public/flutter-demo alongside demo source.");
