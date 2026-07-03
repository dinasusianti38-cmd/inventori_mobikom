import 'package:flutter/material.dart';
import '../models/user_stok_product_model.dart';
import '../service/user_stok_product_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ProductStockPage extends StatefulWidget {
  @override
  _ProductStockPageState createState() => _ProductStockPageState();
}

class _ProductStockPageState extends State<ProductStockPage> {
  List<ProductStock> _productStocks = [];
  List<ProductStock> _filteredProductStocks = [];
  bool _isLoading = true;
  String _errorMessage = '';

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _globalSearchController = TextEditingController();
  int _currentPage = 1;
  int _itemsPerPage = 10;

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
    _loadProductStocks();
  }

  Future<void> _loadProductStocks() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final stocks = await UserStokProductService.getAllProductStocks();
      setState(() {
        _productStocks = stocks;
        _filteredProductStocks = stocks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  void _filterProducts() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProductStocks = _productStocks;
      } else {
        _filteredProductStocks = _productStocks.where((stock) =>
          stock.productName.toLowerCase().contains(query) ||
          stock.productCode.toLowerCase().contains(query)
        ).toList();
      }
      _currentPage = 1;
    });
  }

  void _globalSearch() {
    String query = _globalSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProductStocks = _productStocks;
      } else {
        _filteredProductStocks = _productStocks.where((stock) =>
          stock.productName.toLowerCase().contains(query) ||
          stock.productCode.toLowerCase().contains(query) ||
          stock.kategori.toLowerCase().contains(query) ||
          stock.status.toLowerCase().contains(query)
        ).toList();
      }
      _currentPage = 1;
    });
  }

  List<ProductStock> get _paginatedStocks {
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredProductStocks.length) return [];
    if (endIndex > _filteredProductStocks.length) endIndex = _filteredProductStocks.length;
    return _filteredProductStocks.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_filteredProductStocks.length / _itemsPerPage).ceil();

  String get _paginationInfo {
    if (_filteredProductStocks.isEmpty) return 'Showing 0 to 0 of 0 entries';
    int startIndex = (_currentPage - 1) * _itemsPerPage + 1;
    int endIndex = _currentPage * _itemsPerPage;
    if (endIndex > _filteredProductStocks.length) endIndex = _filteredProductStocks.length;
    return 'Showing $startIndex to $endIndex of ${_filteredProductStocks.length} entries';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'stok habis': return Colors.red;
      case 'stok menipis': return Colors.orange;
      case 'stok normal': return Colors.green;
      default: return Colors.grey;
    }
  }

  void _showProductDetail(ProductStock product) {
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
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: 8), width: 40, height: 4,
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
                      Icon(Icons.inventory_2, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(product.productName,
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
                      _buildDetailRow('Nama Projek', product.productName),
                      _buildDetailRow('Kode Barang', product.productCode),
                      _buildDetailRow('Jumlah', '${product.stokTersedia} Unit'),
                      _buildDetailRow('Kategori', product.kategori),
                      _buildDetailRowWithStatus('Status', product.status),
                      _buildDetailRow('Last Update', _formatDate(product.lastUpdated)),
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

  Widget _buildDetailRowWithStatus(String label, String value) {
    Color statusColor = _getStatusColor(value);
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
          Expanded(
            flex: 3,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(value, style: TextStyle(color: statusColor, fontWeight: FontWeight.w500)),
            ),
          ),
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
              'Stok Projek',
              style: TextStyle(
                color: Colors.grey[900],
                fontSize: isMobile ? 18 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: _primaryRed, size: 24),
            onPressed: _loadProductStocks,
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
        Text('Cari Projek', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        SizedBox(height: 6),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'cari nama atau kode Projek..',
            hintStyle: TextStyle(fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _primaryRed)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: IconButton(
              icon: Icon(Icons.clear, size: 18),
              onPressed: () { _searchController.clear(); _filterProducts(); },
            ),
          ),
          onChanged: (value) => _filterProducts(),
        ),
        SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _filterProducts,
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
              Text('Cari Projek', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'cari nama atau kode projek..',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _primaryRed)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (value) => _filterProducts(),
              ),
            ],
          ),
        ),
        SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _filterProducts,
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
          // Controls — tanpa search sesuai permintaan
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
                      value: _itemsPerPage,
                      items: [10, 25, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text('$v', style: TextStyle(fontSize: 13)))).toList(),
                      onChanged: (value) { setState(() { _itemsPerPage = value!; _currentPage = 1; }); },
                    ),
                  ),
                ),
                Text(' Entries', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryRed))
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 56, color: Colors.red),
                            SizedBox(height: 12),
                            Text('Error: $_errorMessage', style: TextStyle(color: Colors.red, fontSize: 14), textAlign: TextAlign.center),
                            SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadProductStocks,
                              style: ElevatedButton.styleFrom(backgroundColor: _primaryRed, foregroundColor: Colors.white),
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _paginatedStocks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[400]),
                                SizedBox(height: 12),
                                Text('Tidak ada data projek', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
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
      children: _paginatedStocks.asMap().entries.map((entry) {
        int index = entry.key;
        ProductStock stock = entry.value;
        int displayIndex = (_currentPage - 1) * _itemsPerPage + index + 1;
        bool isEven = index % 2 == 0;

        return InkWell(
          onTap: () => _showProductDetail(stock),
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
                      Text(stock.productName,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[850])),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.qr_code, size: 13, color: Colors.grey[500]),
                          SizedBox(width: 4),
                          Text(stock.productCode, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          SizedBox(width: 12),
                          Icon(Icons.inventory_2, size: 13, color: _primaryRed),
                          SizedBox(width: 4),
                          Text('${stock.stokTersedia} Unit', style: TextStyle(fontSize: 12, color: _primaryRed, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: _lightRed, borderRadius: BorderRadius.circular(4)),
                            child: Text(stock.kategori, style: TextStyle(fontSize: 11, color: _primaryRed)),
                          ),
                          SizedBox(width: 6),
                          _buildStatusChip(stock.status),
                          Spacer(),
                          Icon(Icons.update, size: 12, color: Colors.grey[400]),
                          SizedBox(width: 3),
                          Text(_formatDate(stock.lastUpdated), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
              _headerCell('Nama Projek', flex: 3),
              _headerCell('Kode Barang', flex: 2),
              _headerCell('Jumlah', flex: 2),
              _headerCell('Kategori', flex: 2),
              _headerCell('Status', flex: 2),
              _headerCell('Last Update', flex: 2),
            ],
          ),
        ),
        ..._paginatedStocks.asMap().entries.map((entry) {
          int index = entry.key;
          ProductStock stock = entry.value;
          int globalIndex = (_currentPage - 1) * _itemsPerPage + index + 1;
          bool isEven = index % 2 == 0;

          return Container(
            width: double.infinity,
            color: isEven ? Colors.white : _lightRed,
            child: Row(
              children: [
                _dataCell('$globalIndex', flex: 1),
                _dataCell(stock.productName, flex: 3),
                _dataCell(stock.productCode, flex: 2),
                _dataCell('${stock.stokTersedia} Unit', flex: 2),
                _dataCell(stock.kategori, flex: 2),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
                    child: _buildStatusChip(stock.status),
                  ),
                ),
                _dataCell(_formatDate(stock.lastUpdated), flex: 2),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = _getStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: isMobile
          ? Column(
              children: [
                Text(_paginationInfo, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: _buildPageButtons()),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_paginationInfo, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                Row(children: _buildPageButtons()),
              ],
            ),
    );
  }

  List<Widget> _buildPageButtons() {
    return [
      ElevatedButton(
        onPressed: _currentPage > 1 ? () { setState(() { _currentPage--; }); } : null,
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
        child: Text('$_currentPage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      SizedBox(width: 8),
      ElevatedButton(
        onPressed: _currentPage < _totalPages ? () { setState(() { _currentPage++; }); } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[200], foregroundColor: Colors.grey[800],
          elevation: 0, padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text('Next', style: TextStyle(fontSize: 13)),
      ),
    ];
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _globalSearchController.dispose();
    super.dispose();
  }
}