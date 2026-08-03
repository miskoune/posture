import type { CompareRow } from '../types';

/**
 * Rule 31 — show why someone would switch, not what the product does.
 *
 * The alternatives are categories, never brands, and each row asks something
 * that follows from how that category works rather than from a review of any
 * particular product.
 */
export const compareRows: readonly CompareRow[] = [
  {
    question: 'Nothing to wear',
    posture: true,
    brace: false,
    cloud: true,
    willpower: true,
  },
  {
    question: 'Notices without you thinking about it',
    posture: true,
    brace: true,
    cloud: true,
    willpower: false,
  },
  {
    question: 'Camera feed stays on the machine',
    posture: true,
    brace: true,
    cloud: false,
    willpower: true,
  },
  {
    question: 'Works with the Wi-Fi off',
    posture: true,
    brace: true,
    cloud: false,
    willpower: true,
  },
  {
    question: 'No account to create',
    posture: true,
    brace: true,
    cloud: false,
    willpower: true,
  },
  {
    question: 'You can read every line that runs',
    posture: true,
    brace: false,
    cloud: false,
    willpower: false,
  },
] as const;

export const compareColumns = [
  'Posture',
  'A brace',
  'A cloud app',
  'Willpower',
] as const;
