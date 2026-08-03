/** Shared shapes for the page content. Everything is readonly — the site is
 *  static, so nothing should ever mutate these at build time. */

export interface SiteConfig {
  readonly name: string;
  readonly tagline: string;
  readonly description: string;
  readonly url: string;
  readonly repo: string;
  readonly requirements: string;
}

export interface Step {
  readonly n: `${number}`;
  readonly title: string;
  readonly body: string;
}

export interface Feature {
  readonly title: string;
  readonly body: string;
  /** Raw `d` attribute for a 24×24 stroked icon path. */
  readonly icon: string;
}

export interface PrivacyPoint {
  readonly title: string;
  readonly body: string;
}

export interface FaqItem {
  readonly q: string;
  readonly a: string;
}
