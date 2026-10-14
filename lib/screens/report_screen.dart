import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repositories.dart';
import '../providers/providers.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> with SingleTickerProviderStateMixin {
  final _repo = ReportRepository();
  late final TabController _tab;

  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: akhirHari(DateTime.now()),
  );

  ReportSummary _summary = const ReportSummary();
  List<ProductSold> _products = [];
  List<Refund> _refunds = [];
  List<DailyPoint> _daily = [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await _repo.summary(_range.start, _range.end);
    final p = await _repo.productsSold(_range.start, _range.end);
    final r = await _repo.refunds(_range.start, _range.end);
    final d = await _repo.dailyRevenue(_range.start, _range.end);
    if (!mounted) return;
    setState(() {
      _summary = s;
      _products = p;
      _refunds = r;
      _daily = d;
      _loading = false;
    });
  }

  void _preset(String key) {
    final now = DateTime.now();
    setState(() {
      _range = switch (key) {
        'hari' => DateTimeRange(start: awalHari(now), end: akhirHari(now)),
        'minggu' => DateTimeRange(
            start: awalHari(now.subtract(const Duration(days: 6))), end: akhirHari(now)),
        'bulan' => DateTimeRange(start: DateTime(now.year, now.month, 1), end: akhirHari(now)),
        _ => DateTimeRange(start: DateTime(now.year, 1, 1), end: akhirHari(now)),
      };
    });
    _load();
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
    setState(() => _range = DateTimeRange(start: awalHari(picked.start), end: akhirHari(picked.end)));
    _load();
  }

  /// Satu berkas berisi tiga bagian: ringkasan, produk terjual, dan retur.
  /// Digabung dalam satu lembar supaya pemilik toko cukup membuka satu berkas,
  /// bukan mencari-cari di antara tiga lampiran.
  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final rows = <List<Object?>>[
        ['LAPORAN PENJUALAN'],
        ['Periode', '${tanggalPendek(_range.start)} sampai ${tanggalPendek(_range.end)}'],
        ['Dibuat', tanggalJam(DateTime.now())],
        [],
        ['RINGKASAN'],
        ['Penjualan kotor', _summary.penjualanKotor],
        ['Total potongan', _summary.totalDiskon],
        ['Total retur', _summary.totalRetur],
        ['Pendapatan bersih', _summary.pendapatanBersih],
        ['Laba kotor', _summary.labaKotor],
        ['Jumlah transaksi', _summary.jumlahTransaksi],
        ['Jumlah retur', _summary.jumlahRetur],
        ['Barang terjual (pcs)', _summary.itemTerjual],
        ['Rata-rata per nota', _summary.rataRataTransaksi],
        [],
        ['PENJUALAN PER HARI'],
        ['Tanggal', 'Total'],
        ..._daily.map((d) => [tanggalPendek(d.date), d.value]),
        [],
        ['PRODUK TERJUAL'],
        ['Kode', 'Nama Barang', 'Terjual', 'Diretur', 'Bersih', 'Omzet', 'Laba'],
        ..._products.map((p) => [p.sku, p.name, p.qty, p.qtyReturned, p.qtyNet, p.omzet, p.laba]),
        [],
        ['RETUR'],
        ['Tanggal', 'No Nota', 'Petugas', 'Barang', 'Jumlah', 'Nilai', 'Alasan'],
        ..._refunds.expand((r) => r.items.map((i) => [
              tanggalJam(r.createdAt),
              r.invoiceNo,
              r.userName,
              i.name,
              i.qty,
              i.subtotal,
              r.reason,
            ])),
      ];

      final name = ExportService.safeName(
          'Laporan_${tanggalPendek(_range.start)}_${tanggalPendek(_range.end)}.csv');
      await ExportService.exportCsv(
        fileName: name,
        rows: rows,
        subject: 'Laporan Penjualan Anna Seragam',
        text: 'Buka berkas ini dengan Microsoft Excel atau Google Sheets.',
      );
      if (mounted) showSnack(context, 'Berkas $name siap dibagikan.');
    } catch (e) {
      if (mounted) showSnack(context, 'Gagal mengekspor: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

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
          message: 'Laporan memuat harga modal dan keuntungan toko, '
              'sehingga hanya bisa dibuka oleh pemilik.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          IconButton(
            tooltip: 'Pilih rentang tanggal',
            onPressed: _pickRange,
            icon: const Icon(Icons.calendar_today),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.accent,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFBFD3EE),
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 15),
          tabs: const [
            Tab(text: 'Pendapatan'),
            Tab(text: 'Produk'),
            Tab(text: 'Retur'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _preset0('Hari ini', 'hari'),
                        _preset0('7 hari', 'minggu'),
                        _preset0('Bulan ini', 'bulan'),
                        _preset0('Tahun ini', 'tahun'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: AppColors.primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Periode: ${tanggalPendek(_range.start)} - ${tanggalPendek(_range.end)}',
                style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tab,
                    children: [_tabPendapatan(), _tabProduk(), _tabRetur()],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: ElevatedButton.icon(
          onPressed: (_loading || _exporting) ? null : _export,
          icon: _exporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Icon(Icons.table_view, size: 24),
          label: Text(_exporting ? 'Menyiapkan berkas...' : 'Ekspor ke Excel'),
        ),
      ),
    );
  }

  Widget _preset0(String label, String key) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          onPressed: () => _preset(key),
          child: Text(label),
        ),
      );

  // ------------------------------ TAB 1 ------------------------------------

  Widget _tabPendapatan() {
    final maxVal = _daily.isEmpty ? 1 : _daily.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppSize.radius),
          ),
          child: Column(
            children: [
              const Text('Pendapatan bersih',
                  style: TextStyle(fontSize: 15, color: Color(0xFFBFD3EE))),
              const SizedBox(height: 6),
              FittedBox(
                child: Text(rupiah(_summary.pendapatanBersih),
                    style: const TextStyle(
                        fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              Text('Penjualan ${rupiah(_summary.penjualanKotor)}  -  Retur ${rupiah(_summary.totalRetur)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFBFD3EE))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Laba kotor',
                value: rupiah(_summary.labaKotor),
                color: AppColors.success,
                icon: Icons.savings_outlined,
                sub: 'Harga jual dikurangi modal',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Jumlah transaksi',
                value: '${_summary.jumlahTransaksi}',
                color: AppColors.primary,
                icon: Icons.receipt_long_outlined,
                sub: 'Rata-rata ${rupiah(_summary.rataRataTransaksi)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Barang terjual',
                value: '${_summary.itemTerjual} pcs',
                color: AppColors.primaryDark,
                icon: Icons.shopping_bag_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Total potongan',
                value: rupiah(_summary.totalDiskon),
                color: AppColors.accent,
                icon: Icons.percent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Penjualan per hari', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (_daily.isEmpty)
          const AppCard(
            child: Text('Belum ada penjualan pada periode ini.', style: TextStyle(fontSize: 16)),
          )
        else
          AppCard(
            child: Column(
              children: _daily.reversed.take(14).toList().reversed.map((d) {
                final ratio = maxVal == 0 ? 0.0 : d.value / maxVal;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 62,
                        child: Text(tanggalPendek(d.date).substring(0, 5),
                            style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: ratio.clamp(0.02, 1.0),
                              child: Container(
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 96,
                        child: Text(angka(d.value),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ------------------------------ TAB 2 ------------------------------------

  Widget _tabProduk() {
    if (_products.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Belum ada penjualan',
        message: 'Tidak ada produk terjual pada periode ini.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = _products[i];
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i < 3 ? AppColors.accent : AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.25)),
                        const SizedBox(height: 2),
                        Text(p.sku, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _mini('Terjual', '${p.qty} pcs', AppColors.text)),
                  Expanded(child: _mini('Omzet', rupiah(p.omzet), AppColors.primary)),
                  Expanded(child: _mini('Laba', rupiah(p.laba), AppColors.success)),
                ],
              ),
              if (p.qtyReturned > 0) ...[
                const SizedBox(height: 10),
                StatusChip(
                    text: '${p.qtyReturned} pcs diretur - bersih ${p.qtyNet} pcs',
                    color: AppColors.danger,
                    icon: Icons.assignment_return),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _mini(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      );

  // ------------------------------ TAB 3 ------------------------------------

  Widget _tabRetur() {
    if (_refunds.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment_turned_in_outlined,
        title: 'Tidak ada retur',
        message: 'Bagus — tidak ada barang yang dikembalikan pada periode ini.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatTile(
          label: 'Total uang dikembalikan',
          value: rupiah(_summary.totalRetur),
          color: AppColors.danger,
          icon: Icons.assignment_return,
          sub: '${_summary.jumlahRetur} kali retur pada periode ini',
        ),
        const SizedBox(height: 14),
        ..._refunds.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                borderColor: AppColors.danger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(r.invoiceNo,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(rupiah(r.totalRefund),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.danger)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${tanggalJam(r.createdAt)}  -  ${r.userName}',
                        style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    ...r.items.map((i) => Text('- ${i.name} (${i.qty} pcs)',
                        style: const TextStyle(fontSize: 15, height: 1.5))),
                    if (r.reason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Alasan: ${r.reason}',
                          style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
            )),
        const SizedBox(height: 24),
      ],
    );
  }
}
