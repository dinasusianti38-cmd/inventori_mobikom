import 'package:flutter/material.dart';
import '../models/user_material_model.dart';
import '../service/user_stok_material_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class MaterialStockPage extends StatefulWidget {
  @override
  _MaterialStockPageState createState() => _MaterialStockPageState();
}

class _MaterialStockPageState extends State<MaterialStockPage> {
  final TextEditingController _searchController = TextEditingController();
  List<UserMaterialStock> materials = [];
  List<String> categories = ['semua kategory'];
  String selectedCategory = 'semua kategory';
  int currentPage = 1;
  int totalPages = 1;
  int totalRecords = 0;
  int itemsPerPage = 10;
  bool isLoading = false;
  PaginationInfo? paginationInfo;

  static const Color _primaryRed = Color(0xFFB23A48);
  static const Color _lightRed = Color(0xFFF8E8EA);

  bool get isMobile {
    if (kIsWeb) return MediaQuery.of(context).size.width < 800;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  bool get isTablet {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1024;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadCategories();
    await _loadMaterials();
  }

  Future<void> _loadCategories() async {
    try {
      final categoryList = await UserStokMaterialService.getCategories();
      setState(() { categories = categoryList; });
    } catch (e) {
      _showErrorSnackBar('Error loading categories: $e');
    }
  }

  Future<void> _loadMaterials() async {
    setState(() { isLoading = true; });
    try {
      final response = await UserStokMaterialService.getMaterialStock(
        search: _searchController.text,
        category: selectedCategory,
        page: currentPage,
        limit: itemsPerPage,
      );
      setState(() {
        materials = response.data;
        paginationInfo = response.pagination;
        totalPages = response.pagination.totalPages;
        totalRecords = response.pagination.totalRecords;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading materials: $e');
    } finally {
      setState(() { isLoading = false; });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _onSearchChanged() {
    setState(() { currentPage = 1; });
    _loadMaterials();
  }

  void _onCategoryChanged(String? category) {
    if (category != null) {
      setState(() { selectedCategory = category; currentPage = 1; });
      _loadMaterials();
    }
  }

  void _onPageChanged(int page) {
    setState(() { currentPage = page; });
    _loadMaterials();
  }

  void _onItemsPerPageChanged(int? newItemsPerPage) {
    if (newItemsPerPage != null) {
      setState(() { itemsPerPage = newItemsPerPage; currentPage = 1; });
      _loadMaterials();
    }
  }

  void _showMaterialDetail(UserMaterialStock material) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryRed,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(material.namaMaterial,
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.all(16),
                    children: [
                      _buildDetailRow('Nama Material', material.namaMaterial),
                      _buildDetailRow('Kode Material', material.kodeMaterial),
                      _buildDetailRow('Jumlah', material.jumlah),
                      _buildDetailRow('Kategori', material.kategory),
                      _buildDetailRow('Last Update', material.lastUpdate),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]))),
          Expanded(flex: 3, child: Text(value, style: TextStyle(color: Colors.grey[800]))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildTopHeader(),
          Expanded(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.all(isMobile ? 12 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(),
                  SizedBox(height: isMobile ? 12 : 20),
                  Expanded(child: _buildTableSection()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER PUTIH ──
  Widget _buildTopHeader() {
    return Container(
      height: isMobile ? 60 : 80,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: Icon(Icons.menu, color: Colors.grey[800], size: 24),
              onPressed: () { Scaffold.of(context).openDrawer(); },
            ),
          if (isMobile) SizedBox(width: 4),
          Expanded(
            child: Text(
              'Stok Barang',
              style: TextStyle(
                color: Colors.grey[900],
                fontSize: isMobile ? 18 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: _primaryRed, size: 24),
            onPressed: _loadMaterials,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryRed, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: isMobile ? _buildMobileFilterContent() : _buildDesktopFilterContent(),
    );
  }

  Widget _buildMobileFilterContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cari Barang', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        SizedBox(height: 6),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'cari nama atau kode barang..',
            hintStyle: TextStyle(fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _primaryRed)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: IconButton(
              icon: Icon(Icons.clear, size: 18),
              onPressed: () { _searchController.clear(); _onSearchChanged(); },
            ),
          ),
          onChanged: (value) => _onSearchChanged(),
        ),
        SizedBox(height: 10),
        Text('Kategori', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedCategory,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _primaryRed)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontSize: 13)))).toList(),
          onChanged: _onCategoryChanged,
        ),
        SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : _loadMaterials,
            icon: Icon(Icons.search, size: 18),
            label: Text('Filter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryRed, foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopFilterContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cari barang', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'cari nama atau kode barang..',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _primaryRed)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (value) => _onSearchChanged(),
              ),
            ],
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('kategori', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _primaryRed)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: _onCategoryChanged,
              ),
            ],
          ),
        ),
        SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: isLoading ? null : _loadMaterials,
          icon: Icon(Icons.search, size: 18),
          label: Text('filter'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryRed, foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildTableSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryRed, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Text('Show ', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: itemsPerPage,
                      items: [10, 25, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text('$v', style: TextStyle(fontSize: 13)))).toList(),
                      onChanged: _onItemsPerPageChanged,
                    ),
                  ),
                ),
                Text(' Entries', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryRed))
                : materials.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[400]),
                            SizedBox(height: 12),
                            Text('Tidak ada data barang', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: _buildResponsiveTable(),
                      ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          _buildPaginationSection(),
        ],
      ),
    );
  }

  Widget _buildResponsiveTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isMobile) return _buildMobileCardList();
        return _buildDesktopTable();
      },
    );
  }

  Widget _buildMobileCardList() {
    return Column(
      children: materials.asMap().entries.map((entry) {
        int index = entry.key;
        UserMaterialStock material = entry.value;
        int displayIndex = ((currentPage - 1) * itemsPerPage) + index + 1;
        bool isEven = index % 2 == 0;

        return InkWell(
          onTap: () => _showMaterialDetail(material),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isEven ? Colors.white : _lightRed,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: _primaryRed, borderRadius: BorderRadius.circular(4)),
                  alignment: Alignment.center,
                  child: Text('$displayIndex', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(material.namaMaterial,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[850])),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.qr_code, size: 13, color: Colors.grey[500]),
                          SizedBox(width: 4),
                          Text(material.kodeMaterial, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          SizedBox(width: 12),
                          Icon(Icons.inventory_2, size: 13, color: _primaryRed),
                          SizedBox(width: 4),
                          Text(material.jumlah, style: TextStyle(fontSize: 12, color: _primaryRed, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: _lightRed, borderRadius: BorderRadius.circular(4)),
                            child: Text(material.kategory, style: TextStyle(fontSize: 11, color: _primaryRed)),
                          ),
                          Spacer(),
                          Icon(Icons.update, size: 12, color: Colors.grey[400]),
                          SizedBox(width: 3),
                          Text(material.lastUpdate, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDesktopTable() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: _primaryRed,
          child: Row(
            children: [
              _headerCell('No', flex: 1),
              _headerCell('Nama Barang', flex: 3),
              _headerCell('Kode Barang', flex: 2),
              _headerCell('Jumlah', flex: 2),
              _headerCell('Kategori', flex: 2),
              _headerCell('Pembaruan Terakhir', flex: 2),
            ],
          ),
        ),
        ...materials.asMap().entries.map((entry) {
          int index = entry.key;
          UserMaterialStock material = entry.value;
          int displayIndex = ((currentPage - 1) * itemsPerPage) + index + 1;
          bool isEven = index % 2 == 0;

          return Container(
            width: double.infinity,
            color: isEven ? Colors.white : _lightRed,
            child: Row(
              children: [
                _dataCell('$displayIndex', flex: 1),
                _dataCell(material.namaMaterial, flex: 3),
                _dataCell(material.kodeMaterial, flex: 2),
                _dataCell(material.jumlah, flex: 2),
                _dataCell(material.kategory, flex: 2),
                _dataCell(material.lastUpdate, flex: 2),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _headerCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Text(text, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _dataCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
        child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[800])),
      ),
    );
  }

  Widget _buildPaginationSection() {
    if (paginationInfo == null) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: isMobile
          ? Column(
              children: [
                Text(
                  'Showing ${paginationInfo!.showingFrom} to ${paginationInfo!.showingTo} of ${paginationInfo!.totalRecords} entries',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: _buildPageButtons()),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${paginationInfo!.showingFrom} to ${paginationInfo!.showingTo} of ${paginationInfo!.totalRecords} entries',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                Row(children: _buildPageButtons()),
              ],
            ),
    );
  }

  List<Widget> _buildPageButtons() {
    return [
      ElevatedButton(
        onPressed: currentPage > 1 ? () => _onPageChanged(currentPage - 1) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[200], foregroundColor: Colors.grey[800],
          elevation: 0, padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text('Previous', style: TextStyle(fontSize: 13)),
      ),
      SizedBox(width: 8),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: _primaryRed, borderRadius: BorderRadius.circular(6)),
        child: Text('$currentPage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      SizedBox(width: 8),
      ElevatedButton(
        onPressed: currentPage < totalPages ? () => _onPageChanged(currentPage + 1) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[200], foregroundColor: Colors.grey[800],
          elevation: 0, padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text('Next', style: TextStyle(fontSize: 13)),
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}