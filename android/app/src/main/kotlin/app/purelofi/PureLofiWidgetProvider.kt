package app.purelofi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.view.KeyEvent
import android.widget.RemoteViews
import com.ryanheise.audioservice.MediaButtonReceiver
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * The home screen widget (#144): the room, the track, play and pause.
 *
 * Classic RemoteViews rather than Glance: no Compose in the build for one
 * small widget. Play/pause is the media button audio_service already
 * answers, so it works with the app in the background.
 */
class PureLofiWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.purelofi_widget)

            views.setTextViewText(R.id.widget_room, widgetData.getString("room", "PureLofi"))
            views.setTextViewText(R.id.widget_track, widgetData.getString("track", "") ?: "")
            views.setTextViewText(R.id.widget_artist, widgetData.getString("artist", "") ?: "")

            val cover = widgetData.getString("cover", null)?.let(::pixelCover)
            if (cover != null) views.setImageViewBitmap(R.id.widget_cover, cover)

            val playing = widgetData.getBoolean("playing", false)
            views.setImageViewResource(
                R.id.widget_play,
                if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
            )
            views.setContentDescription(R.id.widget_play, if (playing) "Pause" else "Play")
            views.setInt(R.id.widget_play, "setColorFilter", accent(widgetData))
            views.setOnClickPendingIntent(R.id.widget_play, playPause(context))
            views.setOnClickPendingIntent(R.id.widget_root, openApp(context))

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** The accent picked in the app, the lamp until one is or if it cannot be read. */
    private fun accent(widgetData: SharedPreferences): Int =
        widgetData.getString("accent", null)
            ?.let { runCatching { Color.parseColor(it) }.getOrNull() }
            ?: LAMP

    /** The cover, scaled by a whole number with no filtering: pixels stay pixels. */
    private fun pixelCover(path: String): Bitmap? {
        val file = File(path)
        if (!file.exists()) return null
        val source = BitmapFactory.decodeFile(file.path) ?: return null
        val factor = maxOf(1, 256 / maxOf(1, source.width))
        return Bitmap.createScaledBitmap(source, source.width * factor, source.height * factor, false)
    }

    private fun playPause(context: Context): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = ComponentName(context, MediaButtonReceiver::class.java)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        }
        return PendingIntent.getBroadcast(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun openApp(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        return PendingIntent.getActivity(
            context, 1, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private companion object {
        val LAMP = Color.parseColor("#F0A05D")
    }
}
