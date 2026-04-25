import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The result of an update check.
enum UpdateType {
  /// App is up to date — do nothing.
  none,

  /// A new version is available but not required.
  /// Show a dismissible banner / dialog.
  optional,

  /// App version is below the minimum required — block usage.
  forced,
}

class UpdateCheckResult {
  final UpdateType type;

  /// The build number in Firestore marked as the latest.
  final int latestBuildNumber;

  /// The minimum required build number; anything below this is force-updated.
  final int minBuildNumber;

  /// Play Store URL to open when user taps "Update".
  final String storeUrl;

  /// Human-readable version string shown in dialogs (e.g. "1.2.0").
  final String latestVersionName;

  /// What's new in the latest version (shown in optional dialog).
  final String releaseNotes;

  const UpdateCheckResult({
    required this.type,
    required this.latestBuildNumber,
    required this.minBuildNumber,
    required this.storeUrl,
    required this.latestVersionName,
    required this.releaseNotes,
  });
}

/// Checks Firestore for update config and compares against the running build.
///
/// Firestore document path: `app_config/update`
///
/// Expected document structure:
/// ```json
/// {
///   "latest_build_number": 17,
///   "min_build_number":    16,
///   "latest_version_name": "1.2.0",
///   "store_url": "https://play.google.com/store/apps/details?id=com.royalpixels.app",
///   "release_notes": "• New wallpaper categories\n• Bug fixes"
/// }
/// ```
class UpdateService {
  static const String _collection = 'app_config';
  static const String _document   = 'update';

  /// Fetches the update config from Firestore and returns an [UpdateCheckResult].
  /// Returns [UpdateType.none] on any error to avoid blocking users on network issues.
  static Future<UpdateCheckResult> checkForUpdate() async {
    const fallback = UpdateCheckResult(
      type: UpdateType.none,
      latestBuildNumber: 0,
      minBuildNumber: 0,
      storeUrl: '',
      latestVersionName: '',
      releaseNotes: '',
    );

    try {
      // 1. Get current build number from the installed app
      final info = await PackageInfo.fromPlatform();
      final int currentBuild = int.tryParse(info.buildNumber) ?? 0;

      if (kDebugMode) {
        debugPrint('[UpdateService] Current build number: $currentBuild');
      }

      // 2. Read update config from Firestore
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_document)
          .get();

      if (!doc.exists) {
        if (kDebugMode) debugPrint('[UpdateService] No update config in Firestore.');
        return fallback;
      }

      final data = doc.data()!;
      final int latestBuild  = (data['latest_build_number'] as num?)?.toInt() ?? 0;
      final int minBuild     = (data['min_build_number']    as num?)?.toInt() ?? 0;
      final String storeUrl  = data['store_url']?.toString() ?? '';
      final String versionName = data['latest_version_name']?.toString() ?? '';
      final String notes     = data['release_notes']?.toString() ?? '';

      if (kDebugMode) {
        debugPrint('[UpdateService] Firestore → latest: $latestBuild, min: $minBuild');
      }

      // 3. Determine update type
      UpdateType type;
      if (currentBuild < minBuild) {
        type = UpdateType.forced;
      } else if (currentBuild < latestBuild) {
        type = UpdateType.optional;
      } else {
        type = UpdateType.none;
      }

      return UpdateCheckResult(
        type: type,
        latestBuildNumber: latestBuild,
        minBuildNumber: minBuild,
        storeUrl: storeUrl,
        latestVersionName: versionName,
        releaseNotes: notes,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[UpdateService] Error checking update: $e');
      // Network / Firestore error — never block the user
      return fallback;
    }
  }
}
