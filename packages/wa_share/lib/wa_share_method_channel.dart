import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'wa_share_platform_interface.dart';

class MethodChannelWaShare extends WaSharePlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('wa_share');

  @override
  Future<List<String>> installedPackages() async {
    final list = await methodChannel.invokeListMethod<String>('installedPackages');
    return list ?? const [];
  }

  @override
  Future<String> shareImage({
    required String path,
    required String mimeType,
    String? caption,
    String? package,
  }) async {
    final result = await methodChannel.invokeMethod<String>('shareImage', {
      'path': path,
      'mimeType': mimeType,
      'caption': caption,
      'package': package,
    });
    return result ?? 'launched';
  }
}
