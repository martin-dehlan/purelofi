package app.purelofi

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service requires the host activity to extend AudioServiceActivity so
// the playback service can rebind to the Flutter engine. See docs/SPEC.md.
//
// It also carries the wake-up alarm (#146): an AlarmManager alarm clock
// that opens this activity with WAKE_ACTION when it rings; Dart then starts
// the music and fades it in.
class MainActivity : AudioServiceActivity() {
    private var channel: MethodChannel? = null
    private var launchedByAlarm = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchedByAlarm = intent?.action == WAKE_ACTION
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        val at = call.argument<Number>("at")?.toLong()
                        if (at == null) result.error("args", "no time", null)
                        else result.success(schedule(at))
                    }
                    "cancel" -> {
                        alarms().cancel(wakeIntent())
                        result.success(null)
                    }
                    "launchedByAlarm" -> {
                        result.success(launchedByAlarm)
                        launchedByAlarm = false
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == WAKE_ACTION) channel?.invokeMethod("rang", null)
    }

    /** Returns whether the alarm could be set: exact alarms may be refused. */
    private fun schedule(at: Long): Boolean {
        val manager = alarms()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
            return false
        }
        val show = PendingIntent.getActivity(
            this, 2, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        manager.setAlarmClock(AlarmManager.AlarmClockInfo(at, show), wakeIntent())
        return true
    }

    private fun wakeIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = WAKE_ACTION
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            this, 3, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun alarms() = getSystemService(Context.ALARM_SERVICE) as AlarmManager

    companion object {
        const val CHANNEL = "app.purelofi/wake"
        const val WAKE_ACTION = "app.purelofi.WAKE"
    }
}
