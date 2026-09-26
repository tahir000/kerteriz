package com.kerteriz.kerteriz

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * Widget hedeflerini uygulamanın yazdığı özet dosyasından okur.
 *
 * Hedefler eskiden derlemeye gömülüydü: `patch_native.py`, kurulum sırasında
 * `lib/config.dart` içindeki sayıları Kotlin sabitlerinin üstüne yazıyordu.
 * Kişisel bir yapıda bu yeterliydi. Mağazadan kurulan bir uygulamada hedef
 * kullanıcının kendi seçimi olmalı, o yüzden artık ayarlardan geliyor ve
 * `kerteriz_ozet.json` içindeki `hedefler` nesnesiyle Kotlin tarafına
 * taşınıyor.
 *
 * Gömülü sabitler yine duruyor ama artık **varsayılan** görevinde: dosya
 * yoksa (uygulama hiç açılmadıysa) ya da okunamazsa widget onlara düşüyor.
 */
object AyarOkuyucu {

    private const val TAG = "Kerteriz.Ayar"
    private const val DOSYA = "kerteriz_ozet.json"

    /** Hedef nesnesi. Bir çizimde birden çok hedef okunacaksa bir kez alıp
     *  [say] fonksiyonunun nesne alan biçimine verilmeli: aksi halde dosya
     *  her hedef için yeniden açılıp ayrıştırılır. */
    fun hedefler(context: Context): JSONObject? = try {
        val f = File(context.filesDir, DOSYA)
        if (f.exists()) JSONObject(f.readText()).optJSONObject("hedefler") else null
    } catch (e: Exception) {
        Log.w(TAG, "Hedefler okunamadı", e)
        null
    }

    /**
     * [alan] için kullanıcının seçtiği değeri döndürür; yoksa [varsayilan].
     * Sıfır ve negatif değerler de varsayılana düşer: hedef bölen olarak
     * kullanılıyor, sıfır geçmemeli.
     */
    fun say(context: Context, alan: String, varsayilan: Int): Int =
        say(hedefler(context), alan, varsayilan)

    /** Dosyayı bir kez okuyup elde tutan çağıranlar için. */
    fun say(hedefler: JSONObject?, alan: String, varsayilan: Int): Int {
        val h = hedefler ?: return varsayilan
        val v = h.optInt(alan, varsayilan)
        return if (v > 0) v else varsayilan
    }
}
