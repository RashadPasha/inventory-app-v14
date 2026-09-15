# Muno Inventory

Android-first, offline inventarizasiya tətbiqi. Layihə Flutter ilə hazırlanır və source kod GitHub-da saxlanılır.

## MVP-də olan funksiyalar

- Müəssisə yaratmaq və redaktə etmək
- Anbar yaratmaq və redaktə etmək
- Məhsul yaratmaq: kateqoriya, alt kateqoriya, kod, barkod, ad, ölçü vahidi, vahid qiyməti
- Məhsulları XLSX/CSV ilə toplu yükləmək
- Son anbar qalığını XLSX/CSV ilə yükləmək
- Müəssisə + tarix + anbar + məsul şəxs ilə inventarizasiya açmaq
- Kateqoriya → alt kateqoriya → məhsul strukturu
- Sistem qalığı, faktiki sayım, fərq və fərqin AZN məbləği
- Telefon kamerası ilə barkod scan
- Offline SQLite bazası və yarımçıq sayımı davam etdirmək
- Sayılmamış məhsullar qaldıqda inventarizasiyanın bağlanmasına mane olmaq
- Bağlanan inventarizasiyanı XLSX və CSV kimi paylaşmaq
- Admin tərəfindən istifadəçi yaratmaq və istifadəçini müəssisəyə təhkim etmək
- Gələcək Muno365 API sync üçün lokal `sync_queue`

> Qeyd: real server sinxronizasiyası üçün Muno365 API endpoint və autentifikasiya müqaviləsi ayrıca qoşulacaq. Hazırda tətbiq offline işləyir və dəyişiklikləri sync növbəsində saxlayır.

## Məhsul import formatı

Birinci sətir başlıq olmalıdır. Tövsiyə olunan sütunlar:

`Kateqoriya | Alt kateqoriya | Kod | Barkod | Məhsulun adı | Ölçü vahidi | Vahidin qiyməti`

Məcburi sahələr: `Kod`, `Məhsulun adı`.

## Son qalıq import formatı

Admin → **Son qalıq yüklə** bölməsində əvvəl müəssisə və anbar seçilir. Fayl sütunları:

`Kod | Məhsulun adı | Ölçü vahidi | Son qalıq | Cəmi qalıq məbləği`

`Kod` yoxdursa uyğunlaşdırma məhsul adı və ölçü vahidi ilə edilir.

## Android build

Flutter quraşdırıldıqdan sonra:

```bash
bash tool/bootstrap_android.sh
flutter pub get
flutter run
```

Release APK:

```bash
flutter build apk --release
```

APK yolu: `build/app/outputs/flutter-apk/app-release.apk`.

GitHub Actions `inventory-mvp` branch-ə push zamanı Android layihəsini bootstrap edir və release APK artifact yaradır.
