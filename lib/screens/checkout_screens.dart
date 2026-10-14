import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repositories.dart';
import '../providers/providers.dart';
import '../services/printer_service.dart';
import '../services/receipt_builder.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';

// ============================== KERANJANG ==================================

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _discountCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    if (cart.discount > 0) _discountCtrl.text = angka(cart.discount);
    _customerCtrl.text = cart.customerName;
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
        actions: [
          if (!cart.isEmpty)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Kosongkan keranjang?',
                  message: 'Semua barang di keranjang akan dihapus.',
                  confirmText: 'Ya, kosongkan',
                  destructive: true,
                );
                if (ok && context.mounted) {
                  cart.clear();
                  _discountCtrl.clear();
                }
              },
              icon: const Icon(Icons.delete_outline, size: 22),
              label: const Text('Kosongkan'),
            ),
        ],
      ),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Keranjang masih kosong',
              message: 'Pilih barang dulu di halaman Kasir.',
              action: SizedBox(
                width: 220,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Pilih barang'),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...cart.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CartRow(item: item),
                    )),
                const SizedBox(height: 10),
                TextField(
                  controller: _customerCtrl,
                  textCapitalization: TextCapitalization.words,
                  onChanged: cart.setCustomerName,
                  decoration: const InputDecoration(
                    labelText: 'Nama pembeli (boleh dikosongkan)',
                    prefixIcon: Icon(Icons.person_outline, size: 26),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _discountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => cart.setDiscount(parseUang(v)),
                  decoration: const InputDecoration(
                    labelText: 'Potongan harga (Rp)',
                    prefixIcon: Icon(Icons.percent, size: 26),
                    helperText: 'Isi nominal potongan, bukan persen.',
                    helperStyle: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    children: [
                      _row('Subtotal', rupiah(cart.subtotal)),
                      if (cart.discount > 0) ...[
                        const SizedBox(height: 8),
                        _row('Potongan', '- ${rupiah(cart.discount)}', color: AppColors.danger),
                      ],
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                      _row('Total bayar', rupiah(cart.total), big: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : BottomActionBar(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  minimumSize: const Size.fromHeight(60),
                ),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const PaymentScreen())),
                icon: const Icon(Icons.payments, size: 26),
                label: Text('Bayar  ${rupiah(cart.total)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ),
    );
  }

  Widget _row(String label, String value, {bool big = false, Color? color}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: big ? 19 : 16,
                  fontWeight: big ? FontWeight.w700 : FontWeight.w400,
                  color: AppColors.text)),
          Text(value,
              style: TextStyle(
                  fontSize: big ? 26 : 17,
                  fontWeight: big ? FontWeight.w800 : FontWeight.w600,
                  color: color ?? (big ? AppColors.primary : AppColors.text))),
        ],
      );
}

class _CartRow extends StatelessWidget {
  final CartItem item;
  const _CartRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
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
                    Text(item.product.name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.25)),
                    const SizedBox(height: 2),
                    Text('${rupiah(item.product.sellPrice)} / pcs',
                        style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hapus dari keranjang',
                iconSize: 26,
                color: AppColors.danger,
                onPressed: () => cart.remove(item.product.id!),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              QtyStepper(
                value: item.qty,
                onMinus: () => cart.setQty(item.product.id!, item.qty - 1),
                onPlus: () {
                  final err = cart.setQty(item.product.id!, item.qty + 1);
                  if (err != null) showSnack(context, err, isError: true);
                },
              ),
              Text(rupiah(item.subtotal),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================== PEMBAYARAN ================================

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _repo = SaleRepository();
  final _paidCtrl = TextEditingController();
  int _paid = 0;
  bool _saving = false;

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
  }

  void _setPaid(int value) {
    setState(() {
      _paid = value;
      _paidCtrl.text = value == 0 ? '' : angka(value);
      _paidCtrl.selection = TextSelection.collapsed(offset: _paidCtrl.text.length);
    });
  }

  /// Saran pecahan uang: uang pas, lalu pembulatan ke atas yang realistis
  /// dipakai di kasir Indonesia. Menghemat ketukan untuk kasus tersering.
  List<int> _suggestions(int total) {
    final out = <int>{total};
    for (final step in [5000, 10000, 20000, 50000, 100000]) {
      final v = ((total / step).ceil()) * step;
      if (v >= total) out.add(v);
    }
    final list = out.toList()..sort();
    return list.take(6).toList();
  }

  Future<void> _process() async {
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();
    if (_paid < cart.total) {
      showSnack(context, 'Uang bayar masih kurang ${rupiah(cart.total - _paid)}.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final sale = await _repo.createSale(
        user: auth.user!,
        cart: cart.items,
        discount: cart.discount,
        paid: _paid,
        customerName: cart.customerName,
      );
      cart.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ReceiptScreen(sale: sale, isNew: true)),
      );
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final total = cart.total;
    final kembali = _paid - total;

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: ListView(
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
                const Text('Total yang harus dibayar',
                    style: TextStyle(fontSize: 15, color: Color(0xFFBFD3EE))),
                const SizedBox(height: 6),
                FittedBox(
                  child: Text(rupiah(total),
                      style: const TextStyle(
                          fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(height: 4),
                Text('${cart.totalQty} barang',
                    style: const TextStyle(fontSize: 14, color: Color(0xFFBFD3EE))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Uang yang diterima', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          TextField(
            controller: _paidCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            onChanged: (v) => setState(() => _paid = parseUang(v)),
            decoration: const InputDecoration(
              prefixText: 'Rp  ',
              prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textMuted),
              hintText: '0',
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _suggestions(total)
                .map((v) => SizedBox(
                      height: AppSize.tap,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(120, AppSize.tap),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () => _setPaid(v),
                        child: Text(v == total ? 'Uang pas' : angka(v)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kembali < 0 ? AppColors.danger.withValues(alpha: 0.10) : AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSize.radius),
              border: Border.all(color: kembali < 0 ? AppColors.danger : AppColors.success, width: 2),
            ),
            child: Column(
              children: [
                Text(kembali < 0 ? 'Masih kurang' : 'Kembalian',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kembali < 0 ? AppColors.danger : AppColors.success)),
                const SizedBox(height: 6),
                FittedBox(
                  child: Text(rupiah(kembali.abs()),
                      style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: kembali < 0 ? AppColors.danger : AppColors.success)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            minimumSize: const Size.fromHeight(60),
          ),
          onPressed: (_saving || _paid < total) ? null : _process,
          icon: _saving
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Icon(Icons.check_circle, size: 26),
          label: Text(_saving ? 'Menyimpan...' : 'Selesaikan transaksi',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

// ================================ STRUK ====================================

class ReceiptScreen extends StatefulWidget {
  final Sale sale;
  final bool isNew;
  const ReceiptScreen({super.key, required this.sale, this.isNew = false});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    if (widget.isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final s = context.read<SettingsProvider>();
        if (s.autoPrint && s.printerMac.isNotEmpty) _print(silentIfNoPrinter: true);
      });
    }
  }

  Future<void> _print({bool silentIfNoPrinter = false}) async {
    final settings = context.read<SettingsProvider>();
    if (settings.printerMac.isEmpty) {
      if (!silentIfNoPrinter) {
        showSnack(context, 'Printer belum dipilih. Buka Pengaturan > Printer.', isError: true);
      }
      return;
    }
    setState(() => _printing = true);
    final lines = ReceiptBuilder.sale(widget.sale, settings);
    final res = await PrinterService.instance.printLines(settings.printerMac, lines);
    if (!mounted) return;
    setState(() => _printing = false);
    showSnack(context, res.message, isError: !res.success);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final lines = ReceiptBuilder.sale(widget.sale, settings);

    return PopScope(
      canPop: !widget.isNew,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).popUntil((r) => r.isFirst);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? 'Transaksi Berhasil' : 'Struk'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Tutup',
            onPressed: () => widget.isNew
                ? Navigator.of(context).popUntil((r) => r.isFirst)
                : Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.isNew)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSize.radius),
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Transaksi tersimpan',
                              style: TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.success)),
                          const SizedBox(height: 2),
                          Text('Kembalian ${rupiah(widget.sale.change)}',
                              style: const TextStyle(fontSize: 17, color: AppColors.text)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.isNew) const SizedBox(height: 16),
            // Pratinjau memakai teks 32 kolom yang sama persis dengan hasil cetak.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSize.radius),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: Text(
                  ReceiptBuilder.asText(lines),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.text,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (settings.printerMac.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSize.radius),
                  border: Border.all(color: AppColors.accent, width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.print_disabled, color: AppColors.primaryDark, size: 26),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Printer belum dipilih. Buka Pengaturan > Printer untuk memilihnya.',
                          style: TextStyle(fontSize: 15, color: AppColors.text)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.isNew
                      ? Navigator.of(context).popUntil((r) => r.isFirst)
                      : Navigator.pop(context),
                  icon: const Icon(Icons.done, size: 24),
                  label: const Text('Selesai'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _printing ? null : () => _print(),
                  icon: _printing
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.print, size: 24),
                  label: Text(_printing ? 'Mencetak...' : 'Cetak struk'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
