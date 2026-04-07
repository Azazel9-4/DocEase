// lib/screens/editor/save_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/logic/editor_bloc/editor_bloc.dart';
import '/logic/editor_bloc/editor_event.dart';
import '/logic/editor_bloc/editor_state.dart';

class SaveBottomSheet extends StatelessWidget {
  final bool popAfterSave;
  final bool isDarkMode;
  const SaveBottomSheet({super.key, this.popAfterSave = false, required this.isDarkMode});

  static const _formats = [
    _FormatOption(
      format: SaveFormat.json, // primary save format
      icon: Icons.save_rounded,
      iconColor: Color(0xFF0F6E56), //0xFF0F6E56
      iconBg: Color(0xFFE6F1FB),
      title: "Save progress",
      subtitle: "Keeps images, templates — re-editable",
    ),
    _FormatOption(
      format: SaveFormat.txt,
      icon: Icons.text_snippet_rounded,
      iconColor: Color(0xFF6B6B6B),
      iconBg: Color(0xFFF2F2F2),
      title: "Export plain text (.txt)",
      subtitle: "Text only — images and templates not saved",
    ),
    _FormatOption(
      format: SaveFormat.docx,
      icon: Icons.description_rounded,
      iconColor: Color(0xFF185FA5),
      iconBg: Color(0xFFE1F5EE),
      title: "Export as Word (.docx)",
      subtitle: "Compatible with Microsoft Word",
    ),
    _FormatOption(
      format: SaveFormat.pdf,
      icon: Icons.picture_as_pdf_rounded,
      iconColor: Color(0xFF993C1D),
      iconBg: Color(0xFFFAECE7),
      title: "Export as PDF (.pdf)",
      subtitle: "Print-ready, non-editable",
    ),
  ];

  // ─── IMPROVED CONFLICT DIALOG ──────────────────────────────────────────────
  void _showConflictDialog(BuildContext context, EditorState state) {
    final bool isDark = isDarkMode;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<EditorBloc>(),
        child: AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1C2E) : Colors.white,
        surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "File already exists",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF061F33)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.5),
                  children: [
                    const TextSpan(text: "A file named "),
                    TextSpan(
                      text: '"${state.conflictFileName}"',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                        text:
                            "\nalready exists. Do you want to replace it or keep both files?"),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Responsive box for "Keep Both" file name
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "If you choose Keep Both, it will save as:",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.suggestedFileName ?? 'Unknown file name',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context
                    .read<EditorBloc>()
                    .add(ResolveConflict(replace: false));
              },
              child: const Text(
                "Keep Both",
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context
                    .read<EditorBloc>()
                    .add(ResolveConflict(replace: true));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Replace"),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BOTTOM SHEET UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isDark = isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF121430) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF061F33);
    final Color subTextColor = isDark ? Colors.white54 : Colors.grey.shade500;
    final Color borderColor = isDark ? Colors.white10 : Colors.grey.shade200;
    final Color tileColor = isDark ? const Color(0xFF1A1C2E) : Colors.grey.shade50;
    final Color saveBtnBg = isDark ? Colors.blueAccent : const Color(0xFF061F33);
    final Color iconColor = isDark ? Colors.white : const Color(0xFF061F33);
    final Color boxColor = isDark ? Colors.white.withOpacity(0.1) : const Color(0xFF061F33).withOpacity(0.08);

    


    return Padding(
      // Pushes the bottom sheet up when the keyboard is active
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: BlocConsumer<EditorBloc, EditorState>(
        listenWhen: (prev, curr) => prev.saveStatus != curr.saveStatus,
        listener: (context, state) {
          if (state.saveStatus == SaveStatus.success) {
            Navigator.pop(context); // close bottom sheet
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    "Saved as ${state.currentFileName}.${state.selectedSaveFormat.name}"),
                backgroundColor: Colors.green,
              ),
            );
            // Pop editor screen too if triggered from back button
            if (popAfterSave) Navigator.pop(context);
          } else if (state.saveStatus == SaveStatus.conflict) {
            _showConflictDialog(context, state);
          } else if (state.saveStatus == SaveStatus.error) {
            Navigator.pop(context); // close bottom sheet
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Save failed: ${state.saveError}"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          final isSaving = state.saveStatus == SaveStatus.saving;
          final selected = state.selectedSaveFormat;
          final selectedOpt =
              _formats.firstWhere((f) => f.format == selected);

          return Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            // SafeArea + SingleChildScrollView fixes the RenderFlex Overflow bug when keyboard opens
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: boxColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.save_rounded,
                                color: iconColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Save document",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  state.currentFileName,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: subTextColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Divider(
                        height: 1,
                        thickness: 0.5,
                        color: borderColor),
                    const SizedBox(height: 12),

                    // Format tiles
                    ..._formats.map((opt) {
                      final isSelected = selected == opt.format;
                      return GestureDetector(
                        onTap: isSaving
                            ? null
                            : () => context
                                .read<EditorBloc>()
                                .add(SelectSaveFormat(opt.format)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            // THIS IS THE BACKGROUND COLOR OF THE CONTAINER
                            color: isSelected 
                                ? (isDark ? opt.iconColor.withOpacity(0.15) : opt.iconBg) 
                                : tileColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              // THIS IS THE BORDER COLOR
                              color: isSelected ? opt.iconColor : borderColor,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? opt.iconColor
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(opt.icon,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade500,
                                    size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      opt.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? opt.iconColor
                                            : textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      opt.subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? opt.iconColor.withOpacity(0.65)
                                            : subTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: isSelected
                                    ? Icon(Icons.check_circle_rounded,
                                        color: opt.iconColor,
                                        size: 22,
                                        key: const ValueKey('c'))
                                    : Icon(Icons.radio_button_unchecked,
                                        color: Colors.grey.shade300,
                                        size: 22,
                                        key: const ValueKey('u')),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    // Save button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () => context
                                  .read<EditorBloc>()
                                  .add(RequestSave()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: saveBtnBg,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.save_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      selected == SaveFormat.json
                                          ? "Save progress"
                                          : "Save as .${selectedOpt.format.name}",
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                            color: subTextColor, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FormatOption {
  final SaveFormat format;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _FormatOption({
    required this.format,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });
}