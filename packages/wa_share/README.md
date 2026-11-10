# wa_share

Shares a poster image straight into WhatsApp or WhatsApp Business on Android.

Sending the share request directly to the WhatsApp package opens WhatsApp's own picker, with
**My status** at the top. That makes the flow *Share → My status → Send* and skips the generic
Android share sheet.

```dart
const share = WaShare();
final apps = await share.installedApps();          // [whatsapp, business]
final r = await share.shareImage(path,
    target: WhatsAppApp.whatsapp, caption: 'दीपावली की शुभकामनाएं');
if (r == ShareResult.appNotInstalled) { /* fall back */ }
await share.shareImage(path);                        // system share sheet ("More apps")
```

## How it works
- The image is copied to `<cache>/wa_share/` with a new name for every share, then exposed
  through a `FileProvider` (`${applicationId}.wa_share.fileprovider`) with a temporary read
  permission.
- `<queries>` for `com.whatsapp` and `com.whatsapp.w4b` lets the plugin check which apps are
  installed on Android 11+.
- The plugin doesn't remember which WhatsApp the user prefers. The app stores that choice.

## Testing
- `flutter test` covers the Dart API and the method-channel contract.
- `example/` is a developer-only test app that shares a generated image, for checking on a
  real phone (#13).
- Whether WhatsApp keeps the caption on a Status share is tracked in #11.
