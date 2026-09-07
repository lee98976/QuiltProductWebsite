import { cp, lstat, mkdir, readdir } from "node:fs/promises";
import { dirname, isAbsolute, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const destination = resolve(process.argv[2] ?? resolve(root, "outputs/product-website"));
const relativeRoot = relative(destination, root);
if (!relativeRoot || (!relativeRoot.startsWith("..") && !isAbsolute(relativeRoot))) {
  throw new Error("Choose a new destination, not the website root or one of its ancestors.");
}
const folders = [".github", "app", "build", "public", "scripts", "tests", "types", "worker"];
for (const folder of [...folders, "demo"]) {
  const within = relative(resolve(root, folder), destination);
  if (!within || (!within.startsWith("..") && !isAbsolute(within))) {
    throw new Error("The destination cannot be inside website source or assets.");
  }
}

async function verifyTree(path) {
  const stat = await lstat(path);
  if (stat.isSymbolicLink()) throw new Error(`Cannot export symbolic link: ${relative(root, path)}`);
  if (stat.isDirectory()) {
    for (const entry of await readdir(path)) await verifyTree(resolve(path, entry));
  }
}

// Only portable source and assets: no app checkout, Git history, secrets,
// dependency folders, generated output, host registration, or machine caches.
const demoFiles = ["demo/lib", "demo/assets", "demo/web", "demo/test", "demo/pubspec.yaml", "demo/pubspec.lock", "demo/README.md"];
const files = [".gitignore", "README.md", "package.json", "package-lock.json", "tsconfig.json", "next-env.d.ts", "next.config.ts", "vite.config.ts", "postcss.config.mjs", "eslint.config.mjs"];
for (const entry of [...folders, ...files, ...demoFiles]) await verifyTree(resolve(root, entry));
await mkdir(dirname(destination), { recursive: true });
await mkdir(destination); // Never overwrite an existing folder.
for (const entry of [...folders, ...files, ...demoFiles]) {
  await cp(resolve(root, entry), resolve(destination, entry), { recursive: true, errorOnExist: true, force: false });
}
console.log(`Standalone website exported to ${destination}`);
