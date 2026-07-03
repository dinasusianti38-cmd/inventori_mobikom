import 'package:flutter/material.dart';
import '../service/admin_stok_produk_service.dart';
import '../models/produk_stok_models.dart';
import '../service/admin_product_export_service.dart';

class AdminStokProduk extends StatefulWidget {
  @override
  _AdminStokProdukState createState() => _AdminStokProdukState();
}

class _AdminStokProdukState extends State<AdminStokProduk> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ProdukStok> _stokProdukList = [];
  List<ProdukStok> _filteredStokProdukList = [];

  bool _isLoading = false;
  String _selectedStatusFilter = '';
  int _currentPage = 1;
  int _itemsPerPage = 10;
  int _totalItems = 0;

  // Breakpoint: ≥ 600px → desktop table, < 600px → mobile cards
  static const double _kMobileBreak = 600;

  @override
  void initState() {
    super.initState();
    _loadStokProduk();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStokProduk() async {
    setState(() => _isLoading = true);
    try {
      final response = await AdminStokProdukService.getStokProduk(
        search: _searchController.text,
        status: _selectedStatusFilter,
        limit: _itemsPerPage,
        offset: (_currentPage - 1) * _itemsPerPage,
      );
      setState(() {
        _stokProdukList = response.data;
        _filteredStokProdukList = response.data;
        _totalItems = response.total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Error loading data: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'stok habis':   return const Color(0xFFF44336);
      case 'stok menipis': return const Color(0xFFFF9800);
      case 'stok normal':  return const Color(0xFF4CAF50);
      default:             return Colors.grey;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(ProdukStok stok) {
    final stokMinimalController  = TextEditingController(text: stok.stokMinimal.toString());
    final stokTersediaController = TextEditingController(text: stok.stokTersedia.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Projek'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Projek: ${stok.nameP}'),
              const SizedBox(height: 16),
              TextField(
                controller: stokMinimalController,
                decoration: const InputDecoration(
                  labelText: 'Stok Minimal',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stokTersediaController,
                decoration: const InputDecoration(
                  labelText: 'Stok Tersedia',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await AdminStokProdukService.updateStokProduk(
                  idSp: stok.idSp,
                  stokMinimal:  int.parse(stokMinimalController.text),
                  stokTersedia: int.parse(stokTersediaController.text),
                );
                Navigator.of(context).pop();
                _loadStokProduk();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data berhasil diupdate')),
                );
              } catch (e) {
                _showErrorDialog('Error updating data: $e');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(ProdukStok stok) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Apakah Anda yakin ingin menghapus Stok Projek "${stok.nameP}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              try {
                final result = await AdminStokProdukService.deleteStokProduk(stok.idSp);
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                _loadStokProduk();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Data berhasil dihapus'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                _showErrorDialog('Gagal menghapus data: ${e.toString()}');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<BoxShadow> _card3DShadow({
    Color base = const Color(0xFF78B2F5),
    double depth = 5,
    double blur = 12,
  }) {
    return [
      BoxShadow(
        color: Colors.white.withOpacity(0.75),
        offset: const Offset(-1.5, -1.5),
        blurRadius: 4,
      ),
      BoxShadow(
        color: base.withOpacity(0.35),
        offset: Offset(depth, depth),
        blurRadius: blur,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.10),
        offset: const Offset(2, 4),
        blurRadius: blur * 1.5,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= _kMobileBreak;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF0F5FF), Color(0xFFE8F0FB), Color(0xFFF5F8FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isDesktop ? 20 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HEADER ──────────────────────────────────────────────
                _buildHeader(isDesktop),
                SizedBox(height: isDesktop ? 16 : 12),

                // ── FILTER ──────────────────────────────────────────────
                _buildFilter(isDesktop),
                SizedBox(height: isDesktop ? 16 : 12),

                // ── TABLE / CARD SECTION ─────────────────────────────────
                _buildTableCard(isDesktop),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 14,
        vertical: isDesktop ? 16 : 12,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF90C8F8), Color(0xFF7ABAFF), Color(0xFF6AABF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _card3DShadow(base: const Color(0xFF6AADF5), depth: 6, blur: 18),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.2),
      ),
      child: Row(
        children: [
          // Icon box
          Container(
            width: isDesktop ? 50 : 42,
            height: isDesktop ? 50 : 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFE3F2FD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), offset: const Offset(2, 2), blurRadius: 5),
                BoxShadow(color: Colors.white.withOpacity(0.8), offset: const Offset(-1, -1), blurRadius: 3),
              ],
            ),
            child: Icon(Icons.home_work_outlined, color: const Color(0xFF78B2F5), size: isDesktop ? 26 : 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stok Projek',
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 3)],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kelola dan pantau stok projek yang tersedia',
                  style: TextStyle(fontSize: isDesktop ? 13 : 11, color: Colors.white.withOpacity(0.85)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _build3DButton(
            label: isDesktop ? 'Export PDF' : 'PDF',
            icon: Icons.picture_as_pdf,
            baseColor: const Color(0xFFE53935),
            onTap: () async {
              await AdminProductExportService.exportToPdf(
                search: _searchController.text,
                status: _selectedStatusFilter,
                context: context,
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILTER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFilter(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 14,
        vertical: isDesktop ? 16 : 12,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF7FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: _card3DShadow(depth: 4, blur: 14),
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
      ),
      child: isDesktop
          // Desktop: search & filter berdampingan dalam satu baris
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cari Projek',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF78B2F5))),
                      const SizedBox(height: 6),
                      _build3DInputDecoration(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'cari nama atau kode projek...',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                            prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            if (value.length > 2 || value.isEmpty) {
                              _currentPage = 1;
                              _loadStokProduk();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF78B2F5))),
                      const SizedBox(height: 6),
                      _build3DInputDecoration(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatusFilter.isEmpty ? null : _selectedStatusFilter,
                            hint: Text('semua status', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                            isExpanded: true,
                            isDense: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            items: const [
                              DropdownMenuItem(value: '',             child: Text('semua status',  style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'stok normal',  child: Text('Stok Normal',   style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'stok menipis', child: Text('Stok Menipis',  style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'stok habis',   child: Text('Stok Habis',    style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedStatusFilter = value ?? '');
                              _currentPage = 1;
                              _loadStokProduk();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          // Mobile: search & filter ditumpuk vertikal
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cari Projek',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF78B2F5))),
                const SizedBox(height: 6),
                _build3DInputDecoration(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'cari nama atau kode projek...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      if (value.length > 2 || value.isEmpty) {
                        _currentPage = 1;
                        _loadStokProduk();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Status',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF78B2F5))),
                const SizedBox(height: 6),
                _build3DInputDecoration(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatusFilter.isEmpty ? null : _selectedStatusFilter,
                      hint: Text('semua status', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      isExpanded: true,
                      isDense: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      items: const [
                        DropdownMenuItem(value: '',             child: Text('semua status',  style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'stok normal',  child: Text('Stok Normal',   style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'stok menipis', child: Text('Stok Menipis',  style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'stok habis',   child: Text('Stok Habis',    style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedStatusFilter = value ?? '');
                        _currentPage = 1;
                        _loadStokProduk();
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TABLE / CARD CONTAINER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTableCard(bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF8FBFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: _card3DShadow(depth: 5, blur: 16),
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Entries selector ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Text('Tampilkan ', style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
                _buildEntriesDropdown(),
                const Text(' Entries', style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFE8EFFE)),
          Container(height: 1, color: Colors.white),

          // ── Content ──
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF78B2F5))),
            )
          else if (_filteredStokProdukList.isEmpty)
            _buildEmptyState()
          else
            isDesktop ? _buildDesktopTable() : _buildMobileCards(),

          Container(height: 1, color: const Color(0xFFE8EFFE)),
          Container(height: 1, color: Colors.white),

          // ── Pagination ──
          _buildPagination(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DESKTOP TABLE — kolom menyesuaikan lebar layar (flex-based)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          // Header
          _buildDesktopHeaderRow(),
          // Data rows
          ..._filteredStokProdukList.asMap().entries.map((entry) {
            final int index       = entry.key;
            final ProdukStok stok = entry.value;
            final bool isEven     = index % 2 == 0;
            final int dispIdx     = (_currentPage - 1) * _itemsPerPage + index + 1;
            return _buildDesktopDataRow(stok, dispIdx, isEven);
          }),
        ],
      ),
    );
  }

  Widget _buildDesktopHeaderRow() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF90C8F8), Color(0xFF78B6F8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _desktopHeaderCell('No',          flex: 1),
          _desktopHeaderCell('Nama Projek', flex: 4, align: TextAlign.left),
          _desktopHeaderCell('Kode',        flex: 2),
          _desktopHeaderCell('Jumlah',      flex: 2),
          _desktopHeaderCell('Status',      flex: 3, align: TextAlign.left),
          _desktopHeaderCell('Update',      flex: 3),
          _desktopHeaderCell('Aksi',        flex: 1),
        ],
      ),
    );
  }

  Widget _desktopHeaderCell(String text, {int flex = 1, TextAlign align = TextAlign.center}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        alignment: align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2)],
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Widget _buildDesktopDataRow(ProdukStok stok, int displayIndex, bool isEven) {
    final String satuan = stok.nameP.toLowerCase().contains('meter') ? 'meter' : 'pcs';
    final String tanggal = stok.lastUpdated.length > 10
        ? stok.lastUpdated.substring(0, 10)
        : stok.lastUpdated;

    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF7FAFF),
        border: const Border(bottom: BorderSide(color: Color(0xFFEEF3FC), width: 1)),
      ),
      child: Row(
        children: [
          _desktopDataCell(displayIndex.toString(), flex: 1, align: TextAlign.center),
          _desktopDataCell(stok.nameP,               flex: 4, align: TextAlign.left, multiline: true),
          _desktopDataCell(stok.codeP,               flex: 2, align: TextAlign.center),
          _desktopDataCell('${stok.stokTersedia} $satuan', flex: 2, align: TextAlign.center),
          // Status cell
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: _buildStatusBadge(stok.status),
            ),
          ),
          _desktopDataCell(tanggal, flex: 3, align: TextAlign.center),
          // Action cell
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Center(child: _buildDeleteButton(stok)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopDataCell(String text, {int flex = 1, TextAlign align = TextAlign.left, bool multiline = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        alignment: align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF37474F)),
          maxLines: multiline ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE CARDS — setiap baris jadi card ringkas
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: _filteredStokProdukList.asMap().entries.map((entry) {
          final int index       = entry.key;
          final ProdukStok stok = entry.value;
          final int dispIdx     = (_currentPage - 1) * _itemsPerPage + index + 1;
          final String satuan   = stok.nameP.toLowerCase().contains('meter') ? 'meter' : 'pcs';
          final String tanggal  = stok.lastUpdated.length > 10
              ? stok.lastUpdated.substring(0, 10)
              : stok.lastUpdated;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFF5F9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCEBFA), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF78B2F5).withOpacity(0.12),
                  offset: const Offset(2, 3),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  offset: const Offset(-1, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: No + Nama + Delete button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nomor
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF90C8F8), Color(0xFF78B2F5)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$dispIdx',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Nama projek
                      Expanded(
                        child: Text(
                          stok.nameP,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C3E50),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildDeleteButton(stok),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Row 2: info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildInfoChip(Icons.qr_code_2_outlined, stok.codeP),
                      _buildInfoChip(Icons.inventory_2_outlined, '${stok.stokTersedia} $satuan'),
                      _buildInfoChip(Icons.calendar_today_outlined, tanggal),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Row 3: status badge
                  _buildStatusBadge(stok.status),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD0E4F8), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF78B2F5)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF546E7A), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStatusBadge(String status) {
    final Color dotColor = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [dotColor.withOpacity(0.10), dotColor.withOpacity(0.20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dotColor.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: dotColor.withOpacity(0.2), offset: const Offset(1, 2), blurRadius: 3),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: dotColor.withOpacity(0.5), blurRadius: 3)],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(color: dotColor, fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(ProdukStok stok) {
    return GestureDetector(
      onTap: () => _showDeleteConfirmation(stok),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFEF9A9A), width: 1),
          boxShadow: [
            BoxShadow(color: const Color(0xFFF44336).withOpacity(0.25), offset: const Offset(2, 2), blurRadius: 4),
            BoxShadow(color: Colors.white.withOpacity(0.8), offset: const Offset(-1, -1), blurRadius: 2),
          ],
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFF44336), size: 16),
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text('Tidak ada data', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ── Entries Dropdown ─────────────────────────────────────────────────────
  Widget _buildEntriesDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF3F7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFCDD8F5)),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: const Color(0xFF78B2F5).withOpacity(0.12), offset: const Offset(2, 2), blurRadius: 4),
          const BoxShadow(color: Colors.white, offset: Offset(-1, -1), blurRadius: 3),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _itemsPerPage,
          isDense: true,
          items: [5, 10, 25, 50]
              .map((v) => DropdownMenuItem<int>(
                    value: v,
                    child: Text(v.toString(), style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _itemsPerPage = value!;
              _currentPage = 1;
            });
            _loadStokProduk();
          },
        ),
      ),
    );
  }

  // ── Pagination ───────────────────────────────────────────────────────────
  Widget _buildPagination() {
    final int startEntry = _filteredStokProdukList.isEmpty
        ? 0
        : (_currentPage - 1) * _itemsPerPage + 1;
    final int endEntry = startEntry + _filteredStokProdukList.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _filteredStokProdukList.isEmpty
                ? 'Tidak ada data'
                : 'Showing $startEntry – $endEntry of $_totalItems entries',
            style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPaginationButton(
                'Previous',
                enabled: _currentPage > 1,
                onPressed: () {
                  setState(() => _currentPage--);
                  _loadStokProduk();
                  _scrollController.animateTo(0,
                      duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                },
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8EC8FA), Color(0xFF78B2F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF78B2F5).withOpacity(0.4),
                      offset: const Offset(2, 3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  _currentPage.toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              _buildPaginationButton(
                'Next',
                enabled: _currentPage * _itemsPerPage < _totalItems,
                onPressed: () {
                  setState(() => _currentPage++);
                  _loadStokProduk();
                  _scrollController.animateTo(0,
                      duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITY WIDGETS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _build3DButton({
    required String label,
    required IconData icon,
    required Color baseColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              HSLColor.fromColor(baseColor)
                  .withLightness((HSLColor.fromColor(baseColor).lightness + 0.1).clamp(0.0, 1.0))
                  .toColor(),
              baseColor,
              HSLColor.fromColor(baseColor)
                  .withLightness((HSLColor.fromColor(baseColor).lightness - 0.08).clamp(0.0, 1.0))
                  .toColor(),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: baseColor.withOpacity(0.5), offset: const Offset(3, 4), blurRadius: 8),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _build3DInputDecoration({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFC2D0E8).withOpacity(0.6),
              offset: const Offset(2, 2),
              blurRadius: 4),
          BoxShadow(color: Colors.white.withOpacity(0.9), offset: const Offset(-2, -2), blurRadius: 4),
        ],
        border: Border.all(color: const Color(0xFFD8E5F5), width: 1),
      ),
      child: child,
    );
  }

  Widget _buildPaginationButton(
    String text, {
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(colors: [Colors.white, Color(0xFFF0F5FF)])
              : const LinearGradient(colors: [Color(0xFFF5F5F5), Color(0xFFEEEEEE)]),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: enabled ? const Color(0xFFCDD8F5) : const Color(0xFFE0E0E0)),
          boxShadow: enabled
              ? [
                  BoxShadow(
                      color: const Color(0xFF78B2F5).withOpacity(0.15),
                      offset: const Offset(2, 2),
                      blurRadius: 4),
                  const BoxShadow(color: Colors.white, offset: Offset(-1, -1), blurRadius: 2),
                ]
              : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: enabled ? const Color(0xFF78B2F5) : const Color(0xFF9E9E9E),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}