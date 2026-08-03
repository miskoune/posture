import type { Feature } from '../types';

export const features: readonly Feature[] = [
  {
    title: 'Lives in the menu bar',
    body: 'A small native app written in Swift. No Electron, no browser engine, no dock icon taking up space.',
    icon: 'M4 6h16M4 12h16M4 18h10',
  },
  {
    title: 'Patience you can tune',
    body: 'Decide how long a slouch has to last before it says anything — from thirty seconds to half an hour.',
    icon: 'M12 7v5l3 2M12 3a9 9 0 100 18 9 9 0 000-18z',
  },
  {
    title: 'Knows when to shut up',
    body: 'Pauses itself during screen sharing and calls, and whenever another app is already using the camera.',
    icon: 'M17 9V7a5 5 0 00-10 0v2M5 9h14v11H5z',
  },
  {
    title: 'Kind to the battery',
    body: 'Samples a few frames a minute on the efficiency cores and stops entirely when no face is in view.',
    icon: 'M4 8h13v8H4zM20 11v2M7 12h5',
  },
  {
    title: 'Offline by construction',
    body: 'There is no online. No update pings, no telemetry, no remote config — it works the same on a plane.',
    icon: 'M3 12a9 9 0 0118 0M7 15a5 5 0 0110 0M11 19h2',
  },
  {
    title: 'Yours to inspect',
    body: 'Open source under the MIT licence. Read it, fork it, or build it yourself and skip the download.',
    icon: 'M9 18l-6-6 6-6M15 6l6 6-6 6',
  },
] as const;
