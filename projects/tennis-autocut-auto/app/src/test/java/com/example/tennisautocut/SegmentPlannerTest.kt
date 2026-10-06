package com.example.tennisautocut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SegmentPlannerTest {
    @Test
    fun quietMiddleProducesTwoKeepSegments() {
        val scores = buildList {
            add(0.0)
            repeat(12) { add(12.0) }
            repeat(18) { add(1.0) }
            repeat(12) { add(12.0) }
        }
        val plan = SegmentPlanner.plan(
            durationMs = 42_000L,
            sampleIntervalMs = 1_000L,
            scores = scores
        )
        assertTrue(plan.keep.size >= 2)
        assertEquals(0L, plan.keep.first().first)
    }

    @Test
    fun flatSignalFallsBackToWholeVideo() {
        val scores = List(61) { 2.0 }
        val plan = SegmentPlanner.plan(
            durationMs = 60_000L,
            sampleIntervalMs = 1_000L,
            scores = scores
        )
        assertEquals(1, plan.keep.size)
        assertEquals(0L, plan.keep.first().first)
        assertEquals(59_999L, plan.keep.first().last)
    }

    @Test
    fun exportNormalizationMergesOverlap() {
        val input = listOf(
            Segment(1, 0, 5_000, true),
            Segment(2, 4_950, 9_000, true),
            Segment(3, 12_000, 13_000, false)
        )
        val out = SegmentPlanner.normalizeForExport(input, 20_000)
        assertEquals(1, out.size)
        assertEquals(0L, out[0].startMs)
        assertEquals(9_000L, out[0].endMs)
    }
}
