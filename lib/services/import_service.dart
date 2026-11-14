import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

class ImportService {
  static Future<List<List<String>>> readRows({
    required String extension,
    required Uint8List bytes,
  }) async {
    final fileExtension = extension.toLowerCase().replaceFirst('.', '');

    if (fileExtension == 'csv') {
      var text = utf8.decode(bytes, allowMalformed: true);

      if (text.startsWith('\uFEFF')) {
        text = text.substring(1);
      }

      final decoded = Csv().decode(text);

      return decoded
          .map(
            (row) => row
                .map((cell) => cell?.toString() ?? '')
                .toList(),
          )
          .where(
            (row) => row.any((cell) => cell.trim().isNotEmpty),
          )
          .toList();
    }

    if (fileExtension == 'xlsx') {
      final book = Excel.decodeBytes(bytes);

      if (book.tables.isEmpty) {
        return [];
      }

      final sheet = book.tables[book.tables.keys.first];

      if (sheet == null) {
        return [];
      }

      return sheet.rows
          .map(
            (row) => row.map(_cellToString).toList(),
          )
          .toList();
    }

    throw FormatException('الصيغة غير مدعومة: $extension');
  }

  static String _cellToString(Data? cell) {
    final value = cell?.value;

    if (value == null) {
      return '';
    }

    if (value is TextCellValue) {
      return value.value.toString();
    }

    if (value is IntCellValue) {
      return value.value.toString();
    }

    if (value is DoubleCellValue) {
      return value.value.toString();
    }

    if (value is BoolCellValue) {
      return value.value.toString();
    }

    if (value is FormulaCellValue) {
      return value.formula.toString();
    }

    if (value is DateCellValue) {
      return value.asDateTimeLocal().toIso8601String();
    }

    if (value is TimeCellValue) {
      return value.asDuration().toString();
    }

    if (value is DateTimeCellValue) {
      return value.asDateTimeLocal().toIso8601String();
    }

    return value.toString();
  }
}
