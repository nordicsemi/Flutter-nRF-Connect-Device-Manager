import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/no/nordicsemi/android/mcumgr_flutter/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: "no.nordicsemi.android.mcumgr_flutter",
    ),
    swiftOut: 'darwin/mcumgr_flutter/Sources/mcumgr_flutter/messages.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)
/// Generic class that matches all possible events from the native DownloadCallback interface.
sealed class DownloadCallbackEvent {}

class OnDownloadProgressChangedEvent extends DownloadCallbackEvent {
  final int current;
  final int total;
  final int timestamp;
  final String remoteId;
  final String path;
  OnDownloadProgressChangedEvent({
    required this.current,
    required this.total,
    required this.timestamp,
    required this.remoteId,
    required this.path,
  });
}

class OnDownloadFailedEvent extends DownloadCallbackEvent {
  final String? cause;
  final String remoteId;
  final String path;
  OnDownloadFailedEvent({
    required this.cause,
    required this.remoteId,
    required this.path,
  });
}

class OnDownloadCancelledEvent extends DownloadCallbackEvent {
  final String remoteId;

  /// Needed to track the event source coming through a single stream.
  final String path;

  OnDownloadCancelledEvent({required this.remoteId, required this.path});
}

class OnDownloadCompletedEvent extends DownloadCallbackEvent {
  final String remoteId;

  /// Needed to track the event source coming through a single stream.
  final String path;

  /// The raw bytes of the file.
  final Uint8List bytes;

  OnDownloadCompletedEvent(
    this.bytes, {
    required this.remoteId,
    required this.path,
  });
}

class ConnectionStateEvent {
  final String remoteId;
  final bool connected;
  ConnectionStateEvent({required this.remoteId, required this.connected});
}

@EventChannelApi()
abstract class McumgrFlutterEvents {
  DownloadCallbackEvent getFileDownloadEvents();
  ConnectionStateEvent getConnectionStateEvents();
}

// ---------------------------------------------------------------------------
// Custom Group Manager — generic SMP transport decorator + group handler
// ---------------------------------------------------------------------------

@HostApi()
abstract class CustomGroupManagerApi {
  /// Configures the SMP transport decorator for a specific device.
  ///
  /// [suffix] bytes are appended to every outgoing SMP packet.
  /// [opOverride] overrides byte 0 (op) of the SMP header.
  /// [flagsOverride] overrides byte 1 (flags) of the SMP header.
  /// All parameters are optional; omit to leave the field unmodified.
  void setupDecorator(
    String remoteId,
    Uint8List? suffix,
    int? opOverride,
    int? flagsOverride,
  );

  /// Sends a custom SMP command and returns the raw response payload
  /// (the 8-byte SMP header is stripped before returning).
  ///
  /// [groupId]   – SMP group ID (e.g. `0x41` for a vendor-specific group).
  /// [commandId] – command within the group.
  /// [op]        – SMP operation code (`0` = read, `2` = write).
  /// [payload]   – string-keyed map CBOR-encoded as the request payload.
  @async
  Uint8List sendCustomCommand(
    String remoteId,
    int groupId,
    int commandId,
    int op,
    Map<String?, Object?> payload,
  );

  /// Releases all native resources for the given device.
  void kill(String remoteId);
}

// ---------------------------------------------------------------------------

@HostApi()
abstract class FsManagerApi {
  /// Starts the download of a single file with a specific device.
  /// Additional calls to a device that has an ongoing download causes a [PlatformException]
  /// to be thrown.
  void download(String remoteId, String path);

  /// Pause an ongoing download
  void pauseTransfer(String remoteId);

  /// Resume an ongoing download
  void continueTransfer(String remoteId);

  /// Cancel an ongoing download
  void cancelTransfer(String remoteId);

  @async
  int status(String remoteId, String path);

  /// Kill the FsManager instance on the native platform.
  void kill(String remoteId);
}
