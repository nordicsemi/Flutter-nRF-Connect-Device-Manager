import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mcumgr_flutter/proto/flutter_mcu.pb.dart';
import 'package:mcumgr_flutter/src/mcumgr_update_logger.dart';
import 'package:rxdart/rxdart.dart';

import '../mcumgr_flutter.dart';
import '../proto/extensions/proto_ext.dart';
import 'method_channels.dart';

class DeviceUpdateManager extends FirmwareUpdateManager {
  final String _deviceId;
  final McuMgrLogger _logger;

  DeviceUpdateManager._deviceIdentifier(this._deviceId)
      : this._logger = McuMgrLogger.deviceIdentifier(_deviceId);

  // STREAM CONTROLLERS
  // All stream controllers are closed in the `kill()` method.
  // ignore: close_sinks
  final StreamController<ProgressUpdate> _progressStreamController =
      StreamController.broadcast();
  // ignore: close_sinks
  StreamController<FirmwareUpgradeState>? _updateStateStreamController;
  // ignore: close_sinks
  final StreamController<bool>? _updateInProgressStreamController =
      BehaviorSubject.seeded(false);

  // STREAMS
  Stream<ProgressUpdate> get progressStream {
    return _progressStreamController.stream;
  }

  Stream<FirmwareUpgradeState>? get updateStateStream {
    return _updateStateStreamController?.stream;
  }

  Stream<bool>? get updateInProgressStream {
    return _updateInProgressStreamController?.stream;
  }

  void dispose() async {
    await kill();
  }

  // Stream<ProgressUpdate> get

  static Future<DeviceUpdateManager> getInstance(String deviceId) async {
    try {
      await methodChannel.invokeMethod(
          UpdateManagerMethod.initializeUpdateManager.rawValue, deviceId);
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'mcumgr_flutter',
        context: ErrorDescription('getInstance: initialize Update Manager'),
      ));
    }

    final um = DeviceUpdateManager._deviceIdentifier(deviceId);
    um._setupUpdateStateStream();
    um._setupProgressUpdateStream();
    return um;
  }

  @override
  Stream<FirmwareUpgradeState> setup() {
    if (_updateStateStreamController?.isClosed != true) {
      _updateStateStreamController?.close();
    }

    _updateStateStreamController = StreamController.broadcast();
    _setupUpdateStateStream();
    return _updateStateStreamController!.stream;
  }
/*
  Future<void> updateMap(List<Image> images) async {
    return await methodChannel.invokeMethod(
        UpdateManagerMethod.update.rawValue,
        ProtoUpdateWithImageCallArguments(
            deviceUuid: this._deviceId,
            images: images.entries
                .map((e) => Pair(key: e.key, value: e.value))).writeToBuffer());
  }
  */

  @override
  Future<void> update(List<Image> images,
      {FirmwareUpgradeConfiguration configuration =
          const FirmwareUpgradeConfiguration()}) async {
    return await methodChannel.invokeMethod(
        UpdateManagerMethod.update.rawValue,
        ProtoUpdateWithImageCallArguments(
          deviceUuid: _deviceId,
          images: images.map((e) => e.toProto()).toList(),
          configuration: configuration.proto(),
        ).writeToBuffer());
  }

  @override
  Future<void> updateWithImageData({
    required Uint8List imageData,
    Uint8List? hash,
    FirmwareUpgradeConfiguration? configuration,
  }) {
    return methodChannel.invokeMethod(
        UpdateManagerMethod.updateSingleImage.rawValue,
        ProtoUpdateCallArgument(
          deviceUuid: _deviceId,
          firmwareData: imageData,
          hash: hash,
          configuration: configuration?.proto(),
        ).writeToBuffer());
  }

  @override
  Future<void> pause() async {
    await methodChannel.invokeMethod(
        UpdateManagerMethod.pause.rawValue, _deviceId);
    _updateInProgressStreamController!.add(false);
  }

  @override
  Future<void> resume() async {
    await methodChannel.invokeMethod(
        UpdateManagerMethod.resume.rawValue, _deviceId);
    _updateInProgressStreamController!.add(true);
  }

  @override
  Future<void> cancel() async => await methodChannel.invokeMethod(
      UpdateManagerMethod.cancel.rawValue, _deviceId);

  @override
  Future<bool> inProgress() async => await methodChannel.invokeMethod(
      UpdateManagerMethod.isInProgress.rawValue, _deviceId);

  @override
  Future<bool> isPaused() async => await methodChannel.invokeMethod(
      UpdateManagerMethod.isPaused.rawValue, _deviceId);

  static final Stream<dynamic> _sharedProgressStream =
      UpdateManagerChannel.progressStream.receiveBroadcastStream();
  static final Stream<dynamic> _sharedStateStream =
      UpdateManagerChannel.updateStateStream.receiveBroadcastStream();

  void _setupProgressUpdateStream() {
    _sharedProgressStream
        .map((event) => ProtoProgressUpdateStreamArg.fromBuffer(event))
        .where((event) => event.uuid == _deviceId)
        .where((event) => event.hasProgressUpdate())
        .listen((event) {
      if (_progressStreamController.isClosed) return;
      _progressStreamController.add(event.progressUpdate.convert());
    });
  }

  void _setupUpdateStateStream() {
    _sharedStateStream
        .map((event) => ProtoUpdateStateChangesStreamArg.fromBuffer(event))
        .where((event) => event.uuid == _deviceId)
        .listen((data) async {
      // Native side may emit late events after kill() has closed the
      // controllers (e.g. when the user cancels mid-upload or the BLE
      // adapter is turned off). Guard every controller mutation so we
      // don't throw "Cannot add new events after calling close".
      final stateController = _updateStateStreamController;
      if (stateController == null || stateController.isClosed) return;

      if (data.hasError()) {
        stateController.addError(data.error.localizedDescription);
        return;
      }

      if (data.done) {
        await stateController.close();
        return;
      }

      if (!data.hasUpdateStateChanges()) {
        return;
      }

      final stateChanges = data.updateStateChanges;
      if (stateChanges.canceled) {
        await stateController.close();
        return;
      }

      var d = stateChanges.newState.convert();

      stateController.add(d);

      if (d == FirmwareUpgradeState.upload) {
        final inProgressController = _updateInProgressStreamController;
        if (inProgressController != null && !inProgressController.isClosed) {
          inProgressController.add(true);
        }
      }
    });
  }

  @override
  Future<void> kill() async {
    [
      _progressStreamController,
      _updateInProgressStreamController,
      _updateStateStreamController,
    ].forEach((sc) {
      if (!(sc?.isClosed == true)) {
        sc?.close();
      }
    });

    await methodChannel.invokeMethod(
        UpdateManagerMethod.kill.rawValue, _deviceId);
  }

  @override
  FirmwareUpdateLogger get logger => _logger;

  @override
  Future<List<ImageSlot>?> readImageList() async {
    final response = await methodChannel.invokeMethod(
        UpdateManagerMethod.readImageList.rawValue, _deviceId);

    final listImagesResponse = ProtoListImagesResponse.fromBuffer(response);
    if (listImagesResponse.existing) {
      return listImagesResponse.images.map((e) => e.convert()).toList();
    } else {
      return null;
    }
  }

  @override
  Future<void> confirmImage(Uint8List hash) async {
    await methodChannel.invokeMethod(
        UpdateManagerMethod.confirmImage.rawValue,
        <String, dynamic>{
          'deviceId': _deviceId,
          'hash': hash,
        });
  }
  
  @override
  Future<void> erase([int? channel]) async {
    if (channel != null && channel < 0) {
      throw ArgumentError.value(channel, 'channel', 'must not be negative');
    }

    await methodChannel.invokeMethod(UpdateManagerMethod.erase.rawValue, {
      'deviceUuid': _deviceId,
      'channel': channel,
    });
  }
}
