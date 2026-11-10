// Developer smoke test for the plugin only (not product UI): shares a
// generated test image so the WhatsApp share can be checked on a device.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:wa_share/wa_share.dart';

void main() => runApp(const MaterialApp(home: _Smoke()));

class _Smoke extends StatefulWidget {
  const _Smoke();

  @override
  State<_Smoke> createState() => _SmokeState();
}

class _SmokeState extends State<_Smoke> {
  String _log = '';

  Future<String> _testImage() async {
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 540, 960), Paint()..color = Colors.orange);
    final img = await rec.endRecording().toImage(540, 960);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${Directory.systemTemp.path}/wa_share_test.png');
    await file.writeAsBytes(png!.buffer.asUint8List());
    return file.path;
  }

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      final r = await action();
      setState(() => _log = '$r');
    } catch (e) {
      setState(() => _log = 'error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              TextButton(
                onPressed: () => _run(() => const WaShare().installedApps()),
                child: const Text('installed'),
              ),
              for (final app in WhatsAppApp.values)
                TextButton(
                  onPressed: () => _run(() async => const WaShare()
                      .shareImage(await _testImage(), target: app, caption: 'wa_share test')),
                  child: Text('share -> ${app.name}'),
                ),
              TextButton(
                onPressed: () => _run(() async => const WaShare().shareImage(await _testImage())),
                child: const Text('share -> chooser'),
              ),
              Text(_log),
            ],
          ),
        ),
      );
}
