import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Kartu putih standar. Dipakai menggantikan Card bawaan agar radius,
/// border, dan padding konsisten di seluruh aplikasi.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSize.radius),
        border: Border.all(color: borderColor ?? AppColors.border, width: 1.5),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSize.radius),
      child: content,
    );
  }
}

/// Bar aksi bawah yang selalu terlihat. Pengguna Gen X tidak dibiarkan mencari
/// tombol utama — posisinya tetap di tempat yang sama di setiap layar.
class BottomActionBar extends StatelessWidget {
  final Widget child;
  const BottomActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
        ),
        child: child,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: AppColors.border),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final String? sub;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.2)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(sub!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }
}

/// Label status berwarna. Tidak pernah hanya mengandalkan warna —
/// selalu ada teksnya, supaya tetap terbaca oleh mata yang sulit membedakan warna.
class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const StatusChip({super.key, required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 5)],
          Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Tombol +/- besar untuk mengatur jumlah. Tidak memakai gesture tersembunyi.
class QtyStepper extends StatelessWidget {
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final double size;

  const QtyStepper({
    super.key,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove, onMinus, AppColors.danger),
        Container(
          width: 52,
          alignment: Alignment.center,
          child: Text('$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
        ),
        _btn(Icons.add, onPlus, AppColors.success),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, Color color) => Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      );
}

/// [bottomMargin] menaikkan snackbar di atas bar aksi bawah / navigasi tab,
/// supaya notifikasi tidak menutupi tombol yang justru sedang dibutuhkan.
void showSnack(
  BuildContext context,
  String message, {
  bool isError = false,
  double bottomMargin = 0,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.danger : AppColors.primaryDark,
      duration: Duration(seconds: isError ? 4 : 2),
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomMargin),
    ));
}

// Flutter sudah menaikkan snackbar di atas bar navigasi tab (74px) karena
// snackbar berpatokan pada Scaffold terluar milik HomeShell. Nilai di bawah
// ini adalah tambahan DI ATAS offset bawaan itu, bukan jarak dari tepi layar.

/// Halaman tanpa bar aksi: offset bawaan Flutter sudah cukup.
const double kNavBarInset = 0;

/// Halaman dengan bar aksi bawah (mis. total belanja + tombol Keranjang,
/// tinggi sekitar 88px). Snackbar naik tepat di atasnya.
const double kNavBarWithActionInset = 88;

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Ya, lanjutkan',
  String cancelText = 'Batal',
  bool destructive = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
      content: Text(message, style: Theme.of(ctx).textTheme.bodyLarge),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: destructive
                ? ElevatedButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelText)),
        ),
      ],
    ),
  );
  return res ?? false;
}
