package no.nordicsemi.android.mcumgr_flutter

import no.nordicsemi.android.mcumgr.McuMgrCallback
import no.nordicsemi.android.mcumgr.McuMgrScheme
import no.nordicsemi.android.mcumgr.McuMgrTransport
import no.nordicsemi.android.mcumgr.exception.McuMgrException
import no.nordicsemi.android.mcumgr.response.McuMgrResponse
import no.nordicsemi.android.mcumgr_flutter.logging.LoggableMcuMgrBleTransport

class SmpTransportDecorator(
    private val wrapped: LoggableMcuMgrBleTransport,
) : McuMgrTransport {

    private var suffix: ByteArray? = null
    private var opOverride: Byte? = null
    private var flagsOverride: Byte? = null

    fun configure(suffix: ByteArray?, opOverride: Byte?, flagsOverride: Byte?) {
        this.suffix = suffix
        this.opOverride = opOverride
        this.flagsOverride = flagsOverride
    }

    override fun getScheme(): McuMgrScheme = wrapped.scheme

    override fun <T : McuMgrResponse> send(
        data: ByteArray,
        timeout: Long,
        responseType: Class<T>,
        callback: McuMgrCallback<T>,
    ) = wrapped.send(decorate(data), timeout, responseType, callback)

    @Throws(McuMgrException::class)
    override fun <T : McuMgrResponse> send(
        data: ByteArray,
        timeout: Long,
        responseType: Class<T>,
    ): T = wrapped.send(decorate(data), timeout, responseType)

    override fun connect(callback: McuMgrTransport.ConnectionCallback?) =
        wrapped.connect(callback)

    override fun changeMode(
        mode: String,
        callback: McuMgrTransport.ModeChangeCallback?,
    ): Boolean = wrapped.changeMode(mode, callback)

    override fun release() = wrapped.release()

    override fun addObserver(observer: McuMgrTransport.ConnectionObserver) =
        wrapped.addObserver(observer)

    override fun removeObserver(observer: McuMgrTransport.ConnectionObserver) =
        wrapped.removeObserver(observer)

    private fun decorate(data: ByteArray): ByteArray {
        val sfx = suffix
        if (sfx == null && opOverride == null && flagsOverride == null) return data

        val result = if (sfx != null) {
            val r = ByteArray(data.size + sfx.size)
            System.arraycopy(data, 0, r, 0, data.size)
            System.arraycopy(sfx, 0, r, data.size, sfx.size)
            r
        } else {
            data.copyOf()
        }

        opOverride?.let { result[0] = it }
        flagsOverride?.let { result[1] = it }

        if (sfx != null && sfx.isNotEmpty() && data.size >= 4) {
            val originalLen = ((data[2].toInt() and 0xFF) shl 8) or (data[3].toInt() and 0xFF)
            val newLen = originalLen + sfx.size
            result[2] = ((newLen shr 8) and 0xFF).toByte()
            result[3] = (newLen and 0xFF).toByte()
        }

        return result
    }
}
