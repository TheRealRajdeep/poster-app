
import 'wa_share_platform_interface.dart';

class WaShare {
  Future<String?> getPlatformVersion() {
    return WaSharePlatform.instance.getPlatformVersion();
  }
}
