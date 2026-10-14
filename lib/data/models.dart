// ---------------------------------------------------------------------------
// Model data. Seluruh nilai uang bertipe int (rupiah penuh).
// ---------------------------------------------------------------------------

class AppUser {
  final int? id;
  final String username;
  final String passwordHash;
  final String name;
  final String role; // 'admin' | 'kasir'
  final bool isActive;

  const AppUser({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.name,
    required this.role,
    this.isActive = true,
  });

  bool get isAdmin => role == 'admin';
  String get roleLabel => isAdmin ? 'Pemilik / Admin' : 'Kasir';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'username': username,
        'password_hash': passwordHash,
        'name': name,
        'role': role,
        'is_active': isActive ? 1 : 0,
      };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as int?,
        username: m['username'] as String,
        passwordHash: m['password_hash'] as String,
        name: m['name'] as String,
        role: m['role'] as String,
        isActive: (m['is_active'] as int) == 1,
      );

  AppUser copyWith({String? username, String? passwordHash, String? name, String? role, bool? isActive}) =>
      AppUser(
        id: id,
        username: username ?? this.username,
        passwordHash: passwordHash ?? this.passwordHash,
        name: name ?? this.name,
        role: role ?? this.role,
        isActive: isActive ?? this.isActive,
      );
}

class Product {
  final int? id;
  final String sku;
  final String name;
  final String category;
  final int costPrice; // harga modal
  final int sellPrice; // harga jual
  final int stock;
  final int minStock;
  final bool isActive;

  const Product({
    this.id,
    required this.sku,
    required this.name,
    this.category = 'Umum',
    this.costPrice = 0,
    required this.sellPrice,
    this.stock = 0,
    this.minStock = 3,
    this.isActive = true,
  });

  bool get isOutOfStock => stock <= 0;
  int get margin => sellPrice - costPrice;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sku': sku,
        'name': name,
        'category': category,
        'cost_price': costPrice,
        'sell_price': sellPrice,
        'stock': stock,
        'min_stock': minStock,
        'is_active': isActive ? 1 : 0,
      };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as int?,
        sku: m['sku'] as String,
        name: m['name'] as String,
        category: (m['category'] as String?) ?? 'Umum',
        costPrice: (m['cost_price'] as int?) ?? 0,
        sellPrice: m['sell_price'] as int,
        stock: (m['stock'] as int?) ?? 0,
        minStock: (m['min_stock'] as int?) ?? 0,
        isActive: ((m['is_active'] as int?) ?? 1) == 1,
      );

  Product copyWith({
    String? sku,
    String? name,
    String? category,
    int? costPrice,
    int? sellPrice,
    int? stock,
    int? minStock,
    bool? isActive,
  }) =>
      Product(
        id: id,
        sku: sku ?? this.sku,
        name: name ?? this.name,
        category: category ?? this.category,
        costPrice: costPrice ?? this.costPrice,
        sellPrice: sellPrice ?? this.sellPrice,
        stock: stock ?? this.stock,
        minStock: minStock ?? this.minStock,
        isActive: isActive ?? this.isActive,
      );
}

/// Baris keranjang. Bukan entitas database.
class CartItem {
  final Product product;
  int qty;
  CartItem({required this.product, this.qty = 1});
  int get subtotal => product.sellPrice * qty;
}

class SaleItem {
  final int? id;
  final int? saleId;
  final int productId;
  final String sku;
  final String name;
  final int price; // harga jual saat transaksi (snapshot)
  final int costPrice; // modal saat transaksi (snapshot)
  final int qty;
  final int qtyReturned;

  const SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.sku,
    required this.name,
    required this.price,
    required this.costPrice,
    required this.qty,
    this.qtyReturned = 0,
  });

  int get subtotal => price * qty;
  int get qtyRemaining => qty - qtyReturned;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sale_id': saleId,
        'product_id': productId,
        'sku': sku,
        'name': name,
        'price': price,
        'cost_price': costPrice,
        'qty': qty,
        'qty_returned': qtyReturned,
      };

  factory SaleItem.fromMap(Map<String, dynamic> m) => SaleItem(
        id: m['id'] as int?,
        saleId: m['sale_id'] as int?,
        productId: m['product_id'] as int,
        sku: m['sku'] as String,
        name: m['name'] as String,
        price: m['price'] as int,
        costPrice: (m['cost_price'] as int?) ?? 0,
        qty: m['qty'] as int,
        qtyReturned: (m['qty_returned'] as int?) ?? 0,
      );
}

class Sale {
  final int? id;
  final String invoiceNo;
  final int userId;
  final String userName;
  final String customerName;
  final int subtotal;
  final int discount;
  final int total;
  final int paid;
  final int change;
  final String status; // 'selesai' | 'retur_sebagian' | 'retur_penuh'
  final DateTime createdAt;
  final List<SaleItem> items;

  const Sale({
    this.id,
    required this.invoiceNo,
    required this.userId,
    required this.userName,
    this.customerName = '',
    required this.subtotal,
    this.discount = 0,
    required this.total,
    required this.paid,
    required this.change,
    this.status = 'selesai',
    required this.createdAt,
    this.items = const [],
  });

  String get statusLabel => switch (status) {
        'retur_penuh' => 'Diretur penuh',
        'retur_sebagian' => 'Diretur sebagian',
        _ => 'Selesai',
      };

  int get totalQty => items.fold(0, (a, b) => a + b.qty);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'invoice_no': invoiceNo,
        'user_id': userId,
        'user_name': userName,
        'customer_name': customerName,
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'paid': paid,
        'change': change,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  factory Sale.fromMap(Map<String, dynamic> m, {List<SaleItem> items = const []}) => Sale(
        id: m['id'] as int?,
        invoiceNo: m['invoice_no'] as String,
        userId: m['user_id'] as int,
        userName: (m['user_name'] as String?) ?? '-',
        customerName: (m['customer_name'] as String?) ?? '',
        subtotal: m['subtotal'] as int,
        discount: (m['discount'] as int?) ?? 0,
        total: m['total'] as int,
        paid: m['paid'] as int,
        change: m['change'] as int,
        status: (m['status'] as String?) ?? 'selesai',
        createdAt: DateTime.parse(m['created_at'] as String),
        items: items,
      );
}

class RefundItem {
  final int? id;
  final int? refundId;
  final int saleItemId;
  final int productId;
  final String name;
  final int price;
  final int qty;

  const RefundItem({
    this.id,
    this.refundId,
    required this.saleItemId,
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
  });

  int get subtotal => price * qty;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'refund_id': refundId,
        'sale_item_id': saleItemId,
        'product_id': productId,
        'name': name,
        'price': price,
        'qty': qty,
      };

  factory RefundItem.fromMap(Map<String, dynamic> m) => RefundItem(
        id: m['id'] as int?,
        refundId: m['refund_id'] as int?,
        saleItemId: m['sale_item_id'] as int,
        productId: m['product_id'] as int,
        name: m['name'] as String,
        price: m['price'] as int,
        qty: m['qty'] as int,
      );
}

class Refund {
  final int? id;
  final int saleId;
  final String invoiceNo;
  final int userId;
  final String userName;
  final String reason;
  final int totalRefund;
  final bool restock;
  final DateTime createdAt;
  final List<RefundItem> items;

  const Refund({
    this.id,
    required this.saleId,
    required this.invoiceNo,
    required this.userId,
    required this.userName,
    required this.reason,
    required this.totalRefund,
    this.restock = true,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sale_id': saleId,
        'invoice_no': invoiceNo,
        'user_id': userId,
        'user_name': userName,
        'reason': reason,
        'total_refund': totalRefund,
        'restock': restock ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Refund.fromMap(Map<String, dynamic> m, {List<RefundItem> items = const []}) => Refund(
        id: m['id'] as int?,
        saleId: m['sale_id'] as int,
        invoiceNo: m['invoice_no'] as String,
        userId: m['user_id'] as int,
        userName: (m['user_name'] as String?) ?? '-',
        reason: (m['reason'] as String?) ?? '',
        totalRefund: m['total_refund'] as int,
        restock: ((m['restock'] as int?) ?? 1) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        items: items,
      );
}

/// Satu baris pergerakan stok. Menjadi dasar laporan barang masuk/keluar.
class StockMove {
  final int id;
  final int productId;
  final String productName;
  final String sku;
  final String type; // 'masuk' | 'keluar' | 'retur'
  final int qty;
  final int stockAfter;
  final String ref;
  final String note;
  final String userName;
  final DateTime createdAt;

  const StockMove({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.type,
    required this.qty,
    required this.stockAfter,
    required this.ref,
    required this.note,
    required this.userName,
    required this.createdAt,
  });

  String get typeLabel => switch (type) {
        'masuk' => 'Barang masuk',
        'retur' => 'Retur masuk',
        _ => 'Barang keluar',
      };

  bool get isMasuk => type == 'masuk' || type == 'retur';

  factory StockMove.fromMap(Map<String, dynamic> m) => StockMove(
        id: m['id'] as int,
        productId: m['product_id'] as int,
        productName: (m['product_name'] as String?) ?? '(barang dihapus)',
        sku: (m['sku'] as String?) ?? '-',
        type: m['type'] as String,
        qty: m['qty'] as int,
        stockAfter: (m['stock_after'] as int?) ?? 0,
        ref: (m['ref'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
        userName: (m['user_name'] as String?) ?? '-',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

// --------------------------- Model laporan ---------------------------------

class ReportSummary {
  final int penjualanKotor;
  final int totalDiskon;
  final int totalRetur;
  final int jumlahTransaksi;
  final int jumlahRetur;
  final int itemTerjual;
  final int labaKotor;

  const ReportSummary({
    this.penjualanKotor = 0,
    this.totalDiskon = 0,
    this.totalRetur = 0,
    this.jumlahTransaksi = 0,
    this.jumlahRetur = 0,
    this.itemTerjual = 0,
    this.labaKotor = 0,
  });

  /// Pendapatan bersih = penjualan pada periode ini dikurangi retur yang
  /// TERJADI pada periode ini (bukan retur atas transaksi periode ini).
  int get pendapatanBersih => penjualanKotor - totalRetur;
  int get rataRataTransaksi => jumlahTransaksi == 0 ? 0 : (penjualanKotor / jumlahTransaksi).round();
}

class ProductSold {
  final int productId;
  final String sku;
  final String name;
  final int qty;
  final int qtyReturned;
  final int omzet;
  final int laba;

  const ProductSold({
    required this.productId,
    required this.sku,
    required this.name,
    required this.qty,
    required this.qtyReturned,
    required this.omzet,
    required this.laba,
  });

  int get qtyNet => qty - qtyReturned;
}

class DailyPoint {
  final DateTime date;
  final int value;
  const DailyPoint(this.date, this.value);
}
