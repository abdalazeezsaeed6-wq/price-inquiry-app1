import 'package:flutter/material.dart';
import 'app.dart';
import 'database/local_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.instance.database;
  runApp(const PriceInquiryApp());
}
