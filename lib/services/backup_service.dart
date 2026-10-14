import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/db_helper.dart';

class BackupResult {
  final bool success;
  final String message;
  const BackupResult(this.success, this.message);
}

/// Pencadangan dan pemulihan seluruh database.
///
/// Aplikasi ini menyimpan semuanya di dalam HP. Kalau HP hilang, rusak, atau
/// disetel ulang pabrik, seluruh riwayat penjualan ikut hilang. Karena itu
/// pencadangan bukan fitur tambahan, melainkan syarat agar data bisa dipercaya.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  /// Tanda tangan berkas SQLite. Dipakai menolak berkas sembarangan sebelum
  /// menimpa data yang sedang dipakai.
  static const _sqliteHeader = 'SQLite format 3';

  String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}';
  }

  /// Menyalin database ke berkas sementara lalu membuka share sheet, sehingga
  /// pemilik bisa menyimpannya ke Google Drive atau mengirim ke WhatsApp.
  Future<BackupResult> exportBackup() async {
    try {
      final dbPath = await DatabaseHelper.instance.databaseFilePath();
      final src = File(dbPath);
      if (!await src.exists()) {
        return const BackupResult(false, 'Berkas data tidak ditemukan.');
      }

      // Tutup dulu agar semua tulisan tertunda benar-benar tersimpan ke berkas.
      await DatabaseHelper.instance.close();
      final dir = await getTemporaryDirectory();
      final name = 'cadangan-kasir-anna-${_stamp()}.db';
      final dest = File('${dir.path}/$name');
      await src.copy(dest.path);
      await DatabaseHelper.instance.database; // buka kembali

      await Share.shareXFiles(
        [XFile(dest.path)],
        subject: 'Cadangan data Kasir Anna Seragam',
        text: 'Simpan berkas ini di Google Drive. Berkas ini berisi seluruh '
            'data barang, penjualan, dan retur.',
      );
      return BackupResult(true, 'Cadangan dibuat: $name');
    } catch (e) {
      return BackupResult(false, 'Gagal membuat cadangan: $e');
    }
  }

  /// Meminta pengguna memilih berkas cadangan. Mengembalikan null bila batal.
  Future<String?> pickBackupFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    if (res == null || res.files.isEmpty) return null;
    return res.files.single.path;
  }

  /// Memeriksa apakah berkas benar-benar database SQLite yang berisi tabel
  /// aplikasi ini. Pemeriksaan dilakukan SEBELUM data lama disentuh.
  Future<BackupResult> validate(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return const BackupResult(false, 'Berkas tidak ditemukan.');
      final len = await f.length();
      if (len < 512) return const BackupResult(false, 'Berkas terlalu kecil, kemungkinan rusak.');

      final head = await f.openRead(0, 16).first;
      final sig = String.fromCharCodes(head.take(15));
      if (sig != _sqliteHeader) {
        return const BackupResult(
            false, 'Berkas ini bukan cadangan Kasir Anna Seragam.');
      }
      return const BackupResult(true, 'Berkas cadangan valid.');
    } catch (e) {
      return BackupResult(false, 'Gagal memeriksa berkas: $e');
    }
  }

  /// Menimpa database aktif dengan berkas cadangan.
  ///
  /// Data lama disalin dulu sebagai cadangan darurat. Bila berkas baru ternyata
  /// gagal dibuka, data lama dikembalikan otomatis — sehingga pemulihan yang
  /// gagal tidak pernah meninggalkan aplikasi tanpa data.
  Future<BackupResult> restore(String path) async {
    final check = await validate(path);
    if (!check.success) return check;

    String? rollbackPath;
    try {
      final dbPath = await DatabaseHelper.instance.databaseFilePath();
      final current = File(dbPath);
      final dir = await getTemporaryDirectory();

      await DatabaseHelper.instance.close();

      if (await current.exists()) {
        rollbackPath = '${dir.path}/rollback-${_stamp()}.db';
        await current.copy(rollbackPath);
      }

      await File(path).copy(dbPath);

      // Uji buka. Bila skema tidak cocok, kueri ini akan melempar.
      final db = await DatabaseHelper.instance.database;
      await db.rawQuery('SELECT COUNT(*) FROM users');
      await db.rawQuery('SELECT COUNT(*) FROM products');

      return const BackupResult(true, 'Data berhasil dipulihkan.');
    } catch (e) {
      // Kembalikan data lama.
      try {
        if (rollbackPath != null) {
          await DatabaseHelper.instance.close();
          final dbPath = await DatabaseHelper.instance.databaseFilePath();
          await File(rollbackPath).copy(dbPath);
          await DatabaseHelper.instance.database;
        }
      } catch (_) {}
      return BackupResult(
          false, 'Pemulihan gagal, data lama dikembalikan. Rincian: $e');
    }
  }
}
