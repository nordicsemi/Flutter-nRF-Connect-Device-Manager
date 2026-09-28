package no.nordicsemi.android.mcumgr_flutter

import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.os.Handler
import io.flutter.plugin.common.BinaryMessenger
import no.nordicsemi.android.mcumgr.McuMgrCallback
import no.nordicsemi.android.mcumgr.McuMgrTransport
import no.nordicsemi.android.mcumgr.exception.McuMgrException
import no.nordicsemi.android.mcumgr.response.McuMgrResponse
import no.nordicsemi.android.mcumgr_flutter.logging.LoggableMcuMgrBleTransport
import no.nordicsemi.android.mcumgr_flutter.utils.ConnectionStateStreamHandler
import no.nordicsemi.android.mcumgr_flutter.utils.StreamHandler

class CustomGroupManagerPlugin(
    private val context: Context,
    private val logStreamHandler: StreamHandler,
    binaryMessenger: BinaryMessenger,
    private val mainHandler: Handler,
) : CustomGroupManagerApi {

    private val connectionStateStreamHandler = ConnectionStateStreamHandler()

    private val transports: MutableMap<String, LoggableMcuMgrBleTransport> = mutableMapOf()

    private val decorators: MutableMap<String, SmpTransportDecorator> = mutableMapOf()

    init {
        GetConnectionStateEventsStreamHandler.register(binaryMessenger, connectionStateStreamHandler)
        CustomGroupManagerApi.setUp(binaryMessenger, this)
    }

    override fun setupDecorator(
        remoteId: String,
        suffix: ByteArray?,
        opOverride: Long?,
        flagsOverride: Long?,
    ) {
        getOrCreateDecorator(remoteId).configure(
            suffix = suffix,
            opOverride = opOverride?.toByte(),
            flagsOverride = flagsOverride?.toByte(),
        )
    }

    override fun sendCustomCommand(
        remoteId: String,
        groupId: Long,
        commandId: Long,
        op: Long,
        payload: Map<String?, Any?>,
        callback: (Result<ByteArray>) -> Unit,
    ) {
        val decorator = getOrCreateDecorator(remoteId)
        val manager = CustomGroupManager(groupId.toInt(), decorator)
        manager.sendCommand(
            op = op.toInt(),
            commandId = commandId.toInt(),
            payload = payload,
            callback = object : McuMgrCallback<McuMgrResponse> {
                override fun onResponse(response: McuMgrResponse) {
                    val bytes = response.bytes
                    // Strip the 8-byte SMP header before returning the payload.
                    val payload = if (bytes != null && bytes.size > 8)
                        bytes.drop(8).toByteArray()
                    else
                        bytes ?: ByteArray(0)
                    callback(Result.success(payload))
                }

                override fun onError(error: McuMgrException) {
                    callback(Result.failure(error))
                }
            }
        )
    }

    override fun kill(remoteId: String) {
        decorators.remove(remoteId)
        transports.remove(remoteId)?.release()
    }

    private fun getOrCreateTransport(remoteId: String): LoggableMcuMgrBleTransport {
        synchronized(this) {
            return transports[remoteId] ?: run {
                val device = BluetoothAdapter.getDefaultAdapter().getRemoteDevice(remoteId)
                val transport = LoggableMcuMgrBleTransport(context, device, logStreamHandler)
                    .apply { setLoggingEnabled(true) }
                transport.addObserver(makeConnectionObserver(remoteId))
                transports[remoteId] = transport
                transport
            }
        }
    }

    private fun getOrCreateDecorator(remoteId: String): SmpTransportDecorator {
        synchronized(this) {
            return decorators[remoteId] ?: run {
                val transport = getOrCreateTransport(remoteId)
                val decorator = SmpTransportDecorator(transport)
                decorators[remoteId] = decorator
                decorator
            }
        }
    }

    private fun makeConnectionObserver(remoteId: String) =
        object : McuMgrTransport.ConnectionObserver {
            override fun onConnected() {
                mainHandler.post {
                    connectionStateStreamHandler.onEvent(ConnectionStateEvent(remoteId, true))
                }
            }

            override fun onDisconnected() {
                mainHandler.post {
                    connectionStateStreamHandler.onEvent(ConnectionStateEvent(remoteId, false))
                }
            }
        }
}
