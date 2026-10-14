import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/app_info.dart';
import '../widgets/app_widgets.dart';

/// Layar penyiapan awal. Muncul sekali, saat database belum berisi akun apa pun.
///
/// Menggantikan akun dan produk contoh yang dulu ditanam otomatis. Pemilik toko
/// mengisi identitas tokonya sendiri dan membuat kata sandinya sendiri, sehingga
/// tidak ada kredensial bawaan yang bisa ditebak siapa pun.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaToko = TextEditingController();
  final _alamat = TextEditingController();
  final _telp = TextEditingController();
  final _namaPemilik = TextEditingController();
  final _username = TextEditingController();
  final _sandi = TextEditingController();
  final _ulangSandi = TextEditingController();

  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_namaToko, _alamat, _telp, _namaPemilik, _username, _sandi, _ulangSandi]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    final settings = context.read<SettingsProvider>();
    final auth = context.read<AuthProvider>();

    await settings.saveToko(
      nama: _namaToko.text.trim(),
      alamat: _alamat.text.trim(),
      telp: _telp.text.trim(),
      catatan: AppInfo.catatanStrukBawaan,
    );

    final err = await auth.completeSetup(
      name: _namaPemilik.text.trim(),
      username: _username.text.trim(),
      password: _sandi.text,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.storefront, size: 40, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Selamat datang',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Isi data toko dan buat akun pemilik.\nHanya dilakukan sekali.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Color(0xFFBFD3EE), height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _judul(context, 'Data toko', Icons.store_outlined),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _namaToko,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nama toko',
                              hintText: 'Contoh: Anna Seragam',
                              helperText: 'Dicetak di bagian atas struk.',
                              helperStyle: TextStyle(fontSize: 13),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Nama toko belum diisi.' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _alamat,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Alamat toko',
                              hintText: 'Boleh dikosongkan',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _telp,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Nomor telepon / WhatsApp',
                              hintText: 'Boleh dikosongkan',
                            ),
                          ),
                          const SizedBox(height: 24),
                          _judul(context, 'Akun pemilik', Icons.shield_outlined),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _namaPemilik,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nama pemilik',
                              hintText: 'Nama yang tampil di struk',
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Nama pemilik belum diisi.' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _username,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Nama pengguna untuk masuk',
                              helperText: 'Tanpa spasi. Contoh: anna',
                              helperStyle: TextStyle(fontSize: 13),
                            ),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.length < 3) return 'Minimal 3 huruf.';
                              if (t.contains(' ')) return 'Tidak boleh memakai spasi.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _sandi,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'Kata sandi',
                              helperText: 'Minimal 6 huruf. Catat di tempat aman.',
                              helperStyle: const TextStyle(fontSize: 13),
                              suffixIcon: IconButton(
                                iconSize: 26,
                                tooltip: _obscure ? 'Tampilkan sandi' : 'Sembunyikan sandi',
                                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.length < 6) ? 'Minimal 6 huruf.' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _ulangSandi,
                            obscureText: _obscure,
                            decoration: const InputDecoration(labelText: 'Ulangi kata sandi'),
                            validator: (v) =>
                                (v != _sandi.text) ? 'Kata sandi tidak sama.' : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
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
                          const SizedBox(height: 22),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              minimumSize: const Size.fromHeight(58),
                            ),
                            onPressed: _saving ? null : _submit,
                            icon: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.white))
                                : const Icon(Icons.check_circle, size: 26),
                            label: Text(_saving ? 'Menyiapkan...' : 'Mulai gunakan aplikasi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Semua data tersimpan di dalam HP ini.\n'
                    'Jangan lupa membuat cadangan secara berkala.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFFBFD3EE), height: 1.5),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _judul(BuildContext context, String teks, IconData ikon) => Row(
        children: [
          Icon(ikon, size: 24, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(teks, style: Theme.of(context).textTheme.titleLarge),
        ],
      );
}
