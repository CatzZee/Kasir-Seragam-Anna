import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db_helper.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../providers/providers.dart';
import '../services/backup_service.dart';
import '../services/printer_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_info.dart';
import '../utils/refresh_signal.dart';
import '../widgets/app_widgets.dart';
import 'report_screen.dart';
import 'stock_report_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(Icons.person, size: 34, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '-',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${user?.username ?? ''}  -  ${user?.roleLabel ?? ''}',
                          style: const TextStyle(fontSize: 15, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _section(context, 'Toko'),
          _tile(
            context,
            icon: Icons.storefront,
            title: 'Identitas toko',
            subtitle: settings.namaToko.isEmpty ? 'Belum diisi' : settings.namaToko,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const StoreSettingsScreen())),
          ),
          _tile(
            context,
            icon: Icons.print,
            title: 'Printer struk',
            subtitle: settings.printerName.isEmpty ? 'Belum dipilih' : settings.printerName,
            subtitleColor: settings.printerName.isEmpty ? AppColors.danger : null,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen())),
          ),
          if (auth.isAdmin) ...[
            const SizedBox(height: 20),
            _section(context, 'Khusus pemilik'),
            // Laporan memuat harga modal dan laba kotor, jadi dibatasi pemilik.
            _tile(
              context,
              icon: Icons.bar_chart,
              title: 'Laporan lengkap',
              subtitle: 'Pendapatan, produk terjual, dan retur',
              onTap: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen())),
            ),
            _tile(
              context,
              icon: Icons.move_to_inbox,
              title: 'Laporan barang masuk & keluar',
              subtitle: 'Siapa mengubah stok, kapan, dan berapa',
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const StockReportScreen())),
            ),
            _tile(
              context,
              icon: Icons.backup_outlined,
              title: 'Cadangkan data',
              subtitle: 'Simpan salinan ke Google Drive atau WhatsApp',
              onTap: () => _backup(context),
            ),
            _tile(
              context,
              icon: Icons.settings_backup_restore,
              title: 'Pulihkan data dari cadangan',
              subtitle: 'Mengganti seluruh data dengan isi berkas cadangan',
              danger: true,
              onTap: () => _restore(context),
            ),
            _tile(
              context,
              icon: Icons.restart_alt,
              title: 'Kosongkan seluruh data',
              subtitle: 'Menghapus barang, penjualan, dan semua akun',
              danger: true,
              onTap: () => _resetSemua(context),
            ),
            _tile(
              context,
              icon: Icons.group,
              title: 'Pengguna aplikasi',
              subtitle: 'Tambah atau nonaktifkan akun kasir',
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
            ),
            _tile(
              context,
              icon: Icons.cleaning_services_outlined,
              title: 'Hapus semua data transaksi',
              subtitle: 'Data barang tetap, riwayat penjualan dihapus',
              danger: true,
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Hapus semua transaksi?',
                  message: 'Seluruh riwayat penjualan, retur, dan pergerakan stok akan dihapus '
                      'permanen. Data barang dan pengguna tidak terhapus.',
                  confirmText: 'Ya, hapus semua',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
                await DatabaseHelper.instance.resetTransaksi();
                if (context.mounted) showSnack(context, 'Riwayat transaksi dihapus.');
              },
            ),
          ],
          const SizedBox(height: 20),
          _section(context, 'Akun'),
          _tile(
            context,
            icon: Icons.password,
            title: 'Ubah kata sandi saya',
            onTap: () => _changeMyPassword(context),
          ),
          _tile(
            context,
            icon: Icons.logout,
            title: 'Keluar',
            danger: true,
            onTap: () async {
              final ok = await confirmDialog(
                context,
                title: 'Keluar dari aplikasi?',
                message: 'Anda perlu memasukkan nama pengguna dan kata sandi lagi untuk masuk.',
                confirmText: 'Ya, keluar',
                destructive: true,
              );
              if (ok && context.mounted) {
                context.read<CartProvider>().clear();
                await context.read<AuthProvider>().logout();
              }
            },
          ),
          const SizedBox(height: 30),
          Center(
            child: Text('${AppInfo.nama} v${AppInfo.versi}\nData tersimpan di dalam HP ini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1)),
      );

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? subtitleColor,
    bool danger = false,
    required VoidCallback onTap,
  }) {
    final color = danger ? AppColors.danger : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: danger ? AppColors.danger : AppColors.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 14, color: subtitleColor ?? AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 26),
          ],
        ),
      ),
    );
  }

  /// Mengembalikan aplikasi ke kondisi baru dipasang. Dipakai saat masa uji
  /// coba selesai dan toko ingin mulai mencatat dari nol.
  Future<void> _resetSemua(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Kosongkan seluruh data?',
      message: 'SEMUA data akan dihapus permanen: daftar barang, seluruh riwayat '
          'penjualan dan retur, serta semua akun termasuk akun Anda sendiri.\n\n'
          'Aplikasi akan kembali ke layar penyiapan awal.\n\n'
          'Buat cadangan terlebih dahulu bila datanya masih dibutuhkan.',
      confirmText: 'Ya, kosongkan semua',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    final lagi = await confirmDialog(
      context,
      title: 'Yakin sekali lagi?',
      message: 'Tindakan ini tidak bisa dibatalkan dan tidak ada cara mengembalikannya '
          'selain memulihkan dari berkas cadangan.',
      confirmText: 'Saya yakin, hapus semua',
      destructive: true,
    );
    if (!lagi || !context.mounted) return;

    await DatabaseHelper.instance.resetSemua();
    notifyDataChanged();
    if (!context.mounted) return;
    context.read<CartProvider>().clear();
    final auth = context.read<AuthProvider>();
    await auth.logout();
    await auth.checkSetup();
  }

  Future<void> _backup(BuildContext context) async {
    showSnack(context, 'Menyiapkan berkas cadangan...');
    final res = await BackupService.instance.exportBackup();
    if (context.mounted) showSnack(context, res.message, isError: !res.success);
  }

  /// Pemulihan sengaja dibuat berlapis: pilih berkas, periksa keasliannya,
  /// baru konfirmasi. Setelah berhasil, sesi ditutup agar seluruh layar
  /// membaca ulang dari database yang baru.
  Future<void> _restore(BuildContext context) async {
    final path = await BackupService.instance.pickBackupFile();
    if (path == null || !context.mounted) return;

    final check = await BackupService.instance.validate(path);
    if (!context.mounted) return;
    if (!check.success) {
      showSnack(context, check.message, isError: true);
      return;
    }

    final nama = path.split(RegExp(r'[\\/]')).last;
    final ok = await confirmDialog(
      context,
      title: 'Ganti semua data sekarang?',
      message: 'Berkas: $nama\n\n'
          'SELURUH data yang ada di aplikasi ini — barang, penjualan, retur, '
          'dan pengguna — akan diganti dengan isi berkas cadangan tersebut. '
          'Data yang sekarang tidak bisa dikembalikan setelah ini.\n\n'
          'Sebaiknya buat cadangan data yang sekarang terlebih dahulu.',
      confirmText: 'Ya, ganti semua data',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    showSnack(context, 'Memulihkan data...');
    final res = await BackupService.instance.restore(path);
    if (!context.mounted) return;
    showSnack(context, res.message, isError: !res.success);
    if (res.success) {
      // Pengguna pada sesi lama belum tentu ada di database baru.
      context.read<CartProvider>().clear();
      final auth = context.read<AuthProvider>();
      await auth.logout();
      await auth.checkSetup();
      notifyDataChanged();
    }
  }

  Future<void> _changeMyPassword(BuildContext context) async {
    final pass = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (pass == null || !context.mounted) return;
    if (pass.length < 6) {
      showSnack(context, 'Kata sandi minimal 6 huruf.', isError: true);
      return;
    }
    final auth = context.read<AuthProvider>();
    await AuthRepository().update(auth.user!, newPassword: pass);
    await auth.refresh();
    if (context.mounted) showSnack(context, 'Kata sandi diperbarui.');
  }
}

/// Sama seperti dialog ubah stok: controller dimiliki widget-nya sendiri
/// supaya tidak dibuang saat dialog masih dalam animasi menutup.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah kata sandi'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        obscureText: true,
        onSubmitted: (v) => Navigator.pop(context, v),
        decoration: const InputDecoration(labelText: 'Kata sandi baru (min. 6 huruf)'),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _ctrl.text),
            child: const Text('Simpan'),
          ),
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

// -------------------------- IDENTITAS TOKO ---------------------------------

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});
  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  late final TextEditingController _nama;
  late final TextEditingController _alamat;
  late final TextEditingController _telp;
  late final TextEditingController _catatan;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _nama = TextEditingController(text: s.namaToko);
    _alamat = TextEditingController(text: s.alamatToko);
    _telp = TextEditingController(text: s.telpToko);
    _catatan = TextEditingController(text: s.catatanStruk);
  }

  @override
  void dispose() {
    for (final c in [_nama, _alamat, _telp, _catatan]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identitas Toko')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Data ini dicetak di bagian atas dan bawah struk.',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          TextField(
            controller: _nama,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama toko'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _alamat,
            maxLines: 2,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Alamat'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _telp,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Nomor telepon / WhatsApp'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _catatan,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Catatan di bawah struk',
              helperText: 'Contoh: aturan tukar barang.',
              helperStyle: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: ElevatedButton.icon(
          onPressed: () async {
            await context.read<SettingsProvider>().saveToko(
                  nama: _nama.text.trim(),
                  alamat: _alamat.text.trim(),
                  telp: _telp.text.trim(),
                  catatan: _catatan.text.trim(),
                );
            if (context.mounted) {
              showSnack(context, 'Identitas toko tersimpan.');
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.save, size: 24),
          label: const Text('Simpan'),
        ),
      ),
    );
  }
}

// ---------------------------- PENGATURAN PRINTER ---------------------------

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});
  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  List<PrinterDevice> _devices = [];
  bool _loading = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _loading = true);
    try {
      final list = await PrinterService.instance.pairedDevices();
      if (!mounted) return;
      setState(() => _devices = list);
    } catch (e) {
      if (mounted) showSnack(context, 'Gagal membaca daftar printer: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Struk'),
        actions: [
          IconButton(tooltip: 'Cari ulang', onPressed: _scan, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSize.radius),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pasangkan printer lewat Setelan Bluetooth HP terlebih dahulu. '
                    'Printer yang sudah dipasangkan akan muncul di daftar bawah.',
                    style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SwitchListTile(
              value: settings.autoPrint,
              onChanged: (v) => context.read<SettingsProvider>().setAutoPrint(v),
              activeColor: AppColors.success,
              title: const Text('Cetak otomatis setelah transaksi',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              subtitle: const Text('Struk langsung dicetak begitu pembayaran selesai.',
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Printer terpasang', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_devices.isEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Belum ada printer yang dipasangkan.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text(
                    'Nyalakan printer, buka Setelan > Bluetooth di HP, pasangkan printer, '
                    'lalu tekan Cari ulang.',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _scan,
                    icon: const Icon(Icons.refresh, size: 22),
                    label: const Text('Cari ulang'),
                  ),
                ],
              ),
            )
          else
            ..._devices.map((d) {
              final selected = d.mac == settings.printerMac;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  borderColor: selected ? AppColors.success : null,
                  onTap: () async {
                    await context.read<SettingsProvider>().savePrinter(d.name, d.mac);
                    if (context.mounted) showSnack(context, '${d.name} dipilih sebagai printer.');
                  },
                  child: Row(
                    children: [
                      Icon(Icons.print,
                          size: 30, color: selected ? AppColors.success : AppColors.textMuted),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.name.isEmpty ? 'Printer tanpa nama' : d.name,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(d.mac,
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      if (selected)
                        const StatusChip(
                            text: 'Dipakai', color: AppColors.success, icon: Icons.check_circle),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
            onPressed: (settings.printerMac.isEmpty || _testing)
                ? null
                : () async {
                    setState(() => _testing = true);
                    final res = await PrinterService.instance.testPrint(settings.printerMac);
                    if (!mounted) return;
                    setState(() => _testing = false);
                    showSnack(context, res.message, isError: !res.success);
                  },
            icon: const Icon(Icons.receipt, size: 24),
            label: Text(_testing ? 'Mengirim...' : 'Uji cetak'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// -------------------------- MANAJEMEN PENGGUNA -----------------------------

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});
  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _repo = AuthRepository();
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.all();
    if (!mounted) return;
    setState(() {
      _users = list;
      _loading = false;
    });
  }

  Future<void> _openForm([AppUser? user]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: _UserForm(user: user),
      ),
    );
    if (changed != true) return;
    _load();
    if (mounted) {
      showSnack(context, user == null ? 'Pengguna baru dibuat.' : 'Data pengguna tersimpan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengguna Aplikasi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                const Text(
                  'Pemilik yang membuat akun kasir. Tidak ada pendaftaran mandiri, '
                  'supaya tidak ada akun asing yang bisa membuka data penjualan.',
                  style: TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 16),
                ..._users.map((u) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        borderColor: u.isActive ? null : AppColors.border,
                        onTap: () => _openForm(u),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: (u.isAdmin ? AppColors.primary : AppColors.textMuted)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(23),
                              ),
                              child: Icon(u.isAdmin ? Icons.shield : Icons.person,
                                  color: u.isAdmin ? AppColors.primary : AppColors.textMuted, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.name,
                                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('${u.username}  -  ${u.roleLabel}',
                                      style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            if (u.id == me?.id)
                              const StatusChip(text: 'Anda', color: AppColors.primary)
                            else if (!u.isActive)
                              const StatusChip(text: 'Nonaktif', color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.primaryDark,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add, size: 24),
        label: const Text('Tambah pengguna',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _UserForm extends StatefulWidget {
  final AppUser? user;
  const _UserForm({this.user});

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _repo = AuthRepository();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  final _password = TextEditingController();
  late String _role;
  late bool _active;
  bool _saving = false;
  // Snackbar tampil di belakang bottom sheet, jadi galat ditulis di dalam form.
  String? _error;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user?.name ?? '');
    _username = TextEditingController(text: widget.user?.username ?? '');
    _role = widget.user?.role ?? 'kasir';
    _active = widget.user?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (await _repo.usernameTaken(_username.text, exceptId: widget.user?.id)) {
        if (mounted) setState(() => _error = 'Nama pengguna sudah dipakai.');
        return;
      }
      // Jangan sampai toko kehilangan satu-satunya akun pemilik.
      if (_isEdit && widget.user!.isAdmin && (_role != 'admin' || !_active)) {
        if (await _repo.countActiveAdmins() <= 1) {
          if (mounted) {
            setState(() => _error = 'Harus ada minimal satu akun pemilik yang aktif. '
                'Buat pemilik lain dulu sebelum mengubah akun ini.');
          }
          return;
        }
      }

      if (_isEdit) {
        await _repo.update(
          widget.user!.copyWith(
            name: _name.text.trim(),
            username: _username.text.trim().toLowerCase(),
            role: _role,
            isActive: _active,
          ),
          newPassword: _password.text.isEmpty ? null : _password.text,
        );
      } else {
        await _repo.create(
          username: _username.text,
          password: _password.text,
          name: _name.text,
          role: _role,
        );
      }
      if (!mounted) return;
      // Snackbar sukses ditampilkan oleh layar induk setelah sheet tertutup.
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? 'Ubah Pengguna' : 'Pengguna Baru',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama lengkap'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama belum diisi.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _username,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Nama pengguna untuk masuk'),
                validator: (v) =>
                    (v == null || v.trim().length < 3) ? 'Minimal 3 huruf.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isEdit ? 'Kata sandi baru (kosongkan jika tetap)' : 'Kata sandi',
                ),
                validator: (v) {
                  if (_isEdit && (v == null || v.isEmpty)) return null;
                  return (v == null || v.length < 6) ? 'Minimal 6 huruf.' : null;
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'kasir', label: Text('Kasir'), icon: Icon(Icons.person)),
                  ButtonSegment(value: 'admin', label: Text('Pemilik'), icon: Icon(Icons.shield)),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 6),
              Text(
                _role == 'admin'
                    ? 'Pemilik bisa melihat modal, laporan penuh, dan mengelola pengguna.'
                    : 'Kasir hanya bisa menjual, mengubah stok, dan melihat riwayat.',
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  activeColor: AppColors.success,
                  onChanged: (v) => setState(() => _active = v),
                  title: const Text('Akun aktif',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Akun nonaktif tidak bisa masuk aplikasi.',
                      style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppSize.radius),
                    border: Border.all(color: AppColors.danger, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 15, color: AppColors.danger, height: 1.35)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save, size: 24),
                label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
