// Mobile implementation — safe no-ops for all dart:html functionality.

String? getLocalStorageValue(String key) => null;
void setLocalStorageValue(String key, String value) {}
void removeLocalStorageValue(String key) {}
String getLocationHash() => '';
String getLocationOrigin() => '';
void replaceHistoryState(String url) {}
void setLocationHref(String url) {}
String getLocationHref() => '';
void openInNewTab(String url) {}
void assignAndReload(String path) {}
void reloadPage() {}

/// Register a platform view (web-only). No-op on mobile.
void registerPlatformView(String viewId, dynamic element) {}

/// Read the marketing-site `is_anon` attribution cookie. Always null on mobile
/// (mobile funnels start at signup; there is no shared browser cookie).
String? readWebAnonId() => null;
