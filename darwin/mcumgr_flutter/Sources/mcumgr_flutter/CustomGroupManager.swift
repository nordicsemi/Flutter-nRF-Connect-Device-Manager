#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif
import Foundation
import SwiftCBOR
import iOSMcuManagerLibrary

/// `McuMgrGroup`/`McuManager`'s designated initializer only accepts one of
/// the library's predefined groups, but a custom command needs an arbitrary
/// (including vendor-specific) group ID. This is a throwaway `RawRepresentable`
/// wrapper so `McuManager.buildPacket` can be called with a `commandId` that
/// isn't known ahead of time either.
private struct RawCommandId: RawRepresentable {
    let rawValue: UInt8
    init(rawValue: UInt8) { self.rawValue = rawValue }
}

enum CustomGroupManagerError: LocalizedError {
    case invalidOperation(Int64)

    var errorDescription: String? {
        switch self {
        case .invalidOperation(let op):
            return "Invalid SMP operation code: \(op)"
        }
    }
}

/// Sends a single generic SMP command to an arbitrary group, bypassing
/// `McuManager`'s fixed `McuMgrGroup` enum. Mirrors the Android
/// `CustomGroupManager`.
enum CustomGroupManager {
    static func sendCommand(
        transport: McuMgrTransport,
        groupId: Int64,
        commandId: Int64,
        op: Int64,
        payload: [String?: Any?],
        callback: @escaping McuMgrCallback<McuMgrResponse>
    ) {
        guard let operation = McuMgrOperation(rawValue: UInt8(truncatingIfNeeded: op)) else {
            callback(nil, CustomGroupManagerError.invalidOperation(op))
            return
        }

        let packet = McuManager.buildPacket(
            scheme: transport.getScheme(),
            version: .SMPv2,
            op: operation,
            flags: 0,
            group: UInt16(truncatingIfNeeded: groupId),
            sequenceNumber: UInt8.random(in: UInt8.min...UInt8.max),
            commandId: RawCommandId(rawValue: UInt8(truncatingIfNeeded: commandId)),
            payload: cborMap(from: payload)
        )
        transport.send(data: packet, timeout: McuManager.DEFAULT_SEND_TIMEOUT_SECONDS, autoRetry: false, callback: callback)
    }
}

// MARK: - CBOR bridging

/// Converts a Pigeon-decoded, string-keyed `Any?` map into `[String: CBOR]`
/// as required by `McuManager.buildPacket`. Mirrors the Kotlin side, where
/// the underlying library CBOR-encodes a generic `Map<String, Any>` itself.
private func cborMap(from payload: [String?: Any?]) -> [String: CBOR] {
    var result: [String: CBOR] = [:]
    for (key, value) in payload {
        guard let key else { continue }
        result[key] = cborValue(from: value)
    }
    return result
}

private func cborValue(from value: Any?) -> CBOR {
    switch value {
    case nil:
        return .null
    case let v as Bool:
        return v.toCBOR()
    case let v as Int64:
        return v.toCBOR()
    case let v as Int:
        return v.toCBOR()
    case let v as Double:
        return v.toCBOR()
    case let v as String:
        return v.toCBOR()
    case let v as FlutterStandardTypedData:
        return .byteString([UInt8](v.data))
    case let v as Data:
        return .byteString([UInt8](v))
    case let v as [Any?]:
        return .array(v.map(cborValue(from:)))
    case let v as [String?: Any?]:
        return .map(cborMap(from: v).reduce(into: [CBOR: CBOR]()) { acc, entry in
            acc[.utf8String(entry.key)] = entry.value
        })
    default:
        return .null
    }
}
