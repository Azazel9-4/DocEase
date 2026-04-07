import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '/logic/editor_bloc/ocr_service.dart';
import '/logic/editor_bloc/file_name_service.dart';
import '/logic/editor_bloc/text_correction_service.dart';
import '/screens/home/template_picker_screen.dart';


class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  const HomeScreen({super.key, required this.isDarkMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();

  // -----------------------
  // EDIT IMAGE
  // -----------------------
  Future<void> _editImage(int index) async {
    final File? editedFile = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.file(
          _images[index],
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List bytes) async {
              final tempDir = await Directory.systemTemp.createTemp();
              final file = await File(
                      '${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png')
                  .create();
              await file.writeAsBytes(bytes);
              Navigator.pop(context, file);
            },
          ),
        ),
      ),
    );

    if (editedFile != null && mounted) {
      setState(() => _images[index] = editedFile);
    }
  }

  // -----------------------
  // PICK IMAGES
  // -----------------------
  Future<void> _pickMultipleImages() async {
    final List<XFile> picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _images.addAll(picked.map((x) => File(x.path)));
      });
    }
  }

  // -----------------------
  // SCAN TEXT
  // -----------------------
  Future<void> _scanText() async {
    if (_images.isEmpty) return;

    bool animationComplete = false;

    // 1. Show scanning dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double displayProgress = 0;
        bool animateUp = true;

        // --- DIALOG COLORS BASED ON MODE ---
        final bool isDark = widget.isDarkMode;
        final Color dialogBg = isDark ? const Color(0xFF0D1128) : Colors.white;
        final Color textColor = isDark ? Colors.white : const Color(0xFF1A1C2E);
        final Color scannerIconBg = isDark ? Colors.white24 : const Color(0xFF061F33).withOpacity(0.1);
        final Color progressBg = isDark ? Colors.white10 : Colors.black12;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future.delayed(const Duration(milliseconds: 30), () {
              if (context.mounted && displayProgress < 1.0) {
                setDialogState(() {
                  displayProgress += 0.05;
                  if (displayProgress >= 1.0) animationComplete = true;
                });
              }
            });

            return AlertDialog(
              backgroundColor: dialogBg, // Updated
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.document_scanner,
                          size: 50, color: scannerIconBg), // Updated
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: animateUp ? -25.0 : 25.0,
                          end: animateUp ? 25.0 : -25.0,
                        ),
                        duration: const Duration(seconds: 1),
                        onEnd: () =>
                            setDialogState(() => animateUp = !animateUp),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, value),
                            child: Container(
                              width: 60,
                              height: 2,
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "Processing Scans...",
                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600), // Updated
                  ),
                  const SizedBox(height: 15),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: displayProgress.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: progressBg, // Updated
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${(displayProgress.clamp(0.0, 1.0) * 100).toInt()}%",
                    style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // 2. Run OCR via OcrService
    OcrResult? result;
    try {
      result = await _ocrService.scanImages(_images);

      for (final warning in result.qualityWarnings) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(warning), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      debugPrint("OCR Error: $e"); 
      
      if (mounted) {
        String friendlyMessage = "An unexpected error occurred during scanning.";

        if (e.toString().contains("PathNotFoundException") || e.toString().contains("No such file")) {
          friendlyMessage = "The image file could not be found. Please try retaking the photo.";
        } else if (e.toString().contains("PermissionDenied")) {
          friendlyMessage = "Storage permission is required to scan documents.";
        } else if (e.toString().contains("Memory")) {
          friendlyMessage = "The image is too large. Please try a lower resolution.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating, 
            backgroundColor: Colors.red.shade800,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(friendlyMessage)), 
              ],
            ),
            action: SnackBarAction(
              label: "RETRY",
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      while (!animationComplete) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    // 3. Navigate to editor or show warning
    if (result == null || !result.foundText) {
      _showWarning("No text detected in any image.");
    } else {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        final fileName = await FileNameService.nextUntitledName('txt');
        final correctedText = TextCorrectionService.correct(result.formattedText);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TemplatePickerScreen(
              correctedText: correctedText,
              fileName: fileName, 
              isDarkMode: widget.isDarkMode,
            ),
          ),
        ).then((_) => setState(() => _images.clear()));
      }
    }
  }

  // -----------------------
  // SHOW WARNING DIALOG
  // -----------------------
  void _showWarning(String message) {
    if (!mounted) return;
    
    // Warning Dialog Colors
    final bool isDark = widget.isDarkMode;
    final Color dialogBg = isDark ? const Color(0xFF0D1128) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1A1C2E);
    final Color subTextColor = isDark ? Colors.white70 : Colors.black87;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: dialogBg, // Updated
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text("Warning", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)), // Updated
          ],
        ),
        content: Text(message, style: TextStyle(color: subTextColor)), // Updated
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // -----------------------
  // UI COMPONENTS
  // -----------------------
  Widget _buildSlidableImageCard(int i) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_images[i],
                height: 160, width: 100, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => setState(() => _images.removeAt(i)),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.redAccent, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _editImage(i),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.blueAccent, shape: BoxShape.circle),
                child: const Icon(Icons.edit, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMoreBox() {
    return GestureDetector(
      onTap: _pickMultipleImages,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.blueAccent.withOpacity(0.05),
          border: Border.all(
              color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: Colors.blueAccent, size: 28),
            SizedBox(height: 6),
            Text("Add More",
                style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // -----------------------
  // BUILD
  // -----------------------
  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;

    final Color cardBg = isDark ? const Color(0xFF121430) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1A1C2E);
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;
    final Color borderColor = isDark ? Colors.white10 : Colors.black12;

    // --- BUTTON COLORS ---
    // Dark mode = Bright Blue | Light Mode = Dark Navy
    final Color primaryButtonBg = isDark ? Colors.blueAccent : const Color(0xFF061F33);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(25),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ],
              ),
              child: Column(
                children: [
                  Text("Welcome to DocEase",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  const SizedBox(height: 10),
                  Text(
                    "Convert your physical documents into editable text instantly.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, fontSize: 14),
                  ),
                  const SizedBox(height: 25),
                  
                  // --- UPDATED CAPTURE DOCUMENT BUTTON ---
                  ElevatedButton.icon(
                    onPressed: () async {
                      final XFile? picked = await _picker.pickImage(
                          source: ImageSource.camera);
                      if (picked != null) {
                        setState(() => _images.add(File(picked.path)));
                      }
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Capture Document", style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryButtonBg, // Changes based on mode
                      foregroundColor: Colors.white, // Text & Icon are always white inside the dark button
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            Text("Quick Actions",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
            const SizedBox(height: 15),

            // Import from Gallery
            InkWell(
              onTap: _pickMultipleImages,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5))
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_library_rounded,
                        color: Colors.blueAccent, size: 28),
                    const SizedBox(width: 15),
                    Text("Import from Gallery",
                        style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            if (_images.isNotEmpty) ...[
              Center(
                child: Text("${_images.length} image(s) selected",
                    style: TextStyle(color: subTextColor)),
              ),
              const SizedBox(height: 12),
              Container(
                height: 184,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _images.length + 1,
                  itemBuilder: (context, i) {
                    if (i == _images.length) return _buildAddMoreBox();
                    return _buildSlidableImageCard(i);
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  
                  // --- UPDATED SCAN BUTTON ---
                  ElevatedButton.icon(
                    onPressed: _scanText,
                    icon: const Icon(Icons.document_scanner),
                    label: const Text("Scan", style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryButtonBg, // Matches "Capture Document"
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _images = []),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("Clear"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}