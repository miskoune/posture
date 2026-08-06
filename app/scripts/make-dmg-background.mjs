/**
 * Renders the DMG window background — run by release.sh before appdmg.
 *
 * The installer window is the first thing a downloader sees, so it uses the
 * same paper, ink and sage as the site and the OG image, and one instruction.
 * Geometry must agree with app/dmg.json: icons sit at (170,210) and (490,210)
 * in a 660×420 window, so the arrow bridges the gap between them.
 */
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import sharp from 'sharp';

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, '..', 'build');

const W = 660;
const H = 420;

const INK = '#17191c';
const MUTED = '#8a8f7e';
const SAGE = '#7a836a';
const PAPER = '#faf8f1';

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <rect width="${W}" height="${H}" fill="${PAPER}"/>

  <!-- the icon's stone sage, used once as a quiet wash -->
  <circle cx="580" cy="40" r="150" fill="${SAGE}" opacity="0.10"/>

  <g font-family="Inter, Helvetica" text-anchor="middle">
    <text x="${W / 2}" y="86" font-size="24" font-weight="700"
          letter-spacing="-0.5" fill="${INK}">Drag Posture into Applications</text>
    <text x="${W / 2}" y="116" font-size="14" font-weight="450"
          fill="${MUTED}">Then launch it and look for the figure in the menu bar.</text>
  </g>

  <!-- arrow between the two icon positions (centres at x=170 and x=490) -->
  <g stroke="${SAGE}" stroke-width="3" fill="none" stroke-linecap="round">
    <path d="M258 210 H388"/>
    <path d="M372 194 L392 210 L372 226"/>
  </g>

  <text x="${W / 2}" y="392" font-family="Inter, Helvetica" font-size="12"
        font-weight="450" fill="${MUTED}" text-anchor="middle">Free · MIT · 0 bytes uploaded</text>
</svg>`;

for (const scale of [1, 2]) {
  const file = join(
    out,
    scale === 1 ? 'dmg-background.png' : 'dmg-background@2x.png',
  );
  await sharp(Buffer.from(svg), { density: 72 * scale })
    .resize(W * scale, H * scale)
    .png({ compressionLevel: 9 })
    .toFile(file);
  // eslint-disable-next-line no-console -- a build script with no output is worse
  console.log(`wrote ${file}`);
}
