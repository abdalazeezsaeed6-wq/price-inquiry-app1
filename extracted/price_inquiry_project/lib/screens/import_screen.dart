import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../models/inventory_item.dart';
import '../services/import_service.dart';

class ImportScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const ImportScreen({super.key, required this.onChanged});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<List<String>> _rows = [];
  String _fileName = '';
  String _message = '';
  bool _loading = false;
  bool _replaceAll = false;
  final Map<String, int> _mapping = {};

  static const Map<String, String> _fields = {
    'name': 'اسم الصنف',
    'item_code': 'رقم الصنف',
    'barcode': 'الباركود',
    'purchase_price': 'سعر الشراء',
    'selling_price': 'سعر البيع',
    'unit': 'الوحدة',
    'quantity': 'الكمية',
    'notes': 'ملاحظات / المورد',
  };

  String _normalize(String value) => value.toLowerCase().replaceAll(' ', '').replaceAll('_', '').trim();

  int _guessColumn(List<String> headers, List<String> keys) {
    for (var i = 0; i < headers.length; i++) {
      final h = _normalize(headers[i]);
      if (keys.any((key) => h.contains(_normalize(key)))) return i;
    }
    return -1;
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );
      if (file == null) return;
      setState(() {
        _loading = true;
        _message = '';
      });
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final rows = await ImportService.readRows(extension: ext, bytes: bytes);
      if (rows.isEmpty || rows.first.isEmpty) {
        throw const FormatException('الملف لا يحتوي على بيانات قابلة للقراءة.');
      }
      final headers = rows.first;
      final guessed = <String, int>{
        'name': _guessColumn(headers, ['اسم الصنف', 'الصنف', 'name', 'item']),
        'item_code': _guessColumn(headers, ['رقم الصنف', 'كود الصنف', 'الكود', 'item_code', 'code', 'sku']),
        'barcode': _guessColumn(headers, ['الباركود', 'barcode', 'ean']),
        'purchase_price': _guessColumn(headers, ['سعر الشراء', 'شراء', 'purchase', 'buy']),
        'selling_price': _guessColumn(headers, ['سعر البيع', 'بيع', 'selling', 'sale', 'price']),
        'unit': _guessColumn(headers, ['الوحدة', 'unit']),
        'quantity': _guessColumn(headers, ['الكمية', 'quantity', 'qty']),
        'notes': _guessColumn(headers, ['ملاحظات', 'المورد', 'notes', 'supplier']),
      };
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _fileName = file.name;
        _mapping
          ..clear()
          ..addAll(guessed);
        _loading = false;
        _message = 'تمت قراءة الملف. راجع مطابقة الأعمدة قبل الحفظ.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'تعذر قراءة الملف: $error';
      });
    }
  }

  String _cell(List<String> row, String field) {
    final index = _mapping[field] ?? -1;
    if (index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  String _westernDigits(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
    }
    return result.replaceAll(',', '.').trim();
  }

  double _number(String value) => double.tryParse(_westernDigits(value)) ?? double.nan;

  Future<void> _import() async {
    if (_rows.length < 2) return;
    if (['name', 'item_code', 'purchase_price', 'selling_price']
        .any((field) => (_mapping[field] ?? -1) < 0)) {
      setState(() => _message = 'يجب تحديد أعمدة اسم الصنف ورقمه وسعر الشراء وسعر البيع.');
      return;
    }
    setState(() => _loading = true);
    final items = <InventoryItem>[];
    var skipped = 0;
    for (final row in _rows.skip(1)) {
      final name = _cell(row, 'name');
      final code = _cell(row, 'item_code');
      final purchaseText = _cell(row, 'purchase_price');
      final sellingText = _cell(row, 'selling_price');
      final purchase = _number(purchaseText.isEmpty ? '0' : purchaseText);
      final selling = _number(sellingText.isEmpty ? '0' : sellingText);
      if (name.isEmpty || code.isEmpty || purchase.isNaN || selling.isNaN || purchase < 0 || selling < 0) {
        skipped++;
        continue;
      }
      final quantityText = _cell(row, 'quantity');
      final quantity = _number(quantityText.isEmpty ? '0' : quantityText);
      items.add(InventoryItem(
        name: name,
        itemCode: code,
        barcode: _cell(row, 'barcode'),
        purchasePrice: purchase,
        sellingPrice: selling,
        unit: _cell(row, 'unit').isEmpty ? 'حبة' : _cell(row, 'unit'),
        quantity: quantity.isNaN || quantity < 0 ? 0 : quantity,
        notes: _cell(row, 'notes'),
      ));
    }
    try {
      final saved = await LocalDatabase.instance.importItems(items, replaceAll: _replaceAll);
      final notSaved = skipped + (items.length - saved);
      widget.onChanged();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'انتهى الاستيراد: تم حفظ $saved صنف، وتم تجاوز $notSaved صف بسبب نقص أو تكرار في البيانات.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'حدث خطأ أثناء الاستيراد: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final headers = _rows.isEmpty ? <String>[] : _rows.first;
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد Excel وCSV')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _pickFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('اختيار ملف XLSX أو CSV'),
          ),
          if (_fileName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('الملف: $_fileName', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
          if (_loading) const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator())),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('مطابقة الأعمدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('حدد العمود المناسب لكل معلومة. الصف الأول من الملف يعتبر عناوين الأعمدة.'),
            const SizedBox(height: 10),
            ..._fields.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<int>(
                    value: _mapping[entry.key] ?? -1,
                    decoration: InputDecoration(labelText: entry.value),
                    items: [
                      const DropdownMenuItem(value: -1, child: Text('غير محدد')),
                      ...List.generate(headers.length, (index) => DropdownMenuItem(
                            value: index,
                            child: Text('${index + 1}. ${headers[index]}', overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (value) => setState(() => _mapping[entry.key] = value ?? -1),
                  ),
                )),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('استبدال جميع الأصناف الحالية'),
              subtitle: const Text('عند الإيقاف تتم إضافة/تحديث الأصناف حسب رقم الصنف.'),
              value: _replaceAll,
              onChanged: (value) => setState(() => _replaceAll = value),
            ),
            const SizedBox(height: 8),
            const Text('معاينة أول خمسة صفوف', style: TextStyle(fontWeight: FontWeight.bold)),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: headers.map((header) => DataColumn(label: Text(header))).toList(),
                rows: _rows.skip(1).take(5).map((row) => DataRow(
                      cells: List.generate(headers.length, (i) => DataCell(Text(i < row.length ? row[i] : ''))),
                    )).toList(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _import,
              icon: const Icon(Icons.save_alt),
              label: const Text('اعتماد المطابقة وحفظ الأصناف'),
            ),
          ],
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_message, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
