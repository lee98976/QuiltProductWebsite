import assert from "node:assert/strict";
import { lstat, readFile, readdir } from "node:fs/promises";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const root = fileURLToPath(new URL("../", import.meta.url));
const read = (path) => readFile(resolve(root, path), "utf8");

test("demo owns its assets and contains only dummy Firebase configuration", async () => {
  const [bundle, bootstrap, html] = await Promise.all([
    read("public/flutter-demo/main.dart.js"),
    read("public/flutter-demo/flutter_bootstrap.js"),
    read("public/flutter-demo/index.html"),
  ]);
  for (const sample of ["Robotics drive practice", "Fall club fair", "Health Sciences HOSA"]) {
    assert.ok(bundle.includes(sample), `Committed demo is missing sample data: ${sample}`);
  }
  assert.doesNotMatch(bundle, /AIza[\w-]{30,}/);
  const projects = [...bundle.matchAll(/([\w-]+)\.(?:firebaseapp\.com|firebasestorage\.app)/g)];
  assert.ok(projects.length > 0);
  for (const match of projects) assert.equal(match[1], "quilt-demo-public");
  assert.match(bootstrap, /canvasKitBaseUrl: new URL\("canvaskit\/", document.baseURI\)\.href/);
  assert.doesNotMatch(html, /quilt-demo-safe-top|inset:\s*76px/);
  for (const match of html.matchAll(/(?:src|href)="([^"]+)"/g)) {
    const path = match[1];
    if (path.startsWith("/") || path === "./") continue;
    assert.ok((await lstat(resolve(root, "public/flutter-demo", path))).isFile(), path);
  }
});

test("website source imports and scripts stay inside the website", async () => {
  async function walk(path) {
    for (const name of await readdir(path)) {
      const file = resolve(path, name);
      const stat = await lstat(file);
      assert.equal(stat.isSymbolicLink(), false, file);
      if (stat.isDirectory()) await walk(file);
      else if (/\.(?:tsx?|mjs)$/.test(name)) {
        const source = await readFile(file, "utf8");
        for (const match of source.matchAll(/(?:from\s+|import\s*)["'](\.[^"']+)["']/g)) {
          const target = relative(root, resolve(dirname(file), match[1]));
          assert.ok(!target.startsWith(".."), `Import escapes website: ${file}: ${match[1]}`);
        }
      }
    }
  }
  for (const folder of ["app", "build", "scripts", "worker"]) await walk(resolve(root, folder));
  const manifest = JSON.parse(await read("package.json"));
  assert.doesNotMatch(JSON.stringify(manifest), /(?:file:|link:|workspace:|flutter build|\.\.\/)/);
});
