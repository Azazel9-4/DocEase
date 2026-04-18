import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '/logic/editor_bloc/editor_bloc.dart';
import '/logic/editor_bloc/editor_event.dart';
import '/logic/editor_bloc/editor_state.dart';

import '/services/pagination_manager.dart';
import '/services/print_view.dart';
import '/services/mobile_view.dart';

import '/screens/editor/save_bottom_sheet.dart';

class TextEditorScreen extends StatefulWidget {
  final String? initialText;
  final String? fileName;
  final bool isDarkMode;

  const TextEditorScreen({super.key, this.initialText, this.fileName, required this.isDarkMode});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late quill.QuillController _quillController;
  late TextEditingController _titleController;
  final PaginationManager _paginationManager = PaginationManager();
  
  // Manage PopScope cleanly
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    _paginationManager.initialize();

    _titleController =
        TextEditingController(text: widget.fileName ?? 'Untitled Document');

    final bloc = context.read<EditorBloc>();

    if (!bloc.state.isJsonProject && widget.initialText != null) {
      final initialText = widget.initialText ?? '';
      bloc.add(ChangeFileName(widget.fileName ?? 'Untitled Document'));
      
      // Assign directly to the bloc's controller
      bloc.controller = quill.QuillController(
        document: quill.Document()
          ..insert(0, initialText.isEmpty ? '\n' : initialText),
        selection: const TextSelection.collapsed(offset: 0),
      );
      bloc.controller.document.history.clear();

      // Ensure the "Unsaved changes" dialog triggers when hitting the back button
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          bloc.add(UpdateDocument(bloc.controller.document));
        }
      });
      
      // Secondary safety net to delete the placeholder if arriving here directly
      _deleteEmptyPlaceholder(); 
    }
    
    // Both UI and Bloc now reference the exact same controller in memory
    _quillController = bloc.controller;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _quillController.document.changes.listen((_) {
          context.read<EditorBloc>().add(UpdateDocument(_quillController.document));
        });
      }
    });
  }

  Future<void> _deleteEmptyPlaceholder() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/DocEase/JSON/${widget.fileName}.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Failed to delete placeholder: $e");
    }
  }

  @override
  void dispose() {
    _quillController.dispose();
    _titleController.dispose();
    _paginationManager.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // SAVE / POP
  // ─────────────────────────────────────────────────────────────

   Future<bool> _onWillPop() async {
    final bloc = context.read<EditorBloc>();

    if (!bloc.state.hasUnsavedChanges) {
      return true; // Let the native stack safely pop back!
    }

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.save_alt_rounded, color: Color(0xFF061F33)),
            SizedBox(width: 8),
            Text('Unsaved changes',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Do you want to save this document before leaving?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.grey.shade600))),
          TextButton(
              onPressed: () => Navigator.pop(context, 'no'),
              child: const Text('No',
                  style: TextStyle(color: Colors.redAccent))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'yes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF061F33),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (result == null || result == 'cancel') return false;
    
    if (result == 'no')  {
      return true; // Let the native stack safely pop back!
    }
    
    if (mounted) _showSaveBottomSheet(popAfterSave: true);
    return false;
  }

  void _showSaveBottomSheet({bool popAfterSave = false}) {
    context.read<EditorBloc>().add(SelectSaveFormat(SaveFormat.json));
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<EditorBloc>(),
        child: SaveBottomSheet(popAfterSave: popAfterSave, isDarkMode: widget.isDarkMode),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color appBarBg = isDark ? const Color(0xFF061F33) : Colors.white;
    final Color iconColor = isDark ? Colors.white : const Color(0xFF061F33);
    final Color textColor = isDark ? Colors.white : const Color(0xFF061F33);
    final Color fieldBg = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);
    final Color hintColor = isDark ? Colors.white38 : Colors.black38;

    return PopScope(
      canPop: _canPop,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          setState(() => _canPop = true); 
          Navigator.pop(context); 
        }
      },
      child: BlocListener<EditorBloc, EditorState>(
        listenWhen: (prev, curr) =>
            prev.currentFileName != curr.currentFileName,
        listener: (context, state) {
          _titleController.text = state.currentFileName;
        },
        child: BlocBuilder<EditorBloc, EditorState>(
          builder: (context, state) {
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0E0F1A) : const Color(0xFFF1F3F4),
              appBar: AppBar(
                backgroundColor: appBarBg,
                elevation: 0,
                centerTitle: false,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: iconColor),
                  onPressed: () async {
                    final shouldPop = await _onWillPop();
                    if (shouldPop && mounted) {
                      setState(() => _canPop = true); 
                      Navigator.pop(context);
                    }
                  },
                ),
                title: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _titleController,
                    style: TextStyle(
                        color: textColor, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Untitled Document',
                      hintStyle: TextStyle(color: hintColor),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) => context
                        .read<EditorBloc>()
                        .add(ChangeFileName(value)),
                  ),
                ),
                actions: [
                  _appBarAction(
                    icon: state.isPrintView
                        ? Icons.smartphone
                        : Icons.print,
                    onPressed: () => context
                        .read<EditorBloc>()
                        .add(const TogglePrintView()),
                  ),
                  _appBarAction(
                    icon: Icons.save,
                    onPressed: () => _showSaveBottomSheet(),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: Column(
                children: [
                  if (state.showToolbar) _buildModernToolbar(state),

                  GestureDetector(
                    onTap: () => context
                        .read<EditorBloc>()
                        .add(const ToggleToolbar()),
                    child: Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 3),
                      child: AnimatedRotation(
                        turns: state.showToolbar ? 0 : 0.5,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_double_arrow_up_rounded,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: state.isHTMLView
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Html(data: state.text),
                            )
                          : state.isPrintView
                              ? PrintView(
                                  key: ValueKey(
                                      'print_${state.pageSize}'),
                                  controller: _quillController,
                                  paginationManager: _paginationManager,
                                  showHeaderFooter: state.showHeaderFooter,
                                  paperSize: state.pageSize,
                                  alignment: state.alignment, 
                                  fontSize: state.fontSize,
                                  fontFamily: state.fontFamily,
                                  headerText: state.headerText,
                                  footerText: state.footerText,
                                  isLocked: state.isHeaderFooterLocked,
                                  backgroundImagePath:
                                      state.backgroundImagePath,
                                  backgroundOpacity:
                                      state.backgroundOpacity,
                                  bodyTopMargin: state.bodyTopMargin,
                                )
                                : MobileView(
                                    key: const ValueKey('mobile'),
                                    controller: _quillController,
                                    fontSize: state.fontSize,       
                                    fontFamily: state.fontFamily,   
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              }

  // ─────────────────────────────────────────────────────────────
  // TOOLBAR
  // ─────────────────────────────────────────────────────────────

  Widget _buildModernToolbar(EditorState state) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
          top: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AnimatedBuilder(
        animation: _quillController,
        builder: (context, _) {
          final style = _quillController.getSelectionStyle();
          final isBold = style.containsKey(quill.Attribute.bold.key);
          final isItalic =
              style.containsKey(quill.Attribute.italic.key);
          final isUnderline =
              style.containsKey(quill.Attribute.underline.key);
          final align =
              style.attributes[quill.Attribute.align.key]?.value;
          final currentFont =
              style.attributes[quill.Attribute.font.key]?.value ??
                  'Arial';
          final currentSize =
              style.attributes[quill.Attribute.size.key]?.value
                      ?.toDouble() ??
                  14.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    _toolbarButton(
                      Icons.undo_rounded,
                      false,
                      _quillController.hasUndo
                          ? () => _quillController.undo()
                          : null,
                      tooltip: 'Undo',
                      disabled: !_quillController.hasUndo,
                    ),
                    _toolbarButton(
                      Icons.redo_rounded,
                      false,
                      _quillController.hasRedo
                          ? () => _quillController.redo()
                          : null,
                      tooltip: 'Redo',
                      disabled: !_quillController.hasRedo,
                    ),
                    _divider(),

                   _toolbarButton(
                    Icons.format_bold,
                    isBold,
                    () {
                      _quillController.formatSelection(isBold
                          ? quill.Attribute.clone(quill.Attribute.bold, null)
                          : quill.Attribute.bold);
                      context.read<EditorBloc>().add(const ToggleBold());
                    },
                    tooltip: 'Bold',
                  ),
                  _toolbarButton(
                    Icons.format_italic,
                    isItalic,
                    () {
                      _quillController.formatSelection(isItalic
                          ? quill.Attribute.clone(quill.Attribute.italic, null)
                          : quill.Attribute.italic);
                      context.read<EditorBloc>().add(const ToggleItalic());
                    },
                    tooltip: 'Italic',
                  ),
                  _toolbarButton(
                    Icons.format_underline,
                    isUnderline,
                    () {
                      _quillController.formatSelection(isUnderline
                          ? quill.Attribute.clone(quill.Attribute.underline, null)
                          : quill.Attribute.underline);
                      context.read<EditorBloc>().add(const ToggleUnderline());
                    },
                    tooltip: 'Underline',
                  ),
                  _divider(),

                  _toolbarButton(
                    Icons.format_align_left,
                    align == null || align == 'left',
                    () {
                      _quillController.formatSelection(quill.Attribute.leftAlignment);
                      context.read<EditorBloc>().add(const ChangeAlignment(TextAlign.left));
                    },
                    tooltip: 'Align left',
                  ),
                  _toolbarButton(
                    Icons.format_align_center,
                    align == 'center',
                    () {
                      _quillController.formatSelection(quill.Attribute.centerAlignment);
                      context.read<EditorBloc>().add(const ChangeAlignment(TextAlign.center));
                    },
                    tooltip: 'Align center',
                  ),
                  _toolbarButton(
                    Icons.format_align_right,
                    align == 'right',
                    () {
                      _quillController.formatSelection(quill.Attribute.rightAlignment);
                      context.read<EditorBloc>().add(const ChangeAlignment(TextAlign.right));
                    },
                    tooltip: 'Align right',
                  ),
                  _toolbarButton(
                    Icons.format_align_justify,
                    align == 'justify',
                    () {
                      _quillController.formatSelection(quill.Attribute.justifyAlignment);
                      context.read<EditorBloc>().add(const ChangeAlignment(TextAlign.justify));
                    },
                    tooltip: 'Justify',
                  ),
                  _divider(),
                  ],
                ),
              ),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 6.0),
                      child: Text('Font:',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                    ...['Arial', 'Times New Roman', 'Calibri', 'Consolas']
                        .map((f) => _textButton(
                              f,
                              currentFont == f,
                              () => _quillController.formatSelection(
                                  quill.Attribute('font',
                                      quill.AttributeScope.inline, f)),
                            )),
                    _divider(),

                    const Padding(
                      padding: EdgeInsets.only(right: 6.0),
                      child: Text('Size:',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                    ...[12, 14, 16, 18, 20, 24, 28].map((s) =>
                        _textButton(
                          s.toString(),
                          currentSize == s.toDouble(),
                          () => _quillController.formatSelection(
                              quill.Attribute(
                                  'size',
                                  quill.AttributeScope.inline,
                                  s.toDouble())),
                        )),
                    _divider(),

                    const Padding(
                      padding: EdgeInsets.only(right: 6.0),
                      child: Text('Page:',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                    _textButton(
                        'A4',
                        state.pageSize == PaperSize.a4,
                        () => context
                            .read<EditorBloc>()
                            .add(ChangePageSize(PaperSize.a4))),
                    _textButton(
                        'Short',
                        state.pageSize == PaperSize.short,
                        () => context
                            .read<EditorBloc>()
                            .add(ChangePageSize(PaperSize.short))),
                    _textButton(
                        'Long',
                        state.pageSize == PaperSize.long,
                        () => context
                            .read<EditorBloc>()
                            .add(ChangePageSize(PaperSize.long))),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOOLBAR HELPERS
  // ─────────────────────────────────────────────────────────────

  Widget _appBarAction({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final isDark = widget.isDarkMode;
    final iconColor = isDark ? Colors.white : const Color(0xFF061F33);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
      ),
    );
  }

  Widget _toolbarButton(
    IconData icon,
    bool active,
    VoidCallback? onPressed, {
    String? tooltip,
    bool disabled = false,
  }) {
    final btn = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active
            ? Colors.blue.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: disabled ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              color: disabled
                  ? Colors.grey.shade300
                  : (active ? Colors.blue.shade800 : Colors.black),
              size: 24,
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip, child: btn);
    return btn;
  }

  Widget _textButton(
    String text,
    bool active,
    VoidCallback? onPressed, {
    bool disabled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active
            ? Colors.blue.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: disabled ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            child: Text(
              text,
              style: TextStyle(
                color: disabled
                    ? Colors.grey.shade400
                    : (active
                        ? Colors.blue.shade800
                        : Colors.black),
                fontWeight:
                    active ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(
        height: 28,
        width: 1.5,
        color: Colors.grey.shade300,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );
}