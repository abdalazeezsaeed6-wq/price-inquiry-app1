import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسح الباركود')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final codes = capture.barcodes
                  .map((barcode) => barcode.rawValue)
                  .whereType<String>()
                  .where((value) => value.isNotEmpty)
                  .toList();
              final code = codes.isEmpty ? null : codes.first;
              if (code != null && code.isNotEmpty) {
                _handled = true;
                Navigator.of(context).pop(code);
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              color: Colors.black54,
              child: const Text(
                'وجّه كاميرا الهاتف نحو الباركود',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
