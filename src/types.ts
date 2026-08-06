/** Shared shapes for the page content. Everything is readonly — the site is
 *  static, so nothing should ever mutate these at build time. */

export interface SiteConfig {
  readonly name: string;
  readonly tagline: string;
  readonly headline: string;
  readonly subhead: string;
  readonly description: string;
  readonly url: string;
  readonly repo: string;
  readonly downloadUrl: string;
  readonly author: string;
  readonly requirements: string;
  readonly ctaLabel: string;
  readonly ctaNote: string;
}

export interface Step {
  readonly n: `${number}`;
  readonly title: string;
  readonly body: string;
}

export interface PrivacyPoint {
  readonly title: string;
  readonly body: string;
}

export interface FaqItem {
  readonly q: string;
  readonly a: string;
}

/** Rule 3 — a number the eye can land on, plus the words that give it meaning. */
export interface Stat {
  readonly value: string;
  readonly label: string;
  readonly note: string;
}

/** Rule 31 — one row of the comparison table. Alternatives are named by
 *  category, never by brand, so every claim stays defensible. */
export interface CompareRow {
  readonly question: string;
  readonly posture: boolean;
  readonly brace: boolean;
  readonly cloud: boolean;
  readonly willpower: boolean;
}
