import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mcumgr_flutter/mcumgr_flutter.dart';
import 'package:mcumgr_flutter_example/src/utils/string_ext.dart';
import 'package:mcumgr_flutter_example/src/view/custom_group_manager/hex.dart';

class CustomGroupManagerWidget extends StatefulWidget {
  const CustomGroupManagerWidget({super.key});

  @override
  State<CustomGroupManagerWidget> createState() => _CustomGroupManagerWidgetState();
}

class _LogEntry {
  final String text;
  final bool isError;

  _LogEntry(this.text, {this.isError = false});
}

/// One editable key/value row of the request payload map.
class _ParamRow {
  final TextEditingController key = TextEditingController();
  final TextEditingController value = TextEditingController();

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

class _CustomGroupManagerWidgetState extends State<CustomGroupManagerWidget> {
  final _opController = TextEditingController(text: '02');
  final _groupIdController = TextEditingController(text: '41');
  final _commandIdController = TextEditingController(text: '00');
  final List<_ParamRow> _params = [];

  BluetoothDevice? _selectedDevice;
  CustomGroupManager? _manager;
  StreamSubscription? _connectionSub;
  bool _connected = false;
  bool _sending = false;

  bool _isScanning = false;
  String? _connectingDeviceId;
  List<ScanResult> _scanResults = [];

  final List<_LogEntry> _log = [];
  final _logScrollController = ScrollController();

  @override
  void dispose() {
    _opController.dispose();
    _groupIdController.dispose();
    _commandIdController.dispose();
    for (final param in _params) {
      param.dispose();
    }
    _connectionSub?.cancel();
    _manager?.kill();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            spacing: 16.0,
            children: [
              Container(
                alignment: Alignment.center,
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: _connected ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedDevice != null
                      ? '${_connected ? 'Connected' : 'Selected'}: '
                            '${_selectedDevice!.advName.replaceIfEmpty(_selectedDevice!.remoteId.str)}'
                      : 'No device selected',
                  style: TextStyle(
                    color: _connected ? Colors.green[800] : Colors.red[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_selectedDevice == null)
                ElevatedButton(
                  onPressed: _isScanning ? null : _scanForDevices,
                  child: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
                ),
            ],
          ),
        ),

        if (_scanResults.isNotEmpty && _selectedDevice == null)
          Expanded(
            child: ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                final device = result.device;
                final isThisConnecting = _connectingDeviceId == device.remoteId.str;
                return ListTile(
                  title: Text(device.advName.isNotEmpty ? device.advName : 'Unknown Device'),
                  subtitle: Text(device.remoteId.str),
                  trailing: ElevatedButton(
                    onPressed: _connectingDeviceId != null ? null : () => _selectDevice(device),
                    child: isThisConnecting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Select'),
                  ),
                );
              },
            ),
          ),

        if (_selectedDevice != null)
          Expanded(
            child: Column(
              children: [
                SizedBox(height: 240, child: SingleChildScrollView(child: _buildForm())),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ElevatedButton(
                    onPressed: _sending ? null : _sendCommand,
                    child: _sending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send Command'),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    padding: const EdgeInsets.all(8.0),
                    child: ListView.builder(
                      controller: _logScrollController,
                      itemCount: _log.length,
                      itemBuilder: (context, index) {
                        final entry = _log[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            entry.text,
                            style: TextStyle(
                              color: entry.isError ? Colors.redAccent : Colors.greenAccent,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(child: _hexField(_opController, 'Op', 'hex, e.g. 02')),
              const SizedBox(width: 8),
              Expanded(child: _hexField(_groupIdController, 'Group', 'hex, e.g. 41')),
              const SizedBox(width: 8),
              Expanded(child: _hexField(_commandIdController, 'Command', 'hex, e.g. 00')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Payload parameters', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: _addParam,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        for (final param in _params) _buildParamRow(param),
      ],
    );
  }

  Widget _buildParamRow(_ParamRow param) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: param.key,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Key', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: param.value,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder()),
            ),
          ),
          IconButton(
            onPressed: () => _removeParam(param),
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _hexField(TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
    );
  }

  void _addParam() {
    setState(() {
      _params.add(_ParamRow());
    });
  }

  void _removeParam(_ParamRow param) {
    setState(() {
      _params.remove(param);
    });
    param.dispose();
  }

  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    try {
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results.where((result) => result.device.advName.isNotEmpty).toList();
        });
      });
      await FlutterBluePlus.adapterState.where((val) => val == BluetoothAdapterState.on).first;
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
      await subscription.cancel();
    } catch (e) {
      _addLog('Error scanning for devices: $e', isError: true);
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _selectDevice(BluetoothDevice device) {
    final manager = CustomGroupManager(device.remoteId.str);
    _connectionSub = manager.connectionStates.listen((state) {
      setState(() {
        _connected = state.connected;
      });
    });
    setState(() {
      _selectedDevice = device;
      _manager = manager;
      _connected = false;
    });
  }

  Future<void> _sendCommand() async {
    final manager = _manager;
    if (manager == null) return;

    final int op;
    final int groupId;
    final int commandId;
    try {
      op = parseHexInt(_opController.text);
      groupId = parseHexInt(_groupIdController.text);
      commandId = parseHexInt(_commandIdController.text);
    } catch (e) {
      _addLog('Invalid hex input: $e', isError: true);
      return;
    }

    final payload = <String, String>{};
    for (final param in _params) {
      final key = param.key.text.trim();
      if (key.isEmpty) continue;
      payload[key] = param.value.text;
    }

    setState(() {
      _sending = true;
    });

    try {
      final response = await manager.sendCustomCommand(
        groupId: groupId,
        commandId: commandId,
        op: op,
        payload: payload,
      );
      // The plugin API only returns the response payload, with its 8-byte
      // SMP header already stripped - the request bytes and response
      // header aren't available to display here.
      _addLog('← Response: ${formatHexBytes(response)}');
    } catch (e) {
      _addLog('Error: $e', isError: true);
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  void _addLog(String text, {bool isError = false}) {
    setState(() {
      _log.add(_LogEntry(text, isError: isError));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
