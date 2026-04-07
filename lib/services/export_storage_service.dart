// lib/services/export_storage_service.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';

// 1. IMPORT the enum from your editor state instead of redefining it!
import '../logic/editor_bloc/editor_state.dart'; 

import 'package:flutter/foundation.dart'; // ✅ Required for debugPrint
import 'package:media_scanner/media_scanner.dart'; // ✅ Required for MediaScanner

// (Make sure the import path above matches your folder structure. 
//  Based on the error, it looks like this path will work).

// DELETED: enum SaveFormat { json, txt, docx, pdf } <--- DO NOT PUT THIS HERE ANYMORE

class ExportStorageService {
  /// Gets the specific subfolder path depending on the format and OS.
  Future<Directory> getExportDirectory(SaveFormat format) async {
    String basePath;

    if (Platform.isAndroid) {
      // /storage/emulated/0/ is the root of the user's public Internal Storage on Android.
      basePath = '/storage/emulated/0/Documents/DocEase';
    } else if (Platform.isIOS) {
      // On iOS, we use the app's documents directory.
      final dir = await getApplicationDocumentsDirectory();
      basePath = '${dir.path}/DocEase';
    } else {
      // Fallback for desktop/web
      final dir = await getApplicationDocumentsDirectory();
      basePath = '${dir.path}/DocEase';
    }

    // Determine the subfolder based on the format (txt, pdf, docx, etc.)
    String subFolder = format.name.toUpperCase(); 
    
    // Combine base path and subfolder
    final fullPath = '$basePath/$subFolder';
    final directory = Directory(fullPath);

    // If the directory doesn't exist, create it recursively
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

    Future<void> initializePublicFolders() async {
    if (!Platform.isAndroid) return;

    final String basePath = '/storage/emulated/0/Documents/DocEase';
    final List<String> subFolders = ['DOCX', 'PDF', 'TXT'];

    try {
      for (String sub in subFolders) {
        final dir = Directory('$basePath/$sub');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }
      // Scan the ROOT folder so Android sees the subfolders immediately
      await MediaScanner.loadMedia(path: basePath);
    } catch (e) {
      debugPrint("Error initializing folders: $e");
    }
  }
  

  /// Saves plain text to the respective folder
  Future<File> saveTextFile(String textContent, String fileName) async {
    final directory = await getExportDirectory(SaveFormat.txt);
    final file = File('${directory.path}/$fileName.txt');
    
    return await file.writeAsString(textContent);
  }

  /// Saves binary data (like PDF or DOCX) to the respective folder
  Future<File> saveBinaryFile(List<int> bytes, String fileName, SaveFormat format) async {
    final directory = await getExportDirectory(format);
    
    // Safety check: ensure we only append the extension correctly
    final extension = format.name; 
    final file = File('${directory.path}/$fileName.$extension');
    
    return await file.writeAsBytes(bytes);
  }

  /// Checks if a file already exists in the target backup folder
  Future<bool> fileExists(String fileName, SaveFormat format) async {
    final directory = await getExportDirectory(format);
    final extension = format.name;
    final file = File('${directory.path}/$fileName.$extension');
    return await file.exists();
  }
}