/**
 * Renders public/og.png — run with `npm run og`.
 *
 * Rule 5: the OG image is seen more often than the site, so it is built like a
 * YouTube thumbnail — one idea, type large enough to survive a timeline, and
 * the before/after the product is about, rather than a logo on a gradient.
 *
 * The figure geometry is lifted from PostureFigure.astro so the thumbnail and
 * the hero are unmistakably the same drawing.
 */
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import sharp from 'sharp';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');

const W = 1200;
const H = 630;

const INK = '#0c0f0e';
const MUTED = '#9aa39d';
const ACCENT = '#0f9d6e';
const PAPER = '#ffffff';

/** One side-profile figure: spine, arm, neck, skull. */
const figure = (color, slouched) => {
  const torso = slouched ? 'rotate(15 120 216) translate(0 3)' : '';
  const head = slouched ? 'rotate(13 122 142) translate(7 5)' : '';
  return `
    <g transform="${torso}" stroke="${color}" fill="none"
       stroke-linecap="round">
      <path d="M120 216 C116 190 118 166 122 142" stroke-width="11"/>
      <path d="M124 152 C150 160 176 186 206 200" stroke-width="8.5"/>
      <g transform="${head}">
        <path d="M122 142 L126 132" stroke-width="9.5"/>
        <circle cx="127" cy="118" r="21" fill="${color}" stroke="none"/>
      </g>
    </g>`;
};

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <rect width="${W}" height="${H}" fill="${PAPER}"/>

  <!-- the one accent colour, used once -->
  <circle cx="1040" cy="120" r="230" fill="${ACCENT}" opacity="0.07"/>

  <g font-family="Inter" fill="${INK}">
    <text x="80" y="150" font-size="26" font-weight="600"
          letter-spacing="4" fill="${MUTED}">POSTURE · FREE · MIT</text>

    <text x="80" y="290" font-size="86" font-weight="700"
          letter-spacing="-3.5">You are slouching</text>
    <text x="80" y="386" font-size="86" font-weight="700"
          letter-spacing="-3.5" fill="${ACCENT}">right now.</text>

    <text x="80" y="470" font-size="30" font-weight="450" fill="${MUTED}">A Mac app that tells you when you slouch.</text>
    <text x="80" y="556" font-size="26" font-weight="500" fill="${MUTED}">0 bytes uploaded · 0 accounts · 1 nudge</text>
  </g>

  <!-- before / after, in the two colours the app itself uses -->
  <g transform="translate(628 208) scale(1.36)">
    ${figure(MUTED, true)}
  </g>
  <g transform="translate(854 208) scale(1.36)">
    ${figure(ACCENT, false)}
  </g>
</svg>`;

const out = join(root, 'public', 'og.png');
await sharp(Buffer.from(svg)).png({ compressionLevel: 9 }).toFile(out);

// eslint-disable-next-line no-console -- a build script with no output is worse
console.log(`wrote ${out}`);
