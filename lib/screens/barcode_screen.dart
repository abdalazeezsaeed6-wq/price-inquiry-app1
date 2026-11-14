import 'package:barcode/barcode.dart' as barcode;
import 'package:barcode_widget/barcode_widget.dart' as barcode_ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../app_config.dart';
import '../database/local_database.dart';
import '../models/inventory_item.dart';

class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  List<InventoryItem> _items = [];
  final Set<int> _selected = {};
  int _copies = 1;
  String _format = 'code128';
  bool _loading = true;

  barcode.Barcode _selectedBarcode() {
    switch (_format) {
      case 'ean13':
        return barcode.Barcode.ean13();
      case 'ean8':
        return barcode.Barcode.ean8();
      case 'qr':
        return barcode.Barcode.qrCode();
      default:
        return barcode.Barcode.code128();
    }
  }

  String _ean13ForId(int id) {
    final base = '200${id.toString().padLeft(9, '0')}';
    var sum = 0;
    for (var i = 0; i < base.length; i++) {
      final digit = int.parse(base[i]);
      sum += i.isEven ? digit : digit * 3;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return '$base$checkDigit';
  }

  @override
  void initState() {
    super.initState();
    _loadAndGenerateMissing();
  }

  Future<void> _loadAndGenerateMissing() async {
    final database = LocalDatabase.instance;
    var items = await database.getAllItems();
    for (final item in items) {
      if (item.barcode.trim().isEmpty && item.id != null) {
        final generated = _ean13ForId(item.id!);
        await database.setBarcode(item.id!, generated);
      }
    }
    items = await database.getAllItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _selected.addAll(items.where((item) => item.id != null).map((item) => item.id!));
      _loading = false;
    });
  }

  Future<void> _printLabels() async {
    final chosen = _items.where((item) => item.id != null && _selected.contains(item.id)).toList();
    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدد صنفاً واحداً على الأقل.')));
      return;
    }
    final selectedBarcode = _selectedBarcode();
    final invalid = chosen.where((item) => !selectedBarcode.isValid(item.barcode)).toList();
    if (invalid.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الصيغة المختارة غير صالحة لباركود ${invalid.first.itemCode}. جرّب Code 128 أو اختر صيغة مناسبة.')),
      );
      return;
    }
    final doc = pw.Document();
    final pageFormat = PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);
    for (final item in chosen) {
      for (var copy = 0; copy < _copies; copy++) {
        doc.addPage(pw.Page(
          pageFormat: pageFormat,
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.BarcodeWidget(
                  barcode: selectedBarcode,
                  data: item.barcode,
                  width: _format == 'qr' ? 18 * PdfPageFormat.mm : 44 * PdfPageFormat.mm,
                  height: _format == 'qr' ? 18 * PdfPageFormat.mm : 14 * PdfPageFormat.mm,
                  drawText: false,
                ),
                pw.SizedBox(height: 2 * PdfPageFormat.mm),
                pw.Text(item.itemCode, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('PRICE ${item.sellingPrice.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
        ));
      }
    }
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الباركود والملصقات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('أضف أصنافاً أولاً لإنشاء ملصقاتها.'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Text('النوع'),
                          const SizedBox(width: 6),
                          DropdownButton<String>(
                            value: _format,
                            items: const [
                              DropdownMenuItem(value: 'code128', child: Text('Code 128')),
                              DropdownMenuItem(value: 'ean13', child: Text('EAN-13')),
                              DropdownMenuItem(value: 'ean8', child: Text('EAN-8')),
                              DropdownMenuItem(value: 'qr', child: Text('QR')),
                            ],
                            onChanged: (value) => setState(() => _format = value ?? 'code128'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Expanded(child: Text('عدد النسخ لكل صنف')),
                          DropdownButton<int>(
                            value: _copies,
                            items: List.generate(20, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                            onChanged: (value) => setState(() => _copies = value ?? 1),
                          ),
                          TextButton(onPressed: () => setState(() {
                            if (_selected.length == _items.length) {
                              _selected.clear();
                            } else {
                              _selected.addAll(_items.where((e) => e.id != null).map((e) => e.id!));
                            }
                          }), child: const Text('تحديد الكل')),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final id = item.id!;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            child: CheckboxListTile(
                              value: _selected.contains(id),
                              onChanged: (value) => setState(() => value == true ? _selected.add(id) : _selected.remove(id)),
                              title: Text(item.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('الكود: ${item.itemCode} | ${item.sellingPrice.toStringAsFixed(2)} ${AppConfig.currencySymbol}'),
                                  const SizedBox(height: 8),
                                  barcode_ui.BarcodeWidget(
                                    barcode: _selectedBarcode(),
                                    data: item.barcode,
                                    width: _format == 'qr' ? 110 : 210,
                                    height: _format == 'qr' ? 110 : 58,
                                    drawText: _format != 'qr',
                                    errorBuilder: (context, error) => Text('هذا الباركود لا يناسب الصيغة المختارة'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _printLabels,
                            icon: const Icon(Icons.print),
                            label: Text('إنشاء PDF وطباعة (${_selected.length})'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
