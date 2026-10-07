package no.nordicsemi.android.mcumgr_flutter.ext

import no.nordicsemi.android.mcumgr.response.img.McuMgrImageStateResponse
import no.nordicsemi.android.mcumgr_flutter.gen.ProtoImageSlot
import org.junit.Assert.assertEquals
import org.junit.Test

class ImageSlotTest {
    @Test
    fun preservesImageAndSlotThroughProtobuf() {
        for (imageIndex in 0..1) {
            for (slotIndex in 0..1) {
                val source = McuMgrImageStateResponse.ImageSlot().apply {
                    image = imageIndex
                    slot = slotIndex
                    version = "2.3.0"
                    hash = byteArrayOf(1, 2, 3, 4)
                }

                val decoded = ProtoImageSlot.ADAPTER.decode(source.toProto().encode())

                assertEquals(imageIndex.toLong(), decoded.image)
                assertEquals(slotIndex.toLong(), decoded.slot)
            }
        }
    }
}
