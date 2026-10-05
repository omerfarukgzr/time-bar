<p align="center"><img src="docs/icon.png" width="96" alt="Time Bar"></p>

<h1 align="center">Time Bar</h1>

<p align="center">Menü çubuğunda geri sayım, kronometre ve mesai saati.</p>

<p align="center"><a href="https://github.com/omerfarukgzr/time-bar/releases/latest/download/TimeBar.zip"><b>⬇ Time Bar'ı indir (macOS)</b></a></p>

---

Bir ad yaz, süreyi seç, başlat. Sayaç menü çubuğunda ikonuyla birlikte görünür.

## Modlar

- **Geri sayım:** Süre dolunca bildirim ve ses gelir, menü çubuğu kırmızı yanıp söner. Bildirimden "+5 dk" diyebilirsin. Son dakikada süre turuncuya döner.
- **Kronometre:** Sıfırdan yukarı sayar, duraklatılabilir.
- **Mesai:** Satranç saati gibi çalışır. Çalışırken bir taraf, kalkınca diğer taraf işler. Kısayola ya da sağ tıka basınca çalışma ile mola arasında geçer. Mesai bitince özet çıkar: ne kadar çalıştın, ne kadar mola verdin, kaç mola, en uzun kesintisiz çalışma. Geçmiş mesailer panelde listelenir.

## Kullanım

- **Sol tık:** Panel açılır. Yeni sayaç başlatılır, süren sayaç yönetilir.
- **Sağ tık:** Hızlı menü. Başlat/duraklat, molaya geç, +5 dk, bitir, son kullanılanlar.
- **Kısayol:** Ayarlar'dan istediğin tuşu atarsın. Sayaç yoksa son kullanılanı başlatır.

Süreler bitiş saatinden hesaplanır. Mac uykuya geçse ya da uygulama kapanıp açılsa da sayaç kaymaz, kaldığı yerden devam eder.

## Ayarlar

- Süreyi ve adı menü çubuğunda göster ya da gizle (sadece ikon kalır, ikondaki halka ilerlemeyi gösterir)
- Süre biçimi: `1:05:00` ya da `1 sa 5 dk`
- Ekran kilitlenince molaya geç (mesai)
- Bitiş sesi, Dock'ta göster, Mac açılınca başlat, güncellemeleri denetle

## Kurulum

1. **[TimeBar.zip](https://github.com/omerfarukgzr/time-bar/releases/latest/download/TimeBar.zip)** dosyasını indir ve aç.
2. `Time Bar.app` dosyasını **Uygulamalar** klasörüne sürükle.
3. Uygulamayı aç. Apple'a kayıtlı bir sertifikayla imzalanmadığı için macOS ilk açılışta uyarı verir:
   - **Sistem Ayarları › Gizlilik ve Güvenlik** bölümünde en alttaki **"Yine de Aç"** butonuna bas.
   - Ya da Terminal'de: `xattr -dr com.apple.quarantine "/Applications/Time Bar.app"`

## Güncelleme

Time Bar günde bir kez GitHub'daki son sürüme bakar. Yeni sürüm varsa panelin en üstünde **"Yeni sürüm var"** satırı ve ikonda küçük bir nokta görünür. **Güncelle**'ye basınca yeni sürüm indirilir, doğrulanır, eskisinin yerine kurulur ve uygulama yeniden açılır. Süren sayaç ve geçmiş korunur.

## Gizlilik

Veri toplamaz, analitik kullanmaz. Tek ağ isteği GitHub'daki sürüm kontrolüdür. Geçmiş sadece bu Mac'te saklanır.

## Derleme

```bash
scripts/build.sh            # dist/TimeBar.zip
scripts/build.sh --install  # ~/Applications'a kurar ve açar
```

macOS 14 veya üstü. Lisans: MIT.
