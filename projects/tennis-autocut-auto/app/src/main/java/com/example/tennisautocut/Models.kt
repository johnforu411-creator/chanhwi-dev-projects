package com.example.tennisautocut

import android.net.Uri

enum class AnalysisPhase {
    EMPTY, READY, ANALYZING, REVIEW, EXPORTING, EXPORTED, ERROR
}

enum class SegmentOrigin { AUTO, MANUAL }

data class VideoInfo(
    val uri: Uri,
    val displayName: String,
    val durationMs: Long,
    val width: Int?,
    val height: Int?,
    val sizeBytes: Long?
)

data class Segment(
    val id: Long,
    val startMs: Long,
    val endMs: Long,
    val included: Boolean = true,
    val origin: SegmentOrigin = SegmentOrigin.AUTO
) {
    val durationMs: Long get() = (endMs - startMs).coerceAtLeast(0L)
}

data class AnalysisResult(
    val segments: List<Segment>,
    val sampledFrames: Int,
    val sampleIntervalMs: Long,
    val motionThreshold: Double,
    val note: String
)

data class EditorUiState(
    val video: VideoInfo? = null,
    val phase: AnalysisPhase = AnalysisPhase.EMPTY,
    val analysisProgress: Float = 0f,
    val segments: List<Segment> = emptyList(),
    val selectedSegmentId: Long? = null,
    val statusText: String = "영상을 열어 자동 편집을 시작하세요.",
    val exportPath: String? = null,
    val error: String? = null
) {
    val includedSegments: List<Segment>
        get() = segments.filter { it.included }.sortedBy { it.startMs }

    val outputDurationMs: Long
        get() = includedSegments.sumOf { it.durationMs }
}
