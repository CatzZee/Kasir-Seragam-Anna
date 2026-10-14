import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _rp = NumberFormat.decimalPattern('id_ID');

/// Semua nilai uang disimpan sebagai [int] rupiah penuh (tanpa sen).
/// Alasan: aritmetika double pada uang menghasilkan galat pembulatan yang
/// terakumulasi di laporan. Rupiah tidak memakai pecahan di kasir ritel.
String rupiah(int value) => 'Rp ${_rp.format(value)}';
String angka(int value) => _rp.format(value);

String tanggalPanjang(DateTime d) => DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(d);
String tanggalPendek(DateTime d) => DateFormat('dd/MM/yyyy', 'id_ID').format(d);
String tanggalJam(DateTime d) => DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(d);
String jam(DateTime d) => DateFormat('HH:mm', 'id_ID').format(d);

DateTime awalHari(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime akhirHari(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// Membaca angka dari input yang mungkin diketik "150.000" atau "150000".
int parseUang(String s) {
  final clean = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (clean.isEmpty) return 0;
  return int.tryParse(clean) ?? 0;
}

/// Memaksa isi kolom menjadi huruf kapital saat diketik.
///
/// `textCapitalization: TextCapitalization.characters` hanya menyarankan papan
/// ketik menampilkan huruf besar — pengguna tetap bisa mengetik huruf kecil dan
/// sebagian papan ketik pihak ketiga mengabaikan saran itu. Formatter ini
/// bekerja di sisi aplikasi, jadi hasilnya pasti.
class UpperCaseFormatter extends TextInputFormatter {
  const UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      // Posisi kursor dipertahankan supaya pengguna bisa menyisipkan huruf
      // di tengah teks tanpa kursor melompat ke belakang.
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
