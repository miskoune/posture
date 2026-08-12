import type { PostHog } from 'posthog-js';

import { site } from '../config/site';

/**
 * PostHog, loaded lazily so the landing page ships no analytics bytes until
 * the first interaction settles. Same shape as storescreenshot's analytics:
 * a key from the environment gates everything, dev never captures, and a
 * failed import degrades to silence rather than an error.
 *
 * The key is inlined at build time, so production capture requires
 * PUBLIC_POSTHOG_KEY to be present when `astro build` runs (the deploy
 * workflow passes it from a repository secret).
 */

const POSTHOG_KEY: string | undefined = import.meta.env['PUBLIC_POSTHOG_KEY'];
const POSTHOG_HOST: string =
  import.meta.env['PUBLIC_POSTHOG_HOST'] ?? 'https://eu.i.posthog.com';

/** Only the deployed site captures. A production build served on localhost
 *  (or any other host) stays silent, so local browsing never pollutes the
 *  data. */
function isProductionHost() {
  return window.location.hostname === new URL(site.url).hostname;
}

let posthogPromise: Promise<PostHog | null> | null = null;
let initialized = false;

function getPosthog() {
  posthogPromise ??= import('posthog-js')
    .then((module) => module.default)
    .catch(() => null);

  return posthogPromise;
}

export function initAnalytics() {
  if (import.meta.env.DEV || !POSTHOG_KEY || initialized) {
    return;
  }
  if (!isProductionHost()) {
    return;
  }

  initialized = true;

  void getPosthog().then((posthog) => {
    posthog?.init(POSTHOG_KEY, {
      api_host: POSTHOG_HOST,
      persistence: 'localStorage',
      person_profiles: 'identified_only',
      capture_pageview: 'history_change',
      capture_pageleave: true,
    });
  });
}

export function trackEvent({
  name,
  properties,
}: {
  name: string;
  properties?: Record<string, unknown>;
}) {
  if (!initialized) {
    return;
  }

  void getPosthog().then((posthog) => {
    posthog?.capture(name, properties);
  });
}
