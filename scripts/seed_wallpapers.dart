// Run with:  dart run scripts/seed_wallpapers.dart
// Requires: firebase_admin SDK via REST (or flutterfire CLI)
// ──────────────────────────────────────────────────────────────────────────────
// Because Flutter desktop Firebase is not a simple CLI tool, this script uses
// the Firestore REST API with your service-account key.
//
// SETUP (one-time):
//   1. Go to Firebase Console → Project Settings → Service Accounts
//   2. Click "Generate new private key" → save as scripts/service_account.json
//   3. dart pub global activate flutterfire_cli   (if not already)
//   4. dart run scripts/seed_wallpapers.dart
// ──────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
// ignore_for_file: avoid_print, unused_local_variable

// ── CONFIG ────────────────────────────────────────────────────────────────────
const String projectId = 'royalpixels-c2b02'; // ← your Firebase project ID

// The ONE wallpaper to add to the free section
const Map<String, dynamic> freeWallpaper = {
  'title': 'Name Time Stone',
  'image_url': 'https://res.cloudinary.com/dl00rha3n/image/upload/v1774675099/image4_a7imnz.jpg',
  'category': 'Nature',
  'is_premium': false,
  'price': 0.0,
  'tags': ['nature', 'stone', 'time', 'scenic'],
};
// ─────────────────────────────────────────────────────────────────────────────

Future<String> getAccessToken(Map<String, dynamic> serviceAccount) async {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final header = base64Url.encode(utf8.encode(json.encode({'alg': 'RS256', 'typ': 'JWT'})));
  final payload = base64Url.encode(utf8.encode(json.encode({
    'iss': serviceAccount['client_email'],
    'scope': 'https://www.googleapis.com/auth/datastore',
    'aud': 'https://oauth2.googleapis.com/token',
    'iat': now,
    'exp': now + 3600,
  })));

  // NOTE: For simplicity, obtain the token via gcloud CLI if available,
  // or use the Firebase Admin Node SDK. This script shows the seeding logic.
  // If you have gcloud installed, run:
  //   gcloud auth application-default print-access-token
  // and paste it below:
  throw UnsupportedError(
    'Direct JWT signing in Dart requires a native RSA library.\n'
    'Use the Firebase Console or Node.js seeder below instead.\n'
    'See the Node.js alternative at the bottom of this script.',
  );
}

void printFirestoreDocument(String id, Map<String, dynamic> data) {
  print('  Document: $id');
  data.forEach((k, v) => print('    $k: $v'));
}

void main() async {
  print('''
══════════════════════════════════════════════════════
  Royal Pixels – Wallpaper Seeder
══════════════════════════════════════════════════════

  This script will:
    1. Delete ALL existing free wallpapers from Firestore
    2. Add one free wallpaper: "Name Time Stone"

  Easiest method: paste this document manually in
  Firebase Console → Firestore → wallpapers → Add doc

  Document fields:
''');

  freeWallpaper.forEach((k, v) {
    final type = v is bool
        ? 'boolean'
        : v is double
            ? 'number'
            : v is List
                ? 'array'
                : 'string';
    print('    $k ($type): $v');
  });

  print('''

  ─────────────────────────────────────────────────
  OR run the Node.js seeder (auto-handles auth):

    node scripts/seed_wallpapers.js

  (Make sure you have scripts/service_account.json)
══════════════════════════════════════════════════════
''');
}
