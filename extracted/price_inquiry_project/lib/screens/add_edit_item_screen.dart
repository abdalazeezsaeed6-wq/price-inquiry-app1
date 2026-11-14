import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../database/local_database.dart';
import '../models/inventory_item.dart';

class AddEditItemScreen extends StatefulWidget {
  final InventoryItem? item;
  final bool closeOnSave;
  final VoidCallback? onSaved;

  const AddEditItemScreen({
    super.key,
    this.item,
    this.closeOnSave = true,
    this.onSaved,
  });

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _barcode;
  late final TextEditingController _purchase;
  late final TextEditingController _selling;
  late final TextEditingController _unit;
  late final TextEditingController _quantity;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _code = TextEditingController(text: item?.itemCode ?? '');
    _barcode = TextEditingController(text: item?.barcode ?? '');
    _purchase = TextEditingController(text: item?.purchasePrice.toString() ?? '0');
    _selling = TextEditingController(text: item?.sellingPrice.toString() ?? '0');
    _unit = TextEditingController(text: item?.unit ?? 'حبة');
    _quantity = TextEditingController(text: item?.quantity.toString() ?? '0');
    _notes = TextEditingController(text: item?.notes ?? '');
  }

  String _digits(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
    }
    return result.replaceAll(',', '.').trim();
  }

  double _number(String value) => double.tryParse(_digits(value)) ?? 0;

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'أدخل $label';
    return null;
  }

  String? _priceValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'أدخل السعر';
    if (double.tryParse(_digits(value)) == null || _number(value) < 0) {
      return 'أدخل رقماً صحيحاً';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final old = widget.item;
    final item = InventoryItem(
      id: old?.id,
      name: _name.text.trim(),
      itemCode: _code.text.trim(),
      barcode: _barcode.text.trim(),
      purchasePrice: _number(_purchase.text),
      sellingPrice: _number(_selling.text),
      unit: _unit.text.trim().isEmpty ? 'حبة' : _unit.text.trim(),
      quantity: _number(_quantity.text),
      notes: _notes.text.trim(),
      createdAt: old?.createdAt,
    );
    try {
      await LocalDatabase.instance.saveItem(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(old == null ? 'تم حفظ الصنف' : 'تم تحديث الصنف')),
      );
      widget.onSaved?.call();
      if (widget.closeOnSave) {
        Navigator.of(context).pop(true);
      } else {
        _formKey.currentState!.reset();
        _name.clear();
        _code.clear();
        _barcode.clear();
        _purchase.text = '0';
        _selling.text = '0';
        _unit.text = 'حبة';
        _quantity.text = '0';
        _notes.clear();
      }
    } on DatabaseException catch (error) {
      if (!mounted) return;
      final message = error.toString().contains('item_code')
          ? 'رقم الصنف مستخدم من قبل'
          : 'تعذر الحفظ: تحقق من عدم تكرار الباركود أو رقم الصنف';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحفظ: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _barcode.dispose();
    _purchase.dispose();
    _selling.dispose();
    _unit.dispose();
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'تعديل الصنف' : 'إضافة صنف')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم الصنف', prefixIcon: Icon(Icons.inventory_2_outlined)),
              validator: (v) => _required(v, 'اسم الصنف'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'رقم الصنف / الكود', prefixIcon: Icon(Icons.tag)),
              validator: (v) => _required(v, 'رقم الصنف'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              decoration: const InputDecoration(labelText: 'الباركود (اختياري)', prefixIcon: Icon(Icons.qr_code_2)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purchase,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'سعر شراء الحبة'),
              validator: _priceValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _selling,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'سعر بيع الحبة'),
              validator: _priceValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _unit, decoration: const InputDecoration(labelText: 'الوحدة (حبة / كرتون / كيلو)')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'الكمية المتوفرة'),
              validator: _priceValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات / المورد (اختياري)'),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ البيانات'),
            ),
          ],
        ),
      ),
    );
  }
}
