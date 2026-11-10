import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'wa_share_method_channel.dart';

/// Low-level platform contract. App code uses `WaShare` instead.
abstract class WaSharePlatform extends PlatformInterface {
  WaSharePlatform() : super(token: _token);

  static final Object _token = Object();

  static WaSharePlatform _instance = MethodChannelWaShare();

  static WaSharePlatform get instance => _instance;

  static set instance(WaSharePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Package names of installed WhatsApp apps.
  Future<List<String>> installedPackages();

  /// Returns `launched` or `not_installed`.
  Future<String> shareImage({
    required String path,
    required String mimeType,
    String? caption,
    String? package,
  });
}
