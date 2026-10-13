import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';

/// Full-screen QR code to show someone. Their phone camera reads it offline.
class QrScreen extends StatelessWidget {
  const QrScreen({super.key, required this.data, required this.title, required this.hint});
  final String data;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: QrImageView(
                    data: data,
                    size: 300,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.L,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.secondaryText, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
