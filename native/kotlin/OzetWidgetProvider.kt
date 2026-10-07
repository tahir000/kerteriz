package com.kerteriz.kerteriz

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Locale

/**
 * Google Health'in kendi widget'ının Kerteriz karşılığı: günün adımı,
 * kalorisi ve mesafesi üç halka olarak.
 *
 * Üç boyut ([WidgetBoyut]):
 *  - küçük: halkalar, ortada adım yüzdesi
 *  - orta: halkalar ve üç sayı
 *  - büyük: artı hazırlık, uyku, dinlenme nabzı ve günün cümlesi
 *
 * Ham sayılar doğrudan Health Connect'ten okunur. Türetilmiş skorlar
 * uygulamanın yazdığı `kerteriz_ozet.json` dosyasından gelir; uygulama bir
 * buçuk gündür açılmadıysa o kutular boş kalır ve altta uyarı çıkar.
 *
 * Halkaya dokunmak widget'ı yeniler, geri kalan her yer uygulamayı açar.
 * Agresif pil yönetimi olan cihazlarda (Honor MagicOS, Xiaomi, Samsung)
 * periyodik güncelleme atlanabildiği için elle yenileme şart.
 */
class OzetWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_YENILE = "com.kerteriz.kerteriz.OZET_YENILE"

        // Bu dört sayı artık yalnızca VARSAYILAN: gerçek hedefi kullanıcı
        // uygulamanın ayarlar ekranından seçiyor ve [AyarOkuyucu] onu
        // kerteriz_ozet.json üzerinden buraya taşıyor. patch_native.py
        // kurulumda lib/config.dart'taki değerleri buraya yazmaya devam
        // ediyor: uygulama hiç açılmadan widget eklenirse bunlar geçerli.
        const val HEDEF_ADIM = 10000
        const val HEDEF_KALORI = 2400

        // Cihaz yalnizca AKTIF kalori yaziyorsa olcek bu hedefe gore kurulur;
        // aktif kalori toplam kalorinin yanina konamaz.
        const val HEDEF_KALORI_AKTIF = 600
        // Kilometrenin onda biri cinsinden: 70 = 7,0 km
        const val HEDEF_MESAFE_ONDA_KM = 70
    }

    /** Hedefler: kullanıcının ayarlarından; dosya yoksa gömülü varsayılan. */
    data class Hedefler(val adim: Int, val kalori: Int, val mesafeKm: Double)

    private fun hedefler(context: Context, o: OzetOkuyucu.Ozet): Hedefler {
        val h = AyarOkuyucu.hedefler(context)
        return Hedefler(
            adim = AyarOkuyucu.say(h, "adim", HEDEF_ADIM),
            kalori = if (o.kaloriAktif) {
                AyarOkuyucu.say(h, "kaloriAktif", HEDEF_KALORI_AKTIF)
            } else {
                AyarOkuyucu.say(h, "kalori", HEDEF_KALORI)
            },
            mesafeKm = AyarOkuyucu.say(h, "mesafeOndaKm", HEDEF_MESAFE_ONDA_KM) / 10.0
        )
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

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        yeni: Bundle
    ) {
        onUpdate(context, manager, intArrayOf(id))
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_YENILE) return
        val manager = AppWidgetManager.getInstance(context)
        onUpdate(
            context, manager,
            manager.getAppWidgetIds(ComponentName(context, OzetWidgetProvider::class.java))
        )
    }

    private fun ciz(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        o: OzetOkuyucu.Ozet
    ) {
        val yerel = Locale.getDefault()
        val h = hedefler(context, o)
        val oranAdim = WidgetOrtak.oran(o.adim, h.adim)

        val halka = HalkaCizer.ciz(
            halkalar = listOf(
                HalkaCizer.Halka(oranAdim, WidgetOrtak.renk(context, R.color.kerteriz_halka_dis)),
                HalkaCizer.Halka(
                    WidgetOrtak.oran(o.kaloriKcal, h.kalori),
                    WidgetOrtak.renk(context, R.color.kerteriz_halka_orta)
                ),
                HalkaCizer.Halka(
                    WidgetOrtak.oran(o.mesafeKm, h.mesafeKm),
                    WidgetOrtak.renk(context, R.color.kerteriz_halka_ic)
                )
            ),
            izRenk = WidgetOrtak.renk(context, R.color.kerteriz_halka_iz),
            boyutPx = WidgetOrtak.HALKA_PX,
            kalinlikPx = WidgetOrtak.HALKA_PX * 0.095f,
            araPx = WidgetOrtak.HALKA_PX * 0.045f
        )

        val skorlarVar = !o.bayat && o.hazirlik != null && o.hazirlik > 0
        val yenile = WidgetOrtak.yayin(context, OzetWidgetProvider::class.java, ACTION_YENILE, id)

        WidgetBoyut.guncelle(context, manager, id) { boyut ->
            val layout = when (boyut) {
                Boyut.KUCUK -> R.layout.ozet_kucuk
                Boyut.ORTA -> R.layout.ozet_orta
                Boyut.BUYUK -> R.layout.ozet_buyuk
            }
            RemoteViews(context.packageName, layout).apply {
                setImageViewBitmap(R.id.ozet_halka, halka)
                setTextViewText(R.id.ozet_merkez, WidgetOrtak.yuzde(oranAdim))

                setTextViewText(
                    R.id.ozet_adim_deger,
                    "%s / %s".format(yerel, WidgetOrtak.bin(o.adim), WidgetOrtak.bin(h.adim))
                )
                setTextViewText(
                    R.id.ozet_kalori_deger,
                    "%s / %s".format(yerel, WidgetOrtak.bin(o.kaloriKcal), WidgetOrtak.bin(h.kalori))
                )
                setTextViewText(
                    R.id.ozet_mesafe_deger,
                    "%.1f / %.1f km".format(yerel, o.mesafeKm, h.mesafeKm)
                )

                setTextViewText(R.id.ozet_hazirlik, if (skorlarVar) "${o.hazirlik}" else "--")
                setTextViewText(
                    R.id.ozet_uyku,
                    if (skorlarVar && o.uykuSkoru != null) "${o.uykuSkoru}" else "--"
                )
                setTextViewText(
                    R.id.ozet_uyku_etiket,
                    if (skorlarVar && o.uykuDakika != null && o.uykuDakika > 0) {
                        "%s · %s".format(
                            yerel,
                            context.getString(R.string.ozet_uyku_etiket),
                            WidgetOrtak.sure(o.uykuDakika)
                        )
                    } else {
                        context.getString(R.string.ozet_uyku_etiket)
                    }
                )
                setTextViewText(
                    R.id.ozet_nabiz,
                    if (skorlarVar && o.dinlenmeNabzi != null) "${o.dinlenmeNabzi}" else "--"
                )
                setTextViewText(
                    R.id.ozet_not,
                    context.getString(if (skorlarVar) R.string.ozet_yenile else R.string.ozet_bayat)
                )
                setTextViewText(R.id.ozet_cumle, o.cumle ?: "")

                if (boyut == Boyut.KUCUK) {
                    // Küçük boyutta kartın tamamı yenileme.
                    setOnClickPendingIntent(R.id.ozet_kok, yenile)
                } else {
                    setOnClickPendingIntent(R.id.ozet_halka, yenile)
                    WidgetOrtak.uygulamayiAc(this, context, R.id.ozet_kok, id)
                }
            }
        }
    }
}
