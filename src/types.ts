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
}

export interface FaqItem {
  readonly q: string;
  readonly a: string;
}
