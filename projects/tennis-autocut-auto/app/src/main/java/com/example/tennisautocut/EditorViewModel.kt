package com.example.tennisautocut

import android.app.Application
import android.database.Cursor
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Environment
import android.provider.OpenableColumns
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(UnstableApi::class)
class EditorViewModel(application: Application) : AndroidViewModel(application) {
    private val _ui = MutableStateFlow(EditorUiState())
    val ui: StateFlow<EditorUiState> = _ui.asStateFlow()

    private val analyzer = AutoAnalyzer(application)
    private var transformer: Transformer? = null
    private var pendingExport: File? = null

    fun openVideo(uri: Uri) {
        viewModelScope.launch {
            _ui.value = EditorUiState(
                phase = AnalysisPhase.READY,
                statusText = "영상 정보를 확인하는 중…"
            )
            runCatching { readVideoInfo(uri) }
                .onSuccess { info ->
                    _ui.update {
                        it.copy(
                            video = info,
                            phase = AnalysisPhase.READY,
                            statusText = "자동 분석을 시작하면 1차 편집안을 만든 뒤 수동 확인 단계로 넘어갑니다.",
                            error = null
                        )
                    }
                }
                .onFailure { error ->
                    _ui.update {
                        it.copy(
                            phase = AnalysisPhase.ERROR,
                            statusText = "영상을 열 수 없습니다.",
                            error = error.message ?: error.javaClass.simpleName
                        )
                    }
                }
        }
    }

    fun startAutoAnalysis() {
        val video = _ui.value.video ?: return
        if (_ui.value.phase == AnalysisPhase.ANALYZING) return

        _ui.update {
            it.copy(
                phase = AnalysisPhase.ANALYZING,
                analysisProgress = 0f,
                segments = emptyList(),
                selectedSegmentId = null,
                exportPath = null,
                statusText = "자동 분석 중 · 원본 파일은 변경하지 않습니다.",
                error = null
            )
        }

        viewModelScope.launch {
            runCatching {
                analyzer.analyze(video.uri, video.durationMs) { progress ->
                    _ui.update { state -> state.copy(analysisProgress = progress.coerceIn(0f, 1f)) }
                }
            }.onSuccess { result ->
                _ui.update {
                    it.copy(
                        phase = AnalysisPhase.REVIEW,
                        analysisProgress = 1f,
                        segments = result.segments,
                        selectedSegmentId = result.segments.firstOrNull()?.id,
                        statusText = "자동 편집안 생성 완료 · " + result.note,
                        error = null
                    )
                }
            }.onFailure { error ->
                _ui.update {
                    it.copy(
                        phase = AnalysisPhase.ERROR,
                        statusText = "자동 분석에 실패했습니다.",
                        error = error.message ?: error.javaClass.simpleName
                    )
                }
            }
        }
    }

    fun selectSegment(id: Long) {
        _ui.update { it.copy(selectedSegmentId = id) }
    }

    fun toggleSelected() {
        val id = _ui.value.selectedSegmentId ?: return
        _ui.update { state ->
            state.copy(
                segments = state.segments.map {
                    if (it.id == id) it.copy(included = !it.included) else it
                }
            )
        }
    }

    fun adjustSelectedStart(deltaMs: Long) {
        val id = _ui.value.selectedSegmentId ?: return
        val duration = _ui.value.video?.durationMs ?: return
        _ui.update { state ->
            state.copy(
                segments = state.segments.map { seg ->
                    if (seg.id != id) seg else seg.copy(
                        startMs = (seg.startMs + deltaMs)
                            .coerceIn(0L, minOf(duration, seg.endMs - 100L))
                    )
                }
            )
        }
    }

    fun adjustSelectedEnd(deltaMs: Long) {
        val id = _ui.value.selectedSegmentId ?: return
        val duration = _ui.value.video?.durationMs ?: return
        _ui.update { state ->
            state.copy(
                segments = state.segments.map { seg ->
                    if (seg.id != id) seg else seg.copy(
                        endMs = (seg.endMs + deltaMs)
                            .coerceIn(seg.startMs + 100L, duration)
                    )
                }
            )
        }
    }

    fun setSelectedStart(positionMs: Long) {
        val id = _ui.value.selectedSegmentId ?: return
        val duration = _ui.value.video?.durationMs ?: return
        _ui.update { state ->
            state.copy(
                segments = state.segments.map { seg ->
                    if (seg.id != id) seg else seg.copy(
                        startMs = positionMs.coerceIn(0L, minOf(duration, seg.endMs - 100L))
                    )
                }
            )
        }
    }

    fun setSelectedEnd(positionMs: Long) {
        val id = _ui.value.selectedSegmentId ?: return
        val duration = _ui.value.video?.durationMs ?: return
        _ui.update { state ->
            state.copy(
                segments = state.segments.map { seg ->
                    if (seg.id != id) seg else seg.copy(
                        endMs = positionMs.coerceIn(seg.startMs + 100L, duration)
                    )
                }
            )
        }
    }

    fun addManualSegment(positionMs: Long) {
        val duration = _ui.value.video?.durationMs ?: return
        val start = (positionMs - 3_000L).coerceAtLeast(0L)
        val end = (positionMs + 3_000L).coerceAtMost(duration)
        if (end - start < 200L) return
        val id = (_ui.value.segments.maxOfOrNull { it.id } ?: 0L) + 1L
        val segment = Segment(id, start, end, true, SegmentOrigin.MANUAL)
        _ui.update { state ->
            state.copy(
                segments = (state.segments + segment).sortedBy { it.startMs },
                selectedSegmentId = id
            )
        }
    }

    fun resetAutoDraft() = startAutoAnalysis()

    fun export() {
        val state = _ui.value
        val video = state.video ?: return
        val segments = SegmentPlanner.normalizeForExport(state.segments, video.durationMs)
        if (segments.isEmpty()) {
            _ui.update { it.copy(error = "출력할 KEEP 구간이 없습니다.") }
            return
        }
        if (state.phase == AnalysisPhase.EXPORTING) return

        val dir = File(
            getApplication<Application>().getExternalFilesDir(Environment.DIRECTORY_MOVIES),
            "AutoCut"
        )
        dir.mkdirs()
        val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val output = File(dir, "TennisAutoCut_" + stamp + ".mp4")
        if (output.exists()) output.delete()
        pendingExport = output

        val editedItems = segments.map { segment ->
            val clipping = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(segment.startMs)
                .setEndPositionMs(segment.endMs)
                .build()
            val item = MediaItem.Builder()
                .setUri(video.uri)
                .setClippingConfiguration(clipping)
                .build()
            EditedMediaItem.Builder(item).build()
        }
        val sequence = EditedMediaItemSequence.withAudioAndVideoFrom(editedItems)
        val composition = Composition.Builder(sequence).build()

        _ui.update {
            it.copy(
                phase = AnalysisPhase.EXPORTING,
                statusText = "자동편집 영상 출력 중 · 앱을 닫지 마세요.",
                exportPath = null,
                error = null
            )
        }

        transformer?.cancel()
        transformer = Transformer.Builder(getApplication<Application>())
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    val file = pendingExport
                    _ui.update {
                        it.copy(
                            phase = AnalysisPhase.EXPORTED,
                            statusText = "MP4 생성 완료 · 컷 경계를 재생해 최종 확인하세요.",
                            exportPath = file?.absolutePath,
                            error = null
                        )
                    }
                    transformer = null
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException
                ) {
                    pendingExport?.delete()
                    _ui.update {
                        it.copy(
                            phase = AnalysisPhase.REVIEW,
                            statusText = "출력 실패",
                            error = exportException.message ?: exportException.javaClass.simpleName
                        )
                    }
                    transformer = null
                }
            })
            .build()

        runCatching { transformer?.start(composition, output.absolutePath) }
            .onFailure { error ->
                pendingExport?.delete()
                transformer = null
                _ui.update {
                    it.copy(
                        phase = AnalysisPhase.REVIEW,
                        statusText = "출력 시작 실패",
                        error = error.message ?: error.javaClass.simpleName
                    )
                }
            }
    }

    fun cancelExport() {
        transformer?.cancel()
        transformer = null
        pendingExport?.delete()
        _ui.update {
            it.copy(
                phase = AnalysisPhase.REVIEW,
                statusText = "출력을 취소했습니다. 편집안은 그대로 보존됩니다."
            )
        }
    }

    private suspend fun readVideoInfo(uri: Uri): VideoInfo = withContext(Dispatchers.IO) {
        val resolver = getApplication<Application>().contentResolver
        var name = "video.mp4"
        var size: Long? = null
        resolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null
        )?.use { cursor: Cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (nameIndex >= 0) name = cursor.getString(nameIndex) ?: name
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) size = cursor.getLong(sizeIndex)
            }
        }

        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(getApplication<Application>(), uri)
            val duration = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
                ?: error("영상 길이를 읽을 수 없습니다.")
            val width = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull()
            val height = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull()
            VideoInfo(uri, name, duration, width, height, size)
        } finally {
            retriever.release()
        }
    }

    override fun onCleared() {
        transformer?.cancel()
        transformer = null
        super.onCleared()
    }
}
