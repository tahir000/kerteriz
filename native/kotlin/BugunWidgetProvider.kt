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
 * "Bugün" widget'ı: günün tamamı tek kartta. Ortada hazırlık, çevresinde
 * dört halka (adım, kalori, mesafe, su) ve tek dokunuşla su düğmesi.
 *
 * Su ve özet widget'larını ayrı ayrı koymak istemeyenler için. Veri
 * kaynakları onlarla aynı: ham sayılar ve su Health Connect'ten, skorlar
 * ve günün cümlesi uygulamanın yazdığı özet dosyasından.
 *
 * Üç boyut ([WidgetBoyut]):
 *  - küçük: dört halka, ortada hazırlık; dokunmak uygulamayı açar
 *  - orta: halkalar, dört sayı ve su düğmesi
 *  - büyük: artı uyku, dinlenme nabzı, hedef yatış ve günün cümlesi
 */
class BugunWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_SU = "com.kerteriz.kerteriz.BUGUN_SU_EKLE"
        const val ACTION_YENILE = "com.kerteriz.kerteriz.BUGUN_YENILE"

        /** Su değişti ya da uygulama yeni skor yazdı: bütün kopyaları çiz. */
        fun idler(context: Context): IntArray =
            AppWidgetManager.getInstance(context).getAppWidgetIds(
                ComponentName(context, BugunWidgetProvider::class.java)
            )

        suspend fun hepsiniCiz(context: Context, onayMl: Int? = null) {
            if (idler(context).isEmpty()) return
            cizHepsi(
                context, OzetOkuyucu.oku(context), SuKaydedici.bugunkuToplam(context),
                onayMl, null
            )
        }

        /** Okunmuş veriyle çizer; su animasyonunun kareleri bunu kullanıyor. */
        fun cizHepsi(
            context: Context,
            o: OzetOkuyucu.Ozet,
            su: Int,
            onayMl: Int?,
            dalga: Float?
        ) {
            val manager = AppWidgetManager.getInstance(context)
            idler(context).forEach { ciz(context, manager, it, o, su, onayMl, dalga) }
        }

        private fun ciz(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            o: OzetOkuyucu.Ozet,
            su: Int,
            onayMl: Int?,
            dalga: Float? = null
        ) {
            val yerel = Locale.getDefault()
            val h = AyarOkuyucu.hedefler(context)
            val hedefAdim = AyarOkuyucu.say(h, "adim", OzetWidgetProvider.HEDEF_ADIM)
            val hedefKalori = if (o.kaloriAktif) {
                AyarOkuyucu.say(h, "kaloriAktif", OzetWidgetProvider.HEDEF_KALORI_AKTIF)
            } else {
                AyarOkuyucu.say(h, "kalori", OzetWidgetProvider.HEDEF_KALORI)
            }
            val hedefMesafe =
                AyarOkuyucu.say(h, "mesafeOndaKm", OzetWidgetProvider.HEDEF_MESAFE_ONDA_KM) / 10.0
            val hedefSu = SuWidgetProvider.hedef(context)
            val porsiyon = SuWidgetProvider.porsiyon(context)

            val halka = HalkaCizer.ciz(
                halkalar = listOf(
                    HalkaCizer.Halka(
                        WidgetOrtak.oran(o.adim, hedefAdim),
                        WidgetOrtak.renk(context, R.color.kerteriz_halka_dis)
                    ),
                    HalkaCizer.Halka(
                        WidgetOrtak.oran(o.kaloriKcal, hedefKalori),
                        WidgetOrtak.renk(context, R.color.kerteriz_halka_orta)
                    ),
                    HalkaCizer.Halka(
                        WidgetOrtak.oran(o.mesafeKm, hedefMesafe),
                        WidgetOrtak.renk(context, R.color.kerteriz_halka_ic)
                    ),
                    HalkaCizer.Halka(
                        WidgetOrtak.oran(su, hedefSu),
                        WidgetOrtak.renk(context, R.color.kerteriz_halka_su)
                    )
                ),
                izRenk = WidgetOrtak.renk(context, R.color.kerteriz_halka_iz),
                boyutPx = WidgetOrtak.HALKA_PX,
                // Dört halka ortada hazırlık yazısına yer bırakmalı: daha ince.
                kalinlikPx = WidgetOrtak.HALKA_PX * 0.078f,
                araPx = WidgetOrtak.HALKA_PX * 0.032f,
                dalga = dalga
            )

            val skorlarVar = !o.bayat && o.hazirlik != null && o.hazirlik > 0
            val dugme = if (onayMl != null) {
                context.getString(R.string.su_eklendi, onayMl)
            } else {
                "+ $porsiyon ml"
            }

            WidgetBoyut.guncelle(context, manager, id) { boyut ->
                val layout = when (boyut) {
                    Boyut.KUCUK -> R.layout.bugun_kucuk
                    Boyut.ORTA -> R.layout.bugun_orta
                    Boyut.BUYUK -> R.layout.bugun_buyuk
                }
                RemoteViews(context.packageName, layout).apply {
                    setImageViewBitmap(R.id.bugun_halka, halka)
                    setTextViewText(R.id.bugun_hazirlik, if (skorlarVar) "${o.hazirlik}" else "--")
                    setTextViewText(R.id.bugun_adim, WidgetOrtak.bin(o.adim))
                    setTextViewText(R.id.bugun_kalori, "${WidgetOrtak.bin(o.kaloriKcal)} kcal")
                    setTextViewText(R.id.bugun_mesafe, "%.1f km".format(yerel, o.mesafeKm))
                    setTextViewText(
                        R.id.bugun_su,
                        "${WidgetOrtak.bin(su)} / ${WidgetOrtak.bin(hedefSu)} ml"
                    )
                    setTextViewText(
                        R.id.bugun_uyku,
                        if (skorlarVar && o.uykuSkoru != null) "${o.uykuSkoru}" else "--"
                    )
                    setTextViewText(
                        R.id.bugun_uyku_etiket,
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
                        R.id.bugun_nabiz,
                        if (skorlarVar && o.dinlenmeNabzi != null) "${o.dinlenmeNabzi}" else "--"
                    )
                    setTextViewText(R.id.bugun_yatis, o.yatis ?: "--")
                    setTextViewText(
                        R.id.bugun_cumle,
                        o.cumle ?: context.getString(R.string.ozet_bayat)
                    )
                    setTextViewText(R.id.bugun_buton, dugme)

                    setOnClickPendingIntent(
                        R.id.bugun_buton,
                        WidgetOrtak.yayin(context, BugunWidgetProvider::class.java, ACTION_SU, id)
                    )
                    // Halkaya dokunmak yeniler, kartın geri kalanı uygulamayı açar.
                    if (boyut != Boyut.KUCUK) {
                        setOnClickPendingIntent(
                            R.id.bugun_halka,
                            WidgetOrtak.yayin(
                                context, BugunWidgetProvider::class.java, ACTION_YENILE, id
                            )
                        )
                    }
                    WidgetOrtak.uygulamayiAc(this, context, R.id.bugun_kok, id)
                }
            }
        }
    }

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray
    ) {
        val bekleyen = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val o = OzetOkuyucu.oku(context)
                val su = SuKaydedici.bugunkuToplam(context)
                ids.forEach { ciz(context, manager, it, o, su, null) }
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
        val eylem = intent.action
        if (eylem != ACTION_SU && eylem != ACTION_YENILE) return

        val bekleyen = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                if (eylem == ACTION_SU) {
                    val ml = SuWidgetProvider.porsiyon(context)
                    SuKaydedici.ekle(context, ml)
                    SuAnimasyon.oynat(context, ml)
                } else {
                    hepsiniCiz(context)
                }
            } finally {
                bekleyen.finish()
            }
        }
    }
}
