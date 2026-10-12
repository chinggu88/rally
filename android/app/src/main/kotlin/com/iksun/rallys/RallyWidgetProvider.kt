package com.iksun.rallys

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

/**
 * 관심 경기 홈스크린 위젯.
 *
 * Flutter(`FavoriteMatchService`)가 App 저장소에 단일 JSON 키 `rally_match`를
 * 기록하고 `updateWidget()`으로 갱신을 푸시한다. 관심 경기가 없으면 값이
 * null이며 안내 문구를 표시한다.
 *
 * 스키마는 `FavoriteMatchResponse.toWidgetJson()`이 유일한 계약이다.
 */
class RallyWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val raw = HomeWidgetPlugin.getData(context).getString(KEY_MATCH, null)

        for (id in appWidgetIds) {
            val minWidth = appWidgetManager.getAppWidgetOptions(id)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val isSmall = minWidth < SMALL_MAX_WIDTH_DP
            val layout =
                if (isSmall) R.layout.rally_widget_small else R.layout.rally_widget_medium

            val views = RemoteViews(context.packageName, layout)

            val match = parse(raw)
            if (match == null) {
                bindEmpty(context, views, isSmall)
            } else {
                bind(context, views, match, isSmall)
            }

            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(DEEP_LINK),
                ),
            )

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** 리사이즈 시에도 small/medium 레이아웃을 다시 고르도록 재바인딩한다. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    // ── 바인딩 ─────────────────────────────────────────────────

    private fun bind(
        context: Context,
        views: RemoteViews,
        match: JSONObject,
        isSmall: Boolean,
    ) {
        val current = match.optJSONArray("current")
        val p1 = current?.optInt(0, 0) ?: 0
        val p2 = current?.optInt(1, 0) ?: 0

        views.setViewVisibility(
            R.id.live_dot,
            if (match.optBoolean("isLive", false)) View.VISIBLE else View.GONE,
        )
        views.setTextViewText(R.id.score, "$p1 · $p2")
        views.setTextColor(R.id.score, COLOR_WHITE)
        // 빈 상태에서 줄여둔 크기가 남지 않도록 항상 명시한다.
        views.setTextViewTextSize(
            R.id.score,
            TypedValue.COMPLEX_UNIT_SP,
            if (isSmall) 22f else 30f,
        )
        views.setTextViewText(R.id.t1_country, match.optString("team1Country", ""))
        views.setTextViewText(R.id.t2_country, match.optString("team2Country", ""))

        if (isSmall) return

        views.setViewVisibility(R.id.tournament, View.VISIBLE)
        views.setViewVisibility(R.id.meta, View.VISIBLE)
        views.setViewVisibility(R.id.set_label, View.VISIBLE)
        views.setTextViewText(R.id.tournament, match.optString("tournament", ""))
        views.setTextViewText(R.id.meta, match.optString("meta", ""))
        views.setTextViewText(R.id.set_label, match.optString("setLabel", ""))
        views.setTextViewText(R.id.t1_name, match.optString("team1", ""))
        views.setTextViewText(R.id.t2_name, match.optString("team2", ""))
        views.setTextViewText(R.id.updated, match.optString("timeKst", ""))

        // 이전 세트 칩 — RemoteViews는 동적 추가가 안 되므로 3개 고정.
        val prev = match.optJSONArray("prevSets")
        val chips = intArrayOf(R.id.set1, R.id.set2, R.id.set3)
        for (i in chips.indices) {
            val item = if (prev != null && i < prev.length()) prev.optJSONObject(i) else null
            if (item == null) {
                views.setViewVisibility(chips[i], View.GONE)
                continue
            }
            val won = item.optBoolean("won", false)
            views.setViewVisibility(chips[i], View.VISIBLE)
            views.setTextViewText(chips[i], item.optString("text", ""))
            views.setTextColor(chips[i], if (won) COLOR_LIME else COLOR_SUBTLE)
            views.setInt(
                chips[i],
                "setBackgroundResource",
                if (won) R.drawable.rally_set_chip_on else R.drawable.rally_set_chip_off,
            )
        }
    }

    /**
     * 빈 상태 — 관심 경기 미지정.
     *
     * 별도 레이아웃 없이 score TextView를 안내 문구로 재활용하고
     * 나머지를 숨긴다.
     */
    private fun bindEmpty(context: Context, views: RemoteViews, isSmall: Boolean) {
        views.setViewVisibility(R.id.live_dot, View.GONE)
        views.setTextViewText(R.id.t1_country, "")
        views.setTextViewText(R.id.t2_country, "")
        views.setTextViewText(R.id.score, context.getString(R.string.rally_widget_empty))
        views.setTextColor(R.id.score, COLOR_SUBTLE)
        views.setTextViewTextSize(
            R.id.score,
            TypedValue.COMPLEX_UNIT_SP,
            if (isSmall) 11f else 13f,
        )

        if (isSmall) return

        views.setViewVisibility(R.id.tournament, View.GONE)
        views.setViewVisibility(R.id.meta, View.GONE)
        views.setViewVisibility(R.id.set_label, View.GONE)
        views.setViewVisibility(R.id.set1, View.GONE)
        views.setViewVisibility(R.id.set2, View.GONE)
        views.setViewVisibility(R.id.set3, View.GONE)
        views.setTextViewText(R.id.t1_name, "")
        views.setTextViewText(R.id.t2_name, "")
        views.setTextViewText(R.id.updated, "")
    }

    private fun parse(raw: String?): JSONObject? {
        if (raw.isNullOrBlank() || raw == "null") return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }

    private companion object {
        /** `FavoriteMatchService._widgetDataKey`와 동일해야 한다. */
        const val KEY_MATCH = "rally_match"
        const val DEEP_LINK = "rally://widget/favorite"

        /** 이 폭(dp) 미만이면 compact 레이아웃을 쓴다. */
        const val SMALL_MAX_WIDTH_DP = 180

        const val COLOR_LIME = 0xFFC3F400.toInt()
        const val COLOR_WHITE = 0xFFFFFFFF.toInt()
        const val COLOR_SUBTLE = 0xFF9CA3A1.toInt()
    }
}
