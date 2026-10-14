import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Menyusun berkas laporan yang bisa dibuka Excel, lalu membagikannya lewat
/// share sheet Android (WhatsApp, Google Drive, Gmail, dsb).
///
/// Formatnya CSV dengan dua penyesuaian khusus Excel berbahasa Indonesia:
/// baris pertama `sep=;` memberi tahu Excel bahwa pemisah kolomnya titik koma
/// (Excel Indonesia memakai koma sebagai desimal, sehingga CSV berkoma akan
/// menumpuk di satu kolom), dan BOM UTF-8 di awal berkas agar huruf beraksen
/// tidak berubah jadi karakter aneh.
class ExportService {
  ExportService._();

  static String _cell(Object? value) {
    final s = value?.toString() ?? '';
    if (s.contains(';') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String toCsv(List<List<Object?>> rows) {
    final b = StringBuffer()..writeln('sep=;');
    for (final r in rows) {
      b.writeln(r.map(_cell).join(';'));
    }
    return '\uFEFF$b';
  }

  static Future<File> writeTemp(String fileName, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content, encoding: utf8, flush: true);
    return file;
  }

  static Future<void> shareFile(File file, {required String subject, String text = ''}) async {
    await Share.shareXFiles([XFile(file.path)], subject: subject, text: text);
  }

  /// Menyimpan lalu langsung membagikan. Mengembalikan nama berkas.
  static Future<String> exportCsv({
    required String fileName,
    required List<List<Object?>> rows,
    required String subject,
    String text = '',
  }) async {
    final file = await writeTemp(fileName, toCsv(rows));
    await shareFile(file, subject: subject, text: text);
    return fileName;
  }

  /// Nama berkas aman untuk semua sistem: tanpa spasi dan karakter khusus.
  static String safeName(String base) =>
      base.replaceAll(RegExp(r'[^A-Za-z0-9_\-.]'), '_');
}
