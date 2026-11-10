import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:wa_share/wa_share.dart';
import 'package:wa_share/wa_share_method_channel.dart';

class FakePlatform with MockPlatformInterfaceMixin implements WaSharePlatform {
  List<String> installed = [];
  Map<String, Object?>? lastShare;
  String shareResponse = 'launched';

  @override
  Future<List<String>> installedPackages() async => installed;

  @override
  Future<String> shareImage({
    required String path,
    required String mimeType,
    String? caption,
    String? package,
  }) async {
    lastShare = {'path': path, 'mimeType': mimeType, 'caption': caption, 'package': package};
    return shareResponse;
  }
}

void main() {
  late FakePlatform fake;
  const share = WaShare();

  setUp(() => WaSharePlatform.instance = fake = FakePlatform());

  test('default platform is the method channel', () {
    WaSharePlatform.instance = MethodChannelWaShare();
    expect(WaSharePlatform.instance, isA<MethodChannelWaShare>());
  });

  group('installedApps', () {
    test('none', () async => expect(await share.installedApps(), isEmpty));

    test('both, in stable order, ignoring unknown packages', () async {
      fake.installed = ['com.whatsapp.w4b', 'com.example.other', 'com.whatsapp'];
      expect(await share.installedApps(), [WhatsAppApp.whatsapp, WhatsAppApp.business]);
    });
  });

  group('shareImage', () {
    test('targets the WhatsApp package with caption', () async {
      final r = await share.shareImage('/c/poster.png', target: WhatsAppApp.business, caption: 'Happy Diwali');
      expect(r, ShareResult.launched);
      expect(fake.lastShare, {
        'path': '/c/poster.png',
        'mimeType': 'image/png',
        'caption': 'Happy Diwali',
        'package': 'com.whatsapp.w4b',
      });
    });

    test('no target means the system share sheet', () async {
      await share.shareImage('/c/poster.jpg');
      expect(fake.lastShare!['package'], isNull);
      expect(fake.lastShare!['mimeType'], 'image/jpeg');
    });

    test('reports a missing app', () async {
      fake.shareResponse = 'not_installed';
      expect(await share.shareImage('/c/p.png', target: WhatsAppApp.whatsapp), ShareResult.appNotInstalled);
    });
  });

  test('mimeTypeFor', () {
    expect(mimeTypeFor('a.PNG'), 'image/png');
    expect(mimeTypeFor('a.jpeg'), 'image/jpeg');
    expect(mimeTypeFor('a.webp'), 'image/webp');
    expect(mimeTypeFor('noext'), 'image/png');
  });
}
