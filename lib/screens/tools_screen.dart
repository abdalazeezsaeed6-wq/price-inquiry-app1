import 'package:flutter/material.dart';

import 'barcode_screen.dart';
import 'settings_screen.dart';

class ToolsScreen extends StatelessWidget {
  final VoidCallback onChanged;
  const ToolsScreen({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأدوات والإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.qr_code_2, size: 32),
              title: const Text('الباركود والملصقات'),
              subtitle: const Text('إنشاء باركود تلقائي للأصناف التي لا تملكه وطباعة PDF'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodeScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings, size: 32),
              title: const Text('الإعدادات والنسخ الاحتياطي'),
              subtitle: const Text('العملة وتصدير واستعادة قاعدة البيانات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(onSettingsChanged: onChanged))),
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('نسخة أولية عملية: لا تتصل بالإنترنت ولا ترسل بيانات المخزون إلى خادم. احتفظ بنسخ احتياطية دورية خارج الهاتف.'),
            ),
          ),
        ],
      ),
    );
  }
}
