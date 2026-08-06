import type { SiteConfig } from '../types';

export const site: SiteConfig = {
  name: 'Posture',

  /** Rule 30 — the whole product in nine words. */
  tagline: 'a Mac app that tells you when your posture goes bad',

  /** Rule 18 — the headline is the product. Reading it makes you sit up,
   *  which is the entire loop demonstrated before a feature is named. */
  headline: 'Your posture is bad right now.',
  subhead:
    'Your Mac already has a camera pointed at your face. Posture uses it to catch the slow slide forward, says one thing, then shuts up.',

  description:
    'A Mac menu bar app that tells you when your posture goes bad. The camera feed never leaves the Mac: 0 bytes uploaded, 0 accounts, 1 nudge. Free and open source.',

  url: 'https://posture.miskoune.com',
  repo: 'https://github.com/miskoune/posture',
  /** Always the newest signed build — GitHub rewrites `latest` per release,
   *  so shipping a version never requires touching the site. */
  downloadUrl:
    'https://github.com/miskoune/posture/releases/latest/download/Posture.dmg',
  author: 'https://github.com/miskoune',

  requirements: 'macOS 14 Sonoma or later · Apple silicon',

  /** Rule 22 — one call to action on the page, and rule 28: it says exactly
   *  what pressing it does. */
  ctaLabel: 'Download for Mac',
  ctaNote:
    'Free, signed and notarized. Drag it to Applications and you are done.',
} as const;
