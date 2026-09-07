# Quilt Product Website

Standalone product website, with a homepage (`/`), privacy draft (`/privacy`), and
an interactive, bundled app preview (`/flutter-demo/index.html`).

## Run and check

Requires Node.js 22.16+ and npm. Run these commands **inside this folder**:

```sh
npm ci
npm run dev
npm run lint
npm run typecheck
npm test
```

`npm test` builds the production Worker and checks both pages, links, error routes,
demo configuration, and source independence. `npm run start` previews a completed
production build. No app checkout, Flutter SDK, app environment variables, live
school database, or production Firebase configuration is needed.

## Move to a separate folder

The website has its own package manifest, lockfile, source, assets, build plugin,
and Worker. A clean, portable copy can be created with:

```sh
npm run export:standalone
# Or choose a new destination (must not already exist):
npm run export:standalone -- /path/to/new/quilt-website
```

The default export is `outputs/product-website`. Move that exported folder anywhere,
then run `npm ci` there. The export includes all current source changes and assets,
including the preview. It omits Git history/remotes, parent-repository membership,
node_modules, build output, local logs/caches, environment files, and hosting registration.
The exporter refuses symbolic links and existing destinations.

You can also move this whole original folder; its `.git` directory is already
self-contained. For a fresh repository with no historical association, use the
clean export. The separate website repository has no dependency on the enclosing app repository.

## Preview ownership

`public/flutter-demo/` is a **frozen, precompiled demo**, owned by this website.
It is copied directly into builds. The website does not import Dart code, copy
assets from the app, or invoke the app's demo-build script. Future app changes do
not change this preview. To change its internal screens, supply a separately
built replacement demo; editable Dart sources are not part of this website.

The bundled preview uses sample data and dummy `quilt-demo-public` Firebase
settings, never production credentials. Its Flutter renderer is served locally.
The inherited demo still loads Firebase library code and fallback fonts from
Google, and some account/admin actions are only representative; it is not an
offline application or a live account portal. Do not enter real personal data.

The surrounding phone frame owns the status-bar space; the iframe starts at zero
inset. The larger preview keeps the same iframe mounted, supports Escape and
keyboard focus containment, and fits its content viewport to the available height.

## Publish on GitHub Pages

This folder must be the **root of the GitHub repository**, with `package.json`
and `.github/workflows/pages.yml` at the top level. Commit the source files,
including the hidden `.github` folder and `.gitignore`; do not commit `node_modules`,
`dist`, or `out`.

1. In the repository, open **Settings → Pages → Build and deployment** and set
   **Source** to **GitHub Actions** (one-time setup).
2. Commit and **push** to the repository's default branch (currently `main`).
3. The **Deploy website to GitHub Pages** workflow installs dependencies, checks
   the code, exports the static site, checks its links, and deploys it.
4. Find the published URL in the completed workflow's `github-pages` deployment.

A local commit alone does not run GitHub Actions; it must be pushed. You can also
run the workflow manually from the Actions tab. No deployment token or Cloudflare
account is needed. The workflow gets the actual URL and repository prefix from
GitHub Pages, so project sites, user sites, and configured custom domains work.
For the current `lee98976/QuiltPrivacy` repository, the default URL is
`https://lee98976.github.io/QuiltPrivacy/`.

### Test the static build locally

```sh
npm ci
npm run lint
npm run typecheck
npm run build:pages
npm run test:pages
```

`out/` is the deployable static artifact: HTML, CSS, JavaScript, and the bundled
preview. Serve it with a static HTTP server; it does not need a Worker or Node
server in production. The privacy page is exported as `privacy/index.html`, so
direct visits and refreshes work on Pages.

To validate a repository prefix before deploying (macOS/Linux):

```sh
PAGES_BASE_PATH=/QuiltPrivacy SITE_URL=https://lee98976.github.io/QuiltPrivacy npm run build:pages
PAGES_BASE_PATH=/QuiltPrivacy npm run test:pages
```

For that preview, mount the contents of `out/` at `/QuiltPrivacy/` in your static
server. `PAGES_BASE_PATH` is optional for root/custom-domain builds. `SITE_URL`
is the full published site URL including any repository path, used in social
preview metadata. The workflow sets both automatically.

The regular `npm run build`, `npm test`, and `npm run start` commands retain the
existing server build for other hosts. GitHub Pages specifically uses
`npm run build:pages` and uploads only `out/`.

## Editing

- `app/page.tsx`: homepage copy and sections.
- `app/DemoFocus.tsx`: phone preview and larger view.
- `app/HeroScreenScroller.tsx`: sample-screen slideshow.
- `app/SiteHeader.tsx`: navigation.
- `app/site-path.ts`: repository prefixes for raw links and assets.
- `app/privacy/page.tsx`: privacy draft.
- `app/globals.css`: layout and responsive styling.
- `public/`: website-owned assets and bundled demo.

The screenshot carousel, store availability, sign-in link, and privacy contact
section retain their existing placeholder/draft status. Supply approved screenshots,
store URLs, and final privacy/contact content before a public launch.
