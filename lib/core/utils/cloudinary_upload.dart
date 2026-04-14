import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryUpload {
  // Free Wallpapers Credentials
  static const String _freeCloudName = 'dl00rha3n';
  static const String _freeUploadPreset = 'royal pixels';

  // Premium & Special Wallpapers Credentials
  static const String _premiumCloudName = 'dmt6y2k6h';
  static const String _premiumUploadPreset = 'premium and special';

  /// Uploads an image file directly to Cloudinary and returns the secure URL
  /// If [isPremiumOrSpecial] is true, uses the premium Cloudinary account.
  static Future<String?> uploadImage(File imageFile, {bool isPremiumOrSpecial = false}) async {
    final String cloudName = isPremiumOrSpecial ? _premiumCloudName : _freeCloudName;
    final String uploadPreset = isPremiumOrSpecial ? _premiumUploadPreset : _freeUploadPreset;

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    var request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        
        return jsonMap['secure_url'];
      } else {
        debugPrint('Cloudinary Upload Failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception during Cloudinary upload: $e');
      return null;
    }
  }
}
