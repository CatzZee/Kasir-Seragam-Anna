import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repositories.dart';
import '../providers/providers.dart';
import '../services/printer_service.dart';
import '../services/receipt_builder.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';
import 'checkout_screens.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repo = SaleRepository();
  final _searchCtrl = TextEditingController();

  DateTimeRange _range = DateTimeRange(
    start: awalHari(DateTime.now().subtract(const Duration(days: 6))),
    end: akhirHari(DateTime.now()),
  );
  List<Sale> _sales = [];
  bool _loading = true;

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
    final list = await _repo.history(
      from: _range.start,
      to: _range.end,
      keyword: _searchCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _sales = list;
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
    setState(() => _range = DateTimeRange(start: awalHari(picked.start), end: akhirHari(picked.end)));
    _load();
  }

  void _preset(int days) {
    final now = DateTime.now();
    setState(() => _range = DateTimeRange(
          start: awalHari(now.subtract(Duration(days: days - 1))),
          end: akhirHari(now),
        ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;
    final totalPeriode = _sales.fold<int>(0, (a, b) => a + b.total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
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
                hintText: 'Cari nomor struk atau nama pembeli',
                prefixIcon: Icon(Icons.search, size: 26),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _chip('Hari ini', () => _preset(1)),
                const SizedBox(width: 8),
                _chip('7 hari', () => _preset(7)),
                const SizedBox(width: 8),
                _chip('30 hari', () => _preset(30)),
                const SizedBox(width: 8),
                _chip('Pilih tanggal', _pickRange, icon: Icons.date_range),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${tanggalPendek(_range.start)} - ${tanggalPendek(_range.end)}',
                          style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      Text('${_sales.length} transaksi',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                // Jumlah omzet satu periode adalah angka laporan.
                // Kasir tetap bisa membuka tiap nota untuk cetak ulang dan retur.
                if (isAdmin)
                  Text(rupiah(totalPeriode),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _sales.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Belum ada transaksi',
                        message: 'Tidak ada transaksi pada rentang tanggal ini.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _sales.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final s = _sales[i];
                            final diretur = s.status != 'selesai';
                            return AppCard(
                              padding: const EdgeInsets.all(14),
                              borderColor: diretur ? AppColors.danger : null,
                              onTap: () async {
                                await Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => SaleDetailScreen(saleId: s.id!)));
                                _load();
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.invoiceNo,
                                            style: const TextStyle(
                                                fontSize: 17, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${tanggalJam(s.createdAt)}  -  ${s.userName}'
                                          '${s.customerName.isEmpty ? '' : '\nPembeli: ${s.customerName}'}',
                                          style: const TextStyle(
                                              fontSize: 14, color: AppColors.textMuted, height: 1.35),
                                        ),
                                        if (diretur) ...[
                                          const SizedBox(height: 8),
                                          StatusChip(
                                            text: s.statusLabel,
                                            color: AppColors.danger,
                                            icon: Icons.assignment_return,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(rupiah(s.total),
                                          style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary)),
                                      const SizedBox(height: 4),
                                      const Icon(Icons.chevron_right, color: AppColors.textMuted),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap, {IconData? icon}) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        onPressed: onTap,
        icon: Icon(icon ?? Icons.schedule, size: 18),
        label: Text(label),
      );
}

// ---------------------------- DETAIL TRANSAKSI ------------------------------

class SaleDetailScreen extends StatefulWidget {
  final int saleId;
  const SaleDetailScreen({super.key, required this.saleId});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  final _repo = SaleRepository();
  Sale? _sale;
  List<Refund> _refunds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _repo.detail(widget.saleId);
    final r = await _repo.refundsOf(widget.saleId);
    if (!mounted) return;
    setState(() {
      _sale = s;
      _refunds = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _sale;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Transaksi')),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'Transaksi tidak ditemukan',
          message: 'Data mungkin sudah dihapus.',
        ),
      );
    }

    final bisaRetur = s.items.any((i) => i.qtyRemaining > 0);
    final totalRetur = _refunds.fold<int>(0, (a, b) => a + b.totalRefund);

    return Scaffold(
      appBar: AppBar(title: Text(s.invoiceNo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _info('Tanggal', tanggalJam(s.createdAt)),
                _info('Kasir', s.userName),
                if (s.customerName.isNotEmpty) _info('Pembeli', s.customerName),
                _info('Status', s.statusLabel,
                    color: s.status == 'selesai' ? AppColors.success : AppColors.danger),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Barang dibeli', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...s.items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text('${it.qty} x ${rupiah(it.price)}',
                                style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                            if (it.qtyReturned > 0) ...[
                              const SizedBox(height: 6),
                              StatusChip(text: '${it.qtyReturned} diretur', color: AppColors.danger),
                            ],
                          ],
                        ),
                      ),
                      Text(rupiah(it.subtotal),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                _row('Subtotal', rupiah(s.subtotal)),
                if (s.discount > 0) _row('Potongan', '- ${rupiah(s.discount)}', color: AppColors.danger),
                _row('Total', rupiah(s.total), big: true),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                _row('Tunai', rupiah(s.paid)),
                _row('Kembalian', rupiah(s.change)),
                if (totalRetur > 0) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                  _row('Total dikembalikan', rupiah(totalRetur), color: AppColors.danger, big: true),
                ],
              ],
            ),
          ),
          if (_refunds.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Riwayat retur', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ..._refunds.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    borderColor: AppColors.danger,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(tanggalJam(r.createdAt),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            Text(rupiah(r.totalRefund),
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.danger)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...r.items.map((i) => Text('- ${i.name}  (${i.qty} pcs)',
                            style: const TextStyle(fontSize: 15, height: 1.5))),
                        if (r.reason.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Alasan: ${r.reason}',
                              style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                        ],
                        Text('Petugas: ${r.userName}${r.restock ? '' : '  (stok tidak dikembalikan)'}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 2),
                ),
                onPressed: bisaRetur
                    ? () async {
                        final done = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => RefundScreen(sale: s)),
                        );
                        if (done == true) _load();
                      }
                    : null,
                icon: const Icon(Icons.assignment_return, size: 22),
                label: const Text('Retur'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => ReceiptScreen(sale: s))),
                icon: const Icon(Icons.print, size: 22),
                label: const Text('Lihat / cetak struk'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textMuted)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: color ?? AppColors.text)),
            ),
          ],
        ),
      );

  Widget _row(String label, String value, {bool big = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: big ? 18 : 16, fontWeight: big ? FontWeight.w700 : FontWeight.w400)),
            Text(value,
                style: TextStyle(
                    fontSize: big ? 22 : 17,
                    fontWeight: big ? FontWeight.w800 : FontWeight.w600,
                    color: color ?? (big ? AppColors.primary : AppColors.text))),
          ],
        ),
      );
}

// -------------------------------- RETUR ------------------------------------

class RefundScreen extends StatefulWidget {
  final Sale sale;
  const RefundScreen({super.key, required this.sale});

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  final _repo = SaleRepository();
  final _reasonCtrl = TextEditingController();
  final Map<int, int> _qty = {};
  bool _restock = true;
  bool _saving = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  int get _total {
    var t = 0;
    for (final it in widget.sale.items) {
      t += (_qty[it.id] ?? 0) * it.price;
    }
    return t;
  }

  Future<void> _process() async {
    if (_total <= 0) {
      showSnack(context, 'Pilih dulu barang yang diretur.', isError: true);
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      showSnack(context, 'Alasan retur wajib diisi untuk catatan toko.', isError: true);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Proses retur?',
      message: 'Uang sebesar ${rupiah(_total)} dikembalikan ke pembeli'
          '${_restock ? ' dan stok barang ditambahkan kembali' : ''}. Tindakan ini tidak bisa dibatalkan.',
      confirmText: 'Ya, proses retur',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      final refund = await _repo.createRefund(
        user: auth.user!,
        sale: widget.sale,
        qtyPerSaleItemId: _qty,
        reason: _reasonCtrl.text,
        restock: _restock,
      );
      if (!mounted) return;
      final settings = context.read<SettingsProvider>();
      if (settings.printerMac.isNotEmpty) {
        final lines = ReceiptBuilder.refund(refund, widget.sale, settings);
        await PrinterService.instance.printLines(settings.printerMac, lines);
      }
      if (!mounted) return;
      showSnack(context, 'Retur ${rupiah(refund.totalRefund)} tercatat.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.sale.items.where((i) => i.qtyRemaining > 0).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Retur Barang')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppSize.radius),
              border: Border.all(color: AppColors.accent, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primaryDark, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Retur dicatat pada tanggal hari ini, bukan tanggal transaksi asli '
                    '(${tanggalPendek(widget.sale.createdAt)}). Laporan bulan berjalan akan berkurang.',
                    style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Pilih barang yang dikembalikan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...items.map((it) {
            final q = _qty[it.id] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                borderColor: q > 0 ? AppColors.danger : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text('${rupiah(it.price)} / pcs  -  bisa diretur ${it.qtyRemaining} pcs',
                        style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        QtyStepper(
                          value: q,
                          onMinus: () => setState(() => _qty[it.id!] = (q - 1).clamp(0, it.qtyRemaining)),
                          onPlus: () => setState(() => _qty[it.id!] = (q + 1).clamp(0, it.qtyRemaining)),
                        ),
                        Text(rupiah(q * it.price),
                            style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: q > 0 ? AppColors.danger : AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Alasan retur (wajib)',
              hintText: 'Contoh: ukuran tidak muat, jahitan lepas',
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SwitchListTile(
              value: _restock,
              onChanged: (v) => setState(() => _restock = v),
              activeColor: AppColors.success,
              title: const Text('Barang kembali ke stok',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              subtitle: Text(
                _restock
                    ? 'Stok bertambah karena barang masih layak jual.'
                    : 'Stok tidak bertambah karena barang rusak.',
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Uang dikembalikan', style: TextStyle(fontSize: 16)),
                Text(rupiah(_total),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.danger)),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size.fromHeight(58),
              ),
              onPressed: (_saving || _total <= 0) ? null : _process,
              icon: const Icon(Icons.assignment_return, size: 24),
              label: Text(_saving ? 'Memproses...' : 'Proses retur'),
            ),
          ],
        ),
      ),
    );
  }
}
