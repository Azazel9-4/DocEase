import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';

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

  const TextEditorScreen({super.key, this.initialText, this.fileName});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  final PaginationManager _paginationManager = PaginationManager();
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _paginationManager.initialize();
    _titleController = TextEditingController(
        text: widget.fileName ?? "Untitled Document");

    final initialText = widget.initialText ?? "";
    _paginationManager.loadInitialText(initialText);

    context.read<EditorBloc>().add(LoadInitialText(initialText, widget.fileName));

    _paginationManager.addListener(() {
      context.read<EditorBloc>().add(UpdateText(_paginationManager.fullText));
    });
  }

  @override
  void dispose() {
    _paginationManager.dispose();
    _titleController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BACK BUTTON HANDLER
  // ---------------------------------------------------------------------------

  Future<bool> _onWillPop() async {
    if (!context.read<EditorBloc>().state.hasUnsavedChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.save_alt_rounded, color: Color(0xFF061F33)),
            SizedBox(width: 8),
            Text(
              "Unsaved changes",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          "Do you want to save this document before leaving?",
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text("Cancel",
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'no'),
            child: const Text("No",
                style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'yes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF061F33),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (result == null || result == 'cancel') return false;
    if (result == 'no') return true;

    // 'yes' — show save sheet, pop editor after successful save
    if (mounted) _showSaveBottomSheet(popAfterSave: true);
    return false;
  }

  // ---------------------------------------------------------------------------
  // SAVE BOTTOM SHEET
  // ---------------------------------------------------------------------------

  void _showSaveBottomSheet({bool popAfterSave = false}) {
    context.read<EditorBloc>().add(SelectSaveFormat(SaveFormat.txt));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<EditorBloc>(),
        child: SaveBottomSheet(popAfterSave: popAfterSave),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.pop(context);
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
              backgroundColor: const Color(0xFFF1F3F4),
              appBar: AppBar(
                backgroundColor: const Color(0xFF061F33),
                elevation: 0,
                centerTitle: false,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () async {
                    final shouldPop = await _onWillPop();
                    if (shouldPop && mounted) Navigator.pop(context);
                  },
                ),
                title: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _titleController,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: "Untitled Document",
                      hintStyle: TextStyle(color: Colors.white38),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) =>
                        context.read<EditorBloc>().add(ChangeFileName(value)),
                  ),
                ),
                actions: [
                  _appBarAction(
                    icon: state.isPrintView
                        ? Icons.smartphone
                        : Icons.print,
                    onPressed: () =>
                        context.read<EditorBloc>().add(TogglePrintView()),
                  ),
                  _appBarAction(
                    icon: state.showToolbar
                        ? Icons.keyboard_hide
                        : Icons.format_size,
                    onPressed: () =>
                        context.read<EditorBloc>().add(ToggleToolbar()),
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
                                      "print_${state.pageSize}"),
                                  paginationManager: _paginationManager,
                                  paperSize: state.pageSize,
                                  isBold: state.isBold,
                                  isItalic: state.isItalic,
                                  isUnderline: state.isUnderline,
                                  alignment: state.alignment,
                                  fontSize: state.fontSize,
                                  fontFamily: state.fontFamily,
                                )
                              : MobileView(
                                  key: const ValueKey("mobile"),
                                  paginationManager: _paginationManager,
                                  isBold: state.isBold,
                                  isItalic: state.isItalic,
                                  isUnderline: state.isUnderline,
                                  alignment: state.alignment,
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

  // ---------------------------------------------------------------------------
  // UI COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _appBarAction(
      {required IconData icon, required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolbarButton(Icons.format_bold, state.isBold,
                () => context.read<EditorBloc>().add(ToggleBold())),
            _toolbarButton(Icons.format_italic, state.isItalic,
                () => context.read<EditorBloc>().add(ToggleItalic())),
            _toolbarButton(Icons.format_underline, state.isUnderline,
                () => context.read<EditorBloc>().add(ToggleUnderline())),
            _divider(),
            _customDropdown<TextAlign>(
              value: state.alignment,
              items: const [
                DropdownMenuItem(
                    value: TextAlign.left,
                    child: Icon(Icons.format_align_left,
                        color: Colors.black, size: 22)),
                DropdownMenuItem(
                    value: TextAlign.center,
                    child: Icon(Icons.format_align_center,
                        color: Colors.black, size: 22)),
                DropdownMenuItem(
                    value: TextAlign.right,
                    child: Icon(Icons.format_align_right,
                        color: Colors.black, size: 22)),
                DropdownMenuItem(
                    value: TextAlign.justify,
                    child: Icon(Icons.format_align_justify,
                        color: Colors.black, size: 22)),
              ],
              onChanged: (v) =>
                  context.read<EditorBloc>().add(ChangeAlignment(v!)),
            ),
            _divider(),
            _customDropdown<double>(
              value: state.fontSize,
              items: [12, 14, 16, 18, 20, 24, 28]
                  .map((e) => DropdownMenuItem(
                        value: e.toDouble(),
                        child: Text("${e.toInt()}",
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                      ))
                  .toList(),
              onChanged: (v) =>
                  context.read<EditorBloc>().add(ChangeFontSize(v!)),
            ),
            _divider(),
            _customDropdown<String>(
              value: state.fontFamily,
              items: ['Arial', 'Times New Roman', 'Calibri', 'Consolas']
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f,
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
              onChanged: (v) =>
                  context.read<EditorBloc>().add(ChangeFontFamily(v!)),
            ),
            _divider(),
            _customDropdown<PaperSize>(
              value: state.pageSize,
              items: const [
                DropdownMenuItem(
                    value: PaperSize.a4,
                    child: Text("A4",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold))),
                DropdownMenuItem(
                    value: PaperSize.short,
                    child: Text("Short",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold))),
                DropdownMenuItem(
                    value: PaperSize.long,
                    child: Text("Long",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold))),
              ],
              onChanged: (v) =>
                  context.read<EditorBloc>().add(ChangePageSize(v!)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton(IconData icon, bool active, VoidCallback tap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: active ? Colors.blue.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: tap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(icon,
                color: active ? Colors.blue.shade800 : Colors.black,
                size: 24),
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(
        height: 28,
        width: 1.5,
        color: Colors.grey.shade400,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );

  Widget _customDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        icon: const Icon(Icons.arrow_drop_down,
            color: Colors.black, size: 24),
        dropdownColor: Colors.white,
      ),
    );
  }
}