package com.example.tennisautocut

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.FileProvider
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import kotlinx.coroutines.delay
import java.io.File
import kotlin.math.roundToLong

@OptIn(UnstableApi::class)
class MainActivity : ComponentActivity() {
    private val viewModel: EditorViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(
                colorScheme = darkColorScheme(
                    primary = Lime,
                    background = Bg,
                    surface = Panel,
                    onPrimary = Color(0xFF102018),
                    onBackground = Color(0xFFF3F5F7),
                    onSurface = Color(0xFFF3F5F7)
                )
            ) {
                AutoCutScreen(viewModel)
            }
        }
    }
}

private val Lime = Color(0xFFB7F35B)
private val Bg = Color(0xFF151D22)
private val Panel = Color(0xFF1B242A)
private val Muted = Color(0xFFAAB2B8)
private val Line = Color(0xFF354149)

@OptIn(UnstableApi::class)
@Composable
private fun AutoCutScreen(vm: EditorViewModel) {
    val state by vm.ui.collectAsState()
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val video = state.video

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri != null) {
            runCatching {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            }
            vm.openVideo(uri)
        }
    }

    val player = remember { ExoPlayer.Builder(context).build() }
    var positionMs by remember { mutableLongStateOf(0L) }

    LaunchedEffect(video?.uri) {
        positionMs = 0L
        val uri = video?.uri
        if (uri != null) {
            player.setMediaItem(MediaItem.fromUri(uri))
            player.prepare()
        } else {
            player.clearMediaItems()
        }
    }

    LaunchedEffect(player) {
        while (true) {
            positionMs = player.currentPosition.coerceAtLeast(0L)
            delay(200)
        }
    }

    DisposableEffect(lifecycleOwner, player) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) player.pause()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            player.release()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Bg)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("TENNIS AUTOCUT", style = MaterialTheme.typography.headlineMedium, color = Lime)
        Text("자동 편집 → 수동 확인 → MP4 출력", style = MaterialTheme.typography.titleMedium)

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(onClick = { picker.launch(arrayOf("video/*")) }) {
                Text("영상 열기")
            }
            if (video != null) {
                OutlinedButton(onClick = {
                    player.seekTo(0L)
                    player.play()
                }) {
                    Text("처음부터")
                }
            }
        }

        if (video != null) {
            Text(video.displayName, style = MaterialTheme.typography.titleMedium)
            Text(
                formatMs(video.durationMs) + " · " +
                    (video.width?.toString() ?: "?") + "×" +
                    (video.height?.toString() ?: "?") + " · " +
                    formatBytes(video.sizeBytes),
                color = Muted
            )

            AndroidView(
                factory = { ctx ->
                    PlayerView(ctx).apply {
                        useController = false
                        this.player = player
                    }
                },
                update = { it.player = player },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(210.dp)
                    .background(Color.Black)
            )

            Slider(
                value = if (video.durationMs > 0L) {
                    (positionMs.toFloat() / video.durationMs).coerceIn(0f, 1f)
                } else 0f,
                onValueChange = { ratio ->
                    player.seekTo((ratio * video.durationMs).roundToLong())
                },
                modifier = Modifier.fillMaxWidth()
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("원본 " + formatMs(positionMs), color = Muted)
                Button(onClick = {
                    if (player.isPlaying) player.pause() else player.play()
                }) {
                    Text("재생/일시정지")
                }
            }
        }

        Text(
            state.statusText,
            color = if (state.error == null) Muted else Color(0xFFFF8A80)
        )
        if (state.error != null) {
            Text(state.error ?: "", color = Color(0xFFFF8A80))
        }

        when (state.phase) {
            AnalysisPhase.READY -> {
                Button(
                    onClick = vm::startAutoAnalysis,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = Lime)
                ) {
                    Text("자동 분석 시작")
                }
                Text(
                    "앱이 먼저 1차 편집안을 만듭니다. 수동 시작/끝 지정은 그 다음 검수 단계에서만 사용합니다.",
                    color = Muted
                )
            }

            AnalysisPhase.ANALYZING -> {
                LinearProgressIndicator(
                    progress = { state.analysisProgress },
                    modifier = Modifier.fillMaxWidth()
                )
                Text("분석 " + (state.analysisProgress * 100).toInt() + "%", color = Lime)
            }

            AnalysisPhase.REVIEW,
            AnalysisPhase.EXPORTING,
            AnalysisPhase.EXPORTED -> {
                ReviewPanel(
                    state = state,
                    onSelect = { id, start ->
                        vm.selectSegment(id)
                        player.seekTo(start)
                    },
                    onToggle = vm::toggleSelected,
                    onStartMinus = { vm.adjustSelectedStart(-100L) },
                    onStartPlus = { vm.adjustSelectedStart(100L) },
                    onEndMinus = { vm.adjustSelectedEnd(-100L) },
                    onEndPlus = { vm.adjustSelectedEnd(100L) },
                    onCurrentStart = { vm.setSelectedStart(positionMs) },
                    onCurrentEnd = { vm.setSelectedEnd(positionMs) },
                    onAdd = { vm.addManualSegment(positionMs) },
                    onReanalyze = vm::resetAutoDraft,
                    onExport = vm::export,
                    onCancelExport = vm::cancelExport,
                    onShare = {
                        val outputPath = state.exportPath
                        if (outputPath != null) {
                            val file = File(outputPath)
                            val shareUri = FileProvider.getUriForFile(
                                context,
                                context.packageName + ".files",
                                file
                            )
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "video/mp4"
                                putExtra(Intent.EXTRA_STREAM, shareUri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            context.startActivity(
                                Intent.createChooser(intent, "자동편집 영상 공유/저장")
                            )
                        }
                    }
                )
            }

            else -> Unit
        }
    }
}

@Composable
private fun ReviewPanel(
    state: EditorUiState,
    onSelect: (Long, Long) -> Unit,
    onToggle: () -> Unit,
    onStartMinus: () -> Unit,
    onStartPlus: () -> Unit,
    onEndMinus: () -> Unit,
    onEndPlus: () -> Unit,
    onCurrentStart: () -> Unit,
    onCurrentEnd: () -> Unit,
    onAdd: () -> Unit,
    onReanalyze: () -> Unit,
    onExport: () -> Unit,
    onCancelExport: () -> Unit,
    onShare: () -> Unit
) {
    val video = state.video ?: return
    val selected = state.segments.firstOrNull { it.id == state.selectedSegmentId }

    HorizontalDivider(color = Line)
    Text("1차 자동 편집 결과", style = MaterialTheme.typography.titleLarge)
    Text(
        "원본 " + formatMs(video.durationMs) +
            " → KEEP " + formatMs(state.outputDurationMs) +
            " · " + state.includedSegments.size + "개 구간",
        color = Lime
    )

    LazyColumn(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(max = 220.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        items(state.segments, key = { it.id }) { seg ->
            val selectedNow = seg.id == state.selectedSegmentId
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = if (selectedNow) Color(0xFF29363D) else Panel
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onSelect(seg.id, seg.startMs) }
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        (if (seg.included) "KEEP" else "EXCLUDE") + "  " +
                            formatMs(seg.startMs) + "–" + formatMs(seg.endMs)
                    )
                    Text(
                        if (seg.origin == SegmentOrigin.AUTO) "AUTO" else "MANUAL",
                        color = Muted
                    )
                }
            }
        }
    }

    if (selected != null) {
        Card(colors = CardDefaults.cardColors(containerColor = Panel)) {
            Column(
                modifier = Modifier.padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text("선택 구간 수동 확인", style = MaterialTheme.typography.titleMedium)
                Text(
                    "시작 " + formatMs(selected.startMs) +
                        " · 끝 " + formatMs(selected.endMs),
                    color = Muted
                )
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    OutlinedButton(onClick = onStartMinus) { Text("시작 −0.1") }
                    OutlinedButton(onClick = onStartPlus) { Text("시작 +0.1") }
                    OutlinedButton(onClick = onCurrentStart) { Text("현재→시작") }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    OutlinedButton(onClick = onEndMinus) { Text("끝 −0.1") }
                    OutlinedButton(onClick = onEndPlus) { Text("끝 +0.1") }
                    OutlinedButton(onClick = onCurrentEnd) { Text("현재→끝") }
                }
                OutlinedButton(onClick = onToggle) {
                    Text(if (selected.included) "이 구간 제외" else "이 구간 복구")
                }
            }
        }
    }

    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedButton(onClick = onAdd) { Text("현재±3초 구간 추가") }
        OutlinedButton(onClick = onReanalyze) { Text("자동분석 다시") }
    }

    if (state.phase == AnalysisPhase.EXPORTING) {
        Button(
            onClick = onCancelExport,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("출력 취소")
        }
    } else {
        Button(
            onClick = onExport,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = Lime)
        ) {
            Text("자동편집 영상 출력")
        }
    }

    if (state.exportPath != null) {
        Button(
            onClick = onShare,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("MP4 공유/저장")
        }
    }

    Text(
        "현재 자동 엔진은 장시간 저활동 구간을 보수적으로 제거하는 1차 엔진입니다. " +
            "공/서브/점수 판정은 아직 사용하지 않으므로 모든 컷 경계를 2차 확인하세요.",
        color = Muted
    )
}

private fun formatMs(ms: Long): String {
    val total = ms.coerceAtLeast(0L) / 1000L
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    return if (h > 0) {
        "%d:%02d:%02d".format(h, m, s)
    } else {
        "%02d:%02d".format(m, s)
    }
}

private fun formatBytes(bytes: Long?): String {
    if (bytes == null) return "크기 알 수 없음"
    val mib = bytes / (1024.0 * 1024.0)
    return "%.1f MiB".format(mib)
}
