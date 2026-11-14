import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

class ImportService {
  static Future<List<List<String>>> readRows({
    required String extension,
    required Uint8List bytes,
  }) async {
    if (extension.toLowerCase() == 'csv') {
      var text = utf8.decode(bytes, allowMalformed: true);
      if (text.startsWith('\uFEFF')) text = text.substring(1);
      final decoded = Csv().decode(text);
      return decoded
          .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
          .where((row) => row.any((cell) => cell.trim().isNotEmpty))
          .toList();
    }

    if (extension.toLowerCase() == 'xlsx') {
      final book = Excel.decodeBytes(bytes);
      if (book.tables.isEmpty) return [];
      final sheet = book.tables[book.tables.keys.first];
      if (sheet == null) return [];
      return sheet.rows.map((row) => row.map(_cellToString).toList()).toList();
    }

    throw FormatException('الصيغة غير مدعومة: $extension');
  }

  static String _cellToString(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    return switch (value) {
      TextCellValue() => value.value,
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value ? 'true' : 'false',
      FormulaCellValue() => value.formula,
      DateCellValue() => value.asDateTimeLocal().toIso8601String(),
      TimeCellValue() => value.asDuration().toString(),
      DateTimeCellValue() => value.asDateTimeLocal().toIso8601String(),
    };
  }
}
