import type { FaqItem } from '../types';

export const faqs: readonly FaqItem[] = [
  {
    q: 'Is any video sent anywhere?',
    a: 'No. The app has no network entitlement at all, so macOS blocks it from making connections even if it tried. Frames are analysed in memory and dropped immediately.',
  },
  {
    q: 'Why is it free?',
    a: 'It is a menu bar app that compares two angles. Charging for it would mean building a licence server, a payment flow and an account system, three things that would each need the network access this app deliberately does not have. Free and MIT is the honest shape for it.',
  },
  {
    q: 'Does it work in bad lighting?',
    a: 'It needs enough light for macOS to find a face, roughly what you would need for a video call. In a dim room it reports that it cannot see you rather than guess.',
  },
  {
    q: 'Will it eat my battery?',
    a: 'It samples a few frames per minute rather than running a live video stream, and the work happens on the efficiency cores. When the lid is shut or no face is in frame, it stops sampling.',
  },
  {
    q: 'Can I use an external webcam?',
    a: 'It is designed around the built-in camera, since that sits at a known angle relative to the screen. External cameras that macOS exposes should work, but calibration matters more.',
  },
  {
    q: 'Windows or Linux?',
    a: 'Not planned. The pose detection leans on Apple’s Vision framework, which does the hard part on-device for free. Rebuilding that elsewhere would be a different project.',
  },
  {
    q: 'When can I download it?',
    a: 'Now. The download button on this page always serves the newest release: a signed and notarized DMG. Open it, drag Posture to Applications, and grant camera access when macOS asks. Every release also lives on the GitHub releases page with its changelog.',
  },
] as const;
