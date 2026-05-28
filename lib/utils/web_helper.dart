// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Web implementation — uses dart:html for browser-specific features.

String? getLocalStorageValue(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void setLocalStorageValue(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

void removeLocalStorageValue(String key) {
  try {
    html.window.localStorage.remove(key);
  } catch (_) {}
}

String getLocationHash() {
  try {
    return html.window.location.hash;
  } catch (_) {
    return '';
  }
}

String getLocationOrigin() {
  try {
    return html.window.location.origin;
  } catch (_) {
    return '';
  }
}

void replaceHistoryState(String url) {
  try {
    html.window.history.replaceState(null, '', url);
  } catch (_) {}
}

void setLocationHref(String url) {
  try {
    html.window.location.href = url;
  } catch (_) {}
}

String getLocationHref() {
  try {
    return html.window.location.href;
  } catch (_) {
    return '';
  }
}

void openInNewTab(String url) {
  try {
    html.window.open(url, '_blank');
  } catch (_) {}
}

void assignAndReload(String url) {
  try {
    html.window.location.assign(url);
    html.window.location.reload();
  } catch (_) {}
}

void reloadPage() {
  try {
    html.window.location.reload();
  } catch (_) {}
}

/// Register a platform view for web (e.g., Stripe card element).
void registerPlatformView(String viewId, dynamic element) {
  try {
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => element,
    );
  } catch (_) {}
}
