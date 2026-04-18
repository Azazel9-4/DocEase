import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

class OcrResult {
  final String formattedText;
  final List<String> qualityWarnings;
  final bool foundText;

  const OcrResult({
    required this.formattedText,
    required this.qualityWarnings,
    required this.foundText,
  });
}

class OcrService {
  // ---------------------------------------------------------------------------
  // PUBLIC
  // ---------------------------------------------------------------------------

  Future<OcrResult> scanImages(List<File> images) async {
    final textRecognizer =
        TextRecognizer(script: TextRecognitionScript.latin);
    String formattedText = "";
    bool foundText = false;
    final List<String> qualityWarnings = [];

    try {
      for (int i = 0; i < images.length; i++) {
        final qualityIssue = await _analyzeImageQuality(images[i]);
        if (qualityIssue != null) {
          qualityWarnings.add("Image ${i + 1}: $qualityIssue");
        }

        final inputImage = InputImage.fromFile(images[i]);
        final recognizedText =
            await textRecognizer.processImage(inputImage);

        if (recognizedText.blocks.isEmpty) continue;
        foundText = true;

        // ── FIX: Sort blocks top-to-bottom by their bounding box Y position.
        //
        // ML Kit does NOT guarantee that blocks are returned in reading order.
        // Large/bold headings are often detected as isolated blocks and may
        // appear anywhere in the list. Sorting by the top edge of each block's
        // bounding rect restores the natural visual order before we join them.
        // ── FIX: Sort blocks top-to-bottom by their bounding box Y position.
        final sortedBlocks = List.of(recognizedText.blocks)
          ..sort((a, b) {
            final aTop = a.boundingBox.top;
            final bTop = b.boundingBox.top;

            // Instead of a microscopic 20 pixels, we use half the height 
            // of the text block. This dynamically adapts to high-resolution 
            // images and large title fonts!
            final dynamicTolerance = a.boundingBox.height / 2;

            if ((aTop - bTop).abs() > dynamicTolerance) {
              // If the height difference is significant, sort Top to Bottom
              return aTop.compareTo(bTop);
            }
            
            // If they truly share the same row, sort Left to Right
            return a.boundingBox.left.compareTo(b.boundingBox.left);
          });

        for (final block in sortedBlocks) {
          if (block.lines.isEmpty) continue;

          for (final line in block.lines) {
            formattedText += "${line.text.trim()}\n";
          }

          formattedText += "\n"; // blank line between blocks
        }

        if (i < images.length - 1) {
          formattedText += "\n\n"; // separator between pages
        }
      }
    } finally {
      await textRecognizer.close();
    }

    return OcrResult(
      formattedText: formattedText.trim(),
      qualityWarnings: qualityWarnings,
      foundText: foundText,
    );
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — image quality helpers
  // ---------------------------------------------------------------------------

  Future<String?> _analyzeImageQuality(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return "Invalid image file.";

    final sizeInMB = bytes.lengthInBytes / (1024 * 1024);
    if (sizeInMB > 5) return "File is too large (max 5MB).";

    final brightness = _calculateBrightness(decoded);
    if (brightness < 40) return "Image is too dark.";
    if (brightness > 280) return "Image is too bright.";

    final blur = _estimateBlur(decoded);
    if (blur < 2) return "Image appears blurry.";

    return null;
  }

  double _calculateBrightness(img.Image image) {
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

  double _estimateBlur(img.Image image) {
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

  double _getLuminance(img.Pixel pixel) =>
      0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
}