package com.kerteriz.kerteriz

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import org.json.JSONObject
import java.io.File
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Özet widget'ının verisini toplar.
 *
 * İki kaynak var:
 *  1. Health Connect: adım, kalori, mesafe. Bunlar ham sayılar, widget
 *     doğrudan okuyabilir.
 *  2. `kerteriz_ozet.json`: hazırlık, uyku skoru, dinlenme nabzı. Bunlar
 *     14 günlük taban çizgiye dayanan türetilmiş değerler; motor Dart
 *     tarafında çalışıyor, o yüzden uygulama her açılışta bu dosyaya yazıyor.
 *     Dosya yoksa, bayatladıysa ya da skorlar hesaplanamadıysa widget o
 *     satırları boş gösterir.
 *
 * Her toplam AYRI bir aggregate çağrısıdır. Health Connect, kümedeki tek bir
 * tipin izni yoksa çağrının tamamını reddediyor; hepsini tek istekte
 * sorsaydık kullanıcı "toplam kalori" iznini vermediğinde adım ve mesafe de
 * sessizce sıfır görünürdü.
 */
object OzetOkuyucu {

    private const val TAG = "Kerteriz.Ozet"

    /** Uygulama bu kadar süredir açılmadıysa türetilmiş skorlar bayat sayılır. */
    private const val BAYAT_SAAT = 36L

    data class Ozet(
        val adim: Int,
        val kaloriKcal: Int,
        /** true ise kalori TOPLAM değil AKTİF kaloridir; hedefi de farklıdır. */
        val kaloriAktif: Boolean,
        val mesafeKm: Double,
        val hazirlik: Int?,
        val uykuSkoru: Int?,
        val uykuDakika: Int?,
        val dinlenmeNabzi: Int?,
        val bayat: Boolean,
        /** Bugün ekranının en üstündeki cümle; uygulama yazıyor. */
        val cumle: String? = null,
        /** Bu gecenin hedef yatış saati, "22:45" biçiminde. */
        val yatis: String? = null
    )

    private fun istemci(context: Context): HealthConnectClient? =
        try {
            if (HealthConnectClient.getSdkStatus(context) ==
                HealthConnectClient.SDK_AVAILABLE
            ) {
                HealthConnectClient.getOrCreate(context)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Health Connect istemcisi alınamadı", e)
            null
        }

    private fun gunBasi(): ZonedDateTime =
        LocalDate.now().atStartOfDay(ZoneId.systemDefault())

    suspend fun oku(context: Context): Ozet {
        var adim = 0
        var kalori = 0
        var kaloriAktif = false
        var mesafe = 0.0

        val c = istemci(context)
        if (c != null) {
            val aralik = TimeRangeFilter.between(
                gunBasi().toInstant(),
                gunBasi().plusDays(1).toInstant()
            )

            try {
                adim = (c.aggregate(
                    AggregateRequest(
                        metrics = setOf(StepsRecord.COUNT_TOTAL),
                        timeRangeFilter = aralik
                    )
                )[StepsRecord.COUNT_TOTAL] ?: 0L).toInt()
            } catch (e: Exception) {
                Log.w(TAG, "Adım toplamı okunamadı", e)
            }

            try {
                mesafe = (c.aggregate(
                    AggregateRequest(
                        metrics = setOf(DistanceRecord.DISTANCE_TOTAL),
                        timeRangeFilter = aralik
                    )
                )[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0) / 1000.0
            } catch (e: Exception) {
                Log.w(TAG, "Mesafe toplamı okunamadı", e)
            }

            // Önce toplam kalori; yoksa ya da izni yoksa aktif kaloriye düş.
            var toplamKcal: Double? = null
            try {
                toplamKcal = c.aggregate(
                    AggregateRequest(
                        metrics = setOf(TotalCaloriesBurnedRecord.ENERGY_TOTAL),
                        timeRangeFilter = aralik
                    )
                )[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories
            } catch (e: Exception) {
                Log.w(TAG, "Toplam kalori okunamadı", e)
            }

            if (toplamKcal != null && toplamKcal > 0.0) {
                kalori = toplamKcal.toInt()
            } else {
                try {
                    val aktif = c.aggregate(
                        AggregateRequest(
                            metrics = setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
                            timeRangeFilter = aralik
                        )
                    )[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories
                    if (aktif != null) {
                        kalori = aktif.toInt()
                        kaloriAktif = true
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Aktif kalori okunamadı", e)
                }
            }
        }

        var hazirlik: Int? = null
        var uykuSkoru: Int? = null
        var uykuDakika: Int? = null
        var nabiz: Int? = null
        var bayat = true
        var cumle: String? = null
        var yatis: String? = null

        try {
            val dosya = File(context.filesDir, "kerteriz_ozet.json")
            if (dosya.exists()) {
                val j = JSONObject(dosya.readText())
                if (!j.isNull("readiness")) hazirlik = j.getInt("readiness")
                if (!j.isNull("sleepScore")) uykuSkoru = j.getInt("sleepScore")
                if (!j.isNull("sleepMinutes")) uykuDakika = j.getInt("sleepMinutes")
                if (!j.isNull("rhr")) nabiz = j.getDouble("rhr").toInt()
                cumle = j.optString("headline", "").ifBlank { null }
                yatis = j.optString("bedtime", "").ifBlank { null }

                val yazilma = j.optLong("updatedAtMs", 0L)
                val tazeYazilmis =
                    yazilma > 0L &&
                        System.currentTimeMillis() - yazilma <= BAYAT_SAAT * 3600_000L

                // Dosya bugün yazılmış olabilir ama içindeki skorlar birkaç gün
                // önceye ait olabilir: uyku ve nabız kaydı gelmeyen bir gece
                // sonrası motor eski günü son gün sayar. İkisini de kontrol et.
                val gun = j.optString("date", "")
                val bugun = LocalDate.now()
                val skorGunu = try {
                    if (gun.length >= 10) LocalDate.parse(gun.substring(0, 10)) else null
                } catch (e: Exception) {
                    null
                }
                val gunGuncel = skorGunu != null &&
                    !skorGunu.isBefore(bugun.minusDays(1)) &&
                    !skorGunu.isAfter(bugun)

                bayat = !(tazeYazilmis && gunGuncel)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Özet dosyası okunamadı", e)
        }

        return Ozet(
            adim, kalori, kaloriAktif, mesafe,
            hazirlik, uykuSkoru, uykuDakika, nabiz, bayat,
            cumle = if (bayat) null else cumle,
            yatis = if (bayat) null else yatis
        )
    }
}
