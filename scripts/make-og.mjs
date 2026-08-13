/**
 * Renders public/og.png — run with `npm run og`.
 *
 * Rule 5: the OG image is seen more often than the site, so it must carry the
 * pitch alone. It is a screenshot of the real hero, taken from a dev server,
 * so the card can never drift from the page it links to: change the hero,
 * rerun this, done.
 *
 * Uses the installed Chrome (playwright-core, channel "chrome") so no browser
 * download is needed.
 */
import { spawn } from 'node:child_process';
import { dirname, join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

import { chromium } from 'playwright-core';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const out = join(root, 'public', 'og.png');

/** Off the default 4321 so the shot never hits an unrelated running server. */
const PORT = 4980;
const PAGE_URL = `http://localhost:${PORT}/`;

// The standard OG canvas; rendered at 2x so headline type stays crisp.
const WIDTH = 1200;
const HEIGHT = 630;

const waitUntilServing = async (url) => {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    try {
      await fetch(url);
      return;
    } catch {
      await sleep(200);
    }
  }
  throw new Error(`dev server never answered on ${url}`);
};

const shootHero = async () => {
  const browser = await chromium.launch({ channel: 'chrome' });
  try {
    const page = await browser.newPage({
      viewport: { width: WIDTH, height: HEIGHT },
      deviceScaleFactor: 2,
    });
    await page.goto(PAGE_URL, { waitUntil: 'networkidle' });
    // The sticky nav would sit over the headline once the hero is scrolled
    // to the top of the 630px frame.
    await page.addStyleTag({ content: 'header { display: none }' });
    await page.locator('#ps-main').scrollIntoViewIfNeeded();
    await page.screenshot({ path: out });
  } finally {
    await browser.close();
  }
};

const server = spawn('npx', ['astro', 'dev', '--port', String(PORT)], {
  cwd: root,
  stdio: 'ignore',
});
try {
  await waitUntilServing(PAGE_URL);
  await shootHero();
} finally {
  server.kill();
}

// eslint-disable-next-line no-console -- a build script with no output is worse
console.log(`wrote ${out}`);
