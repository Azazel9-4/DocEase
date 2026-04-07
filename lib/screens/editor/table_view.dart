// lib/screens/editor/table_view.dart

import 'package:flutter/material.dart';
import '../../logic/editor_bloc/table_controller.dart';

class TableView extends StatefulWidget {
  final TableController controller;
  final bool readOnly;
  final VoidCallback? onChanged; // called after any structural or cell change
  final VoidCallback? onRemove;

  const TableView({
    super.key,
    required this.controller,
    this.readOnly = false,
    this.onChanged,
    this.onRemove,
  });

  @override
  State<TableView> createState() => _TableViewState();
}

class _TableViewState extends State<TableView> {
  bool _showControls = false;

  // Per-cell controllers and focus nodes — rebuilt whenever rows/cols change.
  late List<List<TextEditingController>> _cellCtrl;
  late List<List<FocusNode>> _focusNodes;

  @override
  void initState() {
    super.initState();
    _buildCellControllers();
  }

  // ── Build / rebuild cell controllers ─────────────────────────

  void _buildCellControllers() {
    _cellCtrl = List.generate(
      widget.controller.cells.length,
      (r) => List.generate(
        widget.controller.cells[r].length,
        (c) => TextEditingController(
            text: widget.controller.cells[r][c]),
      ),
    );
    _focusNodes = List.generate(
      widget.controller.cells.length,
      (_) => List.generate(
          widget.controller.cells[0].length, (_) => FocusNode()),
    );
  }

  void _disposeCellControllers() {
    for (final row in _cellCtrl) {
      for (final c in row) c.dispose();
    }
    for (final row in _focusNodes) {
      for (final f in row) f.dispose();
    }
  }

  @override
  void dispose() {
    _disposeCellControllers();
    super.dispose();
  }

  // ── Structural operations ─────────────────────────────────────

  void _addRow() {
    widget.controller.addRow();
    setState(() {
      final cols = widget.controller.cells[0].length;
      _cellCtrl
          .add(List.generate(cols, (_) => TextEditingController()));
      _focusNodes.add(List.generate(cols, (_) => FocusNode()));
    });
    widget.onChanged?.call();
  }

  void _addColumn() {
    widget.controller.addColumn();
    setState(() {
      for (int r = 0; r < _cellCtrl.length; r++) {
        _cellCtrl[r].add(TextEditingController());
        _focusNodes[r].add(FocusNode());
      }
    });
    widget.onChanged?.call();
  }

  void _removeLastRow() {
    if (widget.controller.cells.length <= 1) return;
    final lastRow = _cellCtrl.removeLast();
    final lastFocus = _focusNodes.removeLast();
    for (final c in lastRow) c.dispose();
    for (final f in lastFocus) f.dispose();
    widget.controller.removeRow(widget.controller.cells.length - 1);
    setState(() {});
    widget.onChanged?.call();
  }

  void _removeLastColumn() {
    if (widget.controller.cells[0].length <= 1) return;
    for (int r = 0; r < _cellCtrl.length; r++) {
      _cellCtrl[r].removeLast().dispose();
      _focusNodes[r].removeLast().dispose();
    }
    widget.controller
        .removeColumn(widget.controller.cells[0].length - 1);
    setState(() {});
    widget.onChanged?.call();
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rows = _cellCtrl.length;
    final cols = _cellCtrl[0].length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── MS Word-style floating toolbar ──────────────────────
        if (_showControls && !widget.readOnly)
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tbBtn(Icons.add_box_outlined, 'Add row',
                    _addRow, Colors.blue.shade700),
                _tbBtn(Icons.view_column_outlined, 'Add column',
                    _addColumn, Colors.blue.shade700),
                _tbDivider(),
                _tbBtn(
                  Icons.remove,
                  'Remove last row',
                  rows > 1 ? _removeLastRow : null,
                  rows > 1
                      ? Colors.orange.shade700
                      : Colors.grey.shade300,
                ),
                _tbBtn(
                  Icons.view_column,
                  'Remove last column',
                  cols > 1 ? _removeLastColumn : null,
                  cols > 1
                      ? Colors.orange.shade700
                      : Colors.grey.shade300,
                ),
                _tbDivider(),
                _tbBtn(Icons.delete_outline, 'Delete table',
                    widget.onRemove, Colors.red),
              ],
            ),
          ),

        // ── Table ────────────────────────────────────────────────
        GestureDetector(
          onTap: widget.readOnly
              ? null
              : () =>
                  setState(() => _showControls = !_showControls),
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _showControls
                    ? Colors.blue.shade500
                    : Colors.grey.shade500,
                width: _showControls ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(rows, (r) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: List.generate(cols, (c) {
                      return Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              right: c < cols - 1
                                  ? BorderSide(
                                      color: Colors.grey.shade400)
                                  : BorderSide.none,
                              bottom: r < rows - 1
                                  ? BorderSide(
                                      color: Colors.grey.shade400)
                                  : BorderSide.none,
                            ),
                          ),
                          constraints:
                              const BoxConstraints(minHeight: 32),
                          child: widget.readOnly
                              ? Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    widget.controller.cells[r][c],
                                    style: const TextStyle(
                                        fontSize: 13),
                                  ),
                                )
                              : TextField(
                                  controller: _cellCtrl[r][c],
                                  focusNode: _focusNodes[r][c],
                                  maxLines: null,
                                  minLines: 1,
                                  style: const TextStyle(
                                      fontSize: 13),
                                  decoration:
                                      const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding:
                                        EdgeInsets.all(6),
                                  ),
                                  onChanged: (val) {
                                    widget.controller
                                        .updateCell(r, c, val);
                                    widget.onChanged?.call();
                                  },
                                  // Tab → next cell
                                  onEditingComplete: () {
                                    if (c + 1 < cols) {
                                      _focusNodes[r][c + 1]
                                          .requestFocus();
                                    } else if (r + 1 < rows) {
                                      _focusNodes[r + 1][0]
                                          .requestFocus();
                                    } else {
                                      _focusNodes[r][c].unfocus();
                                    }
                                  },
                                ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tbBtn(IconData icon, String tooltip,
      VoidCallback? onPressed, Color color) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Icon(icon,
              size: 18,
              color: onPressed == null
                  ? Colors.grey.shade300
                  : color),
        ),
      ),
    );
  }

  Widget _tbDivider() => Container(
        width: 1,
        height: 24,
        color: Colors.grey.shade200,
        margin: const EdgeInsets.symmetric(horizontal: 2),
      );
}