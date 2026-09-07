import { spawnSync } from "node:child_process";
import { cp, rm, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const rawPath = process.env.PAGES_BASE_PATH ?? "";
const basePath = rawPath.replace(/\/$/, "");
if (basePath && !/^\/(?:[A-Za-z0-9_.-]+\/)*[A-Za-z0-9_.-]+$/.test(basePath)) {
  throw new Error("PAGES_BASE_PATH must be empty or a URL path such as /quilt-website.");
}
if (basePath.split("/").some((part) => part === "." || part === "..")) {
  throw new Error("PAGES_BASE_PATH cannot contain dot segments.");
}
const build = spawnSync(process.execPath, ["node_modules/vinext/dist/cli.js", "build"], {
  cwd: root,
  stdio: "inherit",
  env: { ...process.env, QUILT_STATIC_EXPORT: "1", NEXT_PUBLIC_BASE_PATH: basePath },
});
if (build.status !== 0) process.exit(build.status ?? 1);
// Vinext nests exported assets under basePath. Pages mounts the artifact
// at that path itself, so publish the contents of that directory.
const output = new URL("../out/", import.meta.url);
await rm(output, { recursive: true, force: true });
await cp(new URL(`../dist/client${basePath}/`, import.meta.url), output, { recursive: true });
await cp(new URL("../dist/client/404.html", import.meta.url), new URL("404.html", output));
await writeFile(new URL(".nojekyll", output), "");
console.log(`GitHub Pages files are ready in out/ (base path: ${basePath || "/"}).`);
