package com.kerteriz.kerteriz

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Ana ekran widget'ı: tek dokunuşla su ekler, üstünde günlük toplam ve hedefe
 * göre ilerleme gösterir.
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

        fun porsiyon(context: Context): Int =
            AyarOkuyucu.say(context, "suPorsiyon", VARSAYILAN_PORSIYON)

        fun hedef(context: Context): Int =
            AyarOkuyucu.say(context, "su", VARSAYILAN_HEDEF)
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
                ids.forEach { ciz(context, manager, it) }
            } finally {
                bekleyen.finish()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        val eylem = intent.action
        if (eylem != ACTION_EKLE && eylem != ACTION_GERI_AL) return

        val bekleyen = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                if (eylem == ACTION_EKLE) {
                    SuKaydedici.ekle(context, porsiyon(context))
                } else {
                    SuKaydedici.sonKaydiSil(context)
                }
                hepsiniYenile(context)
            } finally {
                bekleyen.finish()
            }
        }
    }

    private suspend fun hepsiniYenile(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, SuWidgetProvider::class.java)
        )
        ids.forEach { ciz(context, manager, it) }
    }

    private suspend fun ciz(context: Context, manager: AppWidgetManager, id: Int) {
        val views = RemoteViews(context.packageName, R.layout.su_widget)

        val toplam = SuKaydedici.bugunkuToplam(context)
        val hedef = hedef(context)
        val yuzde = if (hedef > 0) (toplam * 100 / hedef).coerceIn(0, 100) else 0

        views.setTextViewText(R.id.su_toplam, "$toplam")
        views.setTextViewText(R.id.su_hedef, "/ $hedef ml")
        views.setProgressBar(R.id.su_ilerleme, 100, yuzde, false)
        views.setTextViewText(R.id.su_buton, "+ ${porsiyon(context)} ml")

        // Butona dokunma
        views.setOnClickPendingIntent(
            R.id.su_buton,
            yayinIntent(context, ACTION_EKLE, id)
        )
        // Sayıya dokunmak uygulamanın yazdığı son kaydı geri alır
        views.setOnClickPendingIntent(
            R.id.su_geri_al,
            yayinIntent(context, ACTION_GERI_AL, id)
        )

        manager.updateAppWidget(id, views)
    }

    private fun yayinIntent(context: Context, action: String, id: Int): PendingIntent {
        val intent = Intent(context, SuWidgetProvider::class.java).apply {
            this.action = action
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
        }
        return PendingIntent.getBroadcast(
            context,
            action.hashCode() + id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
