package com.personal.shoulder_os

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class ShoulderWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val ACTION_PREVIOUS = "com.personal.shoulder_os.WIDGET_PREVIOUS"
        private const val ACTION_NEXT = "com.personal.shoulder_os.WIDGET_NEXT"
        private const val ACTION_REFRESH = "com.personal.shoulder_os.WIDGET_REFRESH"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val prefs = context.getSharedPreferences("shoulder_widget", Context.MODE_PRIVATE)
        val current = prefs.getInt("month_offset", 0)
        when (intent.action) {
            ACTION_PREVIOUS -> prefs.edit().putInt("month_offset", current - 1).apply()
            ACTION_NEXT -> prefs.edit().putInt("month_offset", current + 1).apply()
            ACTION_REFRESH -> Unit
            else -> return
        }
        val manager = AppWidgetManager.getInstance(context)
        onUpdate(context, manager, manager.getAppWidgetIds(ComponentName(context, ShoulderWidgetProvider::class.java)))
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val offset = context.getSharedPreferences("shoulder_widget", Context.MODE_PRIVATE).getInt("month_offset", 0)
        val month = Calendar.getInstance().apply { add(Calendar.MONTH, offset); set(Calendar.DAY_OF_MONTH, 1) }
        val marks = loadMarks(context, month)
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.shoulder_widget)
            views.setTextViewText(R.id.widget_month_title, SimpleDateFormat("yyyy.MM", Locale.KOREA).format(month.time))
            views.setOnClickPendingIntent(R.id.widget_root, route(context, "/calendar", id * 100))
            views.setOnClickPendingIntent(R.id.widget_previous, broadcast(context, ACTION_PREVIOUS, id * 100 + 1))
            views.setOnClickPendingIntent(R.id.widget_next, broadcast(context, ACTION_NEXT, id * 100 + 2))
            views.setOnClickPendingIntent(R.id.widget_refresh, broadcast(context, ACTION_REFRESH, id * 100 + 3))
            views.setOnClickPendingIntent(R.id.widget_workout, route(context, "/workout", id * 100 + 4))
            views.setOnClickPendingIntent(R.id.widget_rehab, route(context, "/rehab", id * 100 + 5))
            views.setOnClickPendingIntent(R.id.widget_pain, route(context, "/pain", id * 100 + 6))
            views.removeAllViews(R.id.widget_grid)
            val firstWeekday = (month.get(Calendar.DAY_OF_WEEK) + 5) % 7
            val daysInMonth = month.getActualMaximum(Calendar.DAY_OF_MONTH)
            val today = Calendar.getInstance()
            for (rowIndex in 0 until 6) {
                val row = RemoteViews(context.packageName, R.layout.widget_calendar_row)
                for (column in 0 until 7) {
                    val day = rowIndex * 7 + column - firstWeekday + 1
                    val cell = RemoteViews(context.packageName, R.layout.widget_calendar_cell)
                    if (day in 1..daysInMonth) {
                        val date = month.clone() as Calendar
                        date.set(Calendar.DAY_OF_MONTH, day)
                        val key = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(date.time)
                        cell.setTextViewText(R.id.widget_day, day.toString())
                        cell.setTextViewText(R.id.widget_mark, marks[key]?.joinToString("") ?: "")
                        if (today.get(Calendar.YEAR) == date.get(Calendar.YEAR) && today.get(Calendar.DAY_OF_YEAR) == date.get(Calendar.DAY_OF_YEAR)) {
                            cell.setInt(R.id.widget_cell, "setBackgroundResource", R.drawable.widget_today_background)
                        }
                        cell.setOnClickPendingIntent(R.id.widget_cell, route(context, "/calendar", id * 1000 + day))
                    } else {
                        cell.setTextViewText(R.id.widget_day, "")
                        cell.setTextViewText(R.id.widget_mark, "")
                    }
                    row.addView(R.id.widget_row, cell)
                }
                views.addView(R.id.widget_grid, row)
            }
            manager.updateAppWidget(id, views)
        }
    }

    private fun loadMarks(context: Context, month: Calendar): Map<String, MutableSet<String>> {
        val result = mutableMapOf<String, MutableSet<String>>()
        val start = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(month.time)
        val next = month.clone() as Calendar
        next.add(Calendar.MONTH, 1)
        val end = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(next.time)
        val file = context.getDatabasePath("shoulder_os_v2.sqlite")
        if (!file.exists()) return result
        try {
            SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                fun query(sql: String, mark: String) {
                    db.rawQuery(sql, arrayOf(start, end)).use { cursor ->
                        while (cursor.moveToNext()) result.getOrPut(cursor.getString(0)) { mutableSetOf() }.add(mark)
                    }
                }
                query("SELECT DISTINCT substr(started_at,1,10) FROM workout_sessions WHERE started_at >= ? AND started_at < ? AND ended_at IS NOT NULL", "●")
                query("SELECT DISTINCT session_date FROM tennis_sessions WHERE session_date >= ? AND session_date < ?", "◆")
                query("SELECT DISTINCT treatment_date FROM treatment_records WHERE treatment_date >= ? AND treatment_date < ?", "+")
                query("SELECT DISTINCT substr(recorded_at,1,10) FROM pain_records WHERE recorded_at >= ? AND recorded_at < ?", "!")
            }
        } catch (_: Exception) { }
        return result
    }

    private fun broadcast(context: Context, action: String, code: Int): PendingIntent {
        val intent = Intent(context, ShoulderWidgetProvider::class.java).apply { this.action = action }
        return PendingIntent.getBroadcast(context, code, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun route(context: Context, route: String, code: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra("route", route)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(context, code, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}
