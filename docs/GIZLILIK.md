# Kerteriz — Gizlilik Politikası

**Yürürlük tarihi:** 5 Eylül 2026

Bu belgeyi bir web adresinde yayınlamalısın (ör. GitHub Pages, Notion, kendi siten).
Google Play, sağlık verisi okuyan uygulamalarda gizlilik politikası URL'ini zorunlu tutuyor.

---

## Kısa hali

Kerteriz verini telefonundan dışarı çıkarmaz. Sunucumuz yok, hesabın yok,
analiz aracı yok, reklam yok.

---

## 1. Hangi verilere erişiyoruz

Kerteriz, Android **Health Connect** üzerinden şu tiplere **okuma** izniyle erişir:

- Uyku oturumları ve uyku evreleri (derin, hafif, REM, uyanık)
- Nabız, dinlenme nabzı, kalp hızı değişkenliği (HRV)
- Solunum hızı, kandaki oksijen (SpO2), cilt sıcaklığı
- Adım, egzersiz oturumları, yakılan kalori, mesafe
- Kilo, VO2max
- Su alımı (hidrasyon)
- 30 günden eski kayıtlara erişim (geçmiş verisi izni)

Bunların **tek biri** dışında hepsi salt okunurdur. Tek yazma izni **su alımıdır**
(`WRITE_HYDRATION`): ana ekran widget'ındaki düğmeye bastığınızda uygulama
telefonunuzun Health Connect deposuna bir su kaydı ekler. Bu kayıt sizin
eyleminizle oluşur, yine telefonunuzda kalır ve hiçbir yere gönderilmez.
Uygulama başka hiçbir sağlık tipine yazmaz.

## 2. Bu verilerle ne yapıyoruz

Veriler yalnızca cihazınızda işlenir. Uygulama bunlardan hazırlık skoru,
uyku skoru, uyku borcu, günlük yük, akut/kronik yük oranı, sirkadiyen düzenlilik
ve kardiyak toparlanma gibi türetilmiş ölçüler hesaplar ve ekranda gösterir.

## 3. Nereye gönderiyoruz

**Hiçbir yere.** Kerteriz'in sunucusu yoktur. Veriler internete çıkmaz.
Uygulama analiz (analytics), çökme raporlama ya da reklam kitaplığı içermez.

Tek istisna, sizin başlattığınız **dışa aktarma** işlemidir: paylaş düğmesine
bastığınızda cihazınızda bir JSON dosyası oluşturulur ve Android'in paylaşım
menüsü açılır. O dosyanın nereye gideceğine yalnızca siz karar verirsiniz.
Dosya oluşturulmadığı sürece hiçbir yere gitmez.

## 4. Reklam ve satış

Health Connect'ten gelen veriler reklam göstermek, reklam kişiselleştirmek,
üçüncü taraflara aktarmak, satmak ya da kredi değerlendirmesi gibi amaçlarla
**kullanılmaz**. Uygulamada reklam yoktur.

## 5. Saklama ve silme

Veriler uygulamanın kendi alanında geçici olarak işlenir. Uygulamayı
kaldırdığınızda bu alan Android tarafından tamamen silinir.

Health Connect izinlerini istediğiniz an geri alabilirsiniz:
**Ayarlar → Uygulamalar → Health Connect → Uygulama izinleri → Kerteriz**.
İzni geri aldığınızda uygulama hiçbir veri okuyamaz ve su kaydı da yazamaz.

Uygulamanın yazdığı su kayıtlarını silmek için Health Connect'te
**Veri ve erişim → Beslenme → Su** yolunu izleyin; widget'taki geri alma düğmesi
de yalnızca uygulamanın kendi yazdığı son kaydı siler, başka kaynakların
kayıtlarına dokunmaz.

Health Connect'teki verilerin kendisi Google'ın Health Connect deposunda tutulur;
onları silmek için Health Connect uygulamasını kullanın.

## 6. Güvenlik

Veri cihazdan çıkmadığı için ağ üzerinde aktarım yoktur. Cihaz üzerindeki
koruma, Android'in uygulama korumalı alanı (sandbox) ve cihaz şifrelemesidir.

## 7. Çocuklar

Kerteriz 18 yaş altı kullanıcılar için tasarlanmamıştır.

## 8. Tıbbi uyarı

Kerteriz bir tıbbi cihaz değildir. Teşhis koymaz, tedavi önermez, tıbbi tavsiye
vermez. Gösterdiği bütün ölçüler bilgilendirme amaçlıdır. Sağlığınızla ilgili
kararlar için bir sağlık profesyoneline danışın.

## 9. Değişiklikler

Bu politika değişirse yürürlük tarihi güncellenir ve değişiklik uygulama
mağazası açıklamasında belirtilir.

## 10. İletişim

<BURAYA E-POSTA ADRESİNİ YAZ>
