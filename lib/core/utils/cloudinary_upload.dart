import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryUpload {
  // Free Wallpapers Credentials
  static const String _freeCloudName = 'dl00rha3n';
  static const String _freeApiKey = '837238164488567';
  static const String _freeApiSecret = 'bdHDsHE2QyXzqt5UNLJMzxrrpu8';

  // Premium & Special Wallpapers Credentials
  static const String _premiumCloudName = 'dmt6y2k6h';
  static const String _premiumApiKey = '174456259398661';
  static const String _premiumApiSecret = 'OxI0nRoL8RNK7xRJYVQJtX6cEhs';

  /// Uploads an image file to Cloudinary using Signed API.
  /// If [isPremiumOrSpecial] is true, uses the premium Cloudinary account.
  static Future<String?> uploadImage(File imageFile,
      {bool isPremiumOrSpecial = false}) async {
    final String cloudName =
        isPremiumOrSpecial ? _premiumCloudName : _freeCloudName;
    final String apiKey = isPremiumOrSpecial ? _premiumApiKey : _freeApiKey;
    final String apiSecret =
        isPremiumOrSpecial ? _premiumApiSecret : _freeApiSecret;

    final String timestamp =
        DateTime.now().millisecondsSinceEpoch.toString().substring(0, 10);

    // Cloudinary requires signed parameters in alphabetical order
    // For a base upload, we sign 'timestamp={timestamp}'
    final String signature =
        _generateSignature({'timestamp': timestamp}, apiSecret);

    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    try {
      var request = http.MultipartRequest('POST', url)
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp
        ..fields['signature'] = signature
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = await response.stream.toBytes();
        final responseString = utf8.decode(responseData);
        final jsonMap = jsonDecode(responseString);

        return jsonMap['secure_url'];
      } else {
        final responseData = await response.stream.toBytes();
        final responseString = utf8.decode(responseData);
        if (kDebugMode) {
          debugPrint(
              'Cloudinary Upload Failed (${response.statusCode}): $responseString');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Exception during Cloudinary upload: $e');
      }
      return null;
    }
  }

  /// Generates SHA-1 signature for Cloudinary API requests
  static String _generateSignature(
      Map<String, String> params, String apiSecret) {
    // 1. Sort parameters alphabetically by key
    final sortedKeys = params.keys.toList()..sort();

    // 2. Map into key=value pairs joined by &
    final parameterString =
        sortedKeys.map((key) => '$key=${params[key]}').join('&');

    // 3. Append API Secret and hash with SHA-1
    final stringToSign = '$parameterString$apiSecret';
    final bytes = utf8.encode(stringToSign);
    final digest = sha1.convert(bytes);

    return digest.toString();
  }
}
