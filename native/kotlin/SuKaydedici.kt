package com.kerteriz.kerteriz

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Volume
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Health Connect'e su kaydı yazan ve bugünkü toplamı okuyan katman.
 *
 * Widget'tan çağrılır. Bütün çağrılar askıya alınabilir (suspend) —
 * arayüz iş parçacığında çalıştırma.
 */
object SuKaydedici {

    private const val TAG = "Kerteriz.Su"

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

    private fun gunSonu(): ZonedDateTime = gunBasi().plusDays(1)

    /** Bugün için yazılmış toplam su miktarı (ml). */
    suspend fun bugunkuToplam(context: Context): Int {
        val c = istemci(context) ?: return 0
        return try {
            val kayitlar = c.readRecords(
                ReadRecordsRequest(
                    recordType = HydrationRecord::class,
                    // Pencerenin sonu gun sonu; "simdi" olsaydi saniyenin
                    // icinde biten kayit disarida kalirdi.
                    timeRangeFilter = TimeRangeFilter.between(
                        gunBasi().toInstant(),
                        gunSonu().toInstant()
                    )
                )
            ).records
            kayitlar.sumOf { it.volume.inMilliliters }.toInt()
        } catch (e: Exception) {
            Log.w(TAG, "Bugünkü toplam okunamadı", e)
            0
        }
    }

    /** Verilen miktarı (ml) şimdiki zamana kaydeder. */
    suspend fun ekle(context: Context, ml: Int) {
        val c = istemci(context) ?: return
        try {
            val simdi = ZonedDateTime.now()
            val bitis = simdi.toInstant()
            // Kayıt aralığı kısa ve HER ZAMAN bugünün içinde kalmalı: gece
            // yarısını aşan bir aralık ne bugüne ne düne düşer, iki tarafta da
            // kaybolurdu. Başlangıcı gün başına kırpıyoruz.
            var baslangic = bitis.minusMillis(200)
            val gun = gunBasi().toInstant()
            if (baslangic.isBefore(gun)) baslangic = gun
            // Tam gece yarısında dokunulursa aralık sıfır genişlikte kalmasın.
            val son = if (!baslangic.isBefore(bitis)) baslangic.plusMillis(1) else bitis
            c.insertRecords(
                listOf(
                    HydrationRecord(
                        startTime = baslangic,
                        startZoneOffset = simdi.offset,
                        endTime = son,
                        endZoneOffset = simdi.offset,
                        volume = Volume.milliliters(ml.toDouble()),
                        // connect-client 1.1.0'da metadata zorunlu.
                        metadata = Metadata.manualEntry()
                    )
                )
            )
        } catch (e: Exception) {
            Log.w(TAG, "Su kaydı yazılamadı", e)
        }
    }

    /** Bugün yazılmış en son kaydı siler — yanlışlıkla eklemeyi geri almak için. */
    suspend fun sonKaydiSil(context: Context) {
        val c = istemci(context) ?: return
        try {
            val kayitlar = c.readRecords(
                ReadRecordsRequest(
                    recordType = HydrationRecord::class,
                    // Pencerenin sonu gun sonu; "simdi" olsaydi saniyenin
                    // icinde biten kayit disarida kalirdi.
                    timeRangeFilter = TimeRangeFilter.between(
                        gunBasi().toInstant(),
                        gunSonu().toInstant()
                    )
                )
            ).records
            // Yalnızca bu uygulamanın yazdığı kaydı sil; başka uygulamanın
            // verisine dokunmuyoruz.
            val benim = kayitlar
                .filter { it.metadata.dataOrigin.packageName == context.packageName }
                .maxByOrNull { it.endTime }
                ?: return
            c.deleteRecords(
                HydrationRecord::class,
                recordIdsList = listOf(benim.metadata.id),
                clientRecordIdsList = emptyList()
            )
        } catch (e: Exception) {
            Log.w(TAG, "Son kayıt silinemedi", e)
        }
    }
}
