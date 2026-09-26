package com.kerteriz.kerteriz

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.TypedValue
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Locale

/**
 * Google Health'in kendi widget'ının Kerteriz karşılığı: günün adımı,
 * kalorisi ve mesafesi üç halka olarak; altında hazırlık, uyku ve dinlenme
 * nabzı.
 *
 * Ham sayılar doğrudan Health Connect'ten okunur. Türetilmiş skorlar
 * uygulamanın yazdığı `kerteriz_ozet.json` dosyasından gelir; uygulama bir
 * buçuk gündür açılmadıysa o üç kutu boş kalır ve altta uyarı çıkar.
 *
 * Halkaya dokunmak widget'ı yeniler, geri kalan her yer uygulamayı açar.
 * Agresif pil yönetimi olan cihazlarda (Honor MagicOS, Xiaomi, Samsung)
 * periyodik güncelleme atlanabildiği için elle yenileme şart.
 */
class OzetWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_YENILE = "com.kerteriz.kerteriz.OZET_YENILE"

        // Bu üç sayıyı elle değiştirme: patch_native.py kurulum sırasında
        // lib/config.dart içindeki hedeflerle değiştirir.
        private const val HEDEF_ADIM = 10000
        private const val HEDEF_KALORI = 2400

        // Cihaz yalnizca AKTIF kalori yaziyorsa olcek bu hedefe gore kurulur;
        // aktif kalori toplam kalorinin yanina konamaz.
        private const val HEDEF_KALORI_AKTIF = 600
        // Kilometrenin onda biri cinsinden: 70 = 7,0 km
        private const val HEDEF_MESAFE_ONDA_KM = 70
    }

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray
    ) {
        val bekleyen = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Okuma bir kez: ayni widget'tan iki kopya varsa Health
                // Connect'e iki tur gitmeye gerek yok.
                val o = OzetOkuyucu.oku(context)
                ids.forEach { ciz(context, manager, it, o) }
            } finally {
                bekleyen.finish()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_YENILE) return

        val bekleyen = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(
                    ComponentName(context, OzetWidgetProvider::class.java)
                )
                val o = OzetOkuyucu.oku(context)
                ids.forEach { ciz(context, manager, it, o) }
            } finally {
                bekleyen.finish()
            }
        }
    }

    private fun dp(context: Context, deger: Float): Float =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, deger, context.resources.displayMetrics
        )

    private fun ciz(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        o: OzetOkuyucu.Ozet
    ) {
        val views = RemoteViews(context.packageName, R.layout.ozet_widget)
        val yerel = Locale.getDefault()

        val hedefMesafeKm = HEDEF_MESAFE_ONDA_KM / 10.0
        val hedefKalori = if (o.kaloriAktif) HEDEF_KALORI_AKTIF else HEDEF_KALORI

        // --- halkalar ---
        // Yogunlugu yuksek ekranlarda bitmap RemoteViews'in aktarim sinirini
        // zorlamasin diye tavan koyuyoruz; ImageView kalani kendisi olcekler.
        val boyut = minOf(dp(context, 88f).toInt(), 264)
        val bmp = HalkaCizer.ciz(
            oranlar = listOf(
                if (HEDEF_ADIM > 0) o.adim.toFloat() / HEDEF_ADIM else 0f,
                if (hedefKalori > 0) o.kaloriKcal.toFloat() / hedefKalori else 0f,
                if (hedefMesafeKm > 0) (o.mesafeKm / hedefMesafeKm).toFloat() else 0f
            ),
            boyutPx = boyut,
            kalinlikPx = boyut * 0.095f,
            araPx = boyut * 0.045f
        )
        views.setImageViewBitmap(R.id.ozet_halka, bmp)

        // --- ham sayilar ---
        views.setTextViewText(
            R.id.ozet_adim_deger,
            "%s / %s".format(yerel, bin(o.adim, yerel), bin(HEDEF_ADIM, yerel))
        )
        views.setTextViewText(
            R.id.ozet_kalori_deger,
            "%s / %s".format(yerel, bin(o.kaloriKcal, yerel), bin(hedefKalori, yerel))
        )
        views.setTextViewText(
            R.id.ozet_mesafe_deger,
            "%.1f / %.1f km".format(yerel, o.mesafeKm, hedefMesafeKm)
        )

        // --- turetilmis skorlar ---
        val skorlarVar = !o.bayat && o.hazirlik != null && o.hazirlik > 0
        views.setTextViewText(
            R.id.ozet_hazirlik,
            if (skorlarVar) "${o.hazirlik}" else "--"
        )
        views.setTextViewText(
            R.id.ozet_uyku,
            if (skorlarVar && o.uykuSkoru != null) "${o.uykuSkoru}" else "--"
        )
        views.setTextViewText(
            R.id.ozet_uyku_etiket,
            if (skorlarVar && o.uykuDakika != null && o.uykuDakika > 0) {
                "%s · %dsa %02ddk".format(
                    yerel,
                    context.getString(R.string.ozet_uyku_etiket),
                    o.uykuDakika / 60,
                    o.uykuDakika % 60
                )
            } else {
                context.getString(R.string.ozet_uyku_etiket)
            }
        )
        views.setTextViewText(
            R.id.ozet_nabiz,
            if (skorlarVar && o.dinlenmeNabzi != null) "${o.dinlenmeNabzi}" else "--"
        )
        views.setTextViewText(
            R.id.ozet_not,
            context.getString(if (skorlarVar) R.string.ozet_yenile else R.string.ozet_bayat)
        )

        // --- dokunuslar ---
        val yenile = Intent(context, OzetWidgetProvider::class.java).apply {
            action = ACTION_YENILE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
        }
        views.setOnClickPendingIntent(
            R.id.ozet_halka,
            PendingIntent.getBroadcast(
                context,
                ACTION_YENILE.hashCode() + id,
                yenile,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )

        val ac = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (ac != null) {
            ac.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            views.setOnClickPendingIntent(
                R.id.ozet_kok,
                PendingIntent.getActivity(
                    context,
                    id,
                    ac,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }

        manager.updateAppWidget(id, views)
    }

    /** Binlik ayraçlı sayı; cihazın diline göre nokta ya da virgül. */
    private fun bin(deger: Int, yerel: Locale): String = "%,d".format(yerel, deger)
}
