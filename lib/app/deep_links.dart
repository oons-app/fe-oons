import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/app/router.dart';

/// Native Universal Links (`https://lady.oons.app/checkout/...`) and `oons://`.
/// Web already has the path in the address bar.
void attachAppLinks(GoRouter router) {
  if (kIsWeb) return;
  final links = AppLinks();
  void go(Uri uri) {
    final path = pathFromDeepLink(uri);
    if (path == null || path == '/') return;
    rememberPayDeepLink(path);
    router.go(path);
  }

  links.getInitialLink().then((uri) {
    if (uri != null) go(uri);
  });
  links.uriLinkStream.listen(go);
}
