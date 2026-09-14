/**
 * InkSync marketing-site analytics.
 *
 * Drop-in snippet for the marketing site (inksyncnote.com). No dependencies,
 * no third-party trackers. Logs funnel events to the existing `paywall_events`
 * Supabase table using the public anon key (INSERT is allowed by RLS policy
 * "Anyone can insert events").
 *
 * Attribution: sets a first-party `is_anon` cookie on `.inksyncnote.com`
 * (1-year expiry) so the web app at app.inksyncnote.com can read the same id
 * and stitch pre-signup events to the user after signup.
 *
 * Usage in index.html (before </body>):
 *   <script src="/analytics.js" defer></script>
 * CTA tracking: add data-track="signup_cta_click" data-cta="hero" to buttons.
 */
(function () {
  'use strict';

  var SUPABASE_URL = 'https://bgzogfldvbdaoajlxjhf.supabase.co';
  var SUPABASE_ANON_KEY =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJnem9nZmxkdmJkYW9hamx4amhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg1MzQ4OTIsImV4cCI6MjA4NDExMDg5Mn0.Vthud-MOyDAL6NUuHHhGyDlVmCD5nG3B70Q4fQddtoI';

  function uuid() {
    if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      var r = (Math.random() * 16) | 0;
      return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
    });
  }

  function getCookie(name) {
    var m = document.cookie.match(new RegExp('(?:^|; )' + name + '=([^;]*)'));
    return m ? decodeURIComponent(m[1]) : null;
  }

  function setCookie(name, value, days) {
    var d = new Date();
    d.setTime(d.getTime() + days * 24 * 60 * 60 * 1000);
    // Domain=.inksyncnote.com shares the id with app.inksyncnote.com
    document.cookie =
      name + '=' + encodeURIComponent(value) +
      '; expires=' + d.toUTCString() +
      '; path=/; domain=.inksyncnote.com; SameSite=Lax';
  }

  var anonId = getCookie('is_anon');
  if (!anonId) {
    anonId = uuid();
    setCookie('is_anon', anonId, 365);
  }

  var sessionId = getCookie('is_sess');
  if (!sessionId) {
    sessionId = uuid();
    setCookie('is_sess', sessionId, 1); // 1-day sliding session
  }

  function utmParams() {
    var q = new URLSearchParams(window.location.search);
    var out = {};
    ['utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content'].forEach(function (k) {
      var v = q.get(k);
      if (v) out[k] = v;
    });
    return out;
  }

  function track(eventType, extra) {
    try {
      var payload = {
        event_type: eventType,
        anon_id: anonId,
        session_id: sessionId,
        platform: 'web',
        page_path: window.location.pathname,
        referrer: document.referrer || null,
        metadata: Object.assign(utmParams(), extra || {}),
      };
      fetch(SUPABASE_URL + '/rest/v1/paywall_events', {
        method: 'POST',
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: 'Bearer ' + SUPABASE_ANON_KEY,
          'Content-Type': 'application/json',
          Prefer: 'return=minimal',
        },
        body: JSON.stringify(payload),
        keepalive: true,
      }).catch(function () { /* analytics must never break the page */ });
    } catch (e) { /* never break the page */ }
  }

  // Expose for manual tracking: window.inksyncTrack('signup_cta_click', {cta:'pricing'})
  window.inksyncTrack = track;

  // Auto pageview
  track('pageview');

  // Declarative CTA tracking
  document.addEventListener('click', function (ev) {
    var el = ev.target && ev.target.closest ? ev.target.closest('[data-track]') : null;
    if (!el) return;
    var meta = { cta: el.getAttribute('data-cta') || el.textContent.trim().slice(0, 60) };
    var href = el.getAttribute('href');
    if (href) meta.href = href.slice(0, 200);
    track(el.getAttribute('data-track'), meta);
  });
})();
