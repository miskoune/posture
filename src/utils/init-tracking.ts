import { initAnalytics, trackEvent } from './analytics';

/**
 * Declarative tracking for a static page: an element opts in with
 * `data-analytics="<event name>"`, and every other `data-analytics-*`
 * attribute becomes an event property (`data-analytics-target` → `target`).
 * Two delegated listeners cover the whole document, so components never
 * import analytics code; they only annotate their markup.
 */

const PROPERTY_PREFIX = 'analytics';

function propertiesOf(element: HTMLElement): Record<string, string> {
  const properties: Record<string, string> = {};

  for (const [key, value] of Object.entries(element.dataset)) {
    if (key === PROPERTY_PREFIX || value === undefined) {
      continue;
    }
    if (key.startsWith(PROPERTY_PREFIX)) {
      const name = key.slice(PROPERTY_PREFIX.length);
      properties[name.charAt(0).toLowerCase() + name.slice(1)] = value;
    }
  }

  return properties;
}

function track(element: HTMLElement) {
  const name = element.dataset[PROPERTY_PREFIX];
  if (!name) {
    return;
  }

  // A <summary> tracks only when it opens its <details>; at click time the
  // open attribute still holds the state being left.
  if (element.tagName === 'SUMMARY' && element.closest('details')?.open) {
    return;
  }

  trackEvent({ name, properties: propertiesOf(element) });
}

export function initTracking() {
  initAnalytics();

  document.addEventListener('click', (event) => {
    if (!(event.target instanceof Element)) {
      return;
    }
    // Inputs are covered by the change listener; skip them here so a click
    // on an already-selected radio is not double-counted.
    if (event.target instanceof HTMLInputElement) {
      return;
    }
    const element = event.target.closest<HTMLElement>('[data-analytics]');
    if (element && !(element instanceof HTMLInputElement)) {
      track(element);
    }
  });

  document.addEventListener('change', (event) => {
    if (event.target instanceof HTMLInputElement) {
      track(event.target);
    }
  });
}
