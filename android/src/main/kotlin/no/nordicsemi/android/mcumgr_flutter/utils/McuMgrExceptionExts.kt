package no.nordicsemi.android.mcumgr_flutter.utils

import no.nordicsemi.android.mcumgr.exception.McuMgrException
import no.nordicsemi.android.mcumgr_flutter.FlutterError

fun McuMgrException.toFlutterError(): FlutterError = FlutterError("TODO CODE", this.message)