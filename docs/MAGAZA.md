# Kerteriz — Play Store listeleme metinleri

Hepsi kopyala yapıştır için hazır. Karakter sınırları Play Console'un kendi
sınırları; her başlığın altında sayılar yazıyor.

Yazarken uyulan kural: **tıbbi iddia yok.** "Teşhis", "tedavi", "hastalık
tespiti", "sağlığını iyileştirir" gibi ifadeler sağlık uygulamalarında ret
sebebi. Metinler ölçüyor, hesaplıyor ve gösteriyor; söz vermiyor.

**Konumlanma (Ekim 2026, bkz. `PAZAR.md`):** Google Health ve Samsung Health
hazırlık skorunu ücretsiz veriyor; Kerteriz skorla yarışmıyor. Metin üç farkla
açılıyor: **şeffaflık** (skorun neden öyle olduğu), **kendi verinle deney**
(etiketler ve karşılaştırmalar), **gizlilik** (veri telefondan çıkmıyor).
Skor listesi metnin ortasında, giriş değil.

---

## Uygulama adı (30 karakter)

```
Kerteriz
```

## Kısa açıklama (80 karakter)

**Türkçe** (75 karakter):

```
Skorunun neden öyle olduğunu gösteren, verini telefondan çıkarmayan analiz.
```

**English** (69 karakter):

```
Shows why your score is what it is. Your data never leaves the phone.
```

---

## Uzun açıklama (4000 karakter sınırı)

### Türkçe (2465 karakter)

```
Saatin sana her sabah bir skor veriyor. Kerteriz sana o skorun neden öyle
olduğunu gösteriyor, ve neyin seni gerçekten etkilediğini kendi verinden
buluyor. Veri telefonundan çıkmıyor: sunucu yok, hesap yok, reklam yok.

NEDEN ÖYLE: HER SAYININ KAYNAĞI AÇIK

Hazırlık, uyku ve yük skorlarının nasıl hesaplandığı uygulamanın içinde yazıyor.
Hangi girdi kaç puan getirdi, hangi gece eksik kaldı, hangi ölçüm cihazından hiç
gelmiyor: hepsi bir dokunuş uzakta. Kara kutu yok.

KENDİ VERİNLE DENEY

· Akşamları tek dokunuşla etiketle: alkol, geç kafein, geç yemek, stres
· Kerteriz etiketli ve etiketsiz akşamların ertesi sabahını karşılaştırır:
  örneğin "alkollü akşamların ertesinde hazırlığın ortalama 14 puan düşük"
· Etiket istemeyen karşılaştırmalar da var: erken yatış, çok adımlı günler,
  şekerleme, geç yemek, öğleden sonra kafein
· Sabah "bugün nasıl hissediyorsun" diye sorar; skorun hissinle ne kadar
  örtüştüğünü gösterir
· Her kartta iki grubun kaç günden hesaplandığı yazar. Az veriyle sonuç
  göstermez ve bunların neden değil ilişki olduğunu söyler

GÜNÜN TAMAMI

· Günün cümlesi: "Ölçülü bir gün: gece nabzın taban çizginin 6 atım üstünde.
  Bu gece hedef yatış 22:45."
· Hazırlık, uyku skoru, uyku borcu, günlük yük, akut/kronik yük oranı
· Gün içi stres ve enerji tahmini, antrenman listesi ve antrenman yükü
· Yatma saati önerisi: bugünkü yükün ve uyku verimine göre
· Döngüye duyarlı: regl kayıtların varsa luteal evredeki nabız ve HRV
  kaymasını kendi geçmiş döngülerinden ölçüp hazırlığı düzeltir

KENDİ TABAN ÇİZGİN

Sayılar evrensel eşiklere değil, senin son 14 gününe göre değerlendirilir. İlk
günlerde taban çizgin oluşurken bunu açıkça söyler; uydurma bir skor göstermez.

ANA EKRAN WIDGET'LARI

Bugün, özet ve su widget'ları; her biri küçük, orta ve büyük boyutta. Su
widget'ında tek dokunuşla su eklenir, halka su akar gibi dolar.

HANGİ CİHAZLARLA ÇALIŞIR

Health Connect'e veri yazan her cihazla: Fitbit, Pixel Watch, Samsung Galaxy
Watch, Garmin, Oura ve diğerleri. Samsung ve Garmin kalp hızı değişkenliği
paylaşmıyor; Kerteriz bunu ilk gün söyler ve hazırlığı nabız, uyku ve gece
toparlanmasından kurar. Veri sekmesi hangi ölçümün hangi uygulamadan geldiğini
gösterir.

GİZLİLİK

Okunan her şey cihazında işlenir ve cihazında kalır. Tek yazma izni su
alımıdır. Dışa aktarma yalnızca sen paylaş düğmesine bastığında olur.

Kerteriz bir tıbbi cihaz değildir. Teşhis koymaz, tedavi önermez. Gösterdiği
ölçüler bilgilendirme amaçlıdır.
```

### English (2418 karakter)

```
Your watch gives you a score every morning. Kerteriz shows you why the score
is what it is, and finds what actually moves it from your own data. Your data
never leaves the phone: no server, no account, no ads.

WHY: EVERY NUMBER SHOWS ITS SOURCE

How readiness, sleep and load are computed is written inside the app. Which
input added how many points, which night came up short, which measure your
device never sends: all one tap away. No black box.

EXPERIMENT WITH YOUR OWN DATA

· Tag your evenings in one tap: alcohol, late caffeine, late meal, stress
· Kerteriz compares the mornings after tagged and untagged evenings:
  for example "readiness averages 14 points lower after evenings with alcohol"
· Some comparisons need no tags: early nights, high-step days, naps, late
  meals, afternoon caffeine
· Each morning it asks how you feel, and shows how well the score matches
· Every card shows how many days each group comes from. It shows nothing on
  too little data, and says these are associations, not causes

THE WHOLE DAY

· The day in one sentence: "A measured day: overnight heart rate is 6 bpm
  above baseline. Tonight, aim for bed at 22:45."
· Readiness, sleep score, sleep debt, daily load, acute-to-chronic load ratio
· Daytime stress and energy estimate, workout list and workout load
· Suggested bedtime from today's load and your own sleep efficiency
· Cycle-aware: with period records, it measures your own luteal shift in heart
  rate and HRV from past cycles and adjusts readiness

YOUR OWN BASELINE

Numbers are judged against your own last 14 days, not universal thresholds.
While your baseline builds, it says so plainly instead of showing a made-up score.

HOME SCREEN WIDGETS

Today, summary and water widgets, each in small, medium and large sizes. Add
water in one tap and watch the ring fill like water.

WHICH DEVICES

Any device that writes to Health Connect: Fitbit, Pixel Watch, Samsung Galaxy
Watch, Garmin, Oura and others. Samsung and Garmin do not share heart rate
variability; Kerteriz tells you on day one and builds readiness from heart
rate, sleep and overnight recovery. The Data tab shows which app sent what.

PRIVACY

Everything read is processed on your device and stays there. The only write
permission is hydration. Export happens only when you tap share.

Kerteriz is not a medical device. It does not diagnose or treat. Everything it
shows is for information only.
```

---

## Ekran görüntüleri (sıra ve başlıklar)

Play ilk iki-üç görüntüyü arama sonucunda gösteriyor; konumlanma bu ilk üçte
anlaşılmalı. Her görüntünün üstüne kısa bir başlık.

| Sıra | Ekran | Başlık (TR) | Caption (EN) |
|---|---|---|---|
| 1 | "Senin verin ne diyor": etiket kartı (alkol) | Alkol ertesi sabahını kaç puan düşürüyor? | What does alcohol cost your next morning? |
| 2 | Bugün: günün cümlesi + hazırlık göstergesi | Skorun neden öyle, tek cümlede | Why your score is what it is, in one sentence |
| 3 | Hazırlık girdileri açık, alt sayfada formül | Kara kutu yok: her sayının kaynağı açık | No black box: every number shows its source |
| 4 | Gün içi stres ve enerji | Günün nereye gitti | Where your day went |
| 5 | Ana ekran: Bugün + su widget'ları | Widget'larda tek bakışta | At a glance on your home screen |
| 6 | Yük: antrenman ayrıntısı | Her antrenmanın gerçek yükü | The real load of every workout |
| 7 | Veri sekmesi: veri kaynakları | Hangi veri hangi uygulamadan, açıkça | Which app sent what, plainly |
| 8 | Ayarlar / gizlilik notu | Verin telefonundan çıkmaz | Your data never leaves your phone |

---

## Sürüm notları (500 karakter)

**İlk yayın — Türkçe** (290 karakter):

```
· Kendi verinle deney: etiketler, su, his ve otomatik karşılaştırmalar
· Günün cümlesi ve yatma saati önerisi
· Gün içi stres ve enerji, antrenman listesi
· Döngüye duyarlı hazırlık
· Samsung ve Garmin için HRV'siz hazırlık
· Üç boyutlu widget'lar, koyu tema
· Akşam ve sabah hatırlatmaları
```

**First release — English** (307 karakter):

```
· Experiment with your own data: tags, water, mood and automatic comparisons
· The day in one sentence and a suggested bedtime
· Daytime stress and energy, workout list
· Cycle-aware readiness
· Readiness without HRV for Samsung and Garmin
· Widgets in three sizes, dark mode
· Evening and morning reminders
```

---

## Kategori ve etiketler

- Kategori: **Sağlık ve fitness**
- Etiketler: sağlık, fitness takibi, uyku
- İçerik derecelendirmesi anketinde: şiddet yok, kullanıcı içeriği yok,
  konum paylaşımı yok, satın alma yok

## Uygulama içi satın alma

Yok. Uygulama tamamen ücretsiz ve reklamsız. (Pro planı için bkz. `PAZAR.md` §6;
eklenince bu bölüm ve içerik derecelendirmesi güncellenmeli.)
