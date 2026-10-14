# Kasir Anna Seragam

Aplikasi kasir (Point of Sale) **offline** berbasis Flutter untuk UMKM toko seragam.

Toko seragam kecil biasanya masih mencatat penjualan dan stok secara manual. Akibatnya stok sering tidak cocok, omzet harian sulit dihitung, dan retur barang tidak tercatat. Aplikasi ini menyelesaikan masalah tersebut langsung dari HP Android kasir, **tanpa internet dan tanpa server**:

- Setiap transaksi otomatis mengurangi stok dan tercatat dengan nomor nota.
- Setiap perubahan stok (masuk, keluar, retur) tercatat lengkap dengan siapa yang mengubahnya.
- Struk bisa dicetak ke printer thermal Bluetooth 58 mm.
- Pemilik toko bisa melihat laporan pendapatan, laba kotor, dan retur, lalu mengekspornya ke Excel.
- Seluruh data bisa dicadangkan ke Google Drive atau WhatsApp dan dipulihkan kembali.

---

## Daftar Isi

- [Tech Stack](#tech-stack)
- [Fitur Utama](#fitur-utama)
- [Struktur Direktori](#struktur-direktori)
- [Arsitektur & Alur Data](#arsitektur--alur-data)
- [Skema Database](#skema-database)
- [Prasyarat](#prasyarat)
- [Instalasi & Menjalankan Aplikasi](#instalasi--menjalankan-aplikasi)
- [Contoh Penggunaan](#contoh-penggunaan)
- [Kontribusi](#kontribusi)
- [Lisensi](#lisensi)

---

## Tech Stack

| Kategori | Teknologi |
|---|---|
| Framework | [Flutter](https://flutter.dev) (Dart SDK `>=3.6.0 <4.0.0`), Material Design 3 |
| Target utama | Android (orientasi potret) |
| State management | [`provider`](https://pub.dev/packages/provider) (`ChangeNotifier`) |
| Database lokal | SQLite melalui [`sqflite`](https://pub.dev/packages/sqflite) |
| Preferensi & sesi | [`shared_preferences`](https://pub.dev/packages/shared_preferences) |
| Keamanan kata sandi | [`crypto`](https://pub.dev/packages/crypto) (SHA-256 + salt) |
| Printer struk | [`print_bluetooth_thermal`](https://pub.dev/packages/print_bluetooth_thermal) + [`esc_pos_utils_plus`](https://pub.dev/packages/esc_pos_utils_plus) (ESC/POS, kertas 58 mm) |
| Izin perangkat | [`permission_handler`](https://pub.dev/packages/permission_handler) (Bluetooth Scan/Connect) |
| Berkas & berbagi | [`path_provider`](https://pub.dev/packages/path_provider), [`share_plus`](https://pub.dev/packages/share_plus), [`file_picker`](https://pub.dev/packages/file_picker) |
| Lokalisasi | `flutter_localizations` + [`intl`](https://pub.dev/packages/intl) (locale `id_ID`, format Rupiah & tanggal Indonesia) |
| Linting | [`flutter_lints`](https://pub.dev/packages/flutter_lints) |

---

## Fitur Utama

### Penyiapan Awal & Autentikasi
- **Layar penyiapan awal.** Saat pertama dibuka, database masih kosong (tanpa data contoh). Pemilik mengisi identitas toko dan membuat akun admin pertama.
- **Login dengan sesi tersimpan.** Kasir tidak perlu login ulang setiap kali membuka aplikasi.
- **Dua peran pengguna:**

  | Fitur | Admin (Pemilik) | Kasir |
  |---|:---:|:---:|
  | Transaksi penjualan & cetak struk | ✅ | ✅ |
  | Lihat riwayat, cetak ulang struk, proses retur | ✅ | ✅ |
  | Ubah stok (barang masuk/keluar) | ✅ | ✅ |
  | Tambah/ubah data barang | ✅ | ❌ |
  | Laporan pendapatan, laba & ekspor Excel | ✅ | ❌ |
  | Kelola pengguna, cadangkan/pulihkan & reset data | ✅ | ❌ |

### Kasir (POS)
- Pencarian barang dan filter per kategori.
- Keranjang belanja dengan **validasi stok** (tidak bisa menjual melebihi stok).
- Diskon nominal (Rupiah) dan nama pembeli (opsional).
- Tombol nominal cepat saat pembayaran (uang pas, Rp5.000 – Rp100.000) dan hitung kembalian otomatis.
- Nomor nota otomatis dengan format `INV-YYYYMMDD-0001`.
- Transaksi disimpan secara **atomik** (database transaction). Stok berkurang dan jejak audit tercatat dalam satu langkah.

### Manajemen Barang & Stok
- CRUD barang: SKU unik, nama, kategori, harga modal, harga jual, stok, dan stok minimum.
- Barang bisa dinonaktifkan tanpa dihapus, sehingga riwayat penjualan tetap utuh.
- Penyesuaian stok **masuk/keluar** disertai catatan.
- **Jejak audit stok** (`stock_moves`): setiap perubahan stok mencatat jenis, jumlah, sisa stok, referensi, dan nama petugas.

### Riwayat & Retur
- Riwayat transaksi dengan filter rentang tanggal dan kata kunci.
- Detail nota dan cetak ulang struk.
- **Retur sebagian atau penuh**, dengan alasan retur dan opsi mengembalikan barang ke stok.
- Status nota otomatis: `Selesai`, `Diretur sebagian`, atau `Diretur penuh`.
- Cetak **bukti retur**.

### Laporan (Admin)
- Ringkasan: pendapatan kotor/bersih, laba kotor, jumlah transaksi, rata-rata transaksi, barang terjual, total diskon, dan total retur.
- Tab **Pendapatan**, **Produk** (terlaris, omzet & laba per produk), dan **Retur**.
- **Laporan barang masuk & keluar**: siapa yang mengubah stok, kapan, dan berapa.
- **Ekspor ke Excel** (CSV dengan pemisah `;`, BOM UTF-8, dan baris `sep=;` agar langsung terbaca rapi di Excel berbahasa Indonesia). File dibagikan lewat share sheet Android.

### Printer Struk
- Memilih printer dari perangkat Bluetooth yang **sudah dipasangkan** di pengaturan HP.
- Uji cetak dan opsi **cetak otomatis** setelah transaksi selesai.
- Format struk 32 kolom (kertas 58 mm). Pratinjau di layar identik dengan hasil cetak.

### Cadangan & Pemulihan Data
- **Cadangkan** seluruh database (`.db`) lalu bagikan ke Google Drive, WhatsApp, dan sebagainya.
- **Pulihkan** dari berkas cadangan dengan validasi tanda tangan SQLite. Data lama disalin dulu sebagai *rollback*, sehingga pemulihan yang gagal otomatis mengembalikan data semula.
- Reset data transaksi saja, atau reset seluruh data (kembali ke layar penyiapan awal).

---

## Struktur Direktori

```text
kasir_anna_seragam/
├── android/                    # Proyek native Android (izin Bluetooth ada di AndroidManifest.xml)
├── ios/ linux/ macos/          # Proyek native platform lain (bawaan Flutter)
├── web/ windows/
├── lib/
│   ├── main.dart               # Entry point: inisialisasi locale, database, sesi, dan Provider
│   ├── app.dart                # MaterialApp, tema, lokalisasi, routing awal (Setup → Login → Home)
│   ├── data/
│   │   ├── db_helper.dart      # Singleton SQLite: skema tabel, migrasi, hash kata sandi, reset data
│   │   ├── models.dart         # Model: AppUser, Product, Sale, SaleItem, Refund, StockMove, laporan
│   │   └── repositories.dart   # Akses data: Auth, Product, Sale (transaksi & retur), Report
│   ├── providers/
│   │   └── providers.dart      # SettingsProvider, AuthProvider, CartProvider
│   ├── screens/
│   │   ├── setup_screen.dart        # Penyiapan awal toko & akun admin
│   │   ├── auth_screens.dart        # Layar login
│   │   ├── home_shell.dart          # Navigasi bawah + dashboard (Beranda)
│   │   ├── pos_screen.dart          # Katalog barang untuk kasir
│   │   ├── checkout_screens.dart    # Keranjang, pembayaran, dan struk
│   │   ├── product_screens.dart     # Daftar barang, form barang, penyesuaian stok
│   │   ├── history_screens.dart     # Riwayat transaksi, detail nota, retur
│   │   ├── report_screen.dart       # Laporan pendapatan, produk, dan retur
│   │   ├── stock_report_screen.dart # Laporan barang masuk & keluar
│   │   └── settings_screens.dart    # Pengaturan toko, printer, pengguna, cadangan
│   ├── services/
│   │   ├── printer_service.dart     # Koneksi printer Bluetooth & pengiriman ESC/POS
│   │   ├── receipt_builder.dart     # Penyusun teks struk & bukti retur (32 kolom)
│   │   ├── backup_service.dart      # Cadangkan, validasi, dan pulihkan database
│   │   └── export_service.dart      # Ekspor CSV kompatibel Excel + share sheet
│   ├── theme/
│   │   └── app_theme.dart      # Palet warna & ThemeData aplikasi
│   ├── utils/
│   │   ├── app_info.dart       # Nama, versi, dan catatan struk bawaan
│   │   ├── formatters.dart     # Format Rupiah/tanggal, parser uang, formatter huruf kapital
│   │   └── refresh_signal.dart # ValueNotifier untuk menyegarkan layar saat data berubah
│   └── widgets/
│       └── app_widgets.dart    # Komponen UI yang dipakai ulang
├── test/                       # Unit/widget test
├── analysis_options.yaml       # Aturan lint
└── pubspec.yaml                # Metadata proyek & dependencies
```

---

## Arsitektur & Alur Data

Aplikasi memakai arsitektur berlapis sederhana:

```text
Screens (UI)  ──►  Providers (state)  ──►  Repositories  ──►  DatabaseHelper (SQLite)
     │                                                              ▲
     └──────────►  Services (printer, backup, export) ──────────────┘
```

- **Screens** menampilkan UI dan membaca state lewat `context.watch<...>()`.
- **Providers** menyimpan state global: identitas toko & printer (`SettingsProvider`), pengguna aktif (`AuthProvider`), dan keranjang (`CartProvider`). Keranjang sengaja **tidak** disimpan permanen.
- **Repositories** berisi seluruh kueri SQL. Operasi yang mengubah stok dibungkus `db.transaction()`.
- **`refresh_signal.dart`** memberi tahu layar yang tetap hidup (`IndexedStack` / keep-alive) agar memuat ulang data saat stok berubah di layar lain.
- **Nilai uang** selalu disimpan sebagai `int` Rupiah penuh untuk menghindari galat pembulatan `double`.

---

## Skema Database

Database SQLite `kasir_anna.db` (versi skema `2`) berisi tabel berikut:

| Tabel | Fungsi |
|---|---|
| `users` | Akun pengguna (`admin` / `kasir`), kata sandi ter-hash, status aktif |
| `products` | Data barang: SKU, kategori, harga modal & jual, stok, stok minimum |
| `sales` | Header transaksi: nomor nota, kasir, pembeli, subtotal, diskon, total, bayar, kembali, status |
| `sale_items` | Rincian barang per transaksi (*snapshot* harga jual & modal, qty, qty diretur) |
| `refunds` | Header retur: alasan, total pengembalian, opsi kembali ke stok |
| `refund_items` | Rincian barang yang diretur |
| `stock_moves` | Jejak audit stok: jenis (`masuk`/`keluar`/`retur`), qty, sisa stok, referensi, petugas |

Migrasi skema ditangani di `DatabaseHelper._onUpgrade` (`lib/data/db_helper.dart`).

---

## Prasyarat

| Kebutuhan | Keterangan |
|---|---|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | Versi dengan Dart `>= 3.6.0` (Flutter 3.27 atau lebih baru) |
| Android SDK | Lewat Android Studio atau command-line tools |
| Perangkat Android / emulator | Disarankan HP Android asli agar fitur Bluetooth bisa diuji |
| Printer thermal Bluetooth 58 mm | *Opsional*. Dukung ESC/POS dan sudah dipasangkan (*paired*) di pengaturan Bluetooth HP |
| Git | Untuk mengkloning repositori |

Cek kesiapan lingkungan:

```bash
flutter doctor
```

---

## Instalasi & Menjalankan Aplikasi

**1. Kloning repositori**

```bash
git clone https://github.com/CatzZee/Kasir-Seragam-Anna.git
cd Kasir-Seragam-Anna
```

**2. Unduh dependencies**

```bash
flutter pub get
```

**3. Sambungkan perangkat Android, lalu cek apakah terdeteksi**

```bash
flutter devices
```

**4. Jalankan aplikasi (mode debug)**

```bash
flutter run
```

**5. Build APK rilis**

```bash
flutter build apk --release
```

Hasil build ada di `build/app/outputs/flutter-apk/app-release.apk` dan bisa langsung dipasang di HP kasir.

> **Catatan:** Konfigurasi rilis masih memakai *signing key* debug. Sebelum mendistribusikan APK secara luas, siapkan keystore sendiri sesuai [panduan resmi Flutter](https://docs.flutter.dev/deployment/android#sign-the-app).

**Perintah pengembangan lainnya**

```bash
flutter analyze     # Analisis statis & lint
flutter test        # Menjalankan test di folder test/
```

---

## Contoh Penggunaan

> Proyek ini adalah **aplikasi mobile offline**, bukan layanan API. Tidak ada endpoint HTTP. Semua data disimpan di SQLite pada perangkat. Berikut alur penggunaan utamanya.

### 1. Penyiapan pertama kali
1. Buka aplikasi. Layar **Penyiapan Awal** muncul karena belum ada akun.
2. Isi identitas toko (nama, alamat, telepon) dan buat akun **admin**.
3. Aplikasi otomatis masuk ke **Beranda**.

### 2. Menambahkan barang
1. Buka tab **Stok** → **Tambah barang**.
2. Isi SKU, nama, kategori, harga modal, harga jual, stok awal, dan stok minimum.
3. Simpan. Stok awal otomatis tercatat sebagai *barang masuk*.

### 3. Menghubungkan printer
1. Pasangkan printer thermal di **Pengaturan Bluetooth** HP.
2. Di aplikasi, buka **Pengaturan → Printer struk**, pilih printer, lalu tekan **uji cetak**.
3. Aktifkan **Cetak otomatis setelah transaksi** bila diinginkan.

### 4. Melayani transaksi
1. Buka tab **Kasir**, cari barang atau pilih kategori, lalu ketuk barang untuk menambahkannya ke keranjang.
2. Buka **Keranjang**, atur jumlah, isi diskon atau nama pembeli bila perlu, lalu tekan **Bayar**.
3. Masukkan nominal uang diterima (atau pilih tombol cepat). Kembalian dihitung otomatis.
4. Tekan **Selesaikan transaksi**. Struk tampil di layar dan bisa dicetak.

Contoh struk yang dihasilkan `ReceiptBuilder`:

```text
          ANNA SERAGAM
     Jl. Contoh No. 1, Kota
        Telp 08123456789
--------------------------------
No             INV-20261014-0001
Tgl             14/10/2026 09:30
Kasir                       Anna
--------------------------------
KEMEJA SD PUTIH NO 8
  2 x 85.000             170.000
CELANA SD MERAH NO 8
  1 x 75.000              75.000
--------------------------------
Jumlah Kuantitas               3
TOTAL                    245.000
Bayar                    250.000
Kembali                    5.000
--------------------------------
  Terima kasih atas kunjungan
             Anda.
```

### 5. Memproses retur
1. Buka tab **Riwayat**, lalu pilih nota.
2. Tekan **Retur**, tentukan jumlah barang yang dikembalikan, isi alasan, dan pilih apakah barang kembali ke stok.
3. Tekan **Proses retur**. Status nota diperbarui dan bukti retur bisa dicetak.

### 6. Laporan & ekspor (admin)
1. Buka **Pengaturan → Laporan lengkap**, lalu pilih rentang tanggal.
2. Lihat tab **Pendapatan**, **Produk**, atau **Retur**.
3. Tekan **Ekspor ke Excel** untuk membagikan berkas CSV.

### 7. Mencadangkan data
Buka **Pengaturan → Cadangkan data**, lalu simpan berkas `cadangan-kasir-anna-YYYYMMDD-HHMM.db` ke Google Drive. Untuk memulihkan, gunakan **Pulihkan data dari cadangan** dan pilih berkas tersebut.

> ⚠️ Karena semua data tersimpan di HP, **lakukan pencadangan secara rutin**. Jika HP hilang, rusak, atau di-reset tanpa cadangan, data tidak bisa dikembalikan.

---

## Kontribusi

Kontribusi sangat diterima. Langkah-langkahnya:

1. **Fork** repositori ini.
2. Buat branch fitur:
   ```bash
   git checkout -b feat/nama-fitur
   ```
3. Lakukan perubahan, lalu pastikan kode lolos analisis:
   ```bash
   flutter analyze
   ```
4. Commit dengan format [Conventional Commits](https://www.conventionalcommits.org/):
   ```bash
   git commit -m "feat: tambah laporan stok menipis"
   ```
5. Push ke fork Anda, lalu buka **Pull Request** dengan penjelasan perubahan.

**Panduan singkat:**
- Simpan nilai uang sebagai `int` (Rupiah penuh), jangan `double`.
- Setiap perubahan stok wajib melalui repository agar tercatat di `stock_moves`.
- Perubahan skema database wajib menaikkan `_dbVersion` dan menambahkan migrasi di `_onUpgrade`.
- Teks antarmuka memakai Bahasa Indonesia.

Laporan bug dan usulan fitur bisa diajukan lewat tab [Issues](https://github.com/CatzZee/Kasir-Seragam-Anna/issues).

---

## Lisensi

Proyek ini dirilis di bawah **[MIT License](LICENSE)**.

Copyright © 2026 Fadhil Majid Mu'tashim
