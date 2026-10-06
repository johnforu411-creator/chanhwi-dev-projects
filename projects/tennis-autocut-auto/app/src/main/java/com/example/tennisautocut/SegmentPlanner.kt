package com.example.tennisautocut

import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

object SegmentPlanner {
    data class Plan(
        val keep: List<LongRange>,
        val threshold: Double,
        val note: String
    )

    fun plan(durationMs: Long, sampleIntervalMs: Long, scores: List<Double>): Plan {
        if (durationMs <= 0L || scores.size < 8) {
            return whole(durationMs, 0.0, "샘플이 부족해 원본 전체를 보존했습니다.")
        }

        val usable = scores.drop(1).filter { it.isFinite() && it >= 0.0 }
        if (usable.size < 6) return whole(durationMs, 0.0, "유효한 움직임 샘플이 부족합니다.")

        val sorted = usable.sorted()
        val q35 = percentile(sorted, 0.35)
        val q65 = percentile(sorted, 0.65)
        val spread = q65 - q35
        if (spread < 0.7) {
            return whole(durationMs, q35, "움직임 분포가 뚜렷하지 않아 보수적으로 전체 영상을 유지했습니다.")
        }

        val threshold = q35 + spread * 0.18
        val quiet = scores.map { it <= threshold }.toMutableList()

        for (i in 1 until quiet.lastIndex) {
            if (!quiet[i] && quiet[i - 1] && quiet[i + 1]) quiet[i] = true
        }

        val minQuietSamples = max(3, ceil(10_000.0 / sampleIntervalMs).toInt())
        val edgeContextMs = 2_500L
        val candidateCuts = mutableListOf<LongRange>()
        var i = 0
        while (i < quiet.size) {
            if (!quiet[i]) {
                i++
                continue
            }
            val start = i
            while (i < quiet.size && quiet[i]) i++
            val endExclusive = i
            if (endExclusive - start >= minQuietSamples) {
                val quietStart = start * sampleIntervalMs
                val quietEnd = min(durationMs, endExclusive * sampleIntervalMs)
                val cutStart = quietStart + edgeContextMs
                val cutEndExclusive = quietEnd - edgeContextMs
                if (cutEndExclusive - cutStart >= 4_000L) {
                    candidateCuts += cutStart until cutEndExclusive
                }
            }
        }

        if (candidateCuts.isEmpty()) {
            return whole(durationMs, threshold, "10초 이상 지속된 확실한 저활동 구간이 없어 원본 전체를 유지했습니다.")
        }

        val mergedCuts = mergeRanges(candidateCuts, 1_000L)
        val maxExcludedMs = (durationMs * 0.55).toLong()
        val selectedCuts = if (mergedCuts.sumOf { length(it) } <= maxExcludedMs) {
            mergedCuts
        } else {
            val chosen = mutableListOf<LongRange>()
            var total = 0L
            for (r in mergedCuts.sortedByDescending { length(it) }) {
                if (total + length(r) <= maxExcludedMs) {
                    chosen += r
                    total += length(r)
                }
            }
            chosen.sortedBy { it.first }
        }

        val keep = complement(durationMs, selectedCuts).filter { length(it) >= 1_500L }
        if (keep.isEmpty()) {
            return whole(durationMs, threshold, "자동 컷 안전 기준을 충족하지 못해 원본 전체를 유지했습니다.")
        }

        val excluded = selectedCuts.sumOf { length(it) }
        val note = "장시간 저활동 구간 " + selectedCuts.size + "개를 자동 제외 후보로 잡았습니다. " +
            (excluded / 1000) + "초 절감 예상이며, 모든 경계는 수동 확인 대상입니다."
        return Plan(keep, threshold, note)
    }

    fun normalizeForExport(segments: List<Segment>, durationMs: Long): List<Segment> {
        val ranges = segments.filter { it.included }.mapNotNull {
            val s = it.startMs.coerceIn(0L, durationMs)
            val e = it.endMs.coerceIn(0L, durationMs)
            if (e - s >= 100L) s until e else null
        }
        return mergeRanges(ranges, 50L).mapIndexed { index, r ->
            Segment(
                id = index.toLong() + 1,
                startMs = r.first,
                endMs = r.last + 1,
                included = true,
                origin = SegmentOrigin.AUTO
            )
        }
    }

    private fun complement(durationMs: Long, cuts: List<LongRange>): List<LongRange> {
        if (cuts.isEmpty()) return listOf(0L until durationMs)
        val out = mutableListOf<LongRange>()
        var cursor = 0L
        for (cut in cuts.sortedBy { it.first }) {
            val start = cut.first.coerceIn(0L, durationMs)
            val endExclusive = (cut.last + 1).coerceIn(0L, durationMs)
            if (start > cursor) out += cursor until start
            cursor = max(cursor, endExclusive)
        }
        if (cursor < durationMs) out += cursor until durationMs
        return out
    }

    private fun mergeRanges(input: List<LongRange>, bridgeMs: Long): List<LongRange> {
        if (input.isEmpty()) return emptyList()
        val sorted = input.sortedBy { it.first }
        val out = mutableListOf<LongRange>()
        var currentStart = sorted.first().first
        var currentEndExclusive = sorted.first().last + 1
        for (r in sorted.drop(1)) {
            val s = r.first
            val e = r.last + 1
            if (s <= currentEndExclusive + bridgeMs) {
                currentEndExclusive = max(currentEndExclusive, e)
            } else {
                out += currentStart until currentEndExclusive
                currentStart = s
                currentEndExclusive = e
            }
        }
        out += currentStart until currentEndExclusive
        return out
    }

    private fun percentile(sorted: List<Double>, p: Double): Double {
        if (sorted.isEmpty()) return 0.0
        val pos = p.coerceIn(0.0, 1.0) * (sorted.size - 1)
        val lower = pos.toInt()
        val upper = min(sorted.lastIndex, lower + 1)
        val fraction = pos - lower
        return sorted[lower] * (1.0 - fraction) + sorted[upper] * fraction
    }

    private fun whole(durationMs: Long, threshold: Double, note: String): Plan =
        Plan(if (durationMs > 0) listOf(0L until durationMs) else emptyList(), threshold, note)

    private fun length(range: LongRange): Long =
        if (range.isEmpty()) 0L else range.last - range.first + 1
}
