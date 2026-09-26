# Kerteriz — Play Store listeleme metinleri

Hepsi kopyala yapıştır için hazır. Karakter sınırları Play Console'un kendi
sınırları; her başlığın altında sayılar yazıyor.

Yazarken uyulan kural: **tıbbi iddia yok.** "Teşhis", "tedavi", "hastalık
tespiti", "sağlığını iyileştirir" gibi ifadeler sağlık uygulamalarında ret
sebebi. Metinler ölçüyor, hesaplıyor ve gösteriyor; söz vermiyor.

---

## Uygulama adı (30 karakter)

```
Kerteriz
```

## Kısa açıklama (80 karakter)

**Türkçe** (71 karakter):

```
Sağlık verini hazırlık, uyku ve yük skorlarına çeviren sade bir analiz.
```

**English** (72 karakter):

```
Turns your health data into readiness, sleep and load scores. On device.
```

---

## Uzun açıklama (4000 karakter sınırı; ikisi de yaklaşık 2000)

### Türkçe

```
Kerteriz, Health Connect'teki sağlık verini okur ve onu birkaç okunabilir
ölçüye çevirir. Veri telefonundan çıkmaz: sunucu yok, hesap yok, analiz
aracı yok, reklam yok.

NE HESAPLIYOR

· Hazırlık — kalp hızı değişkenliği, dinlenme nabzı ve uyku skorunun 14 günlük
  kendi taban çizgine göre birleşimi
· Uyku — süre, evre dağılımı, uyku borcu ve sirkadiyen düzenlilik
· Yük — nabız bölgelerinde geçen süreden günlük yük, akut ve kronik yükün oranı
· Kalp — gece nabız eğrisi, kardiyak toparlanma, SpO2 ve solunum takibi
· Su — günlük hedefe göre alım; hedefi tutturduğun günlerin ertesindeki
  hazırlık ortalaması, tutturmadıklarınla karşılaştırılır

KENDİ TABAN ÇİZGİN

Sayılar mutlak eşiklere göre değil, senin son 14 gününe göre değerlendirilir.
"İyi HRV" diye evrensel bir rakam yok; olan şey senin normalin ve ondan sapma.

ANA EKRAN WIDGET'LARI

· Özet widget'ı: adım, kalori ve mesafe halkaları, altında hazırlık ve uyku
· Su widget'ı: tek dokunuşla su ekleme, yanlış dokunuşu geri alma

VERİ SEKMESİ

Hangi ölçümün kaç kayıt getirdiğini, hangisinin boş olduğunu tek ekranda
gösterir. Bir skor hesaplanamıyorsa sebebini burada görürsün. Bu sekme
uygulamanın en dürüst parçası: cihazlar farklı tipler yazıyor ve sende
olmayan bir veri varmış gibi davranmıyoruz.

HANGİ CİHAZLARLA ÇALIŞIR

Health Connect'e veri yazan her cihazla: Fitbit, Pixel Watch, Samsung Galaxy
Watch, Garmin, Oura ve diğerleri. Hangi ölçümlerin geldiği cihazına bağlı.
Kalp hızı değişkenliği, solunum ya da cilt sıcaklığı yazmayan bir cihazda
ilgili ekranlar boş kalır; Veri sekmesi bunu açıkça söyler.

GİZLİLİK

Okunan her şey cihazında işlenir ve cihazında kalır. Uygulamanın tek yazma
izni su alımıdır: widget'taki düğmeye bastığında Health Connect'e bir su
kaydı eklenir. Dışa aktarma yalnızca sen paylaş düğmesine bastığında olur ve
dosyanın nereye gideceğine sen karar verirsin.

Kerteriz bir tıbbi cihaz değildir. Teşhis koymaz, tedavi önermez. Gösterdiği
ölçüler bilgilendirme amaçlıdır.

Kaynak kodu açıktır.
```

### English

```
Kerteriz reads your health data from Health Connect and turns it into a few
readable measures. Your data never leaves the phone: no server, no account,
no analytics, no ads.

WHAT IT COMPUTES

· Readiness — heart rate variability, resting heart rate and sleep score
  combined against your own 14-day baseline
· Sleep — duration, stage breakdown, sleep debt and circadian regularity
· Load — daily load from time spent in heart rate zones, plus the ratio of
  acute to chronic load
· Heart — overnight heart rate curve, cardiac recovery, SpO2 and respiration
· Water — intake against a daily goal, and how your readiness on the day after
  hitting the goal compares with the days you missed it

YOUR OWN BASELINE

Numbers are judged against your own last 14 days, not against absolute
thresholds. There is no universal figure for "good HRV" — there is your
normal, and how far you are from it.

HOME SCREEN WIDGETS

· Summary widget: step, calorie and distance rings, with readiness and sleep
· Water widget: add water in one tap, undo a mistap

THE DATA TAB

One screen showing how many records each metric returned and which ones came
back empty. If a score cannot be computed, you see why. Devices write
different types, and the app does not pretend to have data you do not have.

WHICH DEVICES

Any device that writes to Health Connect: Fitbit, Pixel Watch, Samsung Galaxy
Watch, Garmin, Oura and others. Which measures arrive depends on your device.
On a device that writes no heart rate variability, respiration or skin
temperature, those screens stay empty, and the Data tab says so plainly.

PRIVACY

Everything read is processed on your device and stays there. The app's only
write permission is hydration: tapping the widget button adds a water record
to Health Connect. Export happens only when you tap share, and where the file
goes is your decision.

Kerteriz is not a medical device. It does not diagnose or treat. Everything
it shows is for information only.

Open source.
```

---

## Sürüm notları (500 karakter)

**0.8.0 — Türkçe** (284 karakter):

```
· Ayarlar ekranı: yaş ve günlük hedefler artık senin seçimin. Nabız bölgeleri
  girdiğin yaşa göre hesaplanıyor.
· Gece modu: sistem, açık ya da koyu.
· Sekmeler arasında parmakla geçiş, alt menüde canlanan simgeler.
· Yeni açılış ekranı.
· Uyku düzeni haritasındaki taşma düzeltildi.
```

**0.8.0 — English** (272 karakter):

```
· Settings screen: age and daily goals are now yours to set. Heart rate zones
  follow the age you enter.
· Dark mode: system, light or dark.
· Swipe between tabs, with animated icons in the bottom bar.
· New loading screen.
· Fixed an overflow in the sleep pattern chart.
```

---

## Kategori ve etiketler

- Kategori: **Sağlık ve fitness**
- Etiketler: sağlık, fitness takibi, uyku
- İçerik derecelendirmesi anketinde: şiddet yok, kullanıcı içeriği yok,
  konum paylaşımı yok, satın alma yok

## Uygulama içi satın alma

Yok. Uygulama tamamen ücretsiz ve reklamsız.
