package com.wrapupai.mobile.livecapture

import java.util.ArrayDeque

class PcmFrameBuffer(
    private val maxFrames: Int = 30,
) {
    private val queue = ArrayDeque<ShortArray>()

    @Synchronized
    fun offer(frame: ShortArray): Int {
        var dropped = 0
        while (queue.size >= maxFrames) {
            queue.removeFirst()
            dropped += 1
        }
        queue.addLast(frame)
        return dropped
    }

    @Synchronized
    fun poll(): ShortArray? {
        return if (queue.isEmpty()) null else queue.removeFirst()
    }

    @Synchronized
    fun size(): Int = queue.size

    @Synchronized
    fun clear() {
        queue.clear()
    }
}
