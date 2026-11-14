import 'package:flutter/material.dart';

import '../app_config.dart';
import '../database/local_database.dart';
import 'add_edit_item_screen.dart';
import 'import_screen.dart';
import 'items_screen.dart';
import 'search_screen.dart';
import 'tools_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    AppConfig.currencySymbol = await LocalDatabase.instance.getCurrencySymbol();
    if (mounted) setState(() => _revision++);
  }

  void _changed() => setState(() => _revision++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      SearchScreen(key: ValueKey('search-$_revision'), onChanged: _changed),
      ItemsScreen(key: ValueKey('items-$_revision'), onChanged: _changed),
      AddEditItemScreen(key: ValueKey('add-$_revision'), closeOnSave: false, onSaved: _changed),
      ImportScreen(key: ValueKey('import-$_revision'), onChanged: _changed),
      ToolsScreen(key: ValueKey('tools-$_revision'), onChanged: _changed),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'البحث'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'الأصناف'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'إضافة'),
          NavigationDestination(icon: Icon(Icons.upload_file), label: 'استيراد'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'المزيد'),
        ],
      ),
    );
  }
}
