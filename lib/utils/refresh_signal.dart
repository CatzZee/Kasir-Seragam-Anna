import 'package:flutter/foundation.dart';

/// Penanda bahwa data stok/transaksi berubah.
///
/// HomeShell memakai IndexedStack dan PosScreen memakai keep-alive, supaya
/// pindah tab tidak me-reset pencarian dan posisi scroll. Konsekuensinya,
/// layar yang sudah termuat tidak tahu bahwa stok berubah di layar lain.
/// Nilai ini dinaikkan setiap kali stok berubah, dan layar yang menampilkan
/// stok mendengarkannya lalu memuat ulang dirinya sendiri.
final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

void notifyDataChanged() => dataRevision.value++;
