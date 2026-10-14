import 'package:sqflite/sqflite.dart';

import '../utils/refresh_signal.dart';
import 'db_helper.dart';
import 'models.dart';

// ============================== PENGGUNA ===================================

class AuthRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<AppUser?> login(String username, String password) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'username = ? AND password_hash = ? AND is_active = 1',
      whereArgs: [username.trim().toLowerCase(), DatabaseHelper.hashPassword(password)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  /// Menentukan apakah aplikasi masih perlu disiapkan (belum ada akun sama sekali).
  Future<bool> hasAnyUser() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) c FROM users');
    return ((r.first['c'] as int?) ?? 0) > 0;
  }

  Future<AppUser?> byId(int id) async {
    final db = await _db;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<List<AppUser>> all() async {
    final db = await _db;
    final rows = await db.query('users', orderBy: 'role ASC, name ASC');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<bool> usernameTaken(String username, {int? exceptId}) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: exceptId == null ? 'username = ?' : 'username = ? AND id <> ?',
      whereArgs: exceptId == null ? [username.trim().toLowerCase()] : [username.trim().toLowerCase(), exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> create({
    required String username,
    required String password,
    required String name,
    required String role,
  }) async {
    final db = await _db;
    return db.insert('users', {
      'username': username.trim().toLowerCase(),
      'password_hash': DatabaseHelper.hashPassword(password),
      'name': name.trim(),
      'role': role,
      'is_active': 1,
    });
  }

  Future<void> update(AppUser user, {String? newPassword}) async {
    final db = await _db;
    final data = user.toMap();
    data.remove('id');
    if (newPassword != null && newPassword.isNotEmpty) {
      data['password_hash'] = DatabaseHelper.hashPassword(newPassword);
    }
    await db.update('users', data, where: 'id = ?', whereArgs: [user.id]);
  }

  Future<int> countActiveAdmins() async {
    final db = await _db;
    final r = await db.rawQuery("SELECT COUNT(*) c FROM users WHERE role='admin' AND is_active=1");
    return (r.first['c'] as int?) ?? 0;
  }
}

// ============================== PRODUK =====================================

class ProductRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<List<Product>> search({String keyword = '', String? category, bool onlyActive = true}) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (onlyActive) where.add('is_active = 1');
    if (keyword.trim().isNotEmpty) {
      where.add('(name LIKE ? OR sku LIKE ?)');
      args..add('%${keyword.trim()}%')..add('%${keyword.trim()}%');
    }
    if (category != null && category != 'Semua') {
      where.add('category = ?');
      args.add(category);
    }
    final rows = await db.query(
      'products',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> byId(int id) async {
    final db = await _db;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  /// [onlyActive] false dipakai form barang, supaya kategori milik produk
  /// nonaktif tetap muncul di dropdown dan tidak hilang saat diedit.
  Future<List<String>> categories({bool onlyActive = true}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT DISTINCT category FROM products'
      '${onlyActive ? ' WHERE is_active = 1' : ''}'
      ' ORDER BY category COLLATE NOCASE',
    );
    return rows.map((e) => e['category'] as String).toList();
  }

  Future<bool> skuTaken(String sku, {int? exceptId}) async {
    final db = await _db;
    final rows = await db.query(
      'products',
      where: exceptId == null ? 'sku = ?' : 'sku = ? AND id <> ?',
      whereArgs: exceptId == null ? [sku.trim()] : [sku.trim(), exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> insert(Product product, {String userName = '-'}) async {
    final db = await _db;
    late int id;
    await db.transaction((txn) async {
      id = await txn.insert('products', product.toMap()..remove('id'));
      if (product.stock != 0) {
        await txn.insert('stock_moves', {
          'product_id': id,
          'type': 'masuk',
          'qty': product.stock,
          'stock_after': product.stock,
          'ref': 'PRODUK-BARU',
          'note': 'Stok awal',
          'user_name': userName,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
    notifyDataChanged();
    return id;
  }

  /// Memperbarui data produk TANPA menyentuh stok. Stok hanya berubah lewat
  /// [adjustStock], transaksi, atau retur — supaya jejak audit tidak bolong.
  Future<void> update(Product product) async {
    final db = await _db;
    final data = product.toMap()
      ..remove('id')
      ..remove('stock');
    await db.update('products', data, where: 'id = ?', whereArgs: [product.id]);
    notifyDataChanged();
  }

  Future<void> setActive(int id, bool active) async {
    final db = await _db;
    await db.update('products', {'is_active': active ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    notifyDataChanged();
  }

  /// [delta] positif = stok masuk, negatif = stok keluar/koreksi.
  Future<void> adjustStock(
    int productId,
    int delta, {
    required String note,
    required String userName,
    String ref = 'MANUAL',
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query('products', columns: ['stock'], where: 'id = ?', whereArgs: [productId]);
      if (rows.isEmpty) return;
      final after = (rows.first['stock'] as int) + delta;
      await txn.update('products', {'stock': after}, where: 'id = ?', whereArgs: [productId]);
      await txn.insert('stock_moves', {
        'product_id': productId,
        'type': delta >= 0 ? 'masuk' : 'keluar',
        'qty': delta.abs(),
        'stock_after': after,
        'ref': ref,
        'note': note,
        'user_name': userName,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    notifyDataChanged();
  }

  /// Riwayat pergerakan stok untuk laporan barang masuk/keluar.
  /// [type] 'semua' | 'masuk' | 'keluar' | 'retur'.
  Future<List<StockMove>> stockMoves({
    DateTime? from,
    DateTime? to,
    String type = 'semua',
    String keyword = '',
    int limit = 500,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('sm.created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('sm.created_at <= ?');
      args.add(to.toIso8601String());
    }
    if (type != 'semua') {
      where.add('sm.type = ?');
      args.add(type);
    }
    if (keyword.trim().isNotEmpty) {
      where.add('(p.name LIKE ? OR p.sku LIKE ? OR sm.user_name LIKE ?)');
      final k = '%${keyword.trim()}%';
      args..add(k)..add(k)..add(k);
    }
    final rows = await db.rawQuery(
      'SELECT sm.*, p.name AS product_name, p.sku AS sku '
      'FROM stock_moves sm LEFT JOIN products p ON p.id = sm.product_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')} '}'
      'ORDER BY sm.id DESC LIMIT $limit',
      args,
    );
    return rows.map(StockMove.fromMap).toList();
  }
}

// ============================ PENJUALAN ====================================

class SaleRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<String> _nextInvoice(DatabaseExecutor txn) async {
    final now = DateTime.now();
    final prefix =
        'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final r = await txn.rawQuery(
      'SELECT COUNT(*) c FROM sales WHERE invoice_no LIKE ?',
      ['$prefix%'],
    );
    final n = ((r.first['c'] as int?) ?? 0) + 1;
    return '$prefix-${n.toString().padLeft(4, '0')}';
  }

  /// Menyimpan transaksi + potong stok + catat pergerakan dalam SATU transaksi
  /// database. Kalau salah satu langkah gagal, semuanya dibatalkan.
  Future<Sale> createSale({
    required AppUser user,
    required List<CartItem> cart,
    required int discount,
    required int paid,
    String customerName = '',
  }) async {
    if (cart.isEmpty) throw Exception('Keranjang masih kosong.');
    final db = await _db;
    late Sale result;

    await db.transaction((txn) async {
      // Validasi stok di dalam transaksi, bukan di UI. UI bisa basi.
      for (final c in cart) {
        final rows = await txn.query('products',
            columns: ['stock', 'name'], where: 'id = ?', whereArgs: [c.product.id]);
        if (rows.isEmpty) throw Exception('Produk "${c.product.name}" sudah tidak ada.');
        final stock = rows.first['stock'] as int;
        if (stock < c.qty) {
          throw Exception('Stok "${rows.first['name']}" tinggal $stock, diminta ${c.qty}.');
        }
      }

      final subtotal = cart.fold<int>(0, (a, b) => a + b.subtotal);
      final total = subtotal - discount;
      if (total < 0) throw Exception('Diskon melebihi subtotal.');
      if (paid < total) throw Exception('Uang bayar kurang dari total.');

      final invoice = await _nextInvoice(txn);
      final now = DateTime.now();

      final saleId = await txn.insert('sales', {
        'invoice_no': invoice,
        'user_id': user.id,
        'user_name': user.name,
        'customer_name': customerName.trim(),
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'paid': paid,
        'change': paid - total,
        'status': 'selesai',
        'created_at': now.toIso8601String(),
      });

      final items = <SaleItem>[];
      for (final c in cart) {
        final id = await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': c.product.id,
          'sku': c.product.sku,
          'name': c.product.name,
          'price': c.product.sellPrice,
          'cost_price': c.product.costPrice,
          'qty': c.qty,
          'qty_returned': 0,
        });
        await txn.rawUpdate('UPDATE products SET stock = stock - ? WHERE id = ?', [c.qty, c.product.id]);
        final afterRows = await txn.query('products',
            columns: ['stock'], where: 'id = ?', whereArgs: [c.product.id]);
        final after = afterRows.isEmpty ? 0 : afterRows.first['stock'] as int;
        await txn.insert('stock_moves', {
          'product_id': c.product.id,
          'type': 'keluar',
          'qty': c.qty,
          'stock_after': after,
          'ref': invoice,
          'note': 'Penjualan',
          'user_name': user.name,
          'created_at': now.toIso8601String(),
        });
        items.add(SaleItem(
          id: id,
          saleId: saleId,
          productId: c.product.id!,
          sku: c.product.sku,
          name: c.product.name,
          price: c.product.sellPrice,
          costPrice: c.product.costPrice,
          qty: c.qty,
        ));
      }

      result = Sale(
        id: saleId,
        invoiceNo: invoice,
        userId: user.id!,
        userName: user.name,
        customerName: customerName.trim(),
        subtotal: subtotal,
        discount: discount,
        total: total,
        paid: paid,
        change: paid - total,
        createdAt: now,
        items: items,
      );
    });

    notifyDataChanged();
    return result;
  }

  Future<List<Sale>> history({DateTime? from, DateTime? to, String keyword = ''}) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('created_at <= ?');
      args.add(to.toIso8601String());
    }
    if (keyword.trim().isNotEmpty) {
      where.add('(invoice_no LIKE ? OR customer_name LIKE ?)');
      args..add('%${keyword.trim()}%')..add('%${keyword.trim()}%');
    }
    final rows = await db.query(
      'sales',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: 300,
    );
    return rows.map((e) => Sale.fromMap(e)).toList();
  }

  Future<Sale?> detail(int saleId) async {
    final db = await _db;
    final rows = await db.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
    if (rows.isEmpty) return null;
    final items = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId], orderBy: 'id ASC');
    return Sale.fromMap(rows.first, items: items.map(SaleItem.fromMap).toList());
  }

  Future<List<Refund>> refundsOf(int saleId) async {
    final db = await _db;
    final rows = await db.query('refunds', where: 'sale_id = ?', whereArgs: [saleId], orderBy: 'id DESC');
    final out = <Refund>[];
    for (final r in rows) {
      final items = await db.query('refund_items', where: 'refund_id = ?', whereArgs: [r['id']]);
      out.add(Refund.fromMap(r, items: items.map(RefundItem.fromMap).toList()));
    }
    return out;
  }

  /// Memproses retur: catat retur, kembalikan stok (opsional), perbarui
  /// qty_returned tiap baris, lalu hitung ulang status transaksi.
  Future<Refund> createRefund({
    required AppUser user,
    required Sale sale,
    required Map<int, int> qtyPerSaleItemId, // saleItemId -> qty diretur
    required String reason,
    bool restock = true,
  }) async {
    final db = await _db;
    late Refund result;

    await db.transaction((txn) async {
      final now = DateTime.now();
      var total = 0;
      final chosen = <SaleItem>[];

      for (final entry in qtyPerSaleItemId.entries) {
        if (entry.value <= 0) continue;
        final rows = await txn.query('sale_items', where: 'id = ?', whereArgs: [entry.key], limit: 1);
        if (rows.isEmpty) continue;
        final item = SaleItem.fromMap(rows.first);
        if (entry.value > item.qtyRemaining) {
          throw Exception('Jumlah retur "${item.name}" melebihi yang bisa diretur (${item.qtyRemaining}).');
        }
        total += item.price * entry.value;
        chosen.add(item);
      }
      if (chosen.isEmpty) throw Exception('Belum ada barang yang dipilih untuk diretur.');

      final refundId = await txn.insert('refunds', {
        'sale_id': sale.id,
        'invoice_no': sale.invoiceNo,
        'user_id': user.id,
        'user_name': user.name,
        'reason': reason.trim(),
        'total_refund': total,
        'restock': restock ? 1 : 0,
        'created_at': now.toIso8601String(),
      });

      final refundItems = <RefundItem>[];
      for (final item in chosen) {
        final qty = qtyPerSaleItemId[item.id]!;
        await txn.insert('refund_items', {
          'refund_id': refundId,
          'sale_item_id': item.id,
          'product_id': item.productId,
          'name': item.name,
          'price': item.price,
          'qty': qty,
        });
        await txn.rawUpdate(
          'UPDATE sale_items SET qty_returned = qty_returned + ? WHERE id = ?',
          [qty, item.id],
        );
        if (restock) {
          await txn.rawUpdate('UPDATE products SET stock = stock + ? WHERE id = ?', [qty, item.productId]);
          final after = await txn.query('products',
              columns: ['stock'], where: 'id = ?', whereArgs: [item.productId]);
          await txn.insert('stock_moves', {
            'product_id': item.productId,
            'type': 'retur',
            'qty': qty,
            'stock_after': after.isEmpty ? 0 : after.first['stock'],
            'ref': sale.invoiceNo,
            'note': 'Retur: ${reason.trim()}',
            'user_name': user.name,
            'created_at': now.toIso8601String(),
          });
        }
        refundItems.add(RefundItem(
          refundId: refundId,
          saleItemId: item.id!,
          productId: item.productId,
          name: item.name,
          price: item.price,
          qty: qty,
        ));
      }

      final agg = await txn.rawQuery(
        'SELECT SUM(qty) q, SUM(qty_returned) r FROM sale_items WHERE sale_id = ?',
        [sale.id],
      );
      final totalQty = (agg.first['q'] as int?) ?? 0;
      final totalRet = (agg.first['r'] as int?) ?? 0;
      final status = totalRet == 0
          ? 'selesai'
          : (totalRet >= totalQty ? 'retur_penuh' : 'retur_sebagian');
      await txn.update('sales', {'status': status}, where: 'id = ?', whereArgs: [sale.id]);

      result = Refund(
        id: refundId,
        saleId: sale.id!,
        invoiceNo: sale.invoiceNo,
        userId: user.id!,
        userName: user.name,
        reason: reason.trim(),
        totalRefund: total,
        restock: restock,
        createdAt: now,
        items: refundItems,
      );
    });

    notifyDataChanged();
    return result;
  }
}

// ============================ LAPORAN ======================================

class ReportRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<ReportSummary> summary(DateTime from, DateTime to) async {
    final db = await _db;
    final a = [from.toIso8601String(), to.toIso8601String()];

    final s = await db.rawQuery(
      'SELECT COALESCE(SUM(total),0) t, COALESCE(SUM(discount),0) d, COUNT(*) c '
      'FROM sales WHERE created_at BETWEEN ? AND ?',
      a,
    );
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(total_refund),0) t, COUNT(*) c '
      'FROM refunds WHERE created_at BETWEEN ? AND ?',
      a,
    );
    final i = await db.rawQuery(
      'SELECT COALESCE(SUM(si.qty),0) q, '
      'COALESCE(SUM((si.price - si.cost_price) * si.qty),0) laba '
      'FROM sale_items si JOIN sales s ON s.id = si.sale_id '
      'WHERE s.created_at BETWEEN ? AND ?',
      a,
    );
    // Laba yang hilang karena retur pada periode ini.
    final rl = await db.rawQuery(
      'SELECT COALESCE(SUM((si.price - si.cost_price) * ri.qty),0) laba '
      'FROM refund_items ri '
      'JOIN refunds rf ON rf.id = ri.refund_id '
      'JOIN sale_items si ON si.id = ri.sale_item_id '
      'WHERE rf.created_at BETWEEN ? AND ?',
      a,
    );

    final penjualan = (s.first['t'] as int?) ?? 0;
    final diskon = (s.first['d'] as int?) ?? 0;
    final retur = (r.first['t'] as int?) ?? 0;
    final labaKotor = ((i.first['laba'] as int?) ?? 0) - ((rl.first['laba'] as int?) ?? 0);

    return ReportSummary(
      penjualanKotor: penjualan,
      totalDiskon: diskon,
      totalRetur: retur,
      jumlahTransaksi: (s.first['c'] as int?) ?? 0,
      jumlahRetur: (r.first['c'] as int?) ?? 0,
      itemTerjual: (i.first['q'] as int?) ?? 0,
      labaKotor: labaKotor,
    );
  }

  Future<List<ProductSold>> productsSold(DateTime from, DateTime to) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT si.product_id, si.sku, si.name, '
      'SUM(si.qty) qty, SUM(si.qty_returned) qret, '
      'SUM(si.price * si.qty) omzet, '
      'SUM((si.price - si.cost_price) * si.qty) laba '
      'FROM sale_items si JOIN sales s ON s.id = si.sale_id '
      'WHERE s.created_at BETWEEN ? AND ? '
      'GROUP BY si.product_id, si.sku, si.name '
      'ORDER BY qty DESC',
      [from.toIso8601String(), to.toIso8601String()],
    );
    return rows
        .map((m) => ProductSold(
              productId: m['product_id'] as int,
              sku: m['sku'] as String,
              name: m['name'] as String,
              qty: (m['qty'] as int?) ?? 0,
              qtyReturned: (m['qret'] as int?) ?? 0,
              omzet: (m['omzet'] as int?) ?? 0,
              laba: (m['laba'] as int?) ?? 0,
            ))
        .toList();
  }

  Future<List<Refund>> refunds(DateTime from, DateTime to) async {
    final db = await _db;
    final rows = await db.query(
      'refunds',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    final out = <Refund>[];
    for (final r in rows) {
      final items = await db.query('refund_items', where: 'refund_id = ?', whereArgs: [r['id']]);
      out.add(Refund.fromMap(r, items: items.map(RefundItem.fromMap).toList()));
    }
    return out;
  }

  Future<List<DailyPoint>> dailyRevenue(DateTime from, DateTime to) async {
    final db = await _db;
    final rows = await db.rawQuery(
      "SELECT substr(created_at,1,10) d, COALESCE(SUM(total),0) t "
      "FROM sales WHERE created_at BETWEEN ? AND ? GROUP BY d ORDER BY d ASC",
      [from.toIso8601String(), to.toIso8601String()],
    );
    return rows
        .map((m) => DailyPoint(DateTime.parse(m['d'] as String), (m['t'] as int?) ?? 0))
        .toList();
  }
}
