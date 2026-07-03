import 'package:flutter/material.dart';
import '../admin/admin_transaksi.dart';
import '../admin/admin_submititem.dart';
import '../login.dart';
import '../admin/admin_dashboard.dart';
import '../admin/admin_kategori.dart';
import '../admin/admin_stok_material.dart';
import '../admin/admin_stok_produk.dart';
import '../admin/admin_assembly.dart';
import '../admin/admin_export_laporan.dart';

class AdminLayout extends StatefulWidget {
  @override
  _AdminLayoutState createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;

  static const Color _primaryBlue = Color(0xFF4682B4);
  static const Color _lightBlue = Color(0xFF87CEEB);
  static const Color _accentRed = Colors.red;

  void _handleNavigationFromDashboard(int pageIndex) {
    setState(() {
      _selectedIndex = pageIndex;
    });
  }

  List<NavigationItem> get _navigationItems => [
        NavigationItem(
          icon: Icons.dashboard_rounded,
          title: 'Beranda',
          content: AdminDashboard(
            onNavigateToPage: _handleNavigationFromDashboard,
          ),
        ),
        NavigationItem(
          icon: Icons.category_rounded,
          title: 'Kategori',
          content: AdminKategori(),
        ),
        NavigationItem(
          icon: Icons.add_box_rounded,
          title: 'Tambah Barang',
          content: SubmitItem(),
        ),
        NavigationItem(
          icon: Icons.receipt_long_rounded,
          title: 'Transaksi',
          content: AdminTransaksi(),
        ),
        NavigationItem(
          icon: Icons.warehouse_rounded,
          title: 'Stok Barang',
          content: AdminStokMaterial(),
        ),
        NavigationItem(
          icon: Icons.shopping_bag_rounded,
          title: 'Projek',
          content: AdminStokProduk(),
        ),
        NavigationItem(
          icon: Icons.build_rounded,
          title: 'Assembly',
          content: AdminAssembly(),
        ),
        NavigationItem(
          icon: Icons.description_rounded,
          title: 'Laporan',
          content: AdminExportLaporan(),
        ),
      ];

  bool _isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768;

  @override
  Widget build(BuildContext context) {
    return _isDesktop(context) ? _buildDesktopLayout() : _buildMobileLayout();
  }

  // ─────────────────────────────────────────────
  // DESKTOP LAYOUT
  // ─────────────────────────────────────────────
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: _isSidebarExpanded ? 220 : 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_lightBlue, _primaryBlue],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: Offset(3, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSidebarHeader(),
                Expanded(child: _buildSidebarNavItems()),
                _buildSidebarFooter(),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildDesktopTopBar(),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF0F4F8),
                    child: _navigationItems[_selectedIndex].content,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: _isSidebarExpanded
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: [
              if (_isSidebarExpanded)
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'MOBILKOM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _accentRed,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_isSidebarExpanded) ...[
            SizedBox(height: 12),
            Text(
              'Logistik',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: 36,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarNavItems() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      itemCount: _navigationItems.length,
      itemBuilder: (context, index) {
        final item = _navigationItems[index];
        final isSelected = _selectedIndex == index;

        return Tooltip(
          message: _isSidebarExpanded ? '' : item.title,
          preferBelow: false,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: InkWell(
              onTap: () => setState(() => _selectedIndex = index),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: _isSidebarExpanded ? 10 : 12),
                child: Row(
                  mainAxisAlignment: _isSidebarExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _primaryBlue.withOpacity(0.1)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        item.icon,
                        color: isSelected ? _primaryBlue : Colors.white,
                        size: 18,
                      ),
                    ),
                    if (_isSidebarExpanded) ...[
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: isSelected ? _primaryBlue : Colors.white,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: _isSidebarExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.person, color: Colors.white, size: 16),
              ),
              if (_isSidebarExpanded) ...[
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LINA SUSI YANTI',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Administrator',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 10),
          InkWell(
            onTap: () => _showLogoutDialog(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 7, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.red.withOpacity(0.35), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Colors.white, size: 15),
                  if (_isSidebarExpanded) ...[
                    SizedBox(width: 6),
                    Text(
                      'Keluar',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTopBar() {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 14, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text(
                  _currentDate(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MOBILE LAYOUT
  // ─────────────────────────────────────────────
  Widget _buildMobileLayout() {
    // index di navIndices = posisi di bottom nav, value = index _navigationItems
    final List<int> navIndices = [0, 1, 2, 3, 4, 5, 6, 7];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildMobileAppBar(),
      drawer: _buildMobileDrawer(),
      body: _navigationItems[_selectedIndex].content,
      bottomNavigationBar: _buildBottomNavigationBar(navIndices),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_lightBlue, _primaryBlue],
          ),
        ),
      ),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'MOBILKOM',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _accentRed,
                letterSpacing: 1,
              ),
            ),
          ),
          SizedBox(width: 10),
          Text(
            _navigationItems[_selectedIndex].title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.person_rounded, color: Colors.white),
          onPressed: () => _showMobileProfileSheet(context),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(List<int> navIndices) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: _buildBottomNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Beranda',
                  navIndex: navIndices[0],
                  navIndices: navIndices)),
              Expanded(child: _buildBottomNavItem(
                  icon: Icons.category_rounded,
                  label: 'Kategori',
                  navIndex: navIndices[1],
                  navIndices: navIndices)),
              Expanded(child: _buildBottomNavItem(
                  icon: Icons.add_box_rounded,
                  label: 'Tambah',
                  navIndex: navIndices[2],
                  navIndices: navIndices)),
              Expanded(child: _buildBottomNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Transaksi',
                  navIndex: navIndices[3],
                  navIndices: navIndices)),
              Expanded(child: _buildBottomNavItem(
                  icon: Icons.warehouse_rounded,
                  label: 'Stok',
                  navIndex: navIndices[4],
                  navIndices: navIndices)),
              Expanded(child: _buildBottomNavItem(
                  icon: Icons.shopping_bag_rounded,
                  label: 'Projek',
                  navIndex: navIndices[5],
                  navIndices: navIndices)),
              Expanded(child: _buildBottomNavItem(
                  icon: Icons.build_rounded,
                  label: 'Assembly',
                  navIndex: navIndices[6],
                  navIndices: navIndices)),
              Expanded(child: _buildBottomNavItem(
                  icon: Icons.description_rounded,
                  label: 'Laporan',
                  navIndex: navIndices[7],
                  navIndices: navIndices)),
            ],
          ),
        ),
      ),
    );
  }

  // FIX: Hapus parameter currentBottom, gunakan _selectedIndex langsung
  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required int navIndex,       // index tujuan di _navigationItems
    required List<int> navIndices,
  }) {
    // ✅ Bandingkan langsung dengan _selectedIndex — satu sumber kebenaran
    final isSelected = _selectedIndex == navIndex;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = navIndex);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? _primaryBlue.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? _primaryBlue : Colors.grey[500],
              size: 20,
            ),
            SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: isSelected ? _primaryBlue : Colors.grey[500],
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_lightBlue, _primaryBlue],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'MOBILKOM',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _accentRed,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child:
                          Icon(Icons.person, color: Colors.white, size: 22),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LINA SUSI YANTI',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Administrator',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8),
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                final item = _navigationItems[index];
                final isSelected = _selectedIndex == index;
                return ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _primaryBlue.withOpacity(0.12)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item.icon,
                      color: isSelected ? _primaryBlue : Colors.grey[600],
                      size: 18,
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      color: isSelected ? _primaryBlue : Colors.grey[800],
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: _primaryBlue.withOpacity(0.07),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          Container(
            margin: EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showLogoutDialog(context);
              },
              icon: Icon(Icons.logout_rounded, size: 18),
              label: Text('Keluar dari Sistem'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: Size(double.infinity, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMobileProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            CircleAvatar(
              radius: 32,
              backgroundColor: _primaryBlue.withOpacity(0.15),
              child: Icon(Icons.person, size: 32, color: _primaryBlue),
            ),
            SizedBox(height: 12),
            Text(
              'LINA SUSI YANTI',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[800]),
            ),
            Text(
              'Administrator',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showLogoutDialog(context);
              },
              icon: Icon(Icons.logout_rounded),
              label: Text('Keluar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SHARED DIALOGS & UTILITIES
  // ─────────────────────────────────────────────
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('Konfirmasi Keluar', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari sistem?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Batal',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text('Keluar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  String _currentDate() {
    final now = DateTime.now();
    const months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${now.day} ${months[now.month]} ${now.year}';
  }
}

// ─────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────
class NavigationItem {
  final IconData icon;
  final String title;
  final Widget content;

  NavigationItem({
    required this.icon,
    required this.title,
    required this.content,
  });
}