import '../data/models.dart';
import '../providers/providers.dart';
import '../utils/formatters.dart';

/// Menyusun teks struk 32 kolom (kertas 58 mm).
/// Satu sumber kebenaran: dipakai untuk pratinjau di layar DAN untuk dicetak,
/// supaya yang dilihat kasir persis sama dengan yang keluar dari printer.
class ReceiptBuilder {
  static const int width = 32;

  static String center(String s) {
    if (s.length >= width) return s.substring(0, width);
    final pad = (width - s.length) ~/ 2;
    return ' ' * pad + s;
  }

  static String line([String ch = '-']) => ch * width;

  static String pair(String left, String right) {
    final space = width - left.length - right.length;
    if (space < 1) {
      final cut = left.length + space - 1;
      return '${left.substring(0, cut < 0 ? 0 : cut)} $right';
    }
    return left + ' ' * space + right;
  }

  static List<String> wrap(String s, [int max = width]) {
    final words = s.split(' ');
    final out = <String>[];
    var cur = '';
    for (final w in words) {
      if (cur.isEmpty) {
        cur = w;
      } else if ('$cur $w'.length <= max) {
        cur = '$cur $w';
      } else {
        out.add(cur);
        cur = w;
      }
    }
    if (cur.isNotEmpty) out.add(cur);
    return out.isEmpty ? [''] : out;
  }

  static List<String> sale(Sale sale, SettingsProvider s) {
    final out = <String>[];
    out.add(center(s.namaTampilan.toUpperCase()));
    for (final l in wrap(s.alamatToko)) {
      out.add(center(l));
    }
    if (s.telpToko.isNotEmpty) out.add(center('Telp ${s.telpToko}'));
    out.add(line());
    out.add(pair('No', sale.invoiceNo));
    out.add(pair('Tgl', tanggalJam(sale.createdAt)));
    out.add(pair('Kasir', sale.userName));
    if (sale.customerName.isNotEmpty) out.add(pair('Pembeli', sale.customerName));
    out.add(line());
    for (final it in sale.items) {
      out.addAll(wrap(it.name));
      out.add(pair('  ${it.qty} x ${angka(it.price)}', angka(it.subtotal)));
    }
    out.add(line());
    if (sale.discount > 0) {
      out.add(pair('Subtotal', angka(sale.subtotal)));
      out.add(pair('Diskon', '-${angka(sale.discount)}'));
    }
    final totalQty = sale.items.fold<int>(0, (sum, item) => sum + item.qty);
    out.add(pair('Jumlah Kuantitas', angka(totalQty)));
    out.add(pair('TOTAL', angka(sale.total)));
    out.add(pair('Bayar', angka(sale.paid)));
    out.add(pair('Kembali', angka(sale.change)));
    out.add(line());
    for (final l in wrap(s.catatanStruk)) {
      out.add(center(l));
    }
    return out;
  }

  static List<String> refund(Refund r, Sale sale, SettingsProvider s) {
    final out = <String>[];
    out.add(center(s.namaTampilan.toUpperCase()));
    out.add(center('BUKTI RETUR'));
    out.add(line());
    out.add(pair('No Struk', r.invoiceNo));
    out.add(pair('Tgl Retur', tanggalJam(r.createdAt)));
    out.add(pair('Petugas', r.userName));
    out.add(line());
    for (final it in r.items) {
      out.addAll(wrap(it.name));
      out.add(pair('  ${it.qty} x ${angka(it.price)}', angka(it.subtotal)));
    }
    out.add(line());
    out.add(pair('DIKEMBALIKAN', angka(r.totalRefund)));
    if (r.reason.isNotEmpty) {
      out.add(line());
      out.add('Alasan:');
      out.addAll(wrap(r.reason));
    }
    out.add(line());
    out.add(center('Simpan bukti ini'));
    return out;
  }

  static String asText(List<String> lines) => lines.join('\n');
}
