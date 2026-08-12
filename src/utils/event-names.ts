/**
 * Every event the site can emit, in one place, so PostHog never accumulates
 * misspelled twins. Names are snake_case, matching storescreenshot.
 */
export const ANALYTICS_EVENTS = {
  downloadClicked: 'download_clicked',
  navLinkClicked: 'nav_link_clicked',
  footerLinkClicked: 'footer_link_clicked',
  demoPageSelected: 'demo_page_selected',
  faqOpened: 'faq_opened',
} as const;
