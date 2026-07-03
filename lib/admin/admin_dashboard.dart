import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../service/admin_dashboard_service.dart';

class AdminDashboard extends StatefulWidget {
  final Function(int)? onNavigateToPage;

  const AdminDashboard({Key? key, this.onNavigateToPage}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminDashboardService _service = AdminDashboardService();

  Map<String, dynamic> dashboardData = {
    'totalMaterial': 0,
    'totalCategory': 0,
    'totalStokPR': 0,
    'totalStokMT': 0,
    'chartData': [],
  };

  bool isLoading = true;
  double maxChartValue = 100;

  // ─── warna 4 bar ──────────────────────────────────────────────────────────
  static const Color _colorMTMasuk  = Color(0xFF1D9E75);
  static const Color _colorMTKeluar = Color(0xFFE74C3C);
  static const Color _colorPRMasuk  = Color(0xFF48CAE4);
  static const Color _colorPRKeluar = Color(0xFFF39C12);

  // ─── breakpoint ──────────────────────────────────────────────────────────
  static const double _mobileBreakpoint = 700;

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < _mobileBreakpoint;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final data = await _service.getDashboardData();
      setState(() {
        dashboardData = data;
        isLoading = false;
        _calculateMaxChartValue();
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() => isLoading = false);
    }
  }

  void _calculateMaxChartValue() {
    double maxValue = 0;
    for (var m in dashboardData['chartData']) {
      for (final key in ['mt_masuk', 'mt_keluar', 'pr_masuk', 'pr_keluar']) {
        final v = (m[key] ?? 0).toDouble();
        if (v > maxValue) maxValue = v;
      }
    }
    maxChartValue = ((maxValue * 1.2) / 50).ceil() * 50.0;
    if (maxChartValue < 100) maxChartValue = 100;
  }

  void _navigateToPage(int index) => widget.onNavigateToPage?.call(index);

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5DADE2)),
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat data Beranda...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return _isMobile(context) ? _buildMobileLayout() : _buildDesktopLayout();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(isMobile: false),
          const SizedBox(height: 24),
          _buildStatCards(isMobile: false),
          const SizedBox(height: 24),
          Expanded(child: _buildChartContainer(isMobile: false)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(isMobile: true),
          const SizedBox(height: 20),
          _buildStatCards(isMobile: true),
          const SizedBox(height: 20),
          SizedBox(
            height: 380,
            child: _buildChartContainer(isMobile: true),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── welcome banner ───────────────────────────────────────────────────────

  Widget _buildWelcomeBanner({required bool isMobile}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5DADE2), Color(0xFF2E86C1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5DADE2).withOpacity(0.35),
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.home_rounded,
              size: isMobile ? 24 : 30,
              color: Colors.white,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang!',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 15,
                    color: Colors.white.withOpacity(0.88),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'MOBILKOM Logistik — Beranda',
                  style: TextStyle(
                    fontSize: isMobile ? 17 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: const [
                  Icon(Icons.calendar_today_rounded,
                      color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Dashboard Utama',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── stat cards ───────────────────────────────────────────────────────────

  Widget _buildStatCards({required bool isMobile}) {
    final cards = [
      _StatCardData(
        title: 'Total Barang',
        value: dashboardData['totalMaterial'].toString(),
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF5DADE2),
        subtitle: 'Kelola Barang',
        onTap: () => _navigateToPage(1),
      ),
      _StatCardData(
        title: 'Total Kategori',
        value: dashboardData['totalCategory'].toString(),
        icon: Icons.category_rounded,
        color: const Color(0xFF58D68D),
        subtitle: 'Kelola Kategori',
        onTap: () => _navigateToPage(3),
      ),
      _StatCardData(
        title: 'Stok Projek (PR)',
        value: dashboardData['totalStokPR'].toString(),
        icon: Icons.production_quantity_limits_rounded,
        color: const Color(0xFF85C1E9),
        subtitle: 'Lihat Stok PR',
        onTap: () => _navigateToPage(5),
      ),
      _StatCardData(
        title: 'Stok Material (MT)',
        value: dashboardData['totalStokMT'].toString(),
        icon: Icons.storage_rounded,
        color: const Color(0xFF7FB3D3),
        subtitle: 'Lihat Stok MT',
        onTap: () => _navigateToPage(4),
      ),
    ];

    if (isMobile) {
      // Mobile: 2 kolom grid
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: cards
            .map((c) => _buildStatCard(c, isMobile: true))
            .toList(),
      );
    } else {
      // Desktop: 4 kolom baris
      return Row(
        children: cards
            .map(
              (c) => Expanded(
                child: Padding(
                  padding: cards.indexOf(c) < cards.length - 1
                      ? const EdgeInsets.only(right: 16)
                      : EdgeInsets.zero,
                  child: _buildStatCard(c, isMobile: false),
                ),
              ),
            )
            .toList(),
      );
    }
  }

  Widget _buildStatCard(_StatCardData data, {required bool isMobile}) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [data.color, data.color.withOpacity(0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: data.color.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.all(isMobile ? 6 : 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    data.icon,
                    color: Colors.white,
                    size: isMobile ? 18 : 22,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 26 : 32,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        data.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: isMobile ? 11 : 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withOpacity(0.82),
                      size: 10,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── chart container ──────────────────────────────────────────────────────

  Widget _buildChartContainer({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartHeader(isMobile: isMobile),
          SizedBox(height: isMobile ? 14 : 20),
          Expanded(child: _buildEnhancedChart(isMobile: isMobile)),
        ],
      ),
    );
  }

  Widget _buildChartHeader({required bool isMobile}) {
    final legendItems = [
      _LegendItem(_colorMTMasuk,  'MT Masuk'),
      _LegendItem(_colorMTKeluar, 'MT Keluar'),
      _LegendItem(_colorPRMasuk,  'PR Masuk'),
      _LegendItem(_colorPRKeluar, 'PR Keluar'),
    ];

    if (isMobile) {
      // Mobile: judul dan legend di kolom
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaksi Stok',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[850],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Material & Produk — per bulan tahun ini',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: legendItems
                .map((l) => _legendDot(l.color, l.label, small: true))
                .toList(),
          ),
        ],
      );
    }

    // Desktop: judul kiri, legend kanan
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaksi Stok Material & Produk',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[850],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Data per bulan dalam tahun ini',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF5DADE2).withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF5DADE2).withOpacity(0.15),
            ),
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: 6,
            children: legendItems
                .map((l) => _legendDot(l.color, l.label))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label, {bool small = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: small ? 10 : 12,
          height: small ? 10 : 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: small ? 11 : 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── bar chart ────────────────────────────────────────────────────────────

  Widget _buildEnhancedChart({required bool isMobile}) {
    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des',
    ];

    const radius = BorderRadius.only(
      topLeft: Radius.circular(3),
      topRight: Radius.circular(3),
    );

    final double barWidth = isMobile ? 5 : 9;

    final List<BarChartGroupData> barGroups = [];
    final chartData = dashboardData['chartData'] as List;

    for (int i = 0; i < chartData.length; i++) {
      final m = chartData[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          groupVertically: false,
          barRods: [
            BarChartRodData(
              toY: (m['mt_masuk'] ?? 0).toDouble(),
              color: _colorMTMasuk,
              width: barWidth,
              borderRadius: radius,
            ),
            BarChartRodData(
              toY: (m['mt_keluar'] ?? 0).toDouble(),
              color: _colorMTKeluar,
              width: barWidth,
              borderRadius: radius,
            ),
            BarChartRodData(
              toY: (m['pr_masuk'] ?? 0).toDouble(),
              color: _colorPRMasuk,
              width: barWidth,
              borderRadius: radius,
            ),
            BarChartRodData(
              toY: (m['pr_keluar'] ?? 0).toDouble(),
              color: _colorPRKeluar,
              width: barWidth,
              borderRadius: radius,
            ),
          ],
        ),
      );
    }

    final double interval = (maxChartValue / 5).ceilToDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxChartValue,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= months.length) {
                  return const SizedBox.shrink();
                }
                // Mobile: tampilkan setiap 2 bulan agar tidak tumpuk
                if (isMobile && idx % 2 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    months[idx],
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value % interval != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 11,
                      color: Colors.grey[600],
                    ),
                  ),
                );
              },
              reservedSize: isMobile ? 32 : 45,
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left:   BorderSide(color: Colors.grey[300]!, width: 1),
            bottom: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: const Color(0xFF2C3E50),
            tooltipRoundedRadius: 8,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              const labels = ['MT Masuk', 'MT Keluar', 'PR Masuk', 'PR Keluar'];
              final month = months[groupIndex];
              final label = labels[rodIndex];
              return BarTooltipItem(
                '$month\n$label: ${rod.toY.toInt()}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey[200]!,
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
          drawVerticalLine: false,
        ),
      ),
    );
  }
}

// ─── helper classes ───────────────────────────────────────────────────────────

class _StatCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final VoidCallback onTap;

  const _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.onTap,
  });
}

class _LegendItem {
  final Color color;
  final String label;
  const _LegendItem(this.color, this.label);
}