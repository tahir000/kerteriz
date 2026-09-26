package com.kerteriz.kerteriz

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF

/**
 * Üç eş merkezli halka çizip bitmap döndürür.
 *
 * Ana ekran widget'ları yay çizemez (RemoteViews yalnızca hazır görünümleri
 * tanır), bu yüzden halkayı biz çizip `setImageViewBitmap` ile veriyoruz.
 *
 * Renkler aksan mavisinin üç tonu: yeşil/turuncu/kırmızı bu uygulamada
 * "seviye" anlamı taşıyor, halkalarda süs olarak kullanılmıyor.
 */
object HalkaCizer {

    const val RENK_DIS = 0xFF0066CC.toInt()   // adım
    const val RENK_ORTA = 0xFF4D94DB.toInt()  // kalori
    const val RENK_IC = 0xFF99C2EB.toInt()    // mesafe

    private const val RENK_IZ = 0xFFE8E8ED.toInt()

    /**
     * [oranlar] dıştan içe doğru üç doluluk oranı (0..1 arası kırpılır).
     * [boyutPx] kare kenarı, [kalinlikPx] tek bir halkanın kalınlığı,
     * [araPx] iki halka arasındaki boşluk.
     */
    fun ciz(
        oranlar: List<Float>,
        renkler: List<Int> = listOf(RENK_DIS, RENK_ORTA, RENK_IC),
        boyutPx: Int,
        kalinlikPx: Float,
        araPx: Float
    ): Bitmap {
        val bmp = Bitmap.createBitmap(boyutPx, boyutPx, Bitmap.Config.ARGB_8888)
        val tuval = Canvas(bmp)
        tuval.drawColor(Color.TRANSPARENT)

        val boya = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeWidth = kalinlikPx
        }

        for (i in oranlar.indices) {
            // +1: dis halkanin yumusatilmis kenari bitmap sinirina tasmasin.
            val ic = kalinlikPx / 2f + 1f + i * (kalinlikPx + araPx)
            val kutu = RectF(ic, ic, boyutPx - ic, boyutPx - ic)

            // İz: her zaman tam daire, soluk.
            boya.color = RENK_IZ
            tuval.drawArc(kutu, 0f, 360f, false, boya)

            val oran = oranlar[i].coerceIn(0f, 1f)
            if (oran <= 0f) continue
            boya.color = renkler.getOrElse(i) { RENK_DIS }
            // Saat 12'den başla, saat yönünde dön.
            tuval.drawArc(kutu, -90f, 360f * oran, false, boya)
        }
        return bmp
    }
}
