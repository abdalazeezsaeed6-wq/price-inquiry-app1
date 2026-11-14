import 'package:flutter/material.dart';

import '../app_config.dart';
import '../database/local_database.dart';
import '../models/inventory_item.dart';
import 'add_edit_item_screen.dart';
import 'scanner_screen.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const SearchScreen({super.key, required this.onChanged});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<InventoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await LocalDatabase.instance.searchItems(_controller.text);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code != null && mounted) {
      _controller.text = code;
      await _load();
    }
  }

  Future<void> _edit(InventoryItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddEditItemScreen(item: item)),
    );
    if (changed == true) {
      widget.onChanged();
      await _load();
    }
  }

  Future<void> _delete(InventoryItem item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الصنف'),
        content: Text('هل تريد حذف "${item.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (yes == true && item.id != null) {
      await LocalDatabase.instance.deleteItem(item.id!);
      widget.onChanged();
      await _load();
    }
  }

  void _showDetails(InventoryItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('رقم الصنف: ${item.itemCode}'),
            Text('الباركود: ${item.barcode.isEmpty ? 'غير مسجل' : item.barcode}'),
            Text('سعر الشراء: ${item.purchasePrice.toStringAsFixed(2)} ${AppConfig.currencySymbol}'),
            Text('سعر البيع: ${item.sellingPrice.toStringAsFixed(2)} ${AppConfig.currencySymbol}'),
            Text('الكمية: ${item.quantity} ${item.unit}'),
            if (item.notes.isNotEmpty) Text('ملاحظات: ${item.notes}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استعلام الأصناف والأسعار'),
        actions: [IconButton(tooltip: 'مسح بالكاميرا', onPressed: _scan, icon: const Icon(Icons.qr_code_scanner))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _controller,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم الصنف أو الباركود',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(onPressed: _scan, icon: const Icon(Icons.camera_alt_outlined)),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('لا توجد أصناف مطابقة للبحث'))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            child: ListTile(
                              onTap: () => _showDetails(item),
                              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('الكود: ${item.itemCode}\nالباركود: ${item.barcode.isEmpty ? 'غير مسجل' : item.barcode}'),
                              isThreeLine: true,
                              trailing: SizedBox(
                                width: 112,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${item.sellingPrice.toStringAsFixed(2)} ${AppConfig.currencySymbol}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                    Text('شراء: ${item.purchasePrice.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(visualDensity: VisualDensity.compact, tooltip: 'تعديل', onPressed: () => _edit(item), icon: const Icon(Icons.edit_outlined, size: 19)),
                                        IconButton(visualDensity: VisualDensity.compact, tooltip: 'حذف', onPressed: () => _delete(item), icon: const Icon(Icons.delete_outline, size: 19)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
