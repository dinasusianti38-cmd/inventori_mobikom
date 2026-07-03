import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../service/user_dashboard_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class UserDashboard extends StatefulWidget {
  @override
  _UserDashboardState createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final UserDashboardService _service = UserDashboardService();

  bool isLoading = true;
  Map<String, dynamic> dashboardData = {};
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  bool get isMobile {
    if (kIsWeb) return MediaQuery.of(context).size.width < 800;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final data = await _service.getDashboardData();
      setState(() {
        dashboardData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD32F2F)),
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              'Error: $errorMessage',
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final cardData = [
      {
        'title': 'Total Barang',
        'value': dashboardData['totalMaterial']?.toString() ?? '0',
        'icon': Icons.inventory_2,
        'color': Color(0xFFE91E63),
      },
      {
        'title': 'total kategori',
        'value': dashboardData['totalCategory']?.toString() ?? '0',
        'icon': Icons.category,
        'color': Color(0xFF2196F3),
      },
      {
        'title': 'total stok PR',
        'value': dashboardData['totalStokPR']?.toString() ?? '0',
        'icon': Icons.inventory,
        'color': Color(0xFF4CAF50),
      },
      {
        'title': 'total stok MT',
        'value': dashboardData['totalStokMT']?.toString() ?? '0',
        'icon': Icons.warehouse,
        'color': Color(0xFFFF9800),
      },
    ];

    return Container(
      color: Color(0xFFF5F5F5),
      child: isMobile
          ? _buildMobileLayout(cardData)
          : _buildDesktopLayout(cardData),
    );
  }

  // ─── Mobile Layout (DESAIN DIPERKECIL) ─────────────────────────────
  Widget _buildMobileLayout(List<Map<String, dynamic>> cardData) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(isMobileSize: true),
          SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.9, // lebih kecil & pipih
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            children: cardData.map((card) {
              return _buildStatCard(
                card['title'] as String,
                card['value'] as String,
                card['icon'] as IconData,
                card['color'] as Color,
                mobile: true,
              );
            }).toList(),
          ),

          SizedBox(height: 16),

          Container(
            height: 380, // grafik diperbesar
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perbandingan Stok PR dan MT per Kategori',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 10),
                Expanded(child: _buildStockChart()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Desktop Layout (ASLI) ─────────────────────────────────────────
  Widget _buildDesktopLayout(List<Map<String, dynamic>> cardData) {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(isMobileSize: false),
          SizedBox(height: 24),

          Row(
            children: cardData.map((card) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: card == cardData.last ? 0 : 16,
                  ),
                  child: _buildStatCard(
                    card['title'] as String,
                    card['value'] as String,
                    card['icon'] as IconData,
                    card['color'] as Color,
                    mobile: false,
                  ),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: 24),

          Expanded(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perbandingan Stok PR dan MT per Kategori',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 20),
                  Expanded(child: _buildStockChart()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Welcome Card (ASLI) ───────────────────────────────────────────
  Widget _buildWelcomeCard({required bool isMobileSize}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobileSize ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.home, size: isMobileSize ? 26 : 32, color: Color(0xFFD32F2F)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Selamat Datang Di MOBILKOM Logistik',
              style: TextStyle(
                fontSize: isMobileSize ? 14 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stat Card (DESAIN MOBILE DIPERKECIL) ──────────────────────────
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    required bool mobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 10 : 20,
        vertical: mobile ? 8 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(mobile ? 4 : 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: mobile ? 16 : 24),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: mobile ? 10 : 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: mobile ? 20 : 32,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stock Chart (ASLI) ────────────────────────────────────────────
  Widget _buildStockChart() {
    final stockData = dashboardData['stockData'] as List<dynamic>? ?? [];

    if (stockData.isEmpty) {
      final totalStokPR = (dashboardData['totalStokPR'] ?? 0).toDouble();
      final totalStokMT = (dashboardData['totalStokMT'] ?? 0).toDouble();

      if (totalStokPR == 0 && totalStokMT == 0) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
              SizedBox(height: 12),
              Text('Tidak ada data stok',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
          ),
        );
      }

      return Column(
        children: [
          _buildLegend(),
          SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxStock([totalStokPR, totalStokMT]),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: totalStokPR,
                        color: Color(0xFF4CAF50),
                        width: 40,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      BarChartRodData(
                        toY: totalStokMT,
                        color: Color(0xFFFF9800),
                        width: 40,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildLegend(),
        SizedBox(height: 12),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxStockFromData(stockData),
              barGroups: stockData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: (data['stokPR'] ?? 0).toDouble(),
                      color: Color(0xFF4CAF50),
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: (data['stokMT'] ?? 0).toDouble(),
                      color: Color(0xFFFF9800),
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 14, height: 14, color: Color(0xFF4CAF50)),
        SizedBox(width: 6),
        Text('Stok PR'),
        SizedBox(width: 20),
        Container(width: 14, height: 14, color: Color(0xFFFF9800)),
        SizedBox(width: 6),
        Text('Stok MT'),
      ],
    );
  }

  double _getMaxStock(List<double> values) {
    if (values.isEmpty) return 100;
    double maxY = values.reduce((a, b) => a > b ? a : b);
    return maxY > 0 ? maxY + (maxY * 0.1) : 100;
  }

  double _getMaxStockFromData(List<dynamic> data) {
    double maxY = 0;
    for (var item in data) {
      double stokPR = (item['stokPR'] ?? 0).toDouble();
      double stokMT = (item['stokMT'] ?? 0).toDouble();
      if (stokPR > maxY) maxY = stokPR;
      if (stokMT > maxY) maxY = stokMT;
    }
    return maxY > 0 ? maxY + (maxY * 0.1) : 100;
  }
}