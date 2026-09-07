import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import test from "node:test";

const output = fileURLToPath(new URL("../out/", import.meta.url));
const basePath = (process.env.PAGES_BASE_PATH ?? "").replace(/\/$/, "");

test("Pages export contains both routes, a 404 and the complete demo", async () => {
  for (const file of ["index.html", "index.txt", "privacy/index.html", "privacy/index.txt", "404.html", ".nojekyll", "flutter-demo/index.html", "flutter-demo/main.dart.js", "flutter-demo/canvaskit/canvaskit.js", "flutter-demo/canvaskit/canvaskit.wasm"]) {
    await access(resolve(output, file));
  }
  assert.match(await readFile(resolve(output, "index.html"), "utf8"), /Take school community to the next level/);
  assert.match(await readFile(resolve(output, "privacy/index.html"), "utf8"), /Information Quilt Uses/);
});

test("all exported page links and assets resolve inside the Pages artifact", async () => {
  for (const route of ["index.html", "privacy/index.html", "404.html"]) {
    const html = await readFile(resolve(output, route), "utf8");
    for (const match of html.matchAll(/(?:src|href)="([^"]+)"/g)) {
      const value = match[1];
      if (value.startsWith("#") || /^https?:/.test(value)) continue;
      assert.ok(value.startsWith(`${basePath}/`), `${route} escapes the repository path: ${value}`);
      const pathname = new URL(value, "https://pages.example").pathname.slice(basePath.length);
      const file = resolve(output, `.${pathname}${pathname.endsWith("/") ? "index.html" : ""}`);
      await access(file);
    }
  }
});

test("embedded demo resolves assets relative to its own directory", async () => {
  const html = await readFile(resolve(output, "flutter-demo/index.html"), "utf8");
  const bootstrap = await readFile(resolve(output, "flutter-demo/flutter_bootstrap.js"), "utf8");
  assert.match(html, /<base href="\.\/">/);
  assert.match(bootstrap, /new URL\("canvaskit\/", document.baseURI\)/);
  assert.doesNotMatch(html + bootstrap, /["']\/flutter-demo\//);
});
