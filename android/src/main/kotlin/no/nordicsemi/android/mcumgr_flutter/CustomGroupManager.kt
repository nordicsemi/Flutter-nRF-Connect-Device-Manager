package no.nordicsemi.android.mcumgr_flutter

import no.nordicsemi.android.mcumgr.McuManager
import no.nordicsemi.android.mcumgr.McuMgrCallback
import no.nordicsemi.android.mcumgr.McuMgrTransport
import no.nordicsemi.android.mcumgr.response.McuMgrResponse

class CustomGroupManager(groupId: Int, transport: McuMgrTransport) :
    McuManager(groupId, transport) {

    /**
     * Sends a generic SMP command to this manager's group.
     *
     * @param op        SMP operation byte (e.g. 0 = read, 2 = write).
     * @param commandId Command index within the group.
     * @param payload   String-keyed map that will be CBOR-encoded as the request body.
     * @param callback  Receives the raw [McuMgrResponse] on completion.
     */
    fun sendCommand(
        op: Int,
        commandId: Int,
        payload: Map<String?, Any?>,
        callback: McuMgrCallback<McuMgrResponse>,
    ) {
        val safePayload = HashMap<String, Any>()
        payload.forEach { (k, v) -> if (k != null && v != null) safePayload[k] = v }
        @Suppress("UNCHECKED_CAST")
        send(op, commandId, safePayload, McuMgrResponse::class.java, callback)
    }
}
