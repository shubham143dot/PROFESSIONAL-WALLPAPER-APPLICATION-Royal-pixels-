import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeepLinkService {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> init(BuildContext context) async {
    _appLinks = AppLinks();

    // 1. Handle initial link (when app is opened from a link)
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      if (context.mounted) _handleUri(context, initialUri);
    }

    // 2. Handle incoming links (when app is already running)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (context.mounted) _handleUri(context, uri);
    });
  }

  void _handleUri(BuildContext context, Uri uri) {
    // Example: royalpixels.app/w/wallpaperId
    if (uri.pathSegments.contains('w')) {
      final wpId = uri.pathSegments.last;
      // Navigate to detail page
      // Note: We might need to fetch the wallpaper entity first if not in memory
      // For now, we'll navigate to a route that handles fetching by ID
      context.push('/wallpaper/$wpId');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
