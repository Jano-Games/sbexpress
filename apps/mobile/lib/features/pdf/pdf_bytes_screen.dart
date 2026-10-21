import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../data/share_bytes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';

/// In-app PDF. Share stays available from the same screen.
Future<void> openPdf(BuildContext context, {required String title, required String filename, required List<int> bytes}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PdfBytesScreen(title: title, filename: filename, bytes: bytes),
  ));
}

class PdfBytesScreen extends StatelessWidget {
  const PdfBytesScreen({super.key, required this.title, required this.filename, required this.bytes});

  final String title;
  final String filename;
  final List<int> bytes;

  @override
  Widget build(BuildContext context) {
    final data = Uint8List.fromList(bytes);
    return Scaffold(
      appBar: BackTitle(title: title),
      body: Column(
        children: [
          Expanded(child: _pages(data)),
          Padding(
            padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 16),
            child: AppButton(
              label: 'শেয়ার',
              kind: AppButtonKind.teal,
              onPressed: data.isEmpty
                  ? null
                  : () {
                      shareBytes(bytes: data, filename: filename, mimeType: 'application/pdf');
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pages(Uint8List data) {
    if (data.isEmpty) {
      return const Center(child: Text('এই PDF খালি।', style: TextStyle(color: AppColors.muted)));
    }
    // Widget tests have no PDFium. The release and debug APKs use the viewer.
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      return Center(child: Text('PDF ${data.length} বাইট', style: const TextStyle(color: AppColors.muted)));
    }
    return PdfViewer.data(data, sourceName: filename);
  }
}
