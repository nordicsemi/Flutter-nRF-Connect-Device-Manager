import Foundation
import iOSMcuManagerLibrary

/// Wraps a `McuMgrTransport`, allowing per-device overrides of the outgoing
/// SMP packet's op byte, flags byte, and an appended suffix.
///
/// This is the Darwin counterpart of the Android `SmpTransportDecorator`,
/// enabling compatibility with non-standard SMP implementations.
class SmpTransportDecorator: NSObject {
    private let wrapped: McuMgrTransport

    private var suffix: Data?
    private var opOverride: UInt8?
    private var flagsOverride: UInt8?

    init(wrapping transport: McuMgrTransport) {
        self.wrapped = transport
    }

    func configure(suffix: Data?, opOverride: UInt8?, flagsOverride: UInt8?) {
        self.suffix = suffix
        self.opOverride = opOverride
        self.flagsOverride = flagsOverride
    }

    private func decorate(_ data: Data) -> Data {
        guard suffix != nil || opOverride != nil || flagsOverride != nil else {
            return data
        }

        var result = data
        if let suffix, !suffix.isEmpty {
            result.append(suffix)
        }
        if let opOverride, result.count > 0 {
            result[0] = opOverride
        }
        if let flagsOverride, result.count > 1 {
            result[1] = flagsOverride
        }
        if let suffix, !suffix.isEmpty, data.count >= 4 {
            let originalLen = (UInt16(data[2]) << 8) | UInt16(data[3])
            let newLen = originalLen + UInt16(suffix.count)
            result[2] = UInt8((newLen >> 8) & 0xFF)
            result[3] = UInt8(newLen & 0xFF)
        }
        return result
    }
}

// MARK: - McuMgrTransport

extension SmpTransportDecorator: McuMgrTransport {
    var mtu: Int! {
        get { wrapped.mtu }
        set { wrapped.mtu = newValue }
    }

    var mode: McuMgrTransportMode { wrapped.mode }

    func getScheme() -> McuMgrScheme { wrapped.getScheme() }

    func switchMode(to newMode: McuMgrTransportMode, with modeParameter: Any?) throws {
        try wrapped.switchMode(to: newMode, with: modeParameter)
    }

    func send<T: McuMgrResponse>(data: Data, timeout: Int, autoRetry: Bool, callback: @escaping McuMgrCallback<T>) {
        wrapped.send(data: decorate(data), timeout: timeout, autoRetry: autoRetry, callback: callback)
    }

    func connect(_ callback: @escaping ConnectionCallback) {
        wrapped.connect(callback)
    }

    func close() {
        wrapped.close()
    }

    func addObserver(_ observer: ConnectionObserver) {
        wrapped.addObserver(observer)
    }

    func removeObserver(_ observer: ConnectionObserver) {
        wrapped.removeObserver(observer)
    }
}
