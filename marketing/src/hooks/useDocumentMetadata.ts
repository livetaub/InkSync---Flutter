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

    // 4. Update canonical link dynamically
    // Avoid hardcoding the protocol/domain in subpaths.
    let canonical = document.querySelector('link[rel="canonical"]');
    if (!canonical) {
      canonical = document.createElement('link');
      canonical.setAttribute('rel', 'canonical');
      document.head.appendChild(canonical);
    }
    
    // Construct canonical URL using current hostname & pathname (e.g. terms.inksyncnote.com or inksyncnote.com)
    const hostname = window.location.hostname;
    const protocol = window.location.protocol;
    const pathname = window.location.pathname === '/' ? '' : window.location.pathname;
    
    // Fallback locally/dev but build clean canonical url on production
    const canonicalUrl = `${protocol}//${hostname}${pathname}`;
    canonical.setAttribute('href', canonicalUrl);
  }, [title, description]);
}
