import 'package:flutter/material.dart';
import '../admin/admin_transaksi_material.dart';
import '../admin/admin_transaksi_product.dart';

class AdminTransaksi extends StatefulWidget {
  @override
  State<AdminTransaksi> createState() => _AdminTransaksiState();
}

class _AdminTransaksiState extends State<AdminTransaksi>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTab({
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
    required bool isMobile,
  }) {
    final bool isActive = _tabController.index == index;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 8,
        vertical: isMobile ? 4 : 6,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 16,
        vertical: isMobile ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: isActive ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: isMobile ? 16 : 18,
              color: isActive ? Colors.white : Colors.grey),
          SizedBox(width: isMobile ? 5 : 8),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: isMobile ? 60 : 70,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.swap_horiz,
                  size: isMobile ? 18 : 22,
                  color: const Color(0xFFD32F2F)),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaksi',
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                if (!isMobile)
                  Text(
                    'Kelola transaksi barang & projek',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isMobile ? 52 : 60),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicator: const BoxDecoration(),
              dividerColor: Colors.grey.shade300,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              tabs: [
                _buildTab(
                  index: 0,
                  icon: Icons.inventory,
                  label: 'Barang',
                  activeColor: const Color(0xFF1976D2),
                  isMobile: isMobile,
                ),
                _buildTab(
                  index: 1,
                  icon: Icons.inventory_2,
                  label: 'Projek',
                  activeColor: const Color(0xFFD32F2F),
                  isMobile: isMobile,
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          TransaksiMaterial(),
          TransaksiProduct(),
        ],
      ),
    );
  }
}