import type { Step } from '../types';

/** Rule 6 — one idea per step, and rule 7 — a fifth grader can follow all three. */
export const steps: readonly Step[] = [
  {
    n: '01',
    title: 'Sit how you want to sit. Press Calibrate.',
    body: 'Posture stores a handful of numbers describing that pose: the angle of your neck, the height of your shoulders in frame. Not a photo. Numbers.',
  },
  {
    n: '02',
    title: 'It watches the angle, not you.',
    body: 'Every few seconds it finds the same landmarks and compares them to your baseline. That comparison is the entire product. It has no idea what you look like or who else is in the room.',
  },
  {
    n: '03',
    title: 'You drift. It says one thing.',
    body: 'One banner, replaced rather than stacked if you stay folded over. You sit back and it is withdrawn, from the screen and from Notification Center. Nothing to dismiss, nothing to keep up, nothing waiting for you tomorrow morning.',
  },
] as const;
