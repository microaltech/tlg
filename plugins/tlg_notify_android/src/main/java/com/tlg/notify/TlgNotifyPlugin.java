package com.tlg.notify;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;

import androidx.core.content.FileProvider;

import java.io.File;

import androidx.annotation.NonNull;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;

/**
 * Singleton "TlgNotify": menjadwalkan notifikasi lokal lewat AlarmManager, memantau server
 * saat game ditutup (PollReceiver), dan membagikan gambar lewat menu bagikan Android.
 * Dipanggil dari scripts/core/notifier.gd dan scripts/core/sharer.gd.
 */
public class TlgNotifyPlugin extends GodotPlugin {
    private static final String PREFS = "tlg_notify";
    private static final String KEY_IDS = "ids";

    public TlgNotifyPlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "TlgNotify";
    }

    static int immutableFlag() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0;
    }

    private Context context() {
        Activity activity = getActivity();
        return activity == null ? null : activity.getApplicationContext();
    }

    private static PendingIntent alarmIntent(Context ctx, int id, String title, String text) {
        Intent intent = new Intent(ctx, NotifyReceiver.class);
        intent.putExtra(NotifyReceiver.EXTRA_ID, id);
        intent.putExtra(NotifyReceiver.EXTRA_TITLE, title);
        intent.putExtra(NotifyReceiver.EXTRA_TEXT, text);
        return PendingIntent.getBroadcast(ctx, id, intent, PendingIntent.FLAG_UPDATE_CURRENT | immutableFlag());
    }

    /** Tampilkan notifikasi `id` setelah `delaySeconds`; id yang sama menimpa jadwal lama. */
    @UsedByGodot
    public void schedule(int id, String title, String text, int delaySeconds) {
        Context ctx = context();
        if (ctx == null) {
            return;
        }
        AlarmManager alarms = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        // Alarm tidak-eksak cukup untuk pengingat dan tidak butuh izin SCHEDULE_EXACT_ALARM.
        alarms.set(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + delaySeconds * 1000L,
                alarmIntent(ctx, id, title, text));
        SharedPreferences prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        Set<String> ids = new HashSet<>(prefs.getStringSet(KEY_IDS, new HashSet<>()));
        ids.add(String.valueOf(id));
        prefs.edit().putStringSet(KEY_IDS, ids).apply();
    }

    /** Batalkan semua jadwal dan hapus notifikasi yang sedang tampil. */
    @UsedByGodot
    public void cancel_all() {
        Context ctx = context();
        if (ctx == null) {
            return;
        }
        AlarmManager alarms = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        NotificationManager manager = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        SharedPreferences prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        for (String s : prefs.getStringSet(KEY_IDS, new HashSet<>())) {
            int id = Integer.parseInt(s);
            alarms.cancel(alarmIntent(ctx, id, "", ""));
            manager.cancel(id);
        }
        prefs.edit().remove(KEY_IDS).apply();
    }

    /** Pantau server tiap `intervalMinutes` saat game ditutup; teks notifikasi sudah diterjemahkan game. */
    @UsedByGodot
    public void start_server_watch(String url, String token, int intervalMinutes, String mailTitle, String soldTitle,
            String text) {
        Context ctx = context();
        if (ctx == null) {
            return;
        }
        long interval = Math.max(15, intervalMinutes) * 60000L;
        ctx.getSharedPreferences(PollReceiver.PREFS, Context.MODE_PRIVATE).edit()
                .putString("url", url).putString("token", token).putLong("interval", interval)
                .putLong("since", System.currentTimeMillis()).putString("mail_title", mailTitle)
                .putString("sold_title", soldTitle).putString("text", text).apply();
        PollReceiver.arm(ctx, interval);
    }

    @UsedByGodot
    public void stop_server_watch() {
        Context ctx = context();
        if (ctx == null) {
            return;
        }
        PollReceiver.disarm(ctx);
        ctx.getSharedPreferences(PollReceiver.PREFS, Context.MODE_PRIVATE).edit().clear().apply();
    }

    /** Buka menu bagikan Android untuk gambar di files/share/ (user://share/ di Godot). */
    @UsedByGodot
    public boolean share_image(String absolutePath, String text) {
        Activity activity = getActivity();
        if (activity == null) {
            return false;
        }
        try {
            File file = new File(absolutePath);
            Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".tlgshare", file);
            Intent send = new Intent(Intent.ACTION_SEND);
            send.setType("image/png");
            send.putExtra(Intent.EXTRA_STREAM, uri);
            send.putExtra(Intent.EXTRA_TEXT, text);
            send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            activity.startActivity(Intent.createChooser(send, null));
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
