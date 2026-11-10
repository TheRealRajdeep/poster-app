/// Share a poster image straight into WhatsApp / WhatsApp Business.
///
/// Targeting the WhatsApp package directly opens WhatsApp's own picker,
/// where "My status" sits at the top: Share -> My status -> Send.
/// Which app to use (when both are installed) is the app's decision to
/// remember; this package only reports and launches.
library;

import 'wa_share_platform_interface.dart';

export 'wa_share_platform_interface.dart' show WaSharePlatform;

enum WhatsAppApp {
  whatsapp('com.whatsapp'),
  business('com.whatsapp.w4b');

  const WhatsAppApp(this.packageName);
  final String packageName;
}

enum ShareResult {
  /// The target app (or the system chooser) was opened.
  launched,

  /// The requested WhatsApp app is not installed; nothing was opened.
  appNotInstalled,
}

class WaShare {
  const WaShare();

  WaSharePlatform get _platform => WaSharePlatform.instance;

  /// Installed WhatsApp apps, in [WhatsAppApp] order.
  Future<List<WhatsAppApp>> installedApps() async {
    final installed = (await _platform.installedPackages()).toSet();
    return [
      for (final app in WhatsAppApp.values)
        if (installed.contains(app.packageName)) app,
    ];
  }

  /// Shares the image at [imagePath] (png, jpg or webp).
  ///
  /// With a [target], opens that WhatsApp app directly. With no target,
  /// opens the Android share sheet (the "More apps" fallback).
  /// [caption] travels as message text; WhatsApp may drop it for Status (#11).
  Future<ShareResult> shareImage(
    String imagePath, {
    WhatsAppApp? target,
    String? caption,
  }) async {
    final result = await _platform.shareImage(
      path: imagePath,
      mimeType: mimeTypeFor(imagePath),
      caption: caption,
      package: target?.packageName,
    );
    return result == 'not_installed' ? ShareResult.appNotInstalled : ShareResult.launched;
  }
}

/// MIME type from the file extension; posters default to PNG.
String mimeTypeFor(String path) {
  final ext = path.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => 'image/png',
  };
}
