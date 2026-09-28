#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif
import CoreBluetooth
import iOSMcuManagerLibrary

class CustomGroupManagerPlugin: NSObject {
    private let centralManagerProvider: () -> CBCentralManager?
    private let connectionStateStreamHandler = ConnectionStateStreamHandler()

    private var transports: [String: McuMgrBleTransport] = [:]
    private var decorators: [String: SmpTransportDecorator] = [:]

    init(
        centralManagerProvider: @escaping () -> CBCentralManager?,
        messenger: FlutterBinaryMessenger
    ) {
        self.centralManagerProvider = centralManagerProvider
        super.init()

        GetConnectionStateEventsStreamHandler.register(with: messenger, streamHandler: connectionStateStreamHandler)
        CustomGroupManagerApiSetup.setUp(binaryMessenger: messenger, api: self)
    }

    private func getOrCreateTransport(_ remoteId: String) throws -> McuMgrBleTransport {
        if let transport = transports[remoteId] {
            return transport
        }
        guard let uuid = UUID(uuidString: remoteId) else {
            throw PigeonError(code: "TODO Code", message: "remoteId not a valid UUID.", details: nil)
        }
        guard let centralManager = centralManagerProvider() else {
            throw PigeonError(code: "TODO Code", message: "CBCentralManager not available", details: nil)
        }
        guard let peripheral = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first else {
            throw PigeonError(code: "TODO Code", message: "Was not able to retrieve peripheral for UUID \(uuid)", details: nil)
        }
        let transport = McuMgrBleTransport(peripheral)
        transport.addObserver(self)
        transports[remoteId] = transport
        return transport
    }

    private func getOrCreateDecorator(_ remoteId: String) throws -> SmpTransportDecorator {
        if let decorator = decorators[remoteId] {
            return decorator
        }
        let decorator = SmpTransportDecorator(wrapping: try getOrCreateTransport(remoteId))
        decorators[remoteId] = decorator
        return decorator
    }
}

// MARK: - CustomGroupManagerApi

extension CustomGroupManagerPlugin: CustomGroupManagerApi {
    /// Configures the SMP transport decorator for a specific device.
    func setupDecorator(remoteId: String, suffix: FlutterStandardTypedData?, opOverride: Int64?, flagsOverride: Int64?) throws {
        try getOrCreateDecorator(remoteId).configure(
            suffix: suffix?.data,
            opOverride: opOverride.map { UInt8(truncatingIfNeeded: $0) },
            flagsOverride: flagsOverride.map { UInt8(truncatingIfNeeded: $0) }
        )
    }

    /// Sends a custom SMP command and returns the raw response payload
    /// (the 8-byte SMP header is stripped before returning).
    func sendCustomCommand(remoteId: String, groupId: Int64, commandId: Int64, op: Int64, payload: [String?: Any?]) async throws -> FlutterStandardTypedData {
        let decorator = try getOrCreateDecorator(remoteId)
        let response: McuMgrResponse = try await withCheckedThrowingContinuation { continuation in
            CustomGroupManager.sendCommand(
                transport: decorator,
                groupId: groupId,
                commandId: commandId,
                op: op,
                payload: payload
            ) { response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let response {
                    continuation.resume(returning: response)
                } else {
                    continuation.resume(throwing: PigeonError(code: "TODO Code", message: "Unexpected error: nil response/error", details: nil))
                }
            }
        }
        return FlutterStandardTypedData(bytes: response.payloadData ?? Data())
    }

    /// Releases all native resources for the given device.
    func kill(remoteId: String) throws {
        decorators.removeValue(forKey: remoteId)
        transports.removeValue(forKey: remoteId)?.close()
    }
}

// MARK: - ConnectionObserver

extension CustomGroupManagerPlugin: ConnectionObserver {
    func transport(_ transport: McuMgrTransport, didChangeStateTo state: McuMgrTransportState) {
        guard let (remoteId, _) = transports.first(where: { $0.value === transport }) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.connectionStateStreamHandler.onEvent(
                ConnectionStateEvent(remoteId: remoteId, connected: state == .connected)
            )
        }
    }
}

// MARK: - ConnectionStateStreamHandler

private class ConnectionStateStreamHandler: GetConnectionStateEventsStreamHandler {
    private var sink: PigeonEventSink<ConnectionStateEvent>? = nil

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<ConnectionStateEvent>) {
        self.sink = sink
    }

    override func onCancel(withArguments arguments: Any?) {
        self.sink = nil
    }

    func onEvent(_ event: ConnectionStateEvent) {
        sink?.success(event)
    }
}
