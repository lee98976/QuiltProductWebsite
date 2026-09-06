import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render(path = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}-${path}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(`http://localhost${path}`, {
      headers: { accept: "text/html", host: "localhost" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the Quilt homepage", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /Take school community to the next level/);
  assert.match(html, /See how Quilt fits into the school day/);
  assert.match(html, /src="\/flutter-demo\/index\.html"/);
  assert.match(html, /Sign In/);
  assert.match(html, /\/privacy/);
  assert.match(html, /Coming soon on/);
  assert.match(html, /App Store/);
  assert.match(html, /Google Play/);
  assert.match(html, /Sample Quilt app screens/);
  assert.match(html, /Screenshot placeholder/);
  assert.doesNotMatch(html, /\/admin\//);
  assert.doesNotMatch(html, /promo-bar|Try the Flutter demo/);
  assert.doesNotMatch(html, /embedded|production school data|demo Firebase|Flutter UI|hand-built HTML phone mock/i);
  assert.doesNotMatch(html, /qdemo-phone|codex-preview|SkeletonPreview|react-loading-skeleton/);
});

test("server-renders the Quilt privacy page", async () => {
  const response = await render("/privacy");
  assert.equal(response.status, 200);

  const html = await response.text();
  assert.match(html, /Quilt Privacy/);
  assert.match(html, /Information Quilt Uses/);
  assert.match(html, /QR Check-Ins and Hall Passes/);
});

test("keeps starter preview code out of the product draft", async () => {
  const [page, siteHeader, layout, packageJson, demoFocus] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/SiteHeader.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../app/DemoFocus.tsx", import.meta.url), "utf8"),
  ]);

  assert.match(demoFocus, /\/flutter-demo\/index\.html/);
  assert.doesNotMatch(siteHeader, /\/admin\//);
  assert.match(siteHeader, /\/privacy/);
  assert.doesNotMatch(siteHeader, /href=.*Sign In/);
  assert.doesNotMatch(page, /PhoneDemo|qdemo-phone|SkeletonPreview|codex-preview/);
  assert.doesNotMatch(layout, /Starter Project|codex-preview|_sites-preview/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
});

test("keeps private-looking standalone artifacts out of the website copy", async () => {
  const [compiledPreview, demoBootstrap, siteHeader] = await Promise.all([
    readFile(new URL("../public/flutter-demo/main.dart.js", import.meta.url), "utf8"),
    readFile(new URL("../public/flutter-demo/flutter_bootstrap.js", import.meta.url), "utf8"),
    readFile(new URL("../app/SiteHeader.tsx", import.meta.url), "utf8"),
  ]);

  assert.doesNotMatch(compiledPreview, /lee298976@gmail\.com/);
  assert.match(compiledPreview, /demo@quilt\.example/);
  assert.doesNotMatch(compiledPreview, /contact@codingmindsacademy\.com/);
  assert.match(compiledPreview, /support@quilt\.example/);
  assert.doesNotMatch(demoBootstrap, /_flutter\.loader\.load\(\{\s*serviceWorkerSettings/);
  assert.doesNotMatch(siteHeader, /\/admin\//);
});


test("unknown routes return a proper 404", async () => {
  assert.equal((await render("/missing-page")).status, 404);
});

test("the optional image endpoint fails gracefully without a binding", async () => {
  assert.equal((await render("/_vinext/image?url=/og.png&w=640&q=75")).status, 501);
});

test("homepage section links all have a destination", async () => {
  const html = await (await render()).text();
  const ids = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1]));
  for (const match of html.matchAll(/href="\/?#([^"]+)"/g)) {
    assert.ok(ids.has(match[1]), `Missing destination: ${match[1]}`);
  }
});
