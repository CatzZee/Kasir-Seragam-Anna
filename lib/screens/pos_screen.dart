import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repositories.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/refresh_signal.dart';
import '../widgets/app_widgets.dart';
import 'checkout_screens.dart';

/// Layar kasir. Prioritas layout: daftar barang besar dan mudah ditekan,
/// total belanja selalu terlihat di bawah, tanpa gestur tersembunyi.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with AutomaticKeepAliveClientMixin {
  final _repo = ProductRepository();
  final _searchCtrl = TextEditingController();

  List<Product> _products = [];
  List<String> _categories = ['Semua'];
  String _category = 'Semua';
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    // Layar ini tetap hidup saat pindah tab, jadi ia harus diberi tahu
    // ketika stok berubah akibat transaksi atau retur di layar lain.
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
    final cats = await _repo.categories();
    final list = await _repo.search(keyword: _searchCtrl.text, category: _category);
    if (!mounted) return;
    setState(() {
      _categories = ['Semua', ...cats];
      _products = list;
      _loading = false;
    });
  }

  void _addToCart(Product p) {
    final cart = context.read<CartProvider>();
    final inset = cart.isEmpty ? kNavBarInset : kNavBarWithActionInset;
    final err = cart.add(p);
    if (err != null) {
      showSnack(context, err, isError: true, bottomMargin: inset);
      return;
    }
    showSnack(context, '${p.name} masuk keranjang.',
        bottomMargin: kNavBarWithActionInset);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        actions: [
          IconButton(tooltip: 'Muat ulang daftar barang', onPressed: _load, icon: const Icon(Icons.refresh)),
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
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama barang atau kode',
                prefixIcon: const Icon(Icons.search, size: 26),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        iconSize: 26,
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _categories[i];
                final selected = c == _category;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  labelStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.text,
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onSelected: (_) {
                    setState(() => _category = c);
                    _load();
                  },
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'Barang tidak ditemukan',
                        message: 'Coba ganti kata pencarian atau pilih kategori lain.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final p = _products[i];
                          final inCart = cart.qtyOf(p.id!);
                          return _ProductTile(
                            product: p,
                            qtyInCart: inCart,
                            onAdd: p.isOutOfStock ? null : () => _addToCart(p),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : BottomActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${cart.totalQty} barang',
                            style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                        Text(rupiah(cart.subtotal),
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 190,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.primaryDark,
                      ),
                      onPressed: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const CartScreen())),
                      icon: const Icon(Icons.shopping_cart, size: 24),
                      label: const Text('Keranjang'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final int qtyInCart;
  final VoidCallback? onAdd;

  const _ProductTile({required this.product, required this.qtyInCart, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final habis = product.isOutOfStock;
    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: qtyInCart > 0 ? AppColors.success : (habis ? AppColors.border : null),
      onTap: onAdd,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: habis ? AppColors.border : AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.checkroom,
                size: 30, color: habis ? AppColors.textMuted : AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.25)),
                const SizedBox(height: 4),
                Text(product.sku, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(rupiah(product.sellPrice),
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    const SizedBox(width: 10),
                    StatusChip(
                      text: habis ? 'Stok habis' : 'Stok ${product.stock}',
                      color: habis ? AppColors.danger : AppColors.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (qtyInCart > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$qtyInCart',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            )
          else
            SizedBox(
              width: 52,
              height: 52,
              child: Material(
                color: habis ? AppColors.border : AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(10),
                  child: Icon(Icons.add,
                      color: habis ? AppColors.textMuted : Colors.white, size: 28),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
