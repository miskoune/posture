import type { Stat } from '../types';

/**
 * Rule 3 — numbers instead of adjectives, and rule 26 — no weak words.
 *
 * Every figure here is true by construction rather than measured: they follow
 * from the app shipping without the network entitlement and without a backend.
 * Nothing on this page claims a benchmark that has not been run.
 */
export const stats: readonly Stat[] = [
  {
    value: '0',
    label: 'bytes uploaded',
    note: 'The app ships with no network entitlement, so macOS refuses to open a socket for it.',
  },
  {
    value: '0',
    label: 'accounts',
    note: 'No email, no licence key, no sign-in screen. You open the app and it works.',
  },
  {
    value: '1',
    label: 'nudge, then silence',
    note: 'One banner when you drift. No streak, no daily score, no badge turning red.',
  },
] as const;
