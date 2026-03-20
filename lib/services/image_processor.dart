import 'dart:io';
import 'package:image/image.dart' as img;

class ImageProcessor {
  static Future<String?> analyzeImageQuality(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return "Invalid image file.";

    final sizeInMB = bytes.lengthInBytes / (1024 * 1024);
    if (sizeInMB > 5) return "File is too large (max 5MB).";

    double brightness = _calculateBrightness(decoded);
    if (brightness < 40) return "Image is too dark.";
    if (brightness > 280) return "Image is too bright.";

    double blur = _estimateBlur(decoded);
    if (blur < 2) return "Image appears blurry.";

    return null;
  }

  static double _calculateBrightness(img.Image image) {
    double total = 0;
    int count = 0;
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        total += (pixel.r + pixel.g + pixel.b) / 3;
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }

  static double _estimateBlur(img.Image image) {
    double sum = 0;
    int count = 0;
    for (int y = 1; y < image.height - 1; y += 5) {
      for (int x = 1; x < image.width - 1; x += 5) {
        final c = _getLuminance(image.getPixel(x, y));
        final right = _getLuminance(image.getPixel(x + 1, y));
        final down = _getLuminance(image.getPixel(x, y + 1));
        sum += (c - right).abs() + (c - down).abs();
        count++;
      }
    }
    return count > 0 ? sum / count : 0;
  }

  static double _getLuminance(img.Pixel pixel) {
    return 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
  }
}