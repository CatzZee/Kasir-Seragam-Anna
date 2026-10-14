import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Satu-satunya pintu ke SQLite. Skema dibuat sekali, migrasi lewat [onUpgrade].
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'kasir_anna.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _dbName),
      version: _dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// SHA-256 + salt tetap per-aplikasi. Cukup untuk aplikasi kasir offline;
  /// bukan pengganti bcrypt bila kelak datanya dipindah ke server.
  static String hashPassword(String plain) =>
      sha256.convert(utf8.encode('kas1r-4nn4::$plain')).toString();

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        username      TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        name          TEXT NOT NULL,
        role          TEXT NOT NULL DEFAULT 'kasir',
        is_active     INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        sku        TEXT NOT NULL UNIQUE,
        name       TEXT NOT NULL,
        category   TEXT NOT NULL DEFAULT 'Umum',
        cost_price INTEGER NOT NULL DEFAULT 0,
        sell_price INTEGER NOT NULL,
        stock      INTEGER NOT NULL DEFAULT 0,
        min_stock  INTEGER NOT NULL DEFAULT 3,
        is_active  INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');

    await db.execute('''
      CREATE TABLE sales (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no    TEXT NOT NULL UNIQUE,
        user_id       INTEGER NOT NULL,
        user_name     TEXT NOT NULL,
        customer_name TEXT NOT NULL DEFAULT '',
        subtotal      INTEGER NOT NULL,
        discount      INTEGER NOT NULL DEFAULT 0,
        total         INTEGER NOT NULL,
        paid          INTEGER NOT NULL,
        change        INTEGER NOT NULL,
        status        TEXT NOT NULL DEFAULT 'selesai',
        created_at    TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_sales_created ON sales(created_at)');

    await db.execute('''
      CREATE TABLE sale_items (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id      INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        product_id   INTEGER NOT NULL,
        sku          TEXT NOT NULL,
        name         TEXT NOT NULL,
        price        INTEGER NOT NULL,
        cost_price   INTEGER NOT NULL DEFAULT 0,
        qty          INTEGER NOT NULL,
        qty_returned INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)');

    await db.execute('''
      CREATE TABLE refunds (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id      INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        invoice_no   TEXT NOT NULL,
        user_id      INTEGER NOT NULL,
        user_name    TEXT NOT NULL,
        reason       TEXT NOT NULL DEFAULT '',
        total_refund INTEGER NOT NULL,
        restock      INTEGER NOT NULL DEFAULT 1,
        created_at   TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_refunds_created ON refunds(created_at)');

    await db.execute('''
      CREATE TABLE refund_items (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        refund_id    INTEGER NOT NULL REFERENCES refunds(id) ON DELETE CASCADE,
        sale_item_id INTEGER NOT NULL,
        product_id   INTEGER NOT NULL,
        name         TEXT NOT NULL,
        price        INTEGER NOT NULL,
        qty          INTEGER NOT NULL
      )
    ''');

    // Jejak audit stok: setiap perubahan stok tercatat, sehingga selisih fisik
    // vs sistem bisa ditelusuri tanpa menebak.
    await db.execute('''
      CREATE TABLE stock_moves (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type       TEXT NOT NULL,
        qty        INTEGER NOT NULL,
        stock_after INTEGER NOT NULL,
        ref        TEXT NOT NULL DEFAULT '',
        note       TEXT NOT NULL DEFAULT '',
        user_name  TEXT NOT NULL DEFAULT '-',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_moves_product ON stock_moves(product_id)');
    // Tidak ada data contoh. Database sengaja dibuat kosong; pemilik toko
    // mengisi identitas toko dan akunnya sendiri lewat layar penyiapan awal.
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // v2: mencatat siapa yang mengubah stok. Tanpa ini, laporan barang masuk
    // tidak bisa dipakai untuk menelusuri tanggung jawab.
    if (oldV < 2) {
      await db.execute(
        "ALTER TABLE stock_moves ADD COLUMN user_name TEXT NOT NULL DEFAULT '-'",
      );
    }
  }

  /// Menutup koneksi. Dipakai sebelum menimpa file database saat pemulihan.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<String> databaseFilePath() async =>
      p.join(await getDatabasesPath(), _dbName);

  /// Menghapus riwayat penjualan, retur, dan pergerakan stok.
  /// Data barang dan pengguna tidak tersentuh.
  Future<void> resetTransaksi() async {
    final db = await database;
    await db.delete('refund_items');
    await db.delete('refunds');
    await db.delete('sale_items');
    await db.delete('sales');
    await db.delete('stock_moves');
  }

  /// Mengosongkan SELURUH isi database, termasuk barang dan pengguna.
  /// Setelah ini aplikasi kembali ke layar penyiapan awal.
  Future<void> resetSemua() async {
    final db = await database;
    await db.delete('refund_items');
    await db.delete('refunds');
    await db.delete('sale_items');
    await db.delete('sales');
    await db.delete('stock_moves');
    await db.delete('products');
    await db.delete('users');
  }
}
