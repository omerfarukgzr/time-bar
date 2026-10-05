<p align="center"><img src="docs/icon.png" width="96" alt="Time Bar"></p>

<h1 align="center">Time Bar</h1>

<p align="center">Menü çubuğunda yaşayan, sağ tıkla yönetilen bir zaman sayacı.<br>Geri sayım · Kronometre · Mesai · Pomodoro</p>

<p align="center"><a href="https://github.com/omerfarukgzr/time-bar/releases/latest/download/TimeBar.zip"><b>⬇ TimeBar.zip</b></a> · macOS 14+ · Apple Silicon ve Intel</p>

---

Çoğu zamanlayıcı süreyi tutar ama günün nasıl geçtiğini anlatmaz. Time Bar'ın çıkış noktası satranç saati: masaya oturunca bir taraf, kalkınca diğer taraf işler. Akşam baktığında "8 saatin 6 saat 40 dakikası çalışma, 1 saat 20 dakikası mola, en uzun kesintisiz çalışmam 2 saat 10 dakika" gibi bir özet görürsün.

Bunun yanında klasik bir geri sayım, bir kronometre ve bir pomodoro da var. Hepsi aynı yerden, menü çubuğundaki tek bir ikondan yönetilir.

## Bir gün Time Bar ile

> **08:55** Menü çubuğunda çanta ikonu var. Sağ tıklıyorsun, mesai başlıyor. Varsayılan hedef 8 saat.
>
> **10:40** Kahve için kalkıyorsun, yine sağ tık. İkon fincana dönüyor, saat molayı saymaya başlıyor.
>
> **10:55** Döndün, sağ tık. Çanta geri geldi, çalışma süresi kaldığı yerden devam ediyor.
>
> **12:30** Öğle yemeğine çıkarken tuşa basmayı unuttun. Ama "ekran kilitlenince molaya geç" açık olduğu için Mac kilitlenince mola kendiliğinden başladı. Kilidi açınca da çalışmaya döndü.
>
> **17:00** 8 saat doldu, bildirim geliyor. Paneli açıp **Mesaiyi bitir** diyorsun. Günün özeti çıkıyor ve geçmişe yazılıyor.
>
> **21:00** Okumak için Pomodoro sekmesine geçiyorsun. İkon domatese dönüyor. Sağ tık: 25 dakika odak, ardından 5 dakika mola, dört turda bir uzun mola.

## Modlar

| | Ne yapar | Menü çubuğunda | Sağ tık |
|---|---|---|---|
| **Geri sayım** | Seçtiğin süreden geriye sayar. | Zamanlayıcı ikonu ve kalan süre. Son dakikada turuncu, bitince kırmızı "Bitti". | Duraklat / devam et. Bittiyse kapatır. |
| **Kronometre** | Sıfırdan yukarı sayar. | Kronometre ikonu ve geçen süre. | Duraklat / devam et. |
| **Mesai** | Çalışma ve molayı ayrı ayrı sayar. | Çalışırken çanta ve toplam çalışma, moladayken fincan ve bu molanın süresi. | Çalışma ↔ mola. |
| **Pomodoro** | Odak ve molaları sırayla, kendiliğinden sayar. | Odakta domates, molada fincan; aşamanın kalan süresi. | Duraklat / devam et. |

Sayaç çalışmıyorken sağ tık, menü çubuğunda ikonu görünen modu **Ayarlar › Modlar**'daki varsayılan süreyle başlatır. İkon, panelde en son hangi modu seçtiysen onu gösterir. Sol tık her zaman paneli açar. Panelden ad verip süre seçebilir, sayacı bitirebilir, geri sayıma **+5 dk** ekleyebilir ya da pomodoroda bir aşamayı atlayabilirsin.

Ayarlar'dan bir **kısayol tuşu** atarsan sağ tıkla aynı işi klavyeden yaparsın. Kısayol için erişilebilirlik izni gerekmez.

Aynı anda tek bir sayaç çalışır. Yenisini başlatmak için öncekini bitirmen gerekir.

## Ayarlar

Ayarlar penceresi sekmelere ayrılmış:

- **Genel:** Mac açılınca başlat, Dock'ta göster ve diğer sayfalara kısayollar.
- **Modlar:** Hangi modların panelde görüneceği ve her modun ayrıntıları: geri sayımın varsayılan süresi; mesainin varsayılan hedefi ve ekran kilidi davranışı; pomodoronun odak, kısa mola, uzun mola süreleri, uzun molanın kaç odakta bir geleceği ve sonraki aşamanın kendiliğinden başlayıp başlamayacağı.
- **Menü Çubuğu:** Süreyi ve adı göster ya da gizle, süre biçimi (`1:05:00` veya `1 sa 5 dk`), son dakikada turuncu uyarı. Değişiklikleri sayfanın üstündeki önizlemede anında görürsün.
- **Kısayol:** Başlat/durdur tuşunu kaydet. Seçtiğin tuş başka yerde kullanılıyorsa uyarır, kaydetmez.
- **Bildirimler:** Bitiş sesi ve bildirim izninin durumu.
- **Geçmiş:** Aşağıda anlatılıyor.
- **Hakkında:** Sürüm, güncelleme kontrolü ve kaynak kodu.

## Geçmiş

Biten her sayaç, hangi modda olursa olsun geçmişe yazılır. **Ayarlar › Geçmiş** sayfasında hafta hafta gezersin:

- **Tümü** seçiliyken grafik, günlere göre her modda ne kadar zaman geçirdiğini renkli olarak gösterir. Bir mod seçince o modun çalışma (ya da odak) ve mola süreleri ayrılır.
- Grafiğin altında haftanın özeti var. Özet seçtiğin moda göre değişir: mesaide mola oranı, pomodoroda biten odak sayısı, geri sayımda kaçının sonuna kadar tamamlandığı gibi.
- Her kaydın kartında zaman şeridi var. "Ayrıntılar"ı açınca molalar saatleriyle tek tek listelenir.
- Sağ üstteki menüden bütün geçmişi **CSV** olarak kaydedebilirsin. Dosya Excel'de Türkçe karakterler bozulmadan açılır.

Birkaç kural:

- 10 saniyeden kısa denemeler kaydedilmez.
- 5 saniyeden kısa yanlış basışlar özete girmez. Örneğin yanlışlıkla molaya geçip hemen geri döndüysen, o iki çalışma bloğu tek blok sayılır.
- Bir sayacı **Baştan başlat** dersen yarıda kalan hali de kaydedilir.
- Tek tek kayıt silinebilir. Silmek için iki kez basman gerekir.

## Kurulum

**Terminal ile (önerilen).** Şu satırı Terminal'e yapıştır:

```bash
curl -fsSL https://raw.githubusercontent.com/omerfarukgzr/time-bar/main/install.sh | bash
```

Komut son sürümü GitHub'dan indirir, dosyanın SHA-256 özetini GitHub'ın verdiği özetle karşılaştırır, uyuşmazsa hiçbir şey kurmaz. Uyuşursa uygulamayı Uygulamalar klasörüne koyar ve açar. Bu yolla macOS'un "doğrulanamadı" uyarısı çıkmaz. Aynı komut sonradan çalıştırılırsa eski kurulumun üzerine son sürümü kurar. Ne yaptığını önce görmek istersen: [install.sh](install.sh)

**Elle.** [TimeBar.zip](https://github.com/omerfarukgzr/time-bar/releases/latest/download/TimeBar.zip)'i indir, aç ve çıkan `Time Bar.app`'i **Uygulamalar** klasörüne taşı. İndirilenler'den çalıştırma, yoksa uygulama kendini güncelleyemez. İlk açılışta macOS uygulamanın doğrulanamadığını söyler, çünkü ücretli Apple sertifikasıyla imzalı değil:

1. Uyarıda **Bitti**'ye bas. "Çöp Sepeti'ne Taşı"ya basma.
2. **Sistem Ayarları › Gizlilik ve Güvenlik**'i aç, en alta kaydır.
3. Time Bar'ın engellendiğini söyleyen satırda **Yine de Aç**'a bas, parolanla onayla.

Bunu bir kez yaparsın. Sonraki güncellemelerde uyarı çıkmaz.

## Güncellemeler

Time Bar günde bir kez GitHub'a "son sürüm hangisi?" diye sorar. Yeni sürüm varsa panelin en üstünde **Yeni sürüm var** satırı, menü çubuğu ikonunda da küçük bir nokta çıkar. **Güncelle**'ye bastığında olanlar sırasıyla şunlar:

1. Yeni sürümün zip dosyası sadece `github.com` üzerinden indirilir.
2. Dosyanın SHA-256 özeti, GitHub'ın o dosya için yayınladığı özetle karşılaştırılır. GitHub özet vermediyse otomatik kurulum yapılmaz, Releases sayfası açılır. Özet uyuşmazsa kurulum durur ve panelde **İndir** butonu çıkar.
3. Zip'ten çıkan uygulamanın gerçekten Time Bar olduğu (paket kimliği) ve şu ankinden yeni olduğu kontrol edilir. Eski bir sürüme geri dönülmez.
4. Eski uygulama yenisiyle değiştirilir ve Time Bar yeniden açılır.

**Güncellemede hiçbir verin silinmez.** Güncelleme sadece `Time Bar.app` dosyasını değiştirir. Verilerin uygulamanın dışında durur:

| Ne | Nerede |
|---|---|
| Ayarlar ve o an süren sayaç | `~/Library/Preferences/io.github.omerfarukgzr.timebar.plist` |
| Geçmiş | `~/Library/Application Support/Time Bar/history.json` |

Süren bir sayaç varken güncellersen, uygulama yeniden açıldığında sayaç kaldığı yerden devam eder. Aradan geçen birkaç saniye de sayılmış olur. Güncelleme kontrolünü **Ayarlar › Hakkında**'dan kapatabilir ya da **Şimdi denetle** ile hemen yaptırabilirsin.

## Gizlilik

Time Bar hiçbir veri göndermez, analitik kullanmaz. Tek ağ isteği GitHub'daki sürüm kontrolüdür. Mikrofon, kamera, ekran, erişilebilirlik ya da dosya izni istemez. Sorabileceği tek izin **bildirimler**dir: ilk sayacı başlattığında sorulur. Vermezsen süre dolunca sadece ses çalar ve menü çubuğu yanıp söner.

## Sık sorulanlar

**Mac uyursa ya da uygulamayı kapatırsam süre kayar mı?**
Hayır. Time Bar saniyeleri tek tek saymaz. Her aralığın başladığı ve bittiği saati kaydeder, süreyi bunlardan hesaplar. Uygulamayı kapatıp açtığında ya da Mac uyanınca sayaç doğru yerden devam eder. Bu arada dolan bir geri sayım ya da pomodoro aşaması, uygulama açılınca hemen bildirilir.

**Mesaideyken Mac'i kapatıp gidersem ne olur?**
Saat hangi taraftaysa o taraf saymaya devam eder. "Ekran kilitlenince molaya geç" açıksa Mac kilitlenince ya da uyuyunca mola başlar. Kapalıysa çalışma saymaya devam eder. Sonradan fark edersen Geçmiş'ten o kaydı silebilirsin.

**Sağ tıklayınca menü açılmıyor, Ayarlar'a nasıl gideceğim?**
Sol tıkla paneli aç. Ayarlar ve Çık panelin en altında.

**Kısayolum çalışmıyor.**
Ayarlar › Kısayol'da tuşu yeniden kaydet. Tuş sistemde ya da başka bir uygulamada ayrılmışsa Time Bar bunu söyler, başka bir tuş dene.

**Bildirim gelmiyor.**
Ayarlar › Bildirimler'de izin durumu görünür. Kapalıysa **Sistem Ayarları…** butonu seni doğru sayfaya götürür.

**Neden ilk açılışta uyarı çıkıyor?**
Uygulama, Apple'ın yıllık ücretli geliştirici sertifikasıyla imzalanmadı. Terminal ile kurarsan bu uyarı hiç çıkmaz.

## Kaldırma

1. Açtıysan önce **Ayarlar › Genel › Mac açılınca başlat**'ı kapat.
2. Panelden **Çık**'a bas, `Time Bar.app`'i çöpe at.
3. Geçmişi ve ayarları da silmek istersen `~/Library/Application Support/Time Bar` klasörünü sil ve Terminal'de `defaults delete io.github.omerfarukgzr.timebar` çalıştır. Geçmişi saklamak istersen önce Geçmiş sayfasından CSV olarak kaydet.

## Geliştirici notları

Proje Xcode projesi olmadan, sadece Swift Package ile derlenir. Menü çubuğu öğesi ve panel penceresi AppKit ile, panelin ve Ayarlar'ın içi SwiftUI ile yazıldı. Dış bağımlılık yok.

**Zaman nasıl tutuluyor.** Bir sayaç, başlangıç ve bitiş saatleri olan aralıklardan oluşur. Her aralık "çalışma" ya da "mola" tarafına aittir. Duraklatmak açık aralığı kapatır, devam etmek yenisini açar. Mesaide taraf değiştirmek bir aralığı kapatıp karşı tarafta yenisini açar. Pomodoroda her aşama aynı şekilde bir aralıktır, aşama dolunca bitiş anı tam hedefe sabitlenir ve sıradaki aşama o andan başlar. Ekrandaki bütün süreler bu aralıklardan hesaplanır. Saniyelik zamanlayıcı sadece ekranı günceller, süreye bir şey eklemez.

**Dosyalar:**

| Dosya | İçinde ne var |
|---|---|
| `Session.swift` | Modlar, aralıklar, süren sayaç, pomodoro aşamaları, geçmiş özeti, süre biçimleri |
| `Model.swift` | Bütün eylemler (başlat, duraklat, taraf değiştir, bitir), saniyelik saat, bildirim ve ses tetikleme, kayıt |
| `StatusController.swift` | Menü çubuğu öğesi: ikon, yazı, renk; sol ve sağ tık |
| `MenuBarIcon.swift` | Menü çubuğu ikonları ve çizilen domates |
| `PanelViews.swift`, `MenuPanel.swift` | Sol tıkla açılan panel |
| `SettingsView.swift`, `HistoryPage.swift` | Ayarlar penceresi ve Geçmiş sayfası |
| `HotKey.swift` | Kısayol tuşu (`RegisterEventHotKey`) ve kaydedici |
| `Notifier.swift` | Bildirimler ve bildirim butonları |
| `UpdateChecker.swift`, `Updater.swift` | Sürüm kontrolü ve kendi kendini güncelleme |

**Derleme.** macOS 14 SDK'sı olan bir Xcode (16 veya üstü) yeterli:

```bash
scripts/build.sh            # dist/app.noindex/Time Bar.app ve dist/TimeBar.zip
scripts/build.sh --install  # ayrıca ~/Applications'a kurar ve açar
```

**Yeni sürüm çıkarmak.**

1. `Resources/Info.plist`'te `CFBundleShortVersionString`'i artır.
2. `scripts/build.sh` ile `dist/TimeBar.zip`'i üret.
3. GitHub'da `v1.2.3` biçiminde etiketli bir release aç ve zip'i **tam olarak `TimeBar.zip` adıyla** ekle. Uygulama ve `install.sh` dosyayı bu adla arar. SHA-256 özetini GitHub kendisi hesaplar.

Taslak ve ön sürümler kullanıcılara gitmez, sadece "latest" olarak işaretlenen release görülür.

## Lisans

MIT. Ayrıntılar [LICENSE](LICENSE) dosyasında.

---

**English.** Time Bar is a macOS menu bar timer with four modes: countdown, stopwatch, a chess-clock style work shift that tracks work and breaks separately, and pomodoro. Right-clicking the menu bar icon flips the current state (work ↔ break, pause ↔ resume) or starts the mode whose icon is shown; a custom global shortcut does the same. Every finished timer is kept in a weekly history with a chart and CSV export. Install with `curl -fsSL https://raw.githubusercontent.com/omerfarukgzr/time-bar/main/install.sh | bash` or download TimeBar.zip from the latest release. Updates are checked once a day, verified by SHA-256 and never touch your settings or history. No data is collected. MIT licensed.
