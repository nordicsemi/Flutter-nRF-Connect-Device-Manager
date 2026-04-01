import 'dart:typed_data';
import 'smp_client.dart';

/// Comandos Data Store via SMP (Group 0x41 / 65).
///
/// Uso:
/// ```dart
/// final client    = SmpClient(bluetoothDevice);
/// final dataStore = SmpDataStore(client);
///
/// final rawCbor    = await dataStore.groupRead(0);   // partition=0 (Calibration)
/// final schemaCbor = await dataStore.getMetadata(0);
///
/// await client.disconnect();
/// ```
class SmpDataStore {
  final SmpClient _client;

  SmpDataStore(SmpClient client) : _client = client;

  /// GroupRead — retorna o payload CBOR bruto (sem header SMP).
  /// Equivale a: smpmgr data-store read <partition> 0
  Future<Uint8List> groupRead(int partition) async {
    final response = await _client.send(_groupReadFrame(partition));
    return response.length > 8 ? response.sublist(8) : response;
  }

  /// GetMetadata — retorna o payload CBOR bruto com o schema da partição.
  Future<Uint8List> getMetadata(int partition) async {
    final response = await _client.send(_getMetadataFrame(partition));
    return response.length > 8 ? response.sublist(8) : response;
  }

  // ── Frames SMP ──────────────────────────────────────────────────────────

  /// GroupRead: op=READ(0x08), flags=0x80(FT), group=0x41, seq=1, cmd=2
  /// CBOR: {"cell": 0, "partition": N}  FT: [1, 0]
  static Uint8List _groupReadFrame(int partition) => Uint8List.fromList([
    0x08, 0x80, 0x00, 0x1a, 0x00, 0x41, 0x01, 0x02,
    0xa2, 0x64, 0x63, 0x65, 0x6c, 0x6c, 0x00,
    0x69, 0x70, 0x61, 0x72, 0x74, 0x69, 0x74, 0x69, 0x6f, 0x6e, partition,
    0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]);

  /// GetMetadata: op=READ(0x08), flags=0x80(FT), group=0x41, seq=2, cmd=1
  /// CBOR: {"partition": N}  FT: [1, 0]
  static Uint8List _getMetadataFrame(int partition) => Uint8List.fromList([
    0x08, 0x80, 0x00, 0x14, 0x00, 0x41, 0x02, 0x01,
    0xa1, 0x69, 0x70, 0x61, 0x72, 0x74, 0x69, 0x74, 0x69, 0x6f, 0x6e, partition,
    0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]);
}
