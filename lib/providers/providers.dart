import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/repositories.dart';
import '../utils/app_info.dart';

/// Identitas toko + preferensi printer. Disimpan di SharedPreferences karena
/// datanya tunggal dan tidak perlu dikueri.
class SettingsProvider extends ChangeNotifier {
  // Kosong secara bawaan. Diisi pemilik toko saat penyiapan awal.
  String namaToko = '';
  String alamatToko = '';
  String telpToko = '';
  String catatanStruk = AppInfo.catatanStrukBawaan;
  String printerName = '';
  String printerMac = '';
  bool autoPrint = true;

  /// Nama yang aman ditampilkan sebelum identitas toko diisi.
  String get namaTampilan => namaToko.trim().isEmpty ? AppInfo.nama : namaToko;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    namaToko = sp.getString('namaToko') ?? '';
    alamatToko = sp.getString('alamatToko') ?? '';
    telpToko = sp.getString('telpToko') ?? '';
    catatanStruk = sp.getString('catatanStruk') ?? catatanStruk;
    printerName = sp.getString('printerName') ?? '';
    printerMac = sp.getString('printerMac') ?? '';
    autoPrint = sp.getBool('autoPrint') ?? true;
    notifyListeners();
  }

  Future<void> saveToko({
    required String nama,
    required String alamat,
    required String telp,
    required String catatan,
  }) async {
    namaToko = nama;
    alamatToko = alamat;
    telpToko = telp;
    catatanStruk = catatan;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('namaToko', nama);
    await sp.setString('alamatToko', alamat);
    await sp.setString('telpToko', telp);
    await sp.setString('catatanStruk', catatan);
    notifyListeners();
  }

  Future<void> savePrinter(String name, String mac) async {
    printerName = name;
    printerMac = mac;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('printerName', name);
    await sp.setString('printerMac', mac);
    notifyListeners();
  }

  Future<void> setAutoPrint(bool v) async {
    autoPrint = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('autoPrint', v);
    notifyListeners();
  }
}

class AuthProvider extends ChangeNotifier {
  final _repo = AuthRepository();

  AppUser? _user;
  bool _busy = false;
  bool _needsSetup = false;
  String? _error;

  /// True bila database belum berisi satu pun akun, sehingga aplikasi harus
  /// menampilkan layar penyiapan awal alih-alih layar masuk.
  bool get needsSetup => _needsSetup;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get busy => _busy;
  String? get error => _error;

  Future<void> checkSetup() async {
    _needsSetup = !(await _repo.hasAnyUser());
    notifyListeners();
  }

  /// Membuat akun pemilik pertama, lalu langsung masuk dengan akun itu.
  Future<String?> completeSetup({
    required String name,
    required String username,
    required String password,
  }) async {
    try {
      if (await _repo.usernameTaken(username)) {
        return 'Nama pengguna sudah dipakai.';
      }
      await _repo.create(
        username: username,
        password: password,
        name: name,
        role: 'admin',
      );
      _needsSetup = false;
      notifyListeners();
      final ok = await login(username, password);
      return ok ? null : (_error ?? 'Akun dibuat, silakan masuk secara manual.');
    } catch (e) {
      return 'Gagal menyiapkan akun: $e';
    }
  }

  /// Sesi disimpan agar kasir tidak perlu login ulang setiap membuka aplikasi.
  Future<void> restoreSession() async {
    final sp = await SharedPreferences.getInstance();
    final id = sp.getInt('sessionUserId');
    if (id == null) return;
    _user = await _repo.byId(id);
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final u = await _repo.login(username, password);
      if (u == null) {
        _error = 'Nama pengguna atau kata sandi tidak cocok.';
        return false;
      }
      _user = u;
      final sp = await SharedPreferences.getInstance();
      await sp.setInt('sessionUserId', u.id!);
      return true;
    } catch (e) {
      _error = 'Gagal masuk: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove('sessionUserId');
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_user?.id == null) return;
    _user = await _repo.byId(_user!.id!);
    notifyListeners();
  }
}

/// Keranjang belanja aktif. Sengaja tidak dipersistensi: kasir yang menutup
/// aplikasi di tengah transaksi sebaiknya mengulang, bukan melanjutkan data basi.
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  int _discount = 0;
  String _customerName = '';

  List<CartItem> get items => List.unmodifiable(_items);
  int get discount => _discount;
  String get customerName => _customerName;
  bool get isEmpty => _items.isEmpty;
  int get totalQty => _items.fold(0, (a, b) => a + b.qty);
  int get subtotal => _items.fold(0, (a, b) => a + b.subtotal);
  int get total => (subtotal - _discount).clamp(0, subtotal);

  int qtyOf(int productId) {
    for (final i in _items) {
      if (i.product.id == productId) return i.qty;
    }
    return 0;
  }

  /// Mengembalikan pesan galat bila stok tidak cukup, atau null bila berhasil.
  String? add(Product product, {int qty = 1}) {
    final idx = _items.indexWhere((e) => e.product.id == product.id);
    final current = idx >= 0 ? _items[idx].qty : 0;
    if (current + qty > product.stock) {
      return 'Stok ${product.name} tinggal ${product.stock}.';
    }
    if (idx >= 0) {
      _items[idx].qty += qty;
    } else {
      _items.add(CartItem(product: product, qty: qty));
    }
    notifyListeners();
    return null;
  }

  String? setQty(int productId, int qty) {
    final idx = _items.indexWhere((e) => e.product.id == productId);
    if (idx < 0) return null;
    if (qty <= 0) {
      _items.removeAt(idx);
      notifyListeners();
      return null;
    }
    if (qty > _items[idx].product.stock) {
      return 'Stok ${_items[idx].product.name} tinggal ${_items[idx].product.stock}.';
    }
    _items[idx].qty = qty;
    notifyListeners();
    return null;
  }

  void remove(int productId) {
    _items.removeWhere((e) => e.product.id == productId);
    notifyListeners();
  }

  void setDiscount(int value) {
    _discount = value.clamp(0, subtotal);
    notifyListeners();
  }

  void setCustomerName(String value) {
    _customerName = value;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _discount = 0;
    _customerName = '';
    notifyListeners();
  }
}
