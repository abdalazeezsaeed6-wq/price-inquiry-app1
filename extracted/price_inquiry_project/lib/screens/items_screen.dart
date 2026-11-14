import 'package:flutter/material.dart';

import '../app_config.dart';
import '../database/local_database.dart';
import '../models/inventory_item.dart';
import 'add_edit_item_screen.dart';

class ItemsScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const ItemsScreen({super.key, required this.onChanged});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  List<InventoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await LocalDatabase.instance.getAllItems();
    if (mounted) setState(() => _items = result);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف الصنف ${item.name}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true && item.id != null) {
      await LocalDatabase.instance.deleteItem(item.id!);
      widget.onChanged();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الأصناف (${_items.length})')),
      body: _items.isEmpty
          ? const Center(child: Text('لم تتم إضافة أصناف بعد'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text('شراء: ${item.purchasePrice.toStringAsFixed(2)} | بيع: ${item.sellingPrice.toStringAsFixed(2)} ${AppConfig.currencySymbol}\nالكمية: ${item.quantity} ${item.unit}'),
                    isThreeLine: true,
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => value == 'edit' ? _edit(item) : _delete(item),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
