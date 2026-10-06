package com.example.tennisautocut

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

class AutoAnalyzer(private val context: Context) {
    suspend fun analyze(
        uri: Uri,
        durationMs: Long,
        onProgress: (Float) -> Unit
    ): AnalysisResult = withContext(Dispatchers.Default) {
        require(durationMs > 0L) { "영상 길이를 확인할 수 없습니다." }

        val intervalMs = max(750L, ceil(durationMs / 2400.0).toLong())
        val sampleCount = (durationMs / intervalMs).toInt() + 1
        val scores = ArrayList<Double>(sampleCount)

        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(context, uri)
            var previous: Bitmap? = null
            for (index in 0 until sampleCount) {
                val timeMs = min(durationMs - 1L, index * intervalMs).coerceAtLeast(0L)
                val frame = retriever.getScaledFrameAtTime(
                    timeMs * 1000L,
                    MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                    160,
                    90
                )
                if (frame == null) {
                    scores += if (scores.isEmpty()) 0.0 else scores.last()
                } else {
                    scores += if (previous == null) 0.0 else motionScore(previous!!, frame)
                    previous?.recycle()
                    previous = frame
                }
                if (index % 8 == 0 || index == sampleCount - 1) {
                    onProgress((index + 1f) / sampleCount)
                }
            }
            previous?.recycle()
        } finally {
            retriever.release()
        }

        val plan = SegmentPlanner.plan(durationMs, intervalMs, scores)
        val segments = plan.keep.mapIndexed { index, range ->
            Segment(
                id = index.toLong() + 1L,
                startMs = range.first,
                endMs = range.last + 1L,
                included = true,
                origin = SegmentOrigin.AUTO
            )
        }

        AnalysisResult(
            segments = segments,
            sampledFrames = scores.size,
            sampleIntervalMs = intervalMs,
            motionThreshold = plan.threshold,
            note = plan.note
        )
    }

    private fun motionScore(a: Bitmap, b: Bitmap): Double {
        val width = min(a.width, b.width)
        val height = min(a.height, b.height)
        if (width <= 0 || height <= 0) return 0.0

        val yStart = height / 5
        val step = 4
        var total = 0.0
        var count = 0
        var y = yStart
        while (y < height) {
            var x = 0
            while (x < width) {
                val la = luma(a.getPixel(x, y))
                val lb = luma(b.getPixel(x, y))
                total += kotlin.math.abs(la - lb)
                count++
                x += step
            }
            y += step
        }
        return if (count == 0) 0.0 else total / count
    }

    private fun luma(color: Int): Double {
        val r = (color shr 16) and 0xFF
        val g = (color shr 8) and 0xFF
        val b = color and 0xFF
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}
