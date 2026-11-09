import 'package:flutter_test/flutter_test.dart';
import 'package:wa_share/wa_share.dart';
import 'package:wa_share/wa_share_platform_interface.dart';
import 'package:wa_share/wa_share_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockWaSharePlatform
    with MockPlatformInterfaceMixin
    implements WaSharePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final WaSharePlatform initialPlatform = WaSharePlatform.instance;

  test('$MethodChannelWaShare is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWaShare>());
  });

  test('getPlatformVersion', () async {
    WaShare waSharePlugin = WaShare();
    MockWaSharePlatform fakePlatform = MockWaSharePlatform();
    WaSharePlatform.instance = fakePlatform;

    expect(await waSharePlugin.getPlatformVersion(), '42');
  });
}
