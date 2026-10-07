package com.kerteriz.kerteriz

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.SizeF
import android.util.TypedValue
import android.widget.RemoteViews

/**
 * Widget'ların boyuta göre düzen değiştirmesi.
 *
 * Android 12+ (API 31): her boyut sınıfı için bir RemoteViews kurup sisteme
 * hepsini birden veriyoruz; başlatıcı widget büyütülüp küçültüldükçe en
 * uygun olanı kendisi seçiyor, uygulamanın uyanmasına gerek yok.
 *
 * Daha eski sürümler: widget'ın o anki boyutunu seçeneklerden okuyup tek bir
 * düzen veriyoruz; boyut değişince [AppWidgetProvider.onAppWidgetOptionsChanged]
 * yeniden çiziyor.
 */
enum class Boyut { KUCUK, ORTA, BUYUK }

object WidgetBoyut {

    // Eşikler dp. 2x2 genelde 110-170 dp genişliğinde, 4x2 ~150 dp
    // yüksekliğinde, 4x3 ve üstü 200 dp'yi geçiyor.
    private const val ORTA_GENISLIK = 200f
    private const val BUYUK_YUKSEKLIK = 200f

    fun sinif(genislikDp: Float, yukseklikDp: Float): Boyut = when {
        genislikDp < ORTA_GENISLIK -> Boyut.KUCUK
        yukseklikDp >= BUYUK_YUKSEKLIK -> Boyut.BUYUK
        else -> Boyut.ORTA
    }

    fun dp(context: Context, deger: Float): Float =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, deger, context.resources.displayMetrics
        )

    /** Her boyut için [kur] ile düzeni kurar ve widget'a verir. */
    fun guncelle(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        kur: (Boyut) -> RemoteViews
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            manager.updateAppWidget(
                id,
                RemoteViews(
                    mapOf(
                        SizeF(1f, 1f) to kur(Boyut.KUCUK),
                        SizeF(ORTA_GENISLIK, 1f) to kur(Boyut.ORTA),
                        SizeF(ORTA_GENISLIK, BUYUK_YUKSEKLIK) to kur(Boyut.BUYUK)
                    )
                )
            )
        } else {
            val o = manager.getAppWidgetOptions(id)
            // Dikey ekranda genişlik en küçük, yükseklik en büyük değerdir.
            val g = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250).toFloat()
            val y = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 110).toFloat()
            manager.updateAppWidget(id, kur(sinif(g, y)))
        }
    }
}

/**
 * Bütün Kerteriz widget'larını tazeler. Uygulama arka plana geçerken
 * (MainActivity.onStop) çağrılıyor: özet dosyası az önce yazıldı, widget'lar
 * 30 dakikalık periyodu beklemeden yeni skorları göstersin.
 */
object WidgetYenileyici {
    fun hepsi(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        listOf(
            SuWidgetProvider::class.java,
            OzetWidgetProvider::class.java,
            BugunWidgetProvider::class.java
        ).forEach { sinif ->
            val ids = manager.getAppWidgetIds(ComponentName(context, sinif))
            if (ids.isEmpty()) return@forEach
            context.sendBroadcast(
                Intent(context, sinif).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
            )
        }
    }
}
