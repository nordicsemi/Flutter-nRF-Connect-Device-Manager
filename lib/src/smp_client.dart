import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Cliente genérico SMP sobre flutter_blue_plus.
/// Conecta, envia um frame SMP e retorna a resposta completa (header + CBOR).
class SmpClient {
  static const String _smpServiceUuid = "8d53dc1d-1db7-4cd3-868b-8a527460aa84";
  static const String _smpCharUuid    = "da2e7828-fbce-4e01-ae9e-261174997c48";
  static const Duration _timeout      = Duration(seconds: 10);

  final BluetoothDevice device;

  SmpClient(this.device);

  /// Envia [frame] e aguarda a resposta SMP completa (com reassembly automático).
  /// Lança [TimeoutException] se não houver resposta dentro de [_timeout].
  Future<Uint8List> send(Uint8List frame) async {
    if (device.isDisconnected) {
      await device.connect(timeout: const Duration(seconds: 15));
    }

    final services = await device.discoverServices();
    final svc = services.firstWhere(
      (s) => s.uuid == Guid(_smpServiceUuid),
      orElse: () => throw StateError('Serviço SMP não encontrado no dispositivo'),
    );
    final char = svc.characteristics.firstWhere(
      (c) => c.uuid == Guid(_smpCharUuid),
      orElse: () => throw StateError('Characteristic SMP não encontrada'),
    );

    await char.setNotifyValue(true);

    final completer = Completer<Uint8List>();
    List<int> buffer = [];
    int expected = 0;

    final sub = char.lastValueStream.listen((value) {
      if (value.isEmpty) return;

      if (buffer.isEmpty) {
        if (value.length < 8) return;
        final payloadLen = (value[2] << 8) | value[3];
        expected = payloadLen + 8;
        buffer.addAll(value);
      } else {
        buffer.addAll(value);
      }

      if (buffer.length >= expected && !completer.isCompleted) {
        completer.complete(Uint8List.fromList(buffer.sublist(0, expected)));
      }
    });

    try {
      await char.write(frame, withoutResponse: true);
      return await completer.future.timeout(_timeout);
    } finally {
      await sub.cancel();
      await char.setNotifyValue(false);
    }
  }

  Future<void> disconnect() => device.disconnect();
}
