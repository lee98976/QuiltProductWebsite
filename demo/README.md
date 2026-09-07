# Standalone website demo

This source belongs to the product website. It has no imports, scripts, credentials, or runtime dependency on the actual app. Club/event fixtures are local and their dates stay current. Unsupported database actions fail immediately with a sample-preview message; no queries reach a server. Reloading resets the sample session.

With Flutter 3.44.4 installed, run `npm run build:demo` from the website root. Commit both demo source and the rebuilt `public/flutter-demo` assets. Normal website and GitHub Pages builds use those committed assets and do not require Flutter.
