import type { PrivacyPoint } from '../types';

export const privacyPoints: readonly PrivacyPoint[] = [
  {
    title: 'Nothing is uploaded',
    body: 'The app ships without the network entitlement. It is not that Posture chooses not to phone home: it cannot. macOS will not let it open a socket.',
  },
  {
    title: 'Nothing is recorded',
    body: 'Frames are read, measured and discarded in memory. No image is ever written to disk, not even a thumbnail, not even temporarily.',
  },
  {
    title: 'Nothing is an account',
    body: 'No sign-up, no email, no licence server, no analytics SDK. You download an app and it works. That is the whole relationship.',
  },
] as const;
