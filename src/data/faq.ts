import type { FaqItem } from '../types';

export const faqs: readonly FaqItem[] = [
  {
    q: 'Is any video sent anywhere?',
    a: 'No. The app has no network entitlement at all, so macOS blocks it from making connections even if it tried. Frames are analysed in memory and dropped immediately.',
  },
  {
    q: 'Does it work in bad lighting?',
    a: 'It needs enough light for macOS to find a face — roughly what you would need for a video call. In a dim room it will simply report that it cannot see you rather than guess.',
  },
  {
    q: 'Will it eat my battery?',
    a: 'It samples a few frames per minute rather than running a live video stream, and the work happens on the efficiency cores. When the lid is shut or no face is detected, it stops sampling entirely.',
  },
  {
    q: 'Can I use an external webcam?',
    a: 'It is designed around the built-in camera, since that sits at a known angle relative to the screen. External cameras that macOS exposes should work, but calibration will matter more.',
  },
  {
    q: 'Windows or Linux?',
    a: 'Not planned. The pose detection leans on Apple’s Vision framework, which does the hard part on-device for free. Rebuilding that elsewhere would be a different project.',
  },
  {
    q: 'What will it cost?',
    a: 'Free while it is in beta. If it turns into something worth charging for it will be a one-time price, never a subscription, and never an account.',
  },
  {
    q: 'When can I actually download it?',
    a: 'There is no build yet — this page describes what is being made. Progress happens in the open on GitHub, so watching the repository is the way to hear about the first release.',
  },
] as const;
