package com.tlg.notify;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** Menampilkan notifikasi saat alarm dari TlgNotifyPlugin berbunyi. */
public class NotifyReceiver extends BroadcastReceiver {
    static final String EXTRA_ID = "id";
    static final String EXTRA_TITLE = "title";
    static final String EXTRA_TEXT = "text";
    private static final String CHANNEL = "tlg_reminders";

    @Override
    public void onReceive(Context ctx, Intent intent) {
        NotificationManager manager = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(new NotificationChannel(
                    CHANNEL, "Pengingat", NotificationManager.IMPORTANCE_DEFAULT));
            builder = new Notification.Builder(ctx, CHANNEL);
        } else {
            builder = new Notification.Builder(ctx);
        }
        // Ketuk notifikasi = buka game.
        Intent launch = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
        if (launch != null) {
            builder.setContentIntent(PendingIntent.getActivity(ctx, 0, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT | TlgNotifyPlugin.immutableFlag()));
        }
        builder.setSmallIcon(ctx.getApplicationInfo().icon)
                .setContentTitle(intent.getStringExtra(EXTRA_TITLE))
                .setContentText(intent.getStringExtra(EXTRA_TEXT))
                .setAutoCancel(true);
        manager.notify(intent.getIntExtra(EXTRA_ID, 0), builder.build());
    }
}
