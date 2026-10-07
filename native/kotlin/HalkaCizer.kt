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
     * Su eklenince en içteki halkanın efekti. [baslangic] eklemeden önceki
     * doluluk; halka oradan bugünkü değerine akarken yeni eklenen kısım
     * dalgalanıp duruluyor. [p] 0..1 ilerleme.
     */
    data class Dalga(val baslangic: Float, val p: Float)

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
        dalga: Dalga? = null
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
            if (dalga != null && i == halkalar.lastIndex) {
                dalgaCiz(tuval, merkez, yaricap, kalinlikPx, h.renk, dalga, oran)
            }
        }
        return bmp
    }

    /**
     * Yeni eklenen yayın üstünde sönümlenen dalga: kalınlık boyunca ilerleyen
     * bir sinüs, genliği [Dalga.p] ilerledikçe sıfıra iner. Ucunda da sönen
     * yumuşak bir ışıltı. Yay boyunca küçük dairelerle çiziliyor; daireler
     * halkanın rengiyle aynı ve opak, böylece kenar dalgalanıyor gibi görünüyor.
     */
    private fun dalgaCiz(
        tuval: Canvas,
        merkez: Float,
        yaricap: Float,
        kalinlik: Float,
        renk: Int,
        d: Dalga,
        oran: Float
    ) {
        val bas = d.baslangic.coerceIn(0f, oran)
        val uzunluk = oran - bas
        if (uzunluk <= 0.002f) return
        // Hızlı başla, yavaşlayarak durul.
        val e = 1f - (1f - d.p) * (1f - d.p) * (1f - d.p)
        val genlik = 1f - e
        if (genlik <= 0.01f) return

        val boya = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = renk }
        val adimDerece = 1.5f
        val toplamDerece = 360f * uzunluk
        val adim = (toplamDerece / adimDerece).toInt().coerceAtLeast(2)
        for (k in 0..adim) {
            val t = k / adim.toFloat()
            val aci = Math.toRadians((-90f + 360f * (bas + uzunluk * t)).toDouble())
            // Su önü: dalga uca yakın yerde en güçlü, geride sakinleşiyor.
            // Tepeler uca doğru ilerliyor, akış yönünde.
            val zarf = sin(Math.PI * Math.pow(t.toDouble(), 0.6)).toFloat()
            val tepe = 0.5f + 0.5f * sin(t * Math.PI * 5 - d.p * Math.PI * 6).toFloat()
            val r = kalinlik / 2f * (1f + 0.42f * genlik * zarf * tepe)
            tuval.drawCircle(
                merkez + (yaricap * cos(aci)).toFloat(),
                merkez + (yaricap * sin(aci)).toFloat(),
                r, boya
            )
        }

        // Su parıltısı: yeni dolan kısmın üstünde akan ince, açık bir şerit.
        // Uca doğru kayan bir parlaklık; su yüzeyindeki ışık gibi.
        val parilti = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeWidth = kalinlik * 0.22f
            color = Color.argb((120 * genlik).toInt(), 255, 255, 255)
        }
        val seritBas = bas + uzunluk * (0.15f + 0.5f * e)
        val seritUzun = (oran - seritBas) * 0.6f
        if (seritUzun > 0.002f) {
            val ry = yaricap - kalinlik * 0.18f
            tuval.drawArc(
                RectF(merkez - ry, merkez - ry, merkez + ry, merkez + ry),
                -90f + 360f * seritBas, 360f * seritUzun, false, parilti
            )
        }

        // Uçta sönen ışıltı.
        val ucAci = Math.toRadians((-90f + 360f * oran).toDouble())
        val ux = merkez + (yaricap * cos(ucAci)).toFloat()
        val uy = merkez + (yaricap * sin(ucAci)).toFloat()
        val beyaz = Color.argb((150 * genlik).toInt(), 255, 255, 255)
        val isilti = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(
                ux, uy, kalinlik * 0.9f,
                intArrayOf(beyaz, Color.argb(0, 255, 255, 255)),
                floatArrayOf(0f, 1f), Shader.TileMode.CLAMP
            )
        }
        tuval.drawCircle(ux, uy, kalinlik * 0.9f, isilti)
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
