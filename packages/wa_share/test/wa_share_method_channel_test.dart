import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wa_share/wa_share_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = MethodChannelWaShare();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      platform.methodChannel,
      (call) async {
        calls.add(call);
        return switch (call.method) {
          'installedPackages' => ['com.whatsapp'],
          'shareImage' => 'not_installed',
          _ => null,
        };
      },
    );
  });

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(platform.methodChannel, null));

  test('installedPackages', () async {
    expect(await platform.installedPackages(), ['com.whatsapp']);
    expect(calls.single.method, 'installedPackages');
  });

  test('shareImage sends every argument', () async {
    final r = await platform.shareImage(path: '/p.png', mimeType: 'image/png', caption: 'hi', package: 'com.whatsapp');
    expect(r, 'not_installed');
    expect(calls.single.method, 'shareImage');
    expect(calls.single.arguments, {
      'path': '/p.png',
      'mimeType': 'image/png',
      'caption': 'hi',
      'package': 'com.whatsapp',
    });
  });
}
