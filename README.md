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
clean export. The enclosing app currently tracks this directory as a submodule;
removing that entry from the app repository is a separate repository operation
after the move. It is not needed to run or build the exported website.

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

## Editing and deployment

- `app/page.tsx`: homepage copy and sections.
- `app/DemoFocus.tsx`: phone preview and larger view.
- `app/HeroScreenScroller.tsx`: sample-screen slideshow.
- `app/SiteHeader.tsx`: navigation.
- `app/privacy/page.tsx`: privacy draft.
- `app/globals.css`: layout and responsive styling.
- `public/`: website-owned assets and bundled demo.

Build output is `dist/client` plus `dist/server/index.js`, for a Cloudflare Workers
compatible host. Serve the website at the domain root (including `/flutter-demo/`).
The current website has no database or account backend; unused database and
authentication starter code has been removed. Optional hosting configuration is
project-local. No hosting account is carried into the clean export.

The screenshot carousel, store availability, sign-in link, and privacy contact
section retain their existing placeholder/draft status. Supply approved screenshots,
store URLs, and final privacy/contact content before a public launch.
