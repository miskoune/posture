import type { SiteConfig } from '../types';

export const site: SiteConfig = {
  name: 'Posture',

  /** Rule 30 — the whole product in nine words. */
  tagline: 'a Mac app that tells you when you slouch',

  /** Rule 18 — the headline is the product. Reading it makes you sit up,
   *  which is the entire loop demonstrated before a feature is named. */
  headline: 'You are slouching right now.',
  subhead:
    'Your Mac already has a camera pointed at your face. Posture uses it to catch the slow slide forward, says one thing, then shuts up.',

  description:
    'A Mac menu bar app that tells you when you slouch. The camera feed never leaves the Mac: 0 bytes uploaded, 0 accounts, 1 nudge. Free and open source.',

  url: 'https://posture.miskoune.com',
  repo: 'https://github.com/miskoune/posture',
  author: 'https://github.com/miskoune',

  requirements: 'macOS 14 Sonoma or later · Apple silicon',

  /** Rule 22 — one call to action on the page, and rule 28: it says exactly
   *  what pressing it does. */
  ctaLabel: 'Star it on GitHub',
  ctaNote:
    'That is the whole signup. You will see the first build the day it ships.',
} as const;
