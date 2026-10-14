import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/repositories.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/refresh_signal.dart';
import '../widgets/app_widgets.dart';
import 'history_screens.dart';
import 'pos_screen.dart';
import 'product_screens.dart';
import 'report_screen.dart';
import 'settings_screens.dart';

/// Indeks tab aktif dibagikan lewat notifier sederhana supaya kartu "Aksi
/// cepat" di beranda bisa memindah tab tanpa memanggil setState milik widget lain.
final ValueNotifier<int> homeTabIndex = ValueNotifier<int>(0);

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    homeTabIndex.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    homeTabIndex.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final index = homeTabIndex.value;
    final pages = const [
      _DashboardTab(),
      PosScreen(),
      ProductListScreen(),
      HistoryScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 74,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 28,
              color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => homeTabIndex.value = i,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
            NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'Kasir'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Stok'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Riwayat'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Pengaturan'),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final _report = ReportRepository();

  ReportSummary _hariIni = const ReportSummary();
  ReportSummary _bulanIni = const ReportSummary();
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
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final h = await _report.summary(awalHari(now), akhirHari(now));
    final b = await _report.summary(DateTime(now.year, now.month, 1), akhirHari(now));
    if (!mounted) return;
    setState(() {
      _hariIni = h;
      _bulanIni = b;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final toko = context.watch<SettingsProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(toko.namaTampilan,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Halo, ${user?.name ?? ''} - ${user?.roleLabel ?? ''}',
                style: const TextStyle(fontSize: 13, color: Color(0xFFBFD3EE), fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(tanggalPanjang(DateTime.now()),
                      style: const TextStyle(fontSize: 15, color: AppColors.textMuted)),
                  const SizedBox(height: 14),
                  // Seluruh angka rupiah adalah isi laporan, jadi hanya pemilik
                  // yang melihatnya. Kasir mendapat angka operasional yang
                  // memang dibutuhkan untuk bekerja.
                  if (auth.isAdmin) ...[
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'Pendapatan hari ini',
                            value: rupiah(_hariIni.pendapatanBersih),
                            color: AppColors.success,
                            icon: Icons.trending_up,
                            sub: '${_hariIni.jumlahTransaksi} transaksi',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatTile(
                            label: 'Barang terjual hari ini',
                            value: '${_hariIni.itemTerjual} pcs',
                            color: AppColors.primary,
                            icon: Icons.shopping_bag_outlined,
                            sub: 'Rata-rata ${rupiah(_hariIni.rataRataTransaksi)}/nota',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'Pendapatan bulan ini',
                            value: rupiah(_bulanIni.pendapatanBersih),
                            color: AppColors.primaryDark,
                            icon: Icons.calendar_month,
                            sub: 'Laba kotor ${rupiah(_bulanIni.labaKotor)}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatTile(
                            label: 'Retur bulan ini',
                            value: rupiah(_bulanIni.totalRetur),
                            color: AppColors.danger,
                            icon: Icons.assignment_return_outlined,
                            sub: '${_bulanIni.jumlahRetur} kali retur',
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'Transaksi hari ini',
                            value: '${_hariIni.jumlahTransaksi} nota',
                            color: AppColors.primary,
                            icon: Icons.receipt_long_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatTile(
                            label: 'Barang terjual hari ini',
                            value: '${_hariIni.itemTerjual} pcs',
                            color: AppColors.primaryDark,
                            icon: Icons.shopping_bag_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Aksi cepat', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.point_of_sale,
                          label: 'Mulai\nTransaksi',
                          color: AppColors.accent,
                          onTap: () => homeTabIndex.value = 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: auth.isAdmin
                            ? _QuickAction(
                                icon: Icons.add_box_outlined,
                                label: 'Tambah\nBarang',
                                color: AppColors.primary,
                                onTap: () async {
                                  await Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => const ProductFormScreen()));
                                  _load();
                                },
                              )
                            : _QuickAction(
                                icon: Icons.inventory_2_outlined,
                                label: 'Kelola\nStok',
                                color: AppColors.primary,
                                onTap: () => homeTabIndex.value = 2,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: auth.isAdmin
                            ? _QuickAction(
                                icon: Icons.bar_chart,
                                label: 'Lihat\nLaporan',
                                color: AppColors.success,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const ReportScreen())),
                              )
                            : _QuickAction(
                                icon: Icons.receipt_long,
                                label: 'Riwayat\nTransaksi',
                                color: AppColors.success,
                                onTap: () => homeTabIndex.value = 3,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppSize.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSize.radius),
        child: Container(
          height: 110,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSize.radius),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color == AppColors.accent ? AppColors.primaryDark : color),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.text)),
            ],
          ),
        ),
      ),
    );
  }
}
