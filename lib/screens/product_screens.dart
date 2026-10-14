import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repositories.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/refresh_signal.dart';
import '../widgets/app_widgets.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});
  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _repo = ProductRepository();
  final _searchCtrl = TextEditingController();

  List<Product> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    dataRevision.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    dataRevision.removeListener(_onDataChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _repo.search(keyword: _searchCtrl.text, onlyActive: false);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _openForm([Product? p]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)),
    );
    if (changed == true) _load();
  }

  Future<void> _stockDialog(Product p) async {
    final result = await showDialog<_StockChange>(
      context: context,
      builder: (_) => _StockAdjustDialog(product: p),
    );
    if (result == null || result.qty <= 0) return;
    if (!result.masuk && result.qty > p.stock) {
      if (mounted) {
        showSnack(context, 'Jumlah keluar melebihi stok yang ada.',
            isError: true, bottomMargin: kNavBarInset);
      }
      return;
    }
    if (!mounted) return;
    // Nama petugas ikut dicatat agar laporan stok bisa menelusuri
    // siapa yang menambah atau mengurangi barang.
    final petugas = context.read<AuthProvider>().user?.name ?? '-';
    await _repo.adjustStock(
      p.id!,
      result.masuk ? result.qty : -result.qty,
      note: result.note.isEmpty
          ? (result.masuk ? 'Barang masuk' : 'Koreksi/barang keluar')
          : result.note,
      userName: petugas,
    );
    if (mounted) {
      showSnack(context, 'Stok ${p.name} diperbarui.', bottomMargin: kNavBarInset);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Stok')),
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _load(),
              decoration: const InputDecoration(
                hintText: 'Cari nama barang atau kode',
                prefixIcon: Icon(Icons.search, size: 26),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Belum ada barang',
                        message: 'Tambahkan barang dagangan supaya bisa dijual di kasir.',
                        action: isAdmin
                            ? SizedBox(
                                width: 240,
                                child: ElevatedButton.icon(
                                  onPressed: () => _openForm(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Tambah barang'),
                                ),
                              )
                            : null,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final p = _items[i];
                          return AppCard(
                            padding: const EdgeInsets.all(14),
                            borderColor: !p.isActive
                                ? AppColors.border
                                : (p.isOutOfStock ? AppColors.danger : null),
                            onTap: () => isAdmin ? _openForm(p) : _stockDialog(p),
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
                                          Text(p.name,
                                              style: const TextStyle(
                                                  fontSize: 17, fontWeight: FontWeight.w600, height: 1.25)),
                                          const SizedBox(height: 3),
                                          Text('${p.sku}  -  ${p.category}',
                                              style: const TextStyle(
                                                  fontSize: 13, color: AppColors.textMuted)),
                                        ],
                                      ),
                                    ),
                                    if (!p.isActive)
                                      const StatusChip(text: 'Nonaktif', color: AppColors.textMuted),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Harga jual',
                                              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                          Text(rupiah(p.sellPrice),
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary)),
                                        ],
                                      ),
                                    ),
                                    if (isAdmin)
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Modal',
                                                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                            Text(rupiah(p.costPrice),
                                                style: const TextStyle(
                                                    fontSize: 16, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Stok',
                                            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                        Text('${p.stock}',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: p.isOutOfStock
                                                    ? AppColors.danger
                                                    : AppColors.text)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                            minimumSize: const Size.fromHeight(48)),
                                        onPressed: () => _stockDialog(p),
                                        icon: const Icon(Icons.swap_vert, size: 22),
                                        label: const Text('Ubah stok'),
                                      ),
                                    ),
                                    // Harga jual & modal hanya boleh diubah pemilik.
                                    if (isAdmin) ...[
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                              minimumSize: const Size.fromHeight(48)),
                                          onPressed: () => _openForm(p),
                                          icon: const Icon(Icons.edit_outlined, size: 22),
                                          label: const Text('Ubah data'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.primaryDark,
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 26),
              label: const Text('Tambah barang',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

// ---------------------------- FORM BARANG ----------------------------------

/// Nilai penanda untuk item terakhir dropdown kategori. Sengaja memakai
/// karakter yang mustahil diketik pengguna sebagai nama kategori.
const String _kNewCategory = '::kategori-baru::';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _repo = ProductRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _sku;
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _sell;
  late final TextEditingController _stock;
  final _newCategoryCtrl = TextEditingController();
  bool _saving = false;

  // Kategori dipilih dari daftar, bukan diketik bebas, supaya tidak lahir
  // "Atribut" dan "atribut" sebagai dua kategori berbeda.
  List<String> _categories = [];
  late String _category;
  bool _isNewCategory = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _sku = TextEditingController(text: p?.sku ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _cost = TextEditingController(text: p == null ? '' : angka(p.costPrice));
    _sell = TextEditingController(text: p == null ? '' : angka(p.sellPrice));
    _stock = TextEditingController(text: p == null ? '' : '${p.stock}');
    _category = p?.category ?? 'Umum';
    _categories = [_category];
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final list = await _repo.categories(onlyActive: false);
    if (!mounted) return;
    setState(() {
      // Kategori produk yang sedang diedit wajib ada di daftar, kalau tidak
      // DropdownButtonFormField melempar galat karena nilainya tak dikenal.
      _categories = {..._list(list), _category}.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
  }

  List<String> _list(List<String> raw) => raw.where((e) => e.trim().isNotEmpty).toList();

  /// Menentukan kategori final. Bila pengguna mengetik kategori baru yang
  /// ternyata sama dengan yang sudah ada (beda huruf besar/kecil), ejaan lama
  /// yang dipakai — supaya tidak ada kategori kembar.
  String _resolveCategory() {
    if (!_isNewCategory) return _category;
    final typed = _newCategoryCtrl.text.trim();
    if (typed.isEmpty) return 'Umum';
    for (final c in _categories) {
      if (c.toLowerCase() == typed.toLowerCase()) return c;
    }
    return typed;
  }

  @override
  void dispose() {
    for (final c in [_sku, _name, _cost, _sell, _stock, _newCategoryCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Diambil sebelum await pertama agar context tidak dipakai lintas async gap.
    final petugas = context.read<AuthProvider>().user?.name ?? '-';
    setState(() => _saving = true);
    try {
      if (await _repo.skuTaken(_sku.text, exceptId: widget.product?.id)) {
        if (mounted) showSnack(context, 'Kode barang "${_sku.text}" sudah dipakai.', isError: true);
        return;
      }
      final p = Product(
        id: widget.product?.id,
        sku: _sku.text.trim().toUpperCase(),
        name: _name.text.trim(),
        category: _resolveCategory(),
        costPrice: parseUang(_cost.text),
        sellPrice: parseUang(_sell.text),
        stock: _isEdit ? widget.product!.stock : (int.tryParse(_stock.text) ?? 0),
        minStock: 0,
        // Status aktif produk lama dipertahankan apa adanya; produk baru
        // selalu langsung dijual. Toggle-nya dihapus atas permintaan pemilik.
        isActive: widget.product?.isActive ?? true,
      );
      if (_isEdit) {
        await _repo.update(p);
      } else {
        await _repo.insert(p, userName: petugas);
      }
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Data barang tersimpan.' : 'Barang baru ditambahkan.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, 'Gagal menyimpan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label belum diisi.' : null;

  @override
  Widget build(BuildContext context) {
    // Pertahanan berlapis: meski tombolnya sudah disembunyikan, layar ini
    // tetap menolak dibuka oleh peran kasir bila diakses lewat jalur lain.
    if (!context.watch<AuthProvider>().isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Akses Ditolak')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'Hanya untuk pemilik',
          message: 'Harga jual dan harga modal hanya bisa diubah oleh pemilik toko. '
              'Untuk menambah atau mengurangi stok, gunakan tombol "Ubah stok".',
        ),
      );
    }

    final margin = parseUang(_sell.text) - parseUang(_cost.text);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah Barang' : 'Tambah Barang')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama barang',
                hintText: 'Contoh: Kemeja Putih XXL',
              ),
              validator: (v) => _required(v, 'Nama barang'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _sku,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: const [UpperCaseFormatter()],
              decoration: const InputDecoration(
                labelText: 'Kode barang',
                hintText: 'Contoh: KPXXL',
                helperText: 'Otomatis jadi huruf besar. Kode harus unik.',
                helperStyle: TextStyle(fontSize: 13),
              ),
              validator: (v) => _required(v, 'Kode barang'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _isNewCategory ? _kNewCategory : _category,
              isExpanded: true,
              menuMaxHeight: 380,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                prefixIcon: Icon(Icons.category_outlined, size: 26),
              ),
              style: const TextStyle(fontSize: 17, color: AppColors.text),
              items: [
                ..._categories.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(fontSize: 17)),
                    )),
                const DropdownMenuItem(
                  value: _kNewCategory,
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 22, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Tambah kategori baru',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  if (v == _kNewCategory) {
                    _isNewCategory = true;
                  } else {
                    _isNewCategory = false;
                    _category = v;
                  }
                });
              },
            ),
            if (_isNewCategory) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _newCategoryCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama kategori baru',
                  hintText: 'Contoh: Baju',
                  prefixIcon: Icon(Icons.create_new_folder_outlined, size: 26),
                ),
                validator: (v) {
                  if (!_isNewCategory) return null;
                  return (v == null || v.trim().isEmpty) ? 'Nama kategori belum diisi.' : null;
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _isNewCategory = false),
                icon: const Icon(Icons.undo, size: 20),
                label: const Text('Pilih dari kategori yang sudah ada'),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Harga modal', prefixText: 'Rp '),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sell,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Harga jual', prefixText: 'Rp '),
                    validator: (v) =>
                        parseUang(v ?? '') <= 0 ? 'Harga jual harus diisi.' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              borderColor: margin < 0 ? AppColors.danger : AppColors.border,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Untung per barang', style: TextStyle(fontSize: 15)),
                  Text(rupiah(margin),
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: margin < 0 ? AppColors.danger : AppColors.success)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _stock,
              enabled: !_isEdit,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _isEdit ? 'Stok saat ini' : 'Stok awal',
                helperText: _isEdit ? 'Ubah lewat tombol "Ubah stok".' : null,
                helperStyle: const TextStyle(fontSize: 13),
                hintText: _isEdit ? '${widget.product!.stock}' : '0',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save, size: 24),
          label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
        ),
      ),
    );
  }
}


// --------------------------- DIALOG UBAH STOK ------------------------------

class _StockChange {
  final bool masuk;
  final int qty;
  final String note;
  const _StockChange(this.masuk, this.qty, this.note);
}

/// Dialog dibuat sebagai widget tersendiri supaya TextEditingController-nya
/// dimiliki dan dibuang oleh Flutter. Membuang controller tepat setelah
/// `await showDialog` menyebabkan galat "used after being disposed", karena
/// dialog masih dirender selama animasi menutup.
class _StockAdjustDialog extends StatefulWidget {
  final Product product;
  const _StockAdjustDialog({required this.product});

  @override
  State<_StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<_StockAdjustDialog> {
  final _ctrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _masuk = true;

  @override
  void dispose() {
    _ctrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final qty = int.tryParse(_ctrl.text) ?? 0;
    Navigator.pop(context, _StockChange(_masuk, qty, _noteCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return AlertDialog(
      title: const Text('Ubah stok'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Stok sekarang: ${p.stock}',
                style: const TextStyle(fontSize: 15, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Masuk'), icon: Icon(Icons.add)),
                ButtonSegment(value: false, label: Text('Keluar'), icon: Icon(Icons.remove)),
              ],
              selected: {_masuk},
              onSelectionChanged: (s) => setState(() => _masuk = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Jumlah'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Keterangan (boleh dikosongkan)',
                hintText: 'Contoh: kiriman dari supplier',
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: _submit, child: const Text('Simpan perubahan stok')),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ),
      ],
    );
  }
}
