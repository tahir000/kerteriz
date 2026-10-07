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
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
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
        const val ONAY_MS = 1800L

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
            val toplam = SuKaydedici.bugunkuToplam(context)
            SuOnbellek.yaz(context, toplam)
            cizHepsi(context, toplam, onayMl, null)
        }

        /**
         * Okunmuş toplamla çizer; animasyon kareleri bunu kullanıyor.
         * [halkaOrani] verilirse halka toplam yerine o oranda çizilir
         * (eski değerden yeni değere akarken).
         */
        fun cizHepsi(
            context: Context,
            toplam: Int,
            onayMl: Int?,
            dalga: HalkaCizer.Dalga?,
            halkaOrani: Float? = null
        ) {
            val manager = AppWidgetManager.getInstance(context)
            idler(context).forEach {
                ciz(context, manager, it, toplam, onayMl, dalga, halkaOrani)
            }
        }

        private fun ciz(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            toplam: Int,
            onayMl: Int?,
            dalga: HalkaCizer.Dalga? = null,
            halkaOrani: Float? = null
        ) {
            val hedef = hedef(context)
            val porsiyon = porsiyon(context)
            val oran = WidgetOrtak.oran(toplam, hedef)

            // Tek bitmap, üç düzen paylaşıyor.
            val halka = HalkaCizer.ciz(
                halkalar = listOf(
                    HalkaCizer.Halka(
                        halkaOrani ?: oran,
                        WidgetOrtak.renk(context, R.color.kerteriz_halka_su)
                    )
                ),
                izRenk = WidgetOrtak.renk(context, R.color.kerteriz_halka_iz),
                boyutPx = if (dalga != null) SuAnimasyon.KARE_PX else WidgetOrtak.HALKA_PX,
                kalinlikPx = (if (dalga != null) SuAnimasyon.KARE_PX else WidgetOrtak.HALKA_PX) * 0.105f,
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
                SuOnbellek.yaz(context, toplam)
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
                    // Yazma animasyonun içinde, arka planda: ilk kare beklemeden.
                    SuAnimasyon.oynat(context, porsiyon(context))
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
 * Son çizilen günlük toplam. Su eklenince efekt bundan başlıyor, Health
 * Connect'ten okumayı beklemiyor: dokunuşa anında tepki için. Gün değiştiyse
 * geçersiz.
 */
object SuOnbellek {
    private const val DOSYA = "kerteriz_su_widget"

    private fun bugun(): String = java.time.LocalDate.now().toString()

    fun oku(context: Context): Int? {
        val p = context.getSharedPreferences(DOSYA, Context.MODE_PRIVATE)
        return if (p.getString("gun", null) == bugun()) p.getInt("toplam", 0) else null
    }

    fun yaz(context: Context, toplam: Int) {
        context.getSharedPreferences(DOSYA, Context.MODE_PRIVATE).edit()
            .putString("gun", bugun()).putInt("toplam", toplam).apply()
    }
}

/**
 * Su eklenince oynayan efekt: halka eski değerden yeni değere akarak dolar,
 * yeni eklenen kısım dalgalanıp durulur, ucunda sönen bir ışıltı olur.
 *
 * Hız için iki şey: efekt son bilinen toplamdan hemen başlıyor ve Health
 * Connect'e yazma aynı anda arka planda yürüyor. Efekt bitince gerçek toplam
 * okunup son kare ona göre çiziliyor.
 *
 * Widget'lar animasyon oynatamıyor; kareler küçük bitmap'lerle arka arkaya
 * gönderiliyor. Yalnızca dokunuşta çalışıyor, pil açısından önemsiz.
 */
object SuAnimasyon {
    private const val KARE = 12
    private const val KARE_MS = 45L

    /** Animasyon karelerinin bitmap kenarı: aktarım yetişsin diye küçük. */
    const val KARE_PX = 200

    suspend fun oynat(context: Context, ml: Int) = coroutineScope {
        val eski = SuOnbellek.oku(context) ?: SuKaydedici.bugunkuToplam(context)
        val yazma = async { SuKaydedici.ekle(context, ml) }

        val hedef = SuWidgetProvider.hedef(context)
        val yeni = eski + ml
        val eskiOran = WidgetOrtak.oran(eski, hedef)
        val yeniOran = WidgetOrtak.oran(yeni, hedef)
        val bugunVar = BugunWidgetProvider.idler(context).isNotEmpty()
        val ozet = BugunWidgetProvider.sonOzet

        for (i in 1..KARE) {
            val p = i / KARE.toFloat()
            val e = 1f - (1f - p) * (1f - p) * (1f - p)
            val oran = eskiOran + (yeniOran - eskiOran) * e
            val d = HalkaCizer.Dalga(eskiOran, p)
            SuWidgetProvider.cizHepsi(context, yeni, ml, d, oran)
            if (bugunVar && ozet != null) {
                BugunWidgetProvider.cizHepsi(context, ozet, yeni, ml, d, oran)
            }
            delay(KARE_MS)
        }

        // Yazma bitti mi; gerçek toplamla son kare, onay biraz kalsın.
        yazma.await()
        val gercek = SuKaydedici.bugunkuToplam(context)
        SuOnbellek.yaz(context, gercek)
        SuWidgetProvider.cizHepsi(context, gercek, ml, null)
        if (bugunVar) BugunWidgetProvider.hepsiniCiz(context, onayMl = ml)
        delay(SuWidgetProvider.ONAY_MS)
        SuWidgetProvider.cizHepsi(context, gercek, null, null)
        val sonOzet = BugunWidgetProvider.sonOzet
        if (bugunVar && sonOzet != null) {
            BugunWidgetProvider.cizHepsi(context, sonOzet, gercek, null, null)
        }
    }
}
