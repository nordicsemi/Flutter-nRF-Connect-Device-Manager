import 'dart:typed_data';

/// Parses a hex string as a single integer (accepts an optional `0x`
/// prefix; empty input is treated as 0).
int parseHexInt(String input) {
  var s = input.trim();
  if (s.toLowerCase().startsWith('0x')) s = s.substring(2);
  if (s.isEmpty) return 0;
  return int.parse(s, radix: 16);
}

/// Formats [bytes] as space-separated, upper-case hex byte pairs.
String formatHexBytes(Uint8List bytes) {
  if (bytes.isEmpty) return '(empty)';
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
}
