package com.wrapupai.mobile.livecapture

object PcmByteConverter {
    fun toLittleEndianBytes(samples: ShortArray): ByteArray {
        val bytes = ByteArray(samples.size * LiveCaptureAudioContract.BYTES_PER_SAMPLE)
        var byteIndex = 0
        for (sample in samples) {
            val value = sample.toInt()
            bytes[byteIndex] = (value and 0xFF).toByte()
            bytes[byteIndex + 1] = ((value shr 8) and 0xFF).toByte()
            byteIndex += LiveCaptureAudioContract.BYTES_PER_SAMPLE
        }
        return bytes
    }
}
