import { useEffect } from 'react';

/**
 * Reusable hook to dynamically manage document metadata.
 * Ensures page-specific titles, descriptions, OpenGraph tags,
 * and canonical links are correctly populated in the DOM.
 */
export function useDocumentMetadata(title: string, description: string) {
  useEffect(() => {
    // 1. Update document title
    document.title = title;

    // Helper to find or create a meta tag
    const updateMetaTag = (attributeName: string, attributeValue: string, content: string) => {
      let element = document.querySelector(`meta[${attributeName}="${attributeValue}"]`);
      if (!element) {
        element = document.createElement('meta');
        element.setAttribute(attributeName, attributeValue);
        document.head.appendChild(element);
      }
      element.setAttribute('content', content);
    };

    // 2. Update meta description
    updateMetaTag('name', 'description', description);

    // 3. Update OpenGraph tags
    updateMetaTag('property', 'og:title', title);
    updateMetaTag('property', 'og:description', description);
    // 3b. Canonical URL doubles as og:url (set below, then mirrored here).

    // 4. Update canonical link dynamically.
    // Always canonicalize to the apex production domain, no matter which
    // hostname served the page (www, preview URLs, etc.). This consolidates
    // ranking signals on https://inksyncnote.com and prevents duplicate
    // content if the site is ever reachable via an alternate hostname.
    let canonical = document.querySelector('link[rel="canonical"]');
    if (!canonical) {
      const link = document.createElement('link');
      link.setAttribute('rel', 'canonical');
      document.head.appendChild(link);
      canonical = link;
    }

    const pathname = window.location.pathname === '/' ? '' : window.location.pathname;
    // The terms.inksyncnote.com subdomain always serves the terms page,
    // regardless of path — canonicalize it to the real /terms/ URL.
    const canonicalUrl = window.location.hostname === 'terms.inksyncnote.com'
      ? 'https://inksyncnote.com/terms/'
      : `https://inksyncnote.com${pathname}`;
    canonical.setAttribute('href', canonicalUrl);

    // Mirror the canonical URL into og:url so prerendered pages and
    // link unfurlers see the page-specific URL, not the homepage's.
    updateMetaTag('property', 'og:url', canonicalUrl);
  }, [title, description]);
}
