# nRF Connect Device Manager

nRF Connect Device Manager library is a Flutter plugin (aka "wrapper") around the existing [Android](https://github.com/nordicsemi/Android-nRF-Connect-Device-Manager) and [iOS](https://github.com/nordicsemi/IOS-nRF-Connect-Device-Manager) nRF Connect Device Manager libraries. For more concrete documentation, you may also try reaching out into those for specific details.

![Platforms](https://img.shields.io/badge/Platforms-Android%20|%20iOS%20|%20macOS%20|%20Web-333333.svg)
[![License](https://img.shields.io/github/license/nordicsemi/Flutter-nRF-Connect-Device-Manager)](https://github.com/nordicsemi/Flutter-nRF-Connect-Device-Manager/blob/main/LICENSE)
[![Release](https://img.shields.io/github/release/nordicsemi/Flutter-nRF-Connect-Device-Manager.svg)](https://github.com/nordicsemi/Flutter-nRF-Connect-Device-Manager/releases)
[![GitHub stars](https://img.shields.io/github/stars/nordicsemi/Flutter-nRF-Connect-Device-Manager)](https://github.com/nordicsemi/Flutter-nRF-Connect-Device-Manager/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/nordicsemi/Flutter-nRF-Connect-Device-Manager)](https://github.com/nordicsemi/Flutter-nRF-Connect-Device-Manager/members)
[![GitHub contributors](https://img.shields.io/github/contributors/nordicsemi/Flutter-nRF-Connect-Device-Manager)](https://github.com/nordicsemi/Flutter-nRF-Connect-Device-Manager/graphs/contributors)

---

## Supported Platforms

- Android: `minSdkVersion 21`
- iOS: `13.0`
- macOS: `10.15`
- Web: Chrome 56+ (Web Bluetooth required)

## Getting Started

### Creating a manager

Use `UpdateManagerFactory` to create an instance of `FirmwareUpdateManager`:

```dart
final managerFactory: UpdateManagerFactory = FirmwareUpdateManagerFactory()
// `deviceId` is a String with the device's MAC address (on Android) or UUID (on iOS)
final updateManager = await managerFactory.getUpdateManager(deviceId);
// call `setup` before using the manager
final updateStream = updateManager.setup();
```

### Updating the device

To update the device, call `update` method on the `FirmwareUpdateManager` instance:

```dart
// `firmware` is a List of Image objects
List<Image> firmwareImages = [];
for (final file in manifest.files) {
  final image = Image(
    image: file.image,
    data: firmwareFileData,
  );
  firmwareImages.add(image);
}

final configuration = const FirmwareUpgradeConfiguration(
      estimatedSwapTime: const Duration(seconds: 0),
      byteAlignment: ImageUploadAlignment.fourByte,
      eraseAppSettings: true,
      pipelineDepth: 1,
    );
// `configuration` is an optional parameter. If not provided, default values will be used.
updateManager.update(firmwareImages, configuration: configuration);
```

Alternatively, you can use `updateWithImageData` to update the device with a single image data:

```dart
await updateManager.updateWithImageData(image: fwImage!);
```

> [!TIP]
> `update` and `updateWithImageData` methods are asynchronous, however, they do not return a result of the update process. They only start the update process. To listen for updates, subscribe to the `updateStream` and `progressStream`. See also [Issue #63](https://github.com/nordicsemi/Flutter-nRF-Connect-Device-Manager/issues/63) for more information.

### Listening for updates

To listen for updates, subscribe to the `updateStream` and `progressStream`:

```dart
updateManager.updateStateStream?.listen((event) {
    if (event == FirmwareUpgradeState.success) {
        print("Update Success");
    } else {
        print(event);
    }
});

updateManager.progressStream.listen((event) {
    print("${event.bytesSent} / ${event.imageSize}} bytes sent");
});
```

### Controlling the update

To control the update, use `FirmwareUpdateManager` methods:

```dart
  /// Pause the update process.
  Future<void> pause();

  /// Resume the update process.
  Future<void> resume();

  /// Cancel update.
  Future<void> cancel();

  /// Check if the progress is in process.
  Future<bool> inProgress();

  /// Check if the progress is paused.
  Future<bool> isPaused();
```

### Killing the manager

After the update is finished, call `kill` to kill the manager, otherwise it will lead to memory leaks and other issues:

```dart
updateManager.kill();
```

### Reading image list

To read the current image list (installed firmware slots) from the device:

```dart
List<ImageSlot>? slots = await updateManager.readImageList();
```

### Confirming an image

When using `FirmwareUpgradeMode.testOnly`, the new firmware runs without being confirmed. Use `confirmImage` to permanently mark it as the active image after your own validation:

```dart
final slots = await updateManager.readImageList();
final activeSlot = slots!.firstWhere((s) => s.active && !s.confirmed);
await updateManager.confirmImage(activeSlot.hash);
```

If `confirmImage` is not called before the next reboot, the bootloader will revert to the previous firmware.

## Reading logs

To listen for logs, subscribe to the `logger.logMessageStream`:

```dart
updateManager.logger.logMessageStream
        .where((log) => log.level.rawValue > 1) // filter out debug messages
        .listen((log) {
      print(log.message);
    });
```

To read logs from the device, use `readLog` method:

```dart
List<McuLogMessage> logs =
        await updateManager.logger.readLogs(clearLogs: false);
```

## Web Setup

Web support uses the [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API), which is currently supported in Chrome and Chrome-based browsers. It requires a **secure context** (HTTPS or `localhost`).

### Required: Add script tag to `web/index.html`

Add the following `<script>` tag to your app's `web/index.html` **before** `flutter_bootstrap.js`. This installs an intercept that caches the BLE device obtained during scanning so the firmware update flow can reuse it without prompting the user a second time.

```html
<body>
  <script src="assets/packages/mcumgr_flutter/lib/src/mcumgr_web/mcumgr_setup.js"></script>
  <script src="flutter_bootstrap.js" async></script>
</body>
```

Without this script, the browser will show a second Bluetooth device picker when the firmware update starts.

## Settings Manager

The Settings Manager provides functionality to read and write device configuration settings via the MCU Manager protocol.

### Creating a Settings Manager

```dart
import 'package:mcumgr_flutter/mcumgr_flutter.dart';

final mcumgrSettings = McumgrSettings();
```

### Initializing the Settings Manager

Before using the settings manager, you must initialize it with the device address:

```dart
await mcumgrSettings.init(
  deviceAddress: deviceAddress,  // MAC address (Android) or UUID (iOS)
  encodeValueToCBOR: true,       // Encode values to CBOR format (optional, default: false)
  padTo4Bytes: true,             // Pad values to 4-byte alignment (optional, default: false)
);
```

### Reading Settings

You can read all settings or a specific setting:

```dart
// Read all settings
final allSettings = await mcumgrSettings.readSettings();
print('All settings: $allSettings');

// Read a specific setting
final rawBytes = await mcumgrSettings.readSetting('config/timeout/value');
// The result is returned as Uint8List, which you need to decode based on the expected type
```

### Writing Settings

To write a setting:

```dart
// Write a string value
final result = await mcumgrSettings.writeSetting('device/name', 'MyDevice');

// Write other types of values
await mcumgrSettings.writeSetting('config/interval', 1000);
await mcumgrSettings.writeSetting('feature/enabled', true);
```

#### Authenticated Writes (`pwd`)

Some firmware builds protect a subset of settings behind a configurable
password. To authenticate a write, pass the password via the optional
`password` named parameter — it is added to the SMP payload as the `pwd`
CBOR field:

```dart
// Write to a protected setting, supplying the device password.
await mcumgrSettings.writeSetting(
  'protected/setting/key',
  42,
  password: 'your-device-password',
);
```

If `password` is omitted (or `null`), the payload is identical to the
prior behaviour — no `pwd` field is sent. This makes the parameter fully
backwards compatible: existing code keeps working unchanged, and firmware
that doesn't implement password protection simply ignores the extra
field.

Password injection requires the manager to be initialised with
`useByteStringEncoding: false` (the direct CBOR map payload path). With
the byte-string encoding the underlying platform write API hardcodes the
payload shape and silently ignores the parameter.

### Decoding Setting Values

Settings are returned as raw bytes (`Uint8List`). You need to decode them based on their expected type:

```dart
// Decode as string (removing first byte which is typically a type indicator)
String decodeStringSettings(Uint8List bytes) {
  return String.fromCharCodes(List.from(bytes)..removeAt(0));
}

// Decode as double
double decodeDoubleSetting(Uint8List bytes) {
  if (bytes.length != 8) {
    throw Exception("Expected 8 bytes for double, got ${bytes.length}");
  }
  return ByteData.sublistView(bytes).getFloat64(0, Endian.little);
}

// Decode as boolean
bool decodeBoolSetting(Uint8List bytes) {
  if (bytes.isEmpty) throw Exception("Empty byte array for bool");
  return bytes[0] != 0;
}
```

### Disposing the Settings Manager

When you're done using the settings manager:

```dart
await mcumgrSettings.dispose();
```

### Complete Example

```dart
final mcumgrSettings = McumgrSettings();

try {
  // Initialize
  await mcumgrSettings.init(
    deviceAddress: device.remoteId.str,
    encodeValueToCBOR: true,
    padTo4Bytes: true,
  );

  // Read a setting
  final deviceName = await mcumgrSettings.readSetting('device/name');
  final nameString = String.fromCharCodes(List.from(deviceName)..removeAt(0));
  print('Device name: $nameString');

  // Write a setting
  await mcumgrSettings.writeSetting('device/name', 'NewDeviceName');

} catch (e) {
  print('Error: $e');
} finally {
  await mcumgrSettings.dispose();
}
```
