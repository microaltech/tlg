package com.tlg.notify;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;

/**
 * Widget layar beranda: menampilkan ringkasan yang ditulis game saat ditutup
 * (TlgNotifyPlugin.update_widget). Teks sudah berisi jam ("Urusan penuh 14.30"), jadi
 * widget tidak perlu menghitung sendiri. Ketuk widget = buka game.
 */
public class TlgWidget extends AppWidgetProvider {
    static final String PREFS = "tlg_widget";

    @Override
    public void onUpdate(Context ctx, AppWidgetManager manager, int[] ids) {
        render(ctx, manager, ids);
    }

    static void refresh(Context ctx) {
        AppWidgetManager manager = AppWidgetManager.getInstance(ctx);
        int[] ids = manager.getAppWidgetIds(new ComponentName(ctx, TlgWidget.class));
        if (ids.length > 0) {
            render(ctx, manager, ids);
        }
    }

    static void render(Context ctx, AppWidgetManager manager, int[] ids) {
        SharedPreferences prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        Intent launch = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
        PendingIntent open = launch == null ? null : PendingIntent.getActivity(ctx, 9200, launch,
                PendingIntent.FLAG_UPDATE_CURRENT | TlgNotifyPlugin.immutableFlag());
        for (int id : ids) {
            RemoteViews views = new RemoteViews(ctx.getPackageName(), R.layout.tlg_widget);
            views.setTextViewText(R.id.tlg_widget_title, prefs.getString("title", "Tuan Nusantara"));
            views.setTextViewText(R.id.tlg_widget_line1, prefs.getString("line1", "Buka game untuk memulai."));
            views.setTextViewText(R.id.tlg_widget_line2, prefs.getString("line2", ""));
            views.setTextViewText(R.id.tlg_widget_line3, prefs.getString("line3", ""));
            if (open != null) {
                views.setOnClickPendingIntent(R.id.tlg_widget_root, open);
            }
            manager.updateAppWidget(id, views);
        }
    }
}
