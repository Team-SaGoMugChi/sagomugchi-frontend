package app.oddo.oddo

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object DiaryReminder {
    private const val CHANNEL = "diary_reminder"
    private const val ID = 2100
    private fun preferences(context: Context) = context.getSharedPreferences(CHANNEL, Context.MODE_PRIVATE)
    private fun alarmIntent(context: Context) = PendingIntent.getBroadcast(context, ID,
        Intent(context, DiaryReminderReceiver::class.java).setAction("app.oddo.oddo.DIARY_REMINDER"),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun configure(context: Context, enabled: Boolean, hour: Int, minute: Int): Boolean {
        require(hour in 0..23 && minute in 0..59)
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "일기 리마인더",
                NotificationManager.IMPORTANCE_DEFAULT))
        }
        val allowed = (Build.VERSION.SDK_INT < 24 || manager.areNotificationsEnabled()) && (Build.VERSION.SDK_INT < 26 ||
            manager.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
        val active = enabled && allowed
        preferences(context).edit().putBoolean("enabled", active)
            .putInt("hour", hour).putInt("minute", minute).apply()
        val alarm = context.getSystemService(AlarmManager::class.java)
        alarm.cancel(alarmIntent(context))
        if (active) scheduleNext(context) else manager.cancel(ID)
        return !enabled || allowed
    }

    fun scheduleNext(context: Context) {
        val prefs = preferences(context)
        if (!prefs.getBoolean("enabled", false)) return
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, prefs.getInt("hour", 21))
            set(Calendar.MINUTE, prefs.getInt("minute", 0))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        // A daily reminder does not require privileged exact-alarm access.
        context.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP, next.timeInMillis, alarmIntent(context))
    }

    fun deliver(context: Context) {
        if (!preferences(context).getBoolean("enabled", false)) return
        scheduleNext(context)
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return
        val openApp = PendingIntent.getActivity(context, ID,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL)
            else Notification.Builder(context)
        val notification = builder.setSmallIcon(R.drawable.ic_diary_notification)
            .setContentTitle("오늘 이야기를 들려주세요")
            .setContentText("탄카츄와 오늘의 마음을 짧게 기록해볼까요?")
            .setContentIntent(openApp).setAutoCancel(true).build()
        try { manager.notify(ID, notification) } catch (_: SecurityException) { }
    }
}

class DiaryReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "app.oddo.oddo.DIARY_REMINDER") DiaryReminder.deliver(context)
        else DiaryReminder.scheduleNext(context)
    }
}
