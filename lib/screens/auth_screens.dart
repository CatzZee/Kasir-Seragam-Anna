import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_userCtrl.text, _passCtrl.text);
    if (!mounted) return;
    if (!ok) showSnack(context, auth.error ?? 'Gagal masuk.', isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final toko = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.storefront, size: 48, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    toko.namaTampilan,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  const Text('Aplikasi Kasir Toko',
                      style: TextStyle(fontSize: 17, color: Color(0xFFBFD3EE))),
                  const SizedBox(height: 28),
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
                          Text('Masuk', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          const Text('Gunakan akun yang diberikan pemilik toko.',
                              style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _userCtrl,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Nama pengguna',
                              prefixIcon: Icon(Icons.person_outline, size: 26),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Nama pengguna belum diisi.' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Kata sandi',
                              prefixIcon: const Icon(Icons.lock_outline, size: 26),
                              suffixIcon: IconButton(
                                iconSize: 26,
                                tooltip: _obscure ? 'Tampilkan sandi' : 'Sembunyikan sandi',
                                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Kata sandi belum diisi.' : null,
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton.icon(
                            onPressed: auth.busy ? null : _submit,
                            icon: auth.busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Icon(Icons.login, size: 24),
                            label: Text(auth.busy ? 'Memeriksa...' : 'Masuk'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
