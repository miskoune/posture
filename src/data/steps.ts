import type { Step } from '../types';

export const steps: readonly Step[] = [
  {
    n: '01',
    title: 'Set your baseline once',
    body: 'Sit the way you actually want to sit and click Calibrate. Posture stores a handful of numbers describing that pose — the angle of your neck, the height of your shoulders in frame. Not a photo. Numbers.',
  },
  {
    n: '02',
    title: 'It watches the angle, not you',
    body: 'Every few seconds it locates the same landmarks and compares them to your baseline. That comparison is the entire product. It has no idea what you look like, what is behind you, or who else is in the room.',
  },
  {
    n: '03',
    title: 'One nudge, then silence',
    body: 'Drift for a few minutes and you get a single banner. No streak to keep, no daily score, no badge turning red. You sit back, it goes quiet, and that is the end of it.',
  },
] as const;
