# Posture

A small macOS menu bar app that notices when you slouch and gives you one quiet
nudge. Everything runs on-device — no video leaves the Mac, no account, no cloud.

**Status: landing page only.** The desktop app has not been built yet. This
repository currently holds the marketing site at
[posture.miskoune.com](https://posture.miskoune.com).

## The site

Astro 7, no UI framework, no CSS framework — plain scoped styles and custom
properties. It builds to fully static HTML.

```bash
npm install
npm run dev      # http://localhost:4321
npm run build    # → dist/
```

### TypeScript 7, side by side with 6

TypeScript is installed twice, using the aliases the TypeScript 7 release notes
recommend:

```json
"@typescript/native": "npm:typescript@^7.0.2",
"typescript":         "npm:@typescript/typescript6@^6.0.2"
```

The native 7.x compiler is what `npx tsc` runs, and `npm run typecheck` uses it
for the `.ts` sources. The bare `typescript` specifier resolves to the 6.0
compatibility package, because `astro check`, `typescript-eslint` and Prettier
all still call the TypeScript 6 programmatic API — the native compiler does not
expose it yet. Drop the second alias and all three break at once.

`npm run check` typechecks `.astro` files through that TS 6 API; `npm run
typecheck` runs the native 7 compiler over the rest.

### Checks

```bash
npm run format:check
npm run lint
npm run check       # .astro, via TS 6 API
npm run typecheck   # .ts, native TS 7
```

All four gate every deploy.

### Layout

```
src/
  layouts/Layout.astro        document shell, meta tags, JSON-LD
  components/
    Nav.astro
    Hero.astro
    PostureFigure.astro       the animated hero illustration (CSS only)
    Privacy.astro
    HowItWorks.astro
    Features.astro
    Faq.astro
    Footer.astro
  pages/index.astro
  styles/global.css           design tokens + resets
```

Colour carries meaning throughout: amber means slouching, green means upright.
Both are defined once in `global.css` as `--warn` and `--good`.

## Deploying

Pushing to `main` builds the site and rsyncs `dist/` to the server as an atomic
release. See `.github/workflows/deploy.yml`.

## The app

Planned, not written:

- Swift + SwiftUI menu bar app, macOS 14+, Apple silicon
- Pose landmarks via Apple's Vision framework, on-device
- Calibrate once to store a baseline pose as a few numbers, never an image
- Sample a few frames a minute, compare against baseline, notify after sustained drift
- Ship without the network entitlement so it is incapable of phoning home

## Licence

MIT.
