/**
 * Releases the Mac app, not the website. The repo holds both, so versioning
 * keys off the commit scope: only `feat(app): …` / `fix(app): …` commits move
 * the app version. Website commits (any other scope, or none) are release: false
 * below — without those catch-alls, commit-analyzer's default rules would let a
 * website `feat:` bump the app.
 *
 * commit-analyzer picks the HIGHEST release among all matching rules, so an
 * app-scoped fix matching both `{scope:'app', type:'fix' → patch}` and
 * `{type:'fix' → false}` still releases a patch.
 */
export default {
  branches: ['main'],
  tagFormat: 'posture-app-v${version}',
  plugins: [
    [
      '@semantic-release/commit-analyzer',
      {
        preset: 'conventionalcommits',
        releaseRules: [
          // Breaking stays minor to remain in 0.x.x
          { scope: 'app', breaking: true, release: 'minor' },
          { scope: 'app', type: 'feat', release: 'minor' },
          { scope: 'app', type: 'fix', release: 'patch' },
          { scope: 'app', type: 'perf', release: 'patch' },
          { scope: 'app', type: 'refactor', release: 'patch' },
          { scope: 'app', type: 'style', release: 'patch' },
          { scope: 'app', type: 'chore', release: 'patch' },
          // Everything below: the website. Never bumps the app.
          { breaking: true, release: false },
          { type: 'feat', release: false },
          { type: 'fix', release: false },
          { type: 'perf', release: false },
          { type: 'revert', release: false },
        ],
      },
    ],
    [
      '@semantic-release/release-notes-generator',
      { preset: 'conventionalcommits' },
    ],
    ['@semantic-release/changelog', { changelogFile: 'app/CHANGELOG.md' }],
    [
      '@semantic-release/exec',
      {
        // Write the computed version into the bundle, then build, sign,
        // notarize and staple the DMG (app/release.sh).
        prepareCmd:
          '/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${nextRelease.version}" app/Resources/Info.plist && /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${nextRelease.version}" app/Resources/Info.plist && ./app/release.sh',
      },
    ],
    [
      '@semantic-release/git',
      {
        assets: ['app/Resources/Info.plist', 'app/CHANGELOG.md'],
        message:
          'chore: app version ${nextRelease.version}\n\n${nextRelease.notes}',
      },
    ],
    [
      '@semantic-release/github',
      {
        assets: [
          // Versioned artifact for the archive…
          { path: 'app/build/Posture-*.dmg' },
          // …and a stable name so the site can link
          // releases/latest/download/Posture.dmg forever.
          { path: 'app/build/Posture.dmg', label: 'Posture.dmg (latest)' },
        ],
      },
    ],
  ],
};
