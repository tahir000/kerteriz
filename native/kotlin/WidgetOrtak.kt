package com.kerteriz.kerteriz

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Locale

/**
 * Üç widget'ın ortak parçaları: renkler, dokunma niyetleri, sayı biçimleri.
 */
object WidgetOrtak {

    /**
     * Halka bitmap'inin kenarı (px). Üç boyutun düzeni aynı Bitmap nesnesini
     * paylaşıyor; RemoteViews aynı bitmap'i bir kez taşıyor. Binder aktarımı
     * 1 MB ile sınırlı: 320 px ARGB ~400 KB, sınırın rahatça altında.
     * ImageView büyük boyutta da bunu ölçekliyor.
     */
    const val HALKA_PX = 320

    fun renk(context: Context, id: Int): Int = context.getColor(id)

    /** Uygulamayı açan dokunuş. */
    fun uygulamayiAc(views: RemoteViews, context: Context, viewId: Int, istek: Int) {
        val ac = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return
        ac.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        views.setOnClickPendingIntent(
            viewId,
            PendingIntent.getActivity(
                context, istek, ac,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
    }

    /** Sağlayıcıya geri dönen yayın: su ekle, geri al, yenile. */
    fun yayin(context: Context, sinif: Class<*>, eylem: String, id: Int): PendingIntent {
        val intent = Intent(context, sinif).apply {
            action = eylem
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
        }
        return PendingIntent.getBroadcast(
            context,
            eylem.hashCode() + id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Binlik ayraçlı sayı; cihazın diline göre nokta ya da virgül. */
    fun bin(deger: Int, yerel: Locale = Locale.getDefault()): String =
        "%,d".format(yerel, deger)

    fun yuzde(oran: Float): String = "${(oran * 100).toInt().coerceAtLeast(0)}%"

    fun oran(deger: Number, hedef: Number): Float {
        val h = hedef.toDouble()
        return if (h > 0) (deger.toDouble() / h).toFloat() else 0f
    }

    fun sure(dakika: Int): String = "%dsa %02ddk".format(dakika / 60, dakika % 60)
}
