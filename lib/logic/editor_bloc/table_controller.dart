// lib/logic/editor_bloc/table_controller.dart

import 'package:flutter/material.dart';

class TableController extends ChangeNotifier {
  List<List<String>> cells;

  TableController({int rows = 3, int cols = 3})
      : cells = List.generate(rows, (_) => List.generate(cols, (_) => ''));

  void addRow() {
    cells.add(List.generate(cells[0].length, (_) => ''));
    notifyListeners();
  }

  void removeRow(int index) {
    if (cells.length > 1) {
      cells.removeAt(index);
      notifyListeners();
    }
  }

  void addColumn() {
    for (final row in cells) row.add('');
    notifyListeners();
  }

  void removeColumn(int index) {
    if (cells[0].length > 1) {
      for (final row in cells) row.removeAt(index);
      notifyListeners();
    }
  }

  void updateCell(int r, int c, String value) {
    cells[r][c] = value;
    // No notifyListeners() here — TextFields manage their own display.
    // Call it only if you need external widgets to react to cell content.
  }

  @override
  void dispose() {
    super.dispose();
  }
}