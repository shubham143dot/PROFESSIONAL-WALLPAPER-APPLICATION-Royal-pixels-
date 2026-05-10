import 'package:flutter/material.dart';
import 'package:palette_generator_master/palette_generator_master.dart';
import 'adaptive_performance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to extract and cache dominant colors from images for the glow system.
class PaletteService {
  final Map<String, Color> _colorCache = {};

  /// Gets the dominant color for an image URL.
  /// If already cached, returns the cached color.
  /// Otherwise, extracts it and caches it.
  Future<Color> getDominantColor(String imageUrl) async {
    if (_colorCache.containsKey(imageUrl)) {
      return _colorCache[imageUrl]!;
    }

    // Performance Failsafe: Return fallback early if dynamic palette is disabled
    if (!AdaptivePerformance.enableDynamicPalette) {
      return Colors.white.withAlpha(128);
    }

    try {
      // Use PaletteGeneratorMaster as per the project's custom package
      final paletteGenerator = await PaletteGeneratorMaster.fromImageProvider(
        NetworkImage(imageUrl),
        maximumColorCount: 5,
        // Only extract from a small portion to improve performance
        region: const Rect.fromLTWH(0, 0, 100, 100), 
      );

      final color = paletteGenerator.dominantColor?.color ?? 
                    paletteGenerator.vibrantColor?.color ?? 
                    Colors.white;
      
      // Post-process the color as per requirements:
      // Slightly desaturate or darken to avoid oversaturation.
      final processedColor = _processColor(color);
      
      _colorCache[imageUrl] = processedColor;
      return processedColor;
    } catch (e) {
      // Fallback color
      return Colors.white.withAlpha(128); // 0.5 opacity
    }
  }

  Color _processColor(Color color) {
    // Convert to HSL for easier manipulation
    final hsl = HSLColor.fromColor(color);
    
    // Requirement: Make the glow color vibrant to match the wallpaper properly.
    // Boost saturation and ensure it has good lightness.
    final saturation = hsl.saturation.clamp(0.5, 0.95);
    final lightness = hsl.lightness.clamp(0.4, 0.7);
    
    return hsl.withSaturation(saturation).withLightness(lightness).toColor();
  }

  void clearCache() {
    _colorCache.clear();
  }
}

final paletteServiceProvider = Provider((ref) => PaletteService());
