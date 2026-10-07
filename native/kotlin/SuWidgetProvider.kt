package com.kerteriz.kerteriz

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Ana ekran su widget'ı: tek dokunuşla su ekler, hedefe göre halka gösterir.
 *
 * Üç boyut ([WidgetBoyut]):
 *  - küçük: halka ve toplam; widget'ın tamamı bir porsiyon ekleyen düğme
 *  - orta: halka, toplam, geri al ve düğme
 *  - büyük: büyük halka, durum satırı ve düğme
 *
 * Su eklenince düğme birkaç saniye "✓ +250 ml" gösterip normale dönüyor.
 * Widget'larda animasyon yok; yapılabilen geri bildirim bu ve düğmenin
 * dokunma dalgası.
 *
 * Widget uygulamanın kendi süreci içinde çalışır, dolayısıyla uygulamaya verilen
 * Health Connect izinlerini kullanır. Ayrı bir izin akışı yoktur.
 *
 * Yayın alıcısının süreci `onReceive` döndüğü anda öldürülebilir. Health Connect
 * yazması ve çizim askıya alınabilir (suspend) işler olduğu için her iş
 * `goAsync()` ile alınan bekleyen sonuca bağlanır; iş bitince `finish()` çağrılır.
 */
class SuWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_EKLE = "com.kerteriz.kerteriz.SU_EKLE"
        const val ACTION_GERI_AL = "com.kerteriz.kerteriz.SU_GERI_AL"
        // Bu iki sayı artık yalnızca VARSAYILAN: gerçek değeri kullanıcı
        // uygulamanın ayarlar ekranından seçiyor ve [AyarOkuyucu] onu
        // kerteriz_ozet.json üzerinden buraya taşıyor. patch_native.py
        // kurulumda lib/config.dart'taki değerleri buraya yazmaya devam
        // ediyor: uygulama hiç açılmadan widget eklenirse bunlar geçerli.
        private const val VARSAYILAN_PORSIYON = 250
        private const val VARSAYILAN_HEDEF = 2500

        /** Onay yazısının ekranda kalma süresi. */
        const val ONAY_MS = 2500L

        fun porsiyon(context: Context): Int =
            AyarOkuyucu.say(context, "suPorsiyon", VARSAYILAN_PORSIYON)

        fun hedef(context: Context): Int =
            AyarOkuyucu.say(context, "su", VARSAYILAN_HEDEF)

        fun idler(context: Context): IntArray =
            AppWidgetManager.getInstance(context).getAppWidgetIds(
                ComponentName(context, SuWidgetProvider::class.java)
            )

        /** Su değişti: bu widget'ın bütün kopyalarını çiz. */
        suspend fun hepsiniCiz(context: Context, onayMl: Int? = null) {
            if (idler(context).isEmpty()) return
            cizHepsi(context, SuKaydedici.bugunkuToplam(context), onayMl, null)
        }

        /** Okunmuş toplamla çizer; animasyon kareleri bunu kullanıyor. */
        fun cizHepsi(context: Context, toplam: Int, onayMl: Int?, dalga: Float?) {
            val manager = AppWidgetManager.getInstance(context)
            idler(context).forEach { ciz(context, manager, it, toplam, onayMl, dalga) }
        }

        private fun ciz(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            toplam: Int,
            onayMl: Int?,
            dalga: Float? = null
        ) {
            val hedef = hedef(context)
            val porsiyon = porsiyon(context)
            val oran = WidgetOrtak.oran(toplam, hedef)

            // Tek bitmap, üç düzen paylaşıyor.
            val halka = HalkaCizer.ciz(
                halkalar = listOf(
                    HalkaCizer.Halka(oran, WidgetOrtak.renk(context, R.color.kerteriz_halka_su))
                ),
                izRenk = WidgetOrtak.renk(context, R.color.kerteriz_halka_iz),
                boyutPx = WidgetOrtak.HALKA_PX,
                kalinlikPx = WidgetOrtak.HALKA_PX * 0.105f,
                araPx = 0f,
                dalga = dalga
            )
            val durum = when {
                toplam >= hedef -> context.getString(R.string.su_hedef_tamam)
                else -> context.getString(R.string.su_kalan, hedef - toplam)
            }
            val dugme = if (onayMl != null) {
                context.getString(R.string.su_eklendi, onayMl)
            } else {
                "+ $porsiyon ml"
            }

            WidgetBoyut.guncelle(context, manager, id) { boyut ->
                val layout = when (boyut) {
                    Boyut.KUCUK -> R.layout.su_kucuk
                    Boyut.ORTA -> R.layout.su_orta
                    Boyut.BUYUK -> R.layout.su_buyuk
                }
                RemoteViews(context.packageName, layout).apply {
                    setImageViewBitmap(R.id.su_halka, halka)
                    setTextViewText(R.id.su_toplam, WidgetOrtak.bin(toplam))
                    setTextViewText(R.id.su_hedef, "/ ${WidgetOrtak.bin(hedef)} ml")
                    setTextViewText(R.id.su_yuzde, WidgetOrtak.yuzde(oran))
                    // Orta boyutta durum satırı yok: boş satır yer kaplayıp
                    // halkanın ortasındaki yüzdeyi yukarı itiyordu.
                    setTextViewText(R.id.su_durum, durum)
                    setViewVisibility(
                        R.id.su_durum,
                        if (boyut == Boyut.ORTA) View.GONE else View.VISIBLE
                    )
                    setTextViewText(R.id.su_buton, dugme)

                    val ekle = WidgetOrtak.yayin(
                        context, SuWidgetProvider::class.java, ACTION_EKLE, id
                    )
                    if (boyut == Boyut.KUCUK) {
                        // Küçük boyutta bütün kart düğme.
                        setOnClickPendingIntent(R.id.su_kok, ekle)
                    } else {
                        setOnClickPendingIntent(R.id.su_buton, ekle)
                        setOnClickPendingIntent(
                            R.id.su_geri_al,
                            WidgetOrtak.yayin(
                                context, SuWidgetProvider::class.java, ACTION_GERI_AL, id
                            )
                        )
                        WidgetOrtak.uygulamayiAc(this, context, R.id.su_halka, id)
                    }
                }
            }
        }
    }

    /**
     * Periyodik güncelleme ve widget eklenmesi. `super.onReceive` bu metodu
     * ACTION_APPWIDGET_UPDATE için kendisi çağırır; `onReceive` içinde ayrıca
     * ele alınmaz, yoksa her güncellemede iki kez çizilirdi.
     */
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray
    ) {
        val bekleyen = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val toplam = SuKaydedici.bugunkuToplam(context)
                ids.forEach { ciz(context, manager, it, toplam, null) }
            } finally {
                bekleyen.finish()
            }
        }
    }

    /** Eski Android'de boyut değişince düzeni yeniden seç. */
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
        if (eylem != ACTION_EKLE && eylem != ACTION_GERI_AL) return

        val bekleyen = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                if (eylem == ACTION_EKLE) {
                    val ml = porsiyon(context)
                    SuKaydedici.ekle(context, ml)
                    SuAnimasyon.oynat(context, ml)
                } else {
                    SuKaydedici.sonKaydiSil(context)
                    hepsiniCiz(context)
                    BugunWidgetProvider.hepsiniCiz(context)
                }
            } finally {
                bekleyen.finish()
            }
        }
    }
}

/**
 * Su eklenince oynayan efekt: halkanın içinden merkeze yayılan damla dalgası
 * ve düğmede kısa bir onay.
 *
 * Widget'lar animasyon oynatamıyor; başlatıcının dokunma dalgası da her
 * başlatıcıda görünmüyor (Honor'da görünmüyordu). Bu yüzden efekti biz
 * çiziyoruz: veri bir kez okunuyor, sonra altı kare ~110 ms arayla
 * gönderiliyor. Yalnızca dokunuşta çalışıyor, pil açısından önemsiz.
 */
object SuAnimasyon {
    private val KARELER = floatArrayOf(0.12f, 0.3f, 0.48f, 0.66f, 0.84f, 1.05f, 1.3f)
    private const val KARE_MS = 110L

    suspend fun oynat(context: Context, ml: Int) {
        val toplam = SuKaydedici.bugunkuToplam(context)
        val bugunVar = BugunWidgetProvider.idler(context).isNotEmpty()
        val ozet = if (bugunVar) OzetOkuyucu.oku(context) else null

        for (p in KARELER) {
            SuWidgetProvider.cizHepsi(context, toplam, ml, p)
            if (ozet != null) BugunWidgetProvider.cizHepsi(context, ozet, toplam, ml, p)
            delay(KARE_MS)
        }
        // Onay biraz daha kalsın, sonra normale dön.
        SuWidgetProvider.cizHepsi(context, toplam, ml, null)
        if (ozet != null) BugunWidgetProvider.cizHepsi(context, ozet, toplam, ml, null)
        delay(SuWidgetProvider.ONAY_MS - KARELER.size * KARE_MS)
        SuWidgetProvider.cizHepsi(context, toplam, null, null)
        if (ozet != null) BugunWidgetProvider.cizHepsi(context, ozet, toplam, null, null)
    }
}
