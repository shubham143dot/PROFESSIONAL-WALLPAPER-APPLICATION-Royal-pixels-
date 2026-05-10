import 'dart:typed_data';
import 'package:image/image.dart' as img;

enum WallpaperFilter {
  original,
  amoledBlack,
  grayscale,
  highContrast,
}

class ImageFilterUtils {
  /// Returns the ColorMatrix to be used in the UI's ColorFiltered widget
  static List<double> getMatrixForFilter(WallpaperFilter filter) {
    switch (filter) {
      case WallpaperFilter.grayscale:
        // Standard Grayscale Matrix
        return [
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
      case WallpaperFilter.highContrast:
        // Increase contrast by scaling RGB values and shifting
        final double contrast = 1.5; // 1.5x contrast
        final double shift = -128 * (contrast - 1);
        return [
          contrast,
          0,
          0,
          0,
          shift,
          0,
          contrast,
          0,
          0,
          shift,
          0,
          0,
          contrast,
          0,
          shift,
          0,
          0,
          0,
          1,
          0,
        ];
      case WallpaperFilter.amoledBlack:
        // Simulated AMOLED effect via ColorMatrix
        // Increase contrast dramatically for dark colors to crush them to black
        final double contrast = 1.2;
        final double shift = -30; // Crush darker colors to black
        return [
          contrast,
          0,
          0,
          0,
          shift,
          0,
          contrast,
          0,
          0,
          shift,
          0,
          0,
          contrast,
          0,
          shift,
          0,
          0,
          0,
          1,
          0,
        ];
      case WallpaperFilter.original:
        // Identity Matrix (No change)
        return [
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
    }
  }

  /// Applies the selected filter to raw image bytes using the `image` package
  /// Returns the modified JPEG bytes.
  static Future<Uint8List> applyFilterToBytes(
      Uint8List imageBytes, WallpaperFilter filter) async {
    if (filter == WallpaperFilter.original) return imageBytes;

    // Decode image
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) return imageBytes;

    img.Image processedImage = img.Image.from(originalImage);

    // Apply Filter Logic
    switch (filter) {
      case WallpaperFilter.grayscale:
        img.grayscale(processedImage);
        break;
      case WallpaperFilter.highContrast:
        img.adjustColor(processedImage, contrast: 1.5);
        break;
      case WallpaperFilter.amoledBlack:
        // Iterate through all pixels and crush dark grays to pure #000000
        for (var p in processedImage) {
          // If the pixel is dark enough (R,G,B all below a threshold), make it pitch black
          // To calculate perceived luminance: 0.299*R + 0.587*G + 0.114*B
          num luminance = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
          if (luminance < 40) {
            // Turn pixel completely black for deep AMOLED blacks
            p.r = 0;
            p.g = 0;
            p.b = 0;
          } else {
            // Optionally, slight contrast bump for the rest
            p.r = (p.r * 1.05).clamp(0, 255).toInt();
            p.g = (p.g * 1.05).clamp(0, 255).toInt();
            p.b = (p.b * 1.05).clamp(0, 255).toInt();
          }
        }
        break;
      case WallpaperFilter.original:
        break;
    }

    // Encode back to JPG (quality 95 to retain premium look)
    return Uint8List.fromList(img.encodeJpg(processedImage, quality: 95));
  }
}
