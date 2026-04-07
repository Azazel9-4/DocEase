import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../logic/editor_bloc/table_controller.dart';
import 'table_view.dart';

import 'package:uuid/uuid.dart';

class TableEmbed {
  const TableEmbed._();
  static const String type = 'table';

  static quill.CustomBlockEmbed buildEmbed({
    required int rows,
    required int cols,
  }) {
    final id = const Uuid().v4();

    final data = jsonEncode({
      'id': id,
      'rows': rows,
      'cols': cols,
      'cells': List.generate(rows, (_) => List.generate(cols, (_) => '')),
    });

    return quill.CustomBlockEmbed(type, data);
  }

  static quill.CustomBlockEmbed fromController(
    TableController controller,
    String id,
  ) {
    final data = jsonEncode({
      'id': id,
      'rows': controller.cells.length,
      'cols': controller.cells[0].length,
      'cells': controller.cells,
    });

    return quill.CustomBlockEmbed(type, data);
  }
}

// Cache controllers by their initial JSON key so rebuilds don't reset state.
// We use a LinkedHashMap so old entries can be pruned if needed.
final _controllerCache = LinkedHashMap<String, TableController>();

class TableEmbedBuilder extends quill.EmbedBuilder {
  const TableEmbedBuilder();

  @override
  String get key => TableEmbed.type;

  @override
  bool get expanded => false; // render inline, not as a block

  @override
  Widget build(
    BuildContext context,
    quill.EmbedContext embedContext,
  ) {
    final node = embedContext.node;
    final quillController = embedContext.controller;
    final readOnly = embedContext.readOnly;

    final raw = node.value.data as String;

    Map<String, dynamic> map;
    try {
      map = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return const SizedBox.shrink();
    }

    final rows = (map['rows'] as int?) ?? 1;
    final cols = (map['cols'] as int?) ?? 1;
    final rawCells = map['cells'] as List<dynamic>?;

    // ── Get or create a cached TableController for this embed ──
    // Key by raw JSON so the same table always gets the same controller.
    final tableId = map['id'] as String?;
    if (tableId == null) return const SizedBox.shrink();

    final tableController = _controllerCache.putIfAbsent(tableId, () {
      final tc = TableController(rows: rows, cols: cols);
      if (rawCells != null) {
        for (int r = 0; r < rawCells.length && r < rows; r++) {
          final rowData = rawCells[r] as List<dynamic>;
          for (int c = 0; c < rowData.length && c < cols; c++) {
            tc.cells[r][c] = rowData[c] as String? ?? '';
          }
        }
      }
      return tc;
    });

    final offset = _findEmbedOffsetById(quillController, tableId);

    void persistChanges() {
      final offset = _findEmbedOffsetById(quillController, tableId);
      if (offset == null) return;

      final updated =
          TableEmbed.fromController(tableController, tableId);

      quillController.replaceText(
        offset,
        1,
        updated,
        TextSelection.collapsed(offset: offset + 1),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TableView(
        // Use a key based on rows/cols so Flutter reuses the widget
        key: ValueKey('table_$tableId'),
        controller: tableController,
        readOnly: readOnly,
        onChanged: persistChanges,
        onRemove: () {
          if (offset == null) return;
          _controllerCache.remove(tableId);
          quillController.replaceText(
            offset,
            1,
            '',
            TextSelection.collapsed(offset: offset),
          );
        },
      ),
    );
  }

int? _findEmbedOffsetById(
  quill.QuillController controller,
  String tableId,
) {
  try {
    int offset = 0;

    for (final op in controller.document.toDelta().toList()) {
      final data = op.data;

      if (data is Map && data[TableEmbed.type] != null) {
        final embedRaw = data[TableEmbed.type];

        if (embedRaw is String) {
          final decoded = jsonDecode(embedRaw);

          if (decoded is Map && decoded['id'] == tableId) {
            return offset;
          }
        }
      }

      if (data is String) {
        offset += data.length;
      } else {
        offset += 1;
      }
    }
  } catch (_) {}

  return null;
}
}