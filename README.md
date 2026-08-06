# Posture

A small macOS menu bar app that notices when you slouch and gives you one quiet
nudge. Everything runs on-device — no video leaves the Mac, no account, no cloud.

**[Download the latest release](https://github.com/miskoune/posture/releases/latest/download/Posture.dmg)**
(signed and notarized DMG, macOS 14+, Apple silicon) · site at
[posture.miskoune.com](https://posture.miskoune.com)

This repository holds both halves:

```
app/   the Swift menu bar app (Swift Package, no Xcode project)
src/   the Astro marketing site
```

## The app

Vision framework pose landmarks, sampled a few frames a minute and compared
against a baseline you calibrate once. Ships without the network entitlement, so
it is incapable of phoning home — the OS enforces the privacy claim.

```bash
cd app
./build.sh --run    # test, build, bundle, ad-hoc sign, launch
swift test          # the core rules, no camera required
```

Architecture, design decisions and the core/shell boundary are documented in
[`app/README.md`](app/README.md).

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

## Releases

Commits follow [Conventional Commits](https://www.conventionalcommits.org)
(enforced by commitlint via a husky hook). The scope decides what ships:

- `feat(app): …` / `fix(app): …` — releases the Mac app. On push to `main`,
  `.github/workflows/release.yml` runs semantic-release on a macOS runner:
  it computes the next version from the commits, writes it into `Info.plist`,
  builds, signs, notarizes and staples the DMG (`app/release.sh`), attaches it
  to a GitHub Release (tag `posture-app-vX.Y.Z`), and pushes a
  `chore: app version X.Y.Z` commit with the changelog.
- Any other scope, or none — website work; never bumps the app.

The site's download button points at `releases/latest/download/Posture.dmg`, a
stable-name copy attached to every release, so shipping the app never requires
touching the site.

`app/release.sh` also runs locally if you have the Developer ID certificate and
notarization credentials in your keychain — see the comment at the top of the
script. CI needs five repository secrets, listed in
`.github/workflows/release.yml`.

## Deploying the site

Pushing to `main` builds the site and rsyncs `dist/` to the server as an atomic
release (`.github/workflows/deploy.yml`). App-only pushes — including the
version-bump commit the release workflow pushes back — skip the deploy via
`paths-ignore`.

## Licence

MIT.
