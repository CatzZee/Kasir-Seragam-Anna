import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repositories.dart';
import '../providers/providers.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';

/// Laporan pergerakan stok. Setiap baris mencatat siapa yang mengubah stok,
/// kapan, sebanyak berapa, dan sisa stok setelahnya — sehingga selisih antara
/// stok fisik dan stok sistem bisa ditelusuri sampai ke orangnya.
class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  final _repo = ProductRepository();
  final _searchCtrl = TextEditingController();

  DateTimeRange _range = DateTimeRange(
    start: awalHari(DateTime.now().subtract(const Duration(days: 29))),
    end: akhirHari(DateTime.now()),
  );
  String _type = 'masuk';
  List<StockMove> _items = [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.stockMoves(
      from: _range.start,
      to: _range.end,
      type: _type,
      keyword: _searchCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
      locale: const Locale('id', 'ID'),
      helpText: 'Pilih rentang tanggal',
      saveText: 'Terapkan',
    );
    if (picked == null) return;
    setState(() =>
        _range = DateTimeRange(start: awalHari(picked.start), end: akhirHari(picked.end)));
    _load();
  }

  Future<void> _export() async {
    if (_items.isEmpty) {
      showSnack(context, 'Tidak ada data untuk diekspor.', isError: true);
      return;
    }
    setState(() => _exporting = true);
    try {
      final rows = <List<Object?>>[
        ['LAPORAN PERGERAKAN STOK'],
        ['Periode', '${tanggalPendek(_range.start)} sampai ${tanggalPendek(_range.end)}'],
        ['Jenis', _typeLabel(_type)],
        ['Dibuat', tanggalJam(DateTime.now())],
        [],
        ['Tanggal', 'Kode', 'Nama Barang', 'Jenis', 'Jumlah', 'Sisa Stok', 'Petugas', 'Keterangan', 'Referensi'],
        ..._items.map((m) => [
              tanggalJam(m.createdAt),
              m.sku,
              m.productName,
              m.typeLabel,
              m.isMasuk ? m.qty : -m.qty,
              m.stockAfter,
              m.userName,
              m.note,
              m.ref,
            ]),
        [],
        ['Total baris', _items.length],
        ['Total masuk', _items.where((e) => e.isMasuk).fold<int>(0, (a, b) => a + b.qty)],
        ['Total keluar', _items.where((e) => !e.isMasuk).fold<int>(0, (a, b) => a + b.qty)],
      ];

      final name = ExportService.safeName(
          'Stok_${tanggalPendek(_range.start)}_${tanggalPendek(_range.end)}.csv');
      await ExportService.exportCsv(
        fileName: name,
        rows: rows,
        subject: 'Laporan Pergerakan Stok',
        text: 'Buka berkas ini dengan Microsoft Excel atau Google Sheets.',
      );
      if (mounted) showSnack(context, 'Berkas $name siap dibagikan.');
    } catch (e) {
      if (mounted) showSnack(context, 'Gagal mengekspor: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _typeLabel(String t) => switch (t) {
        'masuk' => 'Barang masuk',
        'keluar' => 'Barang keluar',
        'retur' => 'Retur masuk',
        _ => 'Semua',
      };

  @override
  Widget build(BuildContext context) {
    // Pertahanan berlapis: meski pintasannya sudah disembunyikan, layar ini
    // menolak dibuka oleh peran kasir bila diakses lewat jalur lain.
    if (!context.watch<AuthProvider>().isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Akses Ditolak')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'Hanya untuk pemilik',
          message: 'Laporan pergerakan stok hanya bisa dibuka oleh pemilik toko.',
        ),
      );
    }

    final masuk = _items.where((e) => e.isMasuk).fold<int>(0, (a, b) => a + b.qty);
    final keluar = _items.where((e) => !e.isMasuk).fold<int>(0, (a, b) => a + b.qty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Stok'),
        actions: [
          IconButton(
            tooltip: 'Pilih rentang tanggal',
            onPressed: _pickRange,
            icon: const Icon(Icons.calendar_today),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _load(),
              decoration: const InputDecoration(
                hintText: 'Cari barang atau nama petugas',
                prefixIcon: Icon(Icons.search, size: 26),
              ),
            ),
          ),
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final t in const ['masuk', 'keluar', 'retur', 'semua'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_typeLabel(t)),
                      selected: _type == t,
                      labelStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _type == t ? Colors.white : AppColors.text,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.border, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      onSelected: (_) {
                        setState(() => _type = t);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${tanggalPendek(_range.start)} - ${tanggalPendek(_range.end)}',
                          style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      Text('${_items.length} catatan',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Masuk $masuk pcs',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.success)),
                    Text('Keluar $keluar pcs',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.danger)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Belum ada catatan',
                        message: 'Tidak ada pergerakan stok pada rentang tanggal ini.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final m = _items[i];
                          final warna = m.isMasuk ? AppColors.success : AppColors.danger;
                          return AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(m.productName,
                                              style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.25)),
                                          const SizedBox(height: 3),
                                          Text('${m.sku}  -  ${tanggalJam(m.createdAt)}',
                                              style: const TextStyle(
                                                  fontSize: 13, color: AppColors.textMuted)),
                                        ],
                                      ),
                                    ),
                                    Text('${m.isMasuk ? '+' : '-'}${m.qty}',
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: warna)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    StatusChip(text: m.typeLabel, color: warna),
                                    StatusChip(
                                        text: 'Sisa ${m.stockAfter}', color: AppColors.textMuted),
                                    StatusChip(
                                        text: m.userName,
                                        color: AppColors.primary,
                                        icon: Icons.person_outline),
                                  ],
                                ),
                                if (m.note.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(m.note,
                                      style: const TextStyle(
                                          fontSize: 14, color: AppColors.textMuted, height: 1.35)),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: ElevatedButton.icon(
          onPressed: _exporting ? null : _export,
          icon: _exporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Icon(Icons.table_view, size: 24),
          label: Text(_exporting ? 'Menyiapkan...' : 'Ekspor ke Excel'),
        ),
      ),
    );
  }
}
