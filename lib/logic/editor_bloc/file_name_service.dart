import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileNameService {
  // Returns the next available "Untitled Document N" name
  static Future<String> nextUntitledName(String format) async {
    final existing = await _getExistingFileNames(format);
    int counter = 1;
    while (existing.contains('Untitled Document $counter')) {
      counter++;
    }
    return 'Untitled Document $counter';
  }

  // Checks for conflict and returns resolution
  // Returns null if no conflict
  // Returns suggested "Name (N)" if conflict exists
  static Future<String?> checkConflict(String fileName, String format) async {
    final existing = await _getExistingFileNames(format);
    if (!existing.contains(fileName)) return null;

    // Find next available (N)
    int counter = 1;
    while (existing.contains('$fileName ($counter)')) {
      counter++;
    }
    return '$fileName ($counter)';
  }

  static Future<List<String>> _getExistingFileNames(String format) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/DocEase/${format.toUpperCase()}');
    if (!await folder.exists()) return [];

    return folder
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.$format', ''))
        .toList();
  }
}