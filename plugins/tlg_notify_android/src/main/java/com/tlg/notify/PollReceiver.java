package com.tlg.notify;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;

/**
 * Pemantau server tanpa Firebase: alarm tidak-eksak berulang (beberapa jam sekali) memanggil
 * GET /v1/notices dan menampilkan notifikasi bila ada surat baru atau dagangan yang laku.
 * Alamat server dan token disimpan di SharedPreferences privat aplikasi oleh TlgNotifyPlugin.
 */
public class PollReceiver extends BroadcastReceiver {
    static final String PREFS = "tlg_poll";
    static final int NOTIFY_ID = 9100;

    static PendingIntent intent(Context ctx) {
        Intent i = new Intent(ctx, PollReceiver.class);
        return PendingIntent.getBroadcast(ctx, NOTIFY_ID, i,
                PendingIntent.FLAG_UPDATE_CURRENT | TlgNotifyPlugin.immutableFlag());
    }

    static void arm(Context ctx, long intervalMs) {
        AlarmManager alarms = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        alarms.setInexactRepeating(AlarmManager.RTC, System.currentTimeMillis() + intervalMs, intervalMs, intent(ctx));
    }

    static void disarm(Context ctx) {
        AlarmManager alarms = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        alarms.cancel(intent(ctx));
    }

    @Override
    public void onReceive(Context ctx, Intent intent) {
        final SharedPreferences prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        final String url = prefs.getString("url", "");
        final String token = prefs.getString("token", "");
        if (url.isEmpty() || token.isEmpty()) {
            return;
        }
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            arm(ctx, prefs.getLong("interval", 4 * 3600000L));
            return;
        }
        final Context app = ctx.getApplicationContext();
        final PendingResult pending = goAsync();
        new Thread(() -> {
            try {
                long since = prefs.getLong("since", System.currentTimeMillis());
                HttpURLConnection c = (HttpURLConnection) new URL(url + "/v1/notices?since=" + since).openConnection();
                c.setConnectTimeout(10000);
                c.setReadTimeout(10000);
                c.setRequestProperty("Authorization", "Bearer " + token);
                if (c.getResponseCode() == 200) {
                    InputStream in = c.getInputStream();
                    ByteArrayOutputStream out = new ByteArrayOutputStream();
                    byte[] buf = new byte[4096];
                    int n;
                    while ((n = in.read(buf)) > 0) {
                        out.write(buf, 0, n);
                    }
                    JSONObject data = new JSONObject(out.toString("UTF-8"));
                    int mail = data.optInt("mail", 0);
                    int sold = data.optInt("sold", 0);
                    prefs.edit().putLong("since", data.optLong("t", System.currentTimeMillis())).apply();
                    if (mail > 0 || sold > 0) {
                        String title = sold > 0 ? prefs.getString("sold_title", "Dagangan laku!")
                                : prefs.getString("mail_title", "Surat baru dari istana");
                        String text = prefs.getString("text", "Buka game untuk mengambil hadiahnya.");
                        Intent show = new Intent(app, NotifyReceiver.class);
                        show.putExtra(NotifyReceiver.EXTRA_ID, NOTIFY_ID);
                        show.putExtra(NotifyReceiver.EXTRA_TITLE, title);
                        show.putExtra(NotifyReceiver.EXTRA_TEXT, text);
                        new NotifyReceiver().onReceive(app, show);
                    }
                }
                c.disconnect();
            } catch (Exception ignored) {
                // Jaringan mati atau server tidak ada: coba lagi pada jadwal berikutnya.
            } finally {
                pending.finish();
            }
        }).start();
    }
}
