# Add `confirmImage()` for manual firmware confirmation

## Problem

When using `FirmwareUpgradeMode.testOnly`, the device reboots into the new firmware
without confirming it — if the image is not explicitly confirmed before the next reboot,
MCUboot reverts to the previous firmware. This is the safe rollback mechanism.

However, there is currently **no way to confirm an image from Dart**. The native
`ImageManager.confirm()` method exists on both
[Android](https://github.com/NordicSemiconductor/Android-nRF-Connect-Device-Manager) and
[iOS](https://github.com/NordicSemiconductor/IOS-nRF-Connect-Device-Manager), and the
`ImageManager` is already instantiated in both platform `UpdateManager` classes (used by
`readImageList()`), but `confirm()` is simply not bridged to Dart.

This means `testOnly` mode is incomplete — users can upload and test firmware, but cannot
confirm it programmatically. The only workaround is to use `testAndConfirm` which
confirms automatically with no opportunity for custom validation between reset and confirm.

Related: #83 (user unable to activate uploaded firmware)

## Solution

Bridge `ImageManager.confirm(hash)` to Dart as `confirmImage(Uint8List hash)` on
`FirmwareUpdateManager`, following the exact same pattern as the existing
`readImageList()` bridge.

## Usage

```dart
// 1. Update with testOnly — device reboots but firmware is not confirmed
await updateManager.update(images, configuration: FirmwareUpgradeConfiguration(
  firmwareUpgradeMode: FirmwareUpgradeMode.testOnly,
));

// 2. Wait for FirmwareUpgradeState.success (device rebooted with new firmware)

// 3. Perform any custom validation (e.g., BLE health check, version verify)

// 4. Read the image list and confirm when ready
final slots = await updateManager.readImageList();
final activeSlot = slots!.firstWhere((s) => s.active && !s.confirmed);
await updateManager.confirmImage(activeSlot.hash);
// Image is now permanently confirmed — survives reboot
```

If `confirmImage()` is never called, the device safely reverts to the previous
firmware on its next reboot.

## Changed Files

| File | Change |
|------|--------|
| `lib/src/method_channels.dart` | Add `confirmImage` to `UpdateManagerMethod` |
| `lib/src/mcumgr_flutter.dart` | Add `confirmImage(Uint8List hash)` to abstract class |
| `lib/src/mcumgr_update_manager.dart` | Implement `confirmImage()` with method channel call |
| `android/.../utils/FlutterMethod.kt` | Add `confirmImage` enum value |
| `android/.../McumgrFlutterPlugin.kt` | Add handler calling `imageManager.confirm(hash, callback)` |
| `darwin/Classes/Utils/Methods.swift` | Add `confirmImage` enum case |
| `darwin/Classes/SwiftMcumgrFlutterPlugin.swift` | Add handler calling `imageManager.confirm(hash:callback:)` |

## Compatibility

- **Fully backward compatible** — additive only, no existing APIs changed
- **No new native dependencies** — uses existing `ImageManager` already instantiated
- **No protobuf changes** — uses Map argument passing for device ID + hash

## Future Work

The native `ImageManager` also exposes `test(hash)` and `erase()` which could be
bridged in follow-up PRs using the same pattern.
