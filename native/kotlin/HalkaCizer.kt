package com.kerteriz.kerteriz

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * Eş merkezli ilerleme halkalarını bitmap olarak çizer.
 *
 * Ana ekran widget'ları yay çizemez (RemoteViews yalnızca hazır görünümleri
 * tanır), bu yüzden halkayı biz çizip `setImageViewBitmap` ile veriyoruz.
 *
 * Görünüm:
 *  - Her halka başından sonuna açık tondan tam tona bir gradyanla dolar.
 *  - Hedef aşılınca halka ikinci tur atar: ilk tur tam daire, ikinci tur
 *    halkanın tam renginde üstüne biner ve ucunda küçük bir gölge olur,
 *    böylece tur başlangıcının üstüne bindiği yer okunur. En çok iki tur.
 *  - İz (boş kısım) soluk bir halkadır; renkleri çağıran verir, koyu temada
 *    farklı geliyor.
 *
 * Renk tek başına anlam taşımıyor: widget'lar her halkanın yanında sayıyı
 * da yazıyor.
 */
object HalkaCizer {

    data class Halka(val oran: Float, val renk: Int)

    /**
     * [halkalar] dıştan içe. [boyutPx] kare kenarı, [kalinlikPx] tek halkanın
     * kalınlığı, [araPx] iki halka arası boşluk, [izRenk] boş kısmın rengi.
     */
    fun ciz(
        halkalar: List<Halka>,
        izRenk: Int,
        boyutPx: Int,
        kalinlikPx: Float,
        araPx: Float,
        dalga: Float? = null
    ): Bitmap {
        val bmp = Bitmap.createBitmap(boyutPx, boyutPx, Bitmap.Config.ARGB_8888)
        val tuval = Canvas(bmp)
        tuval.drawColor(Color.TRANSPARENT)
        val merkez = boyutPx / 2f

        val boya = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeWidth = kalinlikPx
        }

        halkalar.forEachIndexed { i, h ->
            // Gölge payı: dış halkanın gölgesi bitmap sınırına taşmasın.
            val pay = kalinlikPx * 0.35f
            val ic = kalinlikPx / 2f + pay + i * (kalinlikPx + araPx)
            val kutu = RectF(ic, ic, boyutPx - ic, boyutPx - ic)
            val yaricap = merkez - ic

            boya.shader = null
            boya.clearShadowLayer()
            boya.color = izRenk
            tuval.drawArc(kutu, 0f, 360f, false, boya)

            val oran = h.oran.coerceIn(0f, 2f)
            if (oran <= 0f) return@forEachIndexed

            // Yuvarlak uç, yayın başından yarım kalınlık kadar geriye taşar.
            // Gradyanı o kadar geri döndürüyoruz ki uç da açık tonda kalsın,
            // yoksa saat 12'de koyu bir dikiş görünür.
            val ucDerece = Math.toDegrees((kalinlikPx / 2f / yaricap).toDouble()).toFloat()
            val ilkTur = min(oran, 1f)
            boya.shader = gradyan(
                merkez, acik(h.renk), h.renk,
                bitisOrani = ilkTur, ucDerece = ucDerece
            )
            boya.color = Color.WHITE
            tuval.drawArc(kutu, -90f, 360f * ilkTur, false, boya)

            if (oran > 1f) {
                // İkinci tur: halkanın tam rengi, ucunda gölge. Koyu ton
                // koyu temada griye dönüp leke gibi görünüyordu.
                val ikinci = oran - 1f
                boya.shader = null
                boya.color = h.renk

                // Gölgeyi yalnızca uca koymak için önce gölgeli küçük bir yay,
                // sonra gölgesiz tam yay çiziliyor; gölge yayın gövdesine
                // değil, başlangıcın üstüne binen uca düşüyor.
                val sonAci = -90f + 360f * ikinci
                boya.setShadowLayer(kalinlikPx * 0.3f, 0f, 0f, 0x66000000)
                tuval.drawArc(kutu, sonAci - 2f, 2f, false, boya)
                boya.clearShadowLayer()
                tuval.drawArc(kutu, -90f, 360f * ikinci, false, boya)
            } else if (oran >= 0.999f) {
                // Tam tur: başlangıç noktasına küçük bir koyu nokta, halkanın
                // kapandığı yer belli olsun.
                val a = Math.toRadians(-90.0)
                val nokta = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = koyu(h.renk) }
                tuval.drawCircle(
                    merkez + (yaricap * cos(a)).toFloat(),
                    merkez + (yaricap * sin(a)).toFloat(),
                    kalinlikPx * 0.18f, nokta
                )
            }
        }
        // Damla dalgası: su eklenince en içteki halkanın iç kenarından merkeze
        // doğru yayılıp sönen iki yumuşak ışıltı. Keskin çizgi yerine kenarları
        // sönen bir bant: widget kare kare güncellendiği için (SuAnimasyon)
        // sert kenarlar kareler arasındaki atlamayı belli ediyordu.
        if (dalga != null && halkalar.isNotEmpty()) {
            val son = halkalar.last()
            val icKenar = merkez - (kalinlikPx / 2f + kalinlikPx * 0.35f +
                (halkalar.size - 1) * (kalinlikPx + araPx)) - kalinlikPx / 2f
            if (icKenar > 1f) {
                val bant = kalinlikPx * 1.4f
                val dalgaBoya = Paint(Paint.ANTI_ALIAS_FLAG)
                for (k in 0..1) {
                    val p = ((dalga - k * 0.28f) / 0.72f).coerceIn(0f, 1f)
                    if (p <= 0f || p >= 1f) continue
                    // Hızlı başla, yavaşlayarak sön.
                    val e = 1f - (1f - p) * (1f - p) * (1f - p)
                    val r = icKenar * (1f - 0.82f * e)
                    val alfa = (0.5f * (1f - e) * (if (k == 0) 1f else 0.7f) * 255).toInt()
                    if (alfa <= 2) continue
                    val renk = Color.argb(alfa, Color.red(son.renk), Color.green(son.renk), Color.blue(son.renk))
                    val seffaf = Color.argb(0, Color.red(son.renk), Color.green(son.renk), Color.blue(son.renk))
                    val ic = ((r - bant) / icKenar).coerceIn(0f, 1f)
                    val orta = (r / icKenar).coerceIn(0f, 1f)
                    val dis = ((r + bant) / icKenar).coerceIn(0f, 1f)
                    if (!(ic < orta && orta < dis)) continue
                    dalgaBoya.shader = RadialGradient(
                        merkez, merkez, icKenar,
                        intArrayOf(seffaf, seffaf, renk, seffaf, seffaf),
                        floatArrayOf(0f, ic, orta, dis, 1f),
                        Shader.TileMode.CLAMP
                    )
                    tuval.drawCircle(merkez, merkez, icKenar, dalgaBoya)
                }
            }
        }
        return bmp
    }

    private fun gradyan(
        merkez: Float,
        bas: Int,
        son: Int,
        bitisOrani: Float,
        ucDerece: Float
    ): SweepGradient {
        val basKonum = 0f
        val sonKonum = (bitisOrani + ucDerece / 360f).coerceAtMost(1f)
        val g = SweepGradient(
            merkez, merkez,
            intArrayOf(bas, bas, son, son),
            floatArrayOf(basKonum, ucDerece / 360f, sonKonum, 1f)
        )
        // SweepGradient saat 3'ten başlar; saat 12'ye ve ucun gerisine çevir.
        g.setLocalMatrix(Matrix().apply { setRotate(-90f - ucDerece, merkez, merkez) })
        return g
    }

    /** Rengin beyaza doğru %45 açılmış hali. */
    fun acik(renk: Int): Int = karistir(renk, Color.WHITE, 0.45f)

    /** Rengin siyaha doğru %22 koyulaşmış hali. */
    fun koyu(renk: Int): Int = karistir(renk, Color.BLACK, 0.22f)

    private fun karistir(a: Int, b: Int, t: Float): Int = Color.argb(
        Color.alpha(a),
        (Color.red(a) + (Color.red(b) - Color.red(a)) * t).toInt(),
        (Color.green(a) + (Color.green(b) - Color.green(a)) * t).toInt(),
        (Color.blue(a) + (Color.blue(b) - Color.blue(a)) * t).toInt()
    )
}
