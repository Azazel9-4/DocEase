import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:thesis_app_v5/screens/editor/editor.dart'; // adjust path
import 'package:flutter_bloc/flutter_bloc.dart';
import '/logic/editor_bloc/editor_bloc.dart';

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

  final List<String> _filters = ['All', 'TXT', 'DOCX', 'PDF'];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final docEaseFolder = Directory('${directory.path}/DocEase');

      if (!await docEaseFolder.exists()) {
        setState(() {
          _files = [];
          _isLoading = false;
        });
        return;
      }

      final List<File> allFiles = [];

      // Scan all subfolders: TXT, DOCX, PDF
      for (final subFolder in ['TXT', 'DOCX', 'PDF']) {
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

      setState(() => _files = allFiles);
    } catch (e) {
      debugPrint("Error loading files: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<File> get _filteredFiles {
    if (_selectedFilter == 'All') return _files;
    return _files
        .where((f) =>
            f.path.toLowerCase().endsWith('.${_selectedFilter.toLowerCase()}'))
        .toList();
  }

  void _openFile(String path) => OpenFile.open(path);

  Future<void> _deleteFile(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete file"),
        content: Text(
            'Are you sure you want to delete "${file.path.split('/').last}"?'),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BlocProvider(
        create: (_) => EditorBloc(),
        child: TextEditorScreen(
          initialText: content,
          fileName: nameWithoutExt,
        ),
      ),
    ),
  ).then((_) => _loadFiles()); // refresh list when returning
}

  IconData _iconFor(String fileName) {
    if (fileName.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (fileName.endsWith('.docx')) return Icons.description_rounded;
    return Icons.article_rounded;
  }

  Color _colorFor(String fileName) {
    if (fileName.endsWith('.pdf')) return const Color(0xFF993C1D);
    if (fileName.endsWith('.docx')) return const Color(0xFF0F6E56);
    return const Color(0xFF185FA5);
  }

  Color _bgFor(String fileName) {
    if (fileName.endsWith('.pdf')) return const Color(0xFFFAECE7);
    if (fileName.endsWith('.docx')) return const Color(0xFFE1F5EE);
    return const Color(0xFFE6F1FB);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color cardBg = isDark ? const Color(0xFF121430) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1A1C2E);
    final Color subTextColor = isDark ? Colors.white54 : Colors.black45;
    final Color borderColor = isDark ? Colors.white10 : Colors.black12;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF061F33)
                            : cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
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

          // File count
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

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFiles.isEmpty
                    ? _buildEmptyState(isDark)
                    : RefreshIndicator(
                        onRefresh: _loadFiles,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _filteredFiles.length,
                          itemBuilder: (context, index) {
                            final file = _filteredFiles[index];
                            final fileName = file.path.split('/').last;
                            final nameWithoutExt = fileName
                                .substring(0, fileName.lastIndexOf('.'));
                            final ext = fileName
                                .substring(fileName.lastIndexOf('.') + 1)
                                .toUpperCase();
                            final stats = file.statSync();
                            final dateStr = DateFormat.yMMMd()
                                .add_jm()
                                .format(stats.modified);
                            final sizeKb =
                                (stats.size / 1024).toStringAsFixed(1);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                                boxShadow: isDark
                                    ? []
                                    : [
                                        BoxShadow(
                                          color:
                                              Colors.black.withOpacity(0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                              ),
                              child: Row(
                                children: [
                                  // File icon
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: _bgFor(fileName),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(_iconFor(fileName),
                                        color: _colorFor(fileName),
                                        size: 24),
                                  ),
                                  const SizedBox(width: 12),

                                  // Name + meta
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _bgFor(fileName),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                ext,
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
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: subTextColor),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Actions
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: subTextColor, size: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    onSelected: (value) {
                                      if (value == 'open') {
                                        _openFile(file.path);
                                      } else if (value == 'edit') {
                                        _openInEditor(file);  // <-- new
                                      } else if (value == 'delete') {
                                        _deleteFile(file);
                                      }
                                    },
                                   itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'open',
                                        child: Row(
                                          children: [
                                            Icon(Icons.open_in_new, size: 18, color: Colors.blueAccent),
                                            SizedBox(width: 10),
                                            Text("Open"),
                                          ],
                                        ),
                                      ),

                                      // Only show Edit in Editor for .txt files
                                      if (fileName.endsWith('.txt'))
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 18, color: Color(0xFF061F33)),
                                              SizedBox(width: 10),
                                              Text("Edit in Editor"),
                                            ],
                                          ),
                                        ),

                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                            SizedBox(width: 10),
                                            Text("Delete",
                                                style: TextStyle(color: Colors.redAccent)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded,
              size: 80, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text("No documents found",
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text("Saved documents will appear here.",
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _loadFiles,
            icon: const Icon(Icons.refresh),
            label: const Text("Refresh"),
          ),
        ],
      ),
    );
  }
}