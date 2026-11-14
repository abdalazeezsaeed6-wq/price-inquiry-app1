import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../database/local_database.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  const SettingsScreen({super.key, required this.onSettingsChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _currency = TextEditingController(text: 'ر.ي');
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final value = await LocalDatabase.instance.getCurrencySymbol();
    if (mounted) setState(() => _currency.text = value);
  }

  Future<void> _saveSettings() async {
    final value = _currency.text.trim();
    if (value.isEmpty) return;
    await LocalDatabase.instance.setCurrencySymbol(value);
    AppConfig.currencySymbol = value;
    widget.onSettingsChanged();
    if (mounted) setState(() => _status = 'تم حفظ العملة.');
  }

  Future<void> _exportBackup() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      final bytes = await LocalDatabase.instance.createBackup();
      final saved = await FilePicker.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية',
        fileName: 'price_inquiry_backup.db',
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _status = saved == null ? 'تم إلغاء حفظ النسخة.' : 'تم إنشاء ملف النسخة الاحتياطية. احتفظ به في مكان آمن.');
    } catch (error) {
      if (mounted) setState(() => _status = 'تعذر إنشاء النسخة: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية'),
        content: const Text('سيتم استبدال قاعدة البيانات الحالية بالنسخة المحددة. يُفضّل تصدير نسخة من بياناتك الحالية أولاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('متابعة')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      if (file == null) {
        if (mounted) setState(() => _status = 'لم يتم اختيار ملف.');
        return;
      }
      final bytes = await file.readAsBytes();
      await LocalDatabase.instance.restoreBackup(bytes);
      AppConfig.currencySymbol = await LocalDatabase.instance.getCurrencySymbol();
      widget.onSettingsChanged();
      if (mounted) setState(() => _status = 'تمت استعادة النسخة الاحتياطية.');
    } catch (error) {
      if (mounted) setState(() => _status = 'تعذرت الاستعادة: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _currency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات والنسخ الاحتياطي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('العملة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(controller: _currency, decoration: const InputDecoration(labelText: 'رمز العملة', hintText: 'مثال: ر.ي')),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _saveSettings, child: const Text('حفظ إعدادات العملة')),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('تصدير نسخة احتياطية'),
            subtitle: const Text('حفظ ملف قاعدة البيانات بصيغة DB'),
            onTap: _busy ? null : _exportBackup,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('استعادة نسخة احتياطية'),
            subtitle: const Text('استبدال بيانات التطبيق بملف DB سابق'),
            onTap: _busy ? null : _restoreBackup,
          ),
          const Divider(height: 32),
          const ListTile(
            leading: Icon(Icons.print_outlined),
            title: Text('الطباعة'),
            subtitle: Text('إصدار PDF وفتح نافذة الطباعة متاح. الربط المباشر بطابعة Bluetooth حرارية يحتاج تحديد موديل الطابعة واختباره قبل إضافته.'),
          ),
          const ListTile(
            leading: Icon(Icons.offline_bolt_outlined),
            title: Text('العمل دون إنترنت'),
            subtitle: Text('البحث والإضافة والتعديل والاستيراد والباركود وقاعدة البيانات تعمل محلياً بعد تثبيت التطبيق.'),
          ),
          if (_busy) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status)),
        ],
      ),
    );
  }
}
