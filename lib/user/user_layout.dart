import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../login.dart';
import 'user_dashboard.dart';
import 'user_stok_material.dart';
import 'user_stok_product.dart';
import 'user_assembly.dart';

class UserLayout extends StatefulWidget {
  @override
  _UserLayoutState createState() => _UserLayoutState();
}

class _UserLayoutState extends State<UserLayout> {
  String currentPage = 'Beranda';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<UserNavigationItem> _pages = [
    UserNavigationItem(title: 'Beranda', icon: Icons.home, content: UserDashboard()),
    UserNavigationItem(title: 'Stok Barang', icon: Icons.inventory, content: MaterialStockPage()),
    UserNavigationItem(title: 'Stok Projek', icon: Icons.archive, content: ProductStockPage()),
    UserNavigationItem(title: 'Assembly', icon: Icons.build, content: UserAssemblyPage()),
  ];

  // ── Soft red palette ──────────────────────────────────────────────────────
  static const Color _sidebarBg    = Color(0xFFB85C6E); // muted rose-red
  static const Color _headerBg     = Color(0xFFC0667A); // slightly lighter
  static const Color _accentRed    = Color(0xFFAD4A60); // darker for accents
  static const Color _selectedRed  = Color(0xFFD32F2F); // bottom nav / indicators

  bool get isMobile {
    if (kIsWeb) return MediaQuery.of(context).size.width < 800;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  // ── Helper: "MOBIL" biru → "KOM" merah dengan ShaderMask ─────────────────
  Widget _buildGradientMobilkom({double fontSize = 26, FontWeight fontWeight = FontWeight.bold, double letterSpacing = 1.2}) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFF1565C0), // biru tua  — M
          Color(0xFF1E88E5), // biru muda — OBIL
          Color(0xFFE53935), // merah     — K
          Color(0xFFB71C1C), // merah tua — OM
        ],
        // Titik putus gradasi agar "MOBIL" (5 dari 7 huruf) ≈ biru,
        // "KOM" (2 huruf terakhir) ≈ merah
        stops: [0.0, 0.60, 0.62, 1.0],
      ).createShader(bounds),
      child: Text(
        'MOBILKOM',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          color: Colors.white, // warna dasar (akan di-mask)
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile ? _buildMobileDrawer() : null,
      body: Row(
        children: [
          if (!isMobile) _buildDesktopSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(),
                Expanded(child: _buildPageContent()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomNav() : null,
    );
  }

  // --- Desktop Sidebar ---
  Widget _buildDesktopSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: _sidebarBg,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        children: [
          _buildLogoHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 12),
              children: _pages.map((p) => _buildSidebarMenuItem(p.title, p.icon)).toList(),
            ),
          ),
          Divider(height: 1, color: Colors.white24),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  // --- Mobile Drawer ---
  Widget _buildMobileDrawer() {
    return Drawer(
      child: Container(
        color: _sidebarBg,
        child: Column(
          children: [
            _buildLogoHeader(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: _pages.map((page) {
                  final bool isSelected = currentPage == page.title;
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: Icon(page.icon, color: Colors.white),
                      title: Text(
                        page.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        _navigateTo(page.title);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            Divider(height: 1, color: Colors.white24),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  // --- Logo Header ---
  Widget _buildLogoHeader() {
    return Container(
      height: 120,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildGradientMobilkom(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            SizedBox(height: 4),
            Text(
              'Logistik',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // --- Logout Button ---
  Widget _buildLogoutButton() {
    return Container(
      padding: EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LoginPage()),
          );
        },
        icon: Icon(Icons.logout, color: _accentRed, size: 18),
        label: Text(
          'Logout',
          style: TextStyle(color: _accentRed, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          minimumSize: Size(double.infinity, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
    );
  }

  // --- Top Header (no search) ---
  Widget _buildTopHeader() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: _headerBg,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: Icon(Icons.menu, color: Colors.white, size: 26),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          _buildGradientMobilkom(
            fontSize: isMobile ? 17 : 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
          SizedBox(width: 6),
          Text(
            'Logistik',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isMobile ? 13 : 15,
            ),
          ),
          Spacer(),
          if (!isMobile)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                currentPage,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Page Content ---
  Widget _buildPageContent() {
    final selected = _pages.firstWhere(
      (p) => p.title == currentPage,
      orElse: () => _pages[0],
    );
    return Container(color: Color(0xFFF5F5F5), child: selected.content);
  }

  // --- Sidebar Menu Item ---
  Widget _buildSidebarMenuItem(String title, IconData icon) {
    final bool selected = currentPage == title;
    return GestureDetector(
      onTap: () => _navigateTo(title),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: Colors.white24) : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.w400,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Bottom Navigation ---
  Widget _buildBottomNav() {
    final int currentIndex = _pages.indexWhere((p) => p.title == currentPage);
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex >= 0 ? currentIndex : 0,
      onTap: (idx) => _navigateTo(_pages[idx].title),
      items: _pages
          .map((p) => BottomNavigationBarItem(icon: Icon(p.icon), label: p.title))
          .toList(),
      selectedItemColor: _selectedRed,
      unselectedItemColor: Colors.black45,
      backgroundColor: Colors.white,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
    );
  }

  void _navigateTo(String page) => setState(() => currentPage = page);
}

class UserNavigationItem {
  final String title;
  final IconData icon;
  final Widget content;

  UserNavigationItem({required this.title, required this.icon, required this.content});
}