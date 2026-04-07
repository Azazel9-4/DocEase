import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:thesis_app_v5/screens/editor/editor.dart'; 
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/editor_bloc/editor_bloc.dart';
import '../../logic/editor_bloc/editor_event.dart';

class DocumentsScreen extends StatefulWidget {
  final bool isDarkMode;
  const DocumentsScreen({super.key, required this.isDarkMode});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<File> _files = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  // Changed 'JSON' to 'FILE' for the UI
  final List<String> _filters = ['All', 'FILE', 'DOCX', 'PDF', 'TXT']; 

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final docEaseFolder = Directory('${directory.path}/DocEase');

      if (!await docEaseFolder.exists()) {
        if (mounted) {
          setState(() {
            _files = [];
            _isLoading = false;
          });
        }
        return;
      }

      final List<File> allFiles = [];

      // Scan all subfolders. Note: We check 'JSON' folder here 
      // even though we display 'FILE' in the UI.
      for (final subFolder in ['JSON', 'DOCX', 'PDF', 'TXT']) { 
        final folder = Directory('${docEaseFolder.path}/$subFolder');
        if (await folder.exists()) {
          final entities = folder.listSync();
          for (final entity in entities) {
            if (entity is File) allFiles.add(entity);
          }
        }
      }

      // Sort newest first
      allFiles.sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified));

      if (mounted) {
        setState(() => _files = allFiles);
      }
    } catch (e) {
      debugPrint("Error loading files: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<File> get _filteredFiles {
    if (_selectedFilter == 'All') return _files;
    
    // Map the UI "FILE" filter to the actual ".json" extension
    String extensionToSearch = _selectedFilter.toLowerCase();
    if (extensionToSearch == 'file') {
      extensionToSearch = 'json';
    }
    
    return _files
        .where((f) => f.path.toLowerCase().endsWith('.$extensionToSearch'))
        .toList();
  }

  void _openFile(String path) => OpenFile.open(path);

  Future<void> _deleteFile(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete file"),
        content: Text('Are you sure you want to delete "${file.path.split('/').last}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await file.delete();
      _loadFiles();
    }
  }

  Future<void> _openInEditor(File file) async {
    final content = await file.readAsString();
    final fileName = file.path.split('/').last;
    final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));

    if (!mounted) return;

    final editorBloc = EditorBloc();

    if (file.path.endsWith('.json')) {
      editorBloc.add(LoadJsonProject(
        jsonString: content, 
        sourceFilePath: file.path,
      ));
    } else {
      editorBloc.add(LoadInitialText(
        text: content, 
        fileName: nameWithoutExt,
      ));
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: editorBloc,
          child: TextEditorScreen(
            // Prevent raw JSON from showing in the controller
            initialText: file.path.endsWith('.json') ? "" : content,
            fileName: nameWithoutExt,
            isDarkMode: widget.isDarkMode,
          ),
        ),
      ),
    ).then((_) => _loadFiles());
  }

  IconData _iconFor(String fileName) {
    if (fileName.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (fileName.endsWith('.docx')) return Icons.description_rounded;
    if (fileName.endsWith('.json')) return Icons.edit_document; 
    return Icons.article_rounded;
  }

  Color _colorFor(String fileName) {
    if (fileName.endsWith('.pdf')) return const Color(0xFF993C1D);
    if (fileName.endsWith('.docx')) return const Color(0xFF0F6E56);
    if (fileName.endsWith('.json')) return Colors.deepPurple; 
    return const Color(0xFF185FA5);
  }

  Color _bgFor(String fileName) {
    if (fileName.endsWith('.pdf')) return const Color(0xFFFAECE7);
    if (fileName.endsWith('.docx')) return const Color(0xFFE1F5EE);
    if (fileName.endsWith('.json')) return const Color(0xFFF3E5F5);
    return const Color(0xFFE6F1FB);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color cardBg = isDark ? const Color(0xFF121430) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1A1C2E);
    final Color subTextColor = isDark ? Colors.white54 : const Color(0xFF454754); // Darker grey-blue
    final Color borderColor = isDark ? Colors.white10 : Colors.black12;

    final Color primaryDarkColor = isDark ? Colors.white : const Color(0xFF061F33);


    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF061F33) : cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? Colors.transparent : borderColor),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : textColor,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "${_filteredFiles.length} document${_filteredFiles.length != 1 ? 's' : ''}",
                style: TextStyle(fontSize: 12, color: subTextColor),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFiles.isEmpty
                    ? _buildEmptyState( isDark, textColor, primaryDarkColor)
                    : RefreshIndicator(
                        onRefresh: _loadFiles,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _filteredFiles.length,
                          itemBuilder: (context, index) {
                            final file = _filteredFiles[index];
                            final fileName = file.path.split('/').last;
                            final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
                            
                            // Determine Extension Display Label
                            String extLabel = fileName.substring(fileName.lastIndexOf('.') + 1).toUpperCase();
                            if (extLabel == 'JSON') extLabel = 'FILE';

                            final stats = file.statSync();
                            final dateStr = DateFormat.yMMMd().add_jm().format(stats.modified);
                            final sizeKb = (stats.size / 1024).toStringAsFixed(1);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                                boxShadow: isDark ? [] : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: _bgFor(fileName),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(_iconFor(fileName), color: _colorFor(fileName), size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nameWithoutExt,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _bgFor(fileName),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                extLabel,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: _colorFor(fileName),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$sizeKb KB  ·  $dateStr',
                                              style: TextStyle(fontSize: 11, color: subTextColor),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    // Use the charcoal/dark blue color for the dots icon
                                    icon: Icon(Icons.more_vert, color: textColor.withOpacity(0.7), size: 22),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    color: cardBg, // Menu background follows the theme (white in light mode)
                                    surfaceTintColor: Colors.transparent, // Prevents Material 3 from forcing white text
                                    onSelected: (value) {
                                      if (value == 'open') {
                                        _openFile(file.path);
                                      } else if (value == 'edit') {
                                        _openInEditor(file);
                                      } else if (value == 'delete') {
                                        _deleteFile(file);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      // 1. SHOW "OPEN" ONLY IF IT IS NOT A JSON FILE
                                      if (!fileName.endsWith('.json'))
                                        PopupMenuItem(
                                          value: 'open',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.open_in_new, size: 18, color: Colors.blueAccent),
                                              const SizedBox(width: 10),
                                              Text("Open", style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),
                                      // 2. SHOW "EDIT IN EDITOR" ONLY IF IT IS A JSON FILE
                                      if (fileName.endsWith('.json'))
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                              const SizedBox(width: 10),
                                              Text("Edit in Editor", style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // 3. ALWAYS SHOW "DELETE"
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                            const SizedBox(width: 10),
                                            const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

  Widget _buildEmptyState(bool isDark, Color textColor, Color primaryDarkColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 80, color: isDark ? Colors.grey.withOpacity(0.4): primaryDarkColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text("No documents found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 8),
          Text("Saved documents will appear here.", style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF626471), fontSize: 13)),
          const SizedBox(height: 20),
          TextButton.icon(
          onPressed: _loadFiles,
          style: TextButton.styleFrom(
            foregroundColor: primaryDarkColor, // Dark navy in light mode, white in dark mode
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: primaryDarkColor.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text(
            "Refresh", 
            style: TextStyle(fontWeight: FontWeight.bold)
          ),
        ),
      ],
    ),
  );
}
}
