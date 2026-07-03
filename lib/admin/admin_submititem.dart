import 'package:flutter/material.dart';
import 'admin_material.dart';
import 'admin_produk.dart';

class SubmitItem extends StatefulWidget {
  @override
  _SubmitItemState createState() => _SubmitItemState();
}

class _SubmitItemState extends State<SubmitItem>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const double _mobileBreak = 600;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < _mobileBreak;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: SafeArea(
            child: Column(
              children: [
                // ─── HEADER ─────────────────────────────────────
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: mobile ? 16 : 24, vertical: mobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(mobile ? 8 : 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.add_box,
                          size: mobile ? 22 : 26,
                          color: const Color(0xFFD32F2F),
                        ),
                      ),
                      SizedBox(width: mobile ? 10 : 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tambah Barang',
                              style: TextStyle(
                                fontSize: mobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Kelola Barang dan Projek',
                              style: TextStyle(
                                fontSize: mobile ? 11 : 12,
                                color: Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── TAB BAR ────────────────────────────────────
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: const BoxDecoration(),
                    dividerColor: Colors.grey[200],
                    labelPadding: EdgeInsets.symmetric(horizontal: mobile ? 4 : 8),
                    tabs: [
                      _buildTab(
                        index: 0,
                        icon: Icons.inventory,
                        label: 'Barang',
                        activeColor: const Color(0xFF1976D2),
                        mobile: mobile,
                      ),
                      _buildTab(
                        index: 1,
                        icon: Icons.inventory_2,
                        label: 'Projek',
                        activeColor: const Color(0xFFD32F2F),
                        mobile: mobile,
                      ),
                    ],
                  ),
                ),

                // ─── TAB CONTENT ────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _AdminMaterialTab(),
                      _AdminProductTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Tab button dengan warna aktif/non-aktif berbeda tiap tab, ukuran responsif
  Widget _buildTab({
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
    required bool mobile,
  }) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final isActive = _tabController.index == index;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: mobile ? 6 : 8, vertical: 6),
          padding: EdgeInsets.symmetric(
              horizontal: mobile ? 10 : 16, vertical: mobile ? 7 : 8),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: mobile ? 16 : 18,
                color: isActive ? Colors.white : Colors.grey[500],
              ),
              SizedBox(width: mobile ? 6 : 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: mobile ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Colors.grey[500],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wrapper Tab Barang — menampilkan AdminMaterial tanpa Scaffold
// ─────────────────────────────────────────────────────────────────────────────
class _AdminMaterialTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Karena AdminMaterial sudah punya Scaffold sendiri, kita push sebagai
    // sub-route di dalam tab menggunakan Navigator bertingkat (nested).
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => _AdminMaterialEmbedded(),
      ),
    );
  }
}

/// AdminMaterial yang header "back"-nya diganti dengan tab switch
class _AdminMaterialEmbedded extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Cukup kembalikan AdminMaterial dengan modifikasi:
    // tombol back dihilangkan (pop akan menutup app karena ini root navigator).
    return AdminMaterial();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wrapper Tab Projek — sama dengan di atas untuk AdminProduct
// ─────────────────────────────────────────────────────────────────────────────
class _AdminProductTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => _AdminProductEmbedded(),
      ),
    );
  }
}

class _AdminProductEmbedded extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AdminProduct();
  }
}