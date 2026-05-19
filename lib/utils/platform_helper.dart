// Platform helper — conditional import entrypoint.
// On web, loads web_helper.dart (which uses dart:html).
// On mobile/other, loads mobile_helper.dart (safe no-ops).
export 'mobile_helper.dart'
    if (dart.library.html) 'web_helper.dart';
