package vn.chamcong.cham_cong_don_gian

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget màn hình chính: ngày hôm nay + 2 nút Chấm vào / Chấm ra. */
class ChamCongWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.widget_cham_cong).apply {
            setTextViewText(
                R.id.widget_date, widgetData.getString("date_label", null) ?: "--/--")

            setTextViewText(
                R.id.widget_checkin, widgetData.getString("checkin_label", null) ?: "Chấm vào")
            setOnClickPendingIntent(
                R.id.widget_checkin,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("chamcong://widget?action=checkin")))

            setTextViewText(
                R.id.widget_checkout, widgetData.getString("checkout_label", null) ?: "Chấm ra")
            setOnClickPendingIntent(
                R.id.widget_checkout,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("chamcong://widget?action=checkout")))

            // Chạm vào ngày thì mở app.
            setOnClickPendingIntent(
                R.id.widget_date,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
