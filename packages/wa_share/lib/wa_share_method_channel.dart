import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'wa_share_platform_interface.dart';

/// An implementation of [WaSharePlatform] that uses method channels.
class MethodChannelWaShare extends WaSharePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('wa_share');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
