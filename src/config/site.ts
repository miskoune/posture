import type { SiteConfig } from '../types';

export const site: SiteConfig = {
  name: 'Posture',
  tagline: 'a quiet nudge when you slouch',
  description:
    'A tiny Mac menu bar app that notices when you slouch and gives you a gentle nudge. Everything runs on-device: no video leaves your Mac, no account, no cloud.',
  url: 'https://posture.miskoune.com',
  repo: 'https://github.com/miskoune/posture',
  requirements: 'macOS 14 Sonoma or later · Apple silicon · open source',
} as const;
