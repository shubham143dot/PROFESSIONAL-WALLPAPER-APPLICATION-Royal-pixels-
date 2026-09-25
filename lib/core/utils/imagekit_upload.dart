import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Unified image uploader with ImageKit → Cloudinary fallback for free wallpapers.
///
/// Strategy:
///  - FREE wallpapers  : Try ImageKit first → fallback to Cloudinary on any failure.
///  - PREMIUM wallpapers: Upload directly to the Cloudinary premium account (unchanged).
class ImageKitUpload {
  // ── ImageKit Credentials ────────────────────────────────────────────────
  static const String _ikPrivateKey =
      String.fromEnvironment('IMAGEKIT_PRIVATE_KEY', defaultValue: '');
  static const String _ikUploadUrl =
      'https://upload.imagekit.io/api/v1/files/upload';

  // ── Cloudinary Credentials (Free account — fallback) ───────────────────
  static const String _clFreeCloudName =
      String.fromEnvironment('CLOUDINARY_FREE_CLOUD_NAME', defaultValue: '');
  static const String _clFreeApiKey =
      String.fromEnvironment('CLOUDINARY_FREE_API_KEY', defaultValue: '');
  static const String _clFreeApiSecret =
      String.fromEnvironment('CLOUDINARY_FREE_API_SECRET', defaultValue: '');

  // ── Cloudinary Credentials (Premium account) ────────────────────────────
  static const String _clPremiumCloudName =
      String.fromEnvironment('CLOUDINARY_PREMIUM_CLOUD_NAME', defaultValue: '');
  static const String _clPremiumApiKey =
      String.fromEnvironment('CLOUDINARY_PREMIUM_API_KEY', defaultValue: '');
  static const String _clPremiumApiSecret =
      String.fromEnvironment('CLOUDINARY_PREMIUM_API_SECRET', defaultValue: '');

  // ────────────────────────────────────────────────────────────────────────
  /// Public entry point.
  ///
  /// [isPremiumOrSpecial] = true  → upload to Cloudinary premium (no IK attempt).
  /// [isPremiumOrSpecial] = false → try ImageKit; on failure, fall back to Cloudinary free.
  // ────────────────────────────────────────────────────────────────────────
  static Future<String?> uploadImage(
    File imageFile, {
    bool isPremiumOrSpecial = false,
  }) async {
    if (isPremiumOrSpecial) {
      // Premium: always use Cloudinary premium account.
      if (kDebugMode) debugPrint('[Upload] Premium → Cloudinary premium');
      return _uploadToCloudinary(
        imageFile,
        cloudName: _clPremiumCloudName,
        apiKey: _clPremiumApiKey,
        apiSecret: _clPremiumApiSecret,
      );
    }

    // Free: ImageKit first (with retry), Cloudinary free as fallback.
    if (kDebugMode) debugPrint('[Upload] Free → trying ImageKit...');
    final ikUrl = await _uploadWithRetry(imageFile, maxRetries: 2);

    if (ikUrl != null) {
      if (kDebugMode) debugPrint('[Upload] ImageKit succeeded ✓ → $ikUrl');
      return ikUrl;
    }

    if (kDebugMode) {
      debugPrint(
          '[Upload] ImageKit failed — falling back to Cloudinary free...');
    }
    final clUrl = await _uploadToCloudinary(
      imageFile,
      cloudName: _clFreeCloudName,
      apiKey: _clFreeApiKey,
      apiSecret: _clFreeApiSecret,
    );

    if (clUrl != null) {
      if (kDebugMode) {
        debugPrint('[Upload] Cloudinary fallback succeeded ✓ → $clUrl');
      }
    } else {
      if (kDebugMode) {
        debugPrint('[Upload] Both ImageKit and Cloudinary failed ✗');
      }
    }
    return clUrl;
  }

  // ── Retry wrapper with exponential backoff ──────────────────────────────
  static Future<String?> _uploadWithRetry(File imageFile,
      {int maxRetries = 2}) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      final url = await _uploadToImageKit(imageFile);
      if (url != null) return url;
      if (attempt < maxRetries) {
        final delay = Duration(seconds: 1 << attempt); // 1s, 2s
        if (kDebugMode) {
          debugPrint(
              '[Upload] Retry ${attempt + 1}/$maxRetries after ${delay.inSeconds}s...');
        }
        await Future.delayed(delay);
      }
    }
    return null;
  }

  // ── Verify that an uploaded image URL is actually accessible ─────────────
  /// Does a lightweight HEAD request. Returns true if the CDN responds 2xx/3xx.
  static Future<bool> verifyImageUrl(String url) async {
    try {
      final response =
          await http.head(Uri.parse(url)).timeout(const Duration(seconds: 10));
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  // ── Private: ImageKit upload ─────────────────────────────────────────────
  static Future<String?> _uploadToImageKit(File imageFile) async {
    if (_ikPrivateKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
            '[ImageKit] IMAGEKIT_PRIVATE_KEY not set. Pass via --dart-define=IMAGEKIT_PRIVATE_KEY=...');
      }
      return null;
    }
    try {
      final String fileName = path.basename(imageFile.path);

      // ImageKit server-side auth: Basic base64("privateKey:")
      final String authHeader =
          'Basic ${base64Encode(utf8.encode('$_ikPrivateKey:'))}';

      var request = http.MultipartRequest('POST', Uri.parse(_ikUploadUrl))
        ..headers['Authorization'] = authHeader
        ..fields['fileName'] = fileName
        ..fields['useUniqueFileName'] = 'true'
        ..fields['folder'] = '/free_wallpapers'
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response =
          await request.send().timeout(const Duration(seconds: 45));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = utf8.decode(await response.stream.toBytes());
        final jsonMap = jsonDecode(body) as Map<String, dynamic>;
        // ImageKit returns 'url' (HTTP) and optionally 'thumbnailUrl'; prefer 'url'.
        return jsonMap['url'] as String?;
      } else {
        if (kDebugMode) {
          final body = utf8.decode(await response.stream.toBytes());
          debugPrint('[ImageKit] HTTP ${response.statusCode}: $body');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ImageKit] Exception: $e');
      return null;
    }
  }

  // ── Private: Cloudinary upload ───────────────────────────────────────────
  static Future<String?> _uploadToCloudinary(
    File imageFile, {
    required String cloudName,
    required String apiKey,
    required String apiSecret,
  }) async {
    if (cloudName.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
      if (kDebugMode) {
        debugPrint(
            '[Cloudinary] Credentials not configured. Pass via --dart-define.');
      }
      return null;
    }
    try {
      final String timestamp =
          DateTime.now().millisecondsSinceEpoch.toString().substring(0, 10);
      final String signature =
          _cloudinarySignature({'timestamp': timestamp}, apiSecret);

      final url =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      var request = http.MultipartRequest('POST', url)
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp
        ..fields['signature'] = signature
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response =
          await request.send().timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = utf8.decode(await response.stream.toBytes());
        final jsonMap = jsonDecode(body) as Map<String, dynamic>;
        return jsonMap['secure_url'] as String?;
      } else {
        if (kDebugMode) {
          final body = utf8.decode(await response.stream.toBytes());
          debugPrint('[Cloudinary] HTTP ${response.statusCode}: $body');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Cloudinary] Exception: $e');
      return null;
    }
  }

  // ── Cloudinary SHA-1 signature helper ───────────────────────────────────
  static String _cloudinarySignature(
      Map<String, String> params, String apiSecret) {
    final sortedKeys = params.keys.toList()..sort();
    final paramString = sortedKeys.map((k) => '$k=${params[k]}').join('&');
    final stringToSign = '$paramString$apiSecret';
    final digest = sha1.convert(utf8.encode(stringToSign));
    return digest.toString();
  }
}
