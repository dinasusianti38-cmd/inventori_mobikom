import 'package:flutter/material.dart';
import '../service/admin_kategori_service.dart';

class AdminKategori extends StatefulWidget {
  @override
  _AdminKategoriState createState() => _AdminKategoriState();
}

class _AdminKategoriState extends State<AdminKategori> {
  final AdminKategoriService _service = AdminKategoriService();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  int _itemsPerPage = 10;
  String _searchQuery = '';

  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isActiveController = true;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // ─── Soft blue palette ───
  static const Color _headerBg    = Color(0xFF5B8DB8);
  static const Color _headerMid   = Color(0xFF4A7CA8);
  static const Color _blue600     = Color(0xFF3A6EA0);
  static const Color _blue400     = Color(0xFF5B8DB8);
  static const Color _blue100     = Color(0xFFD6E6F5);
  static const Color _blue50      = Color(0xFFEDF4FB);
  static const Color _pageBg      = Color(0xFFF4F7FB);
  static const Color _textPrimary = Color(0xFF2D3748);
  static const Color _textMuted   = Color(0xFF718096);

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ─── Data methods ──────────────────────────────────────────────────────────

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final response = await _service.getCategories(
        page: _currentPage,
        limit: _itemsPerPage,
        search: _searchQuery,
      );
      if (response['status'] == 'success') {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response['data']);
          _totalPages = response['total_pages'] ?? 1;
          _totalRecords = response['total_records'] ?? 0;
          _isLoading = false;
        });
      } else {
        _showSnackBar(response['message'] ?? 'Error loading categories', false);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar('Error: $e', false);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCategory() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final response = await _service.addCategory(
        nama: _namaController.text.trim(),
        description: _deskripsiController.text.trim(),
        isActive: _isActiveController,
      );
      if (response['status'] == 'success') {
        _showSnackBar('Kategori berhasil ditambahkan', true);
        _clearForm();
        _loadCategories();
      } else {
        _showSnackBar(response['message'] ?? 'Error adding category', false);
      }
    } catch (e) {
      _showSnackBar('Error: $e', false);
    }
  }

  Future<void> _updateCategory(int id) async {
    if (_namaController.text.trim().isEmpty) {
      _showSnackBar('Nama kategori tidak boleh kosong', false);
      return;
    }
    try {
      final response = await _service.updateCategory(
        id: id,
        nama: _namaController.text.trim(),
        description: _deskripsiController.text.trim(),
        isActive: _isActiveController,
      );
      if (response['status'] == 'success') {
        _showSnackBar('Kategori berhasil diupdate', true);
        _clearForm();
        _loadCategories();
      } else {
        _showSnackBar(response['message'] ?? 'Error updating category', false);
      }
    } catch (e) {
      _showSnackBar('Error: $e', false);
    }
  }

  Future<void> _deleteCategory(int id) async {
    final confirmed = await _showConfirmDialog(
        'Apakah Anda yakin ingin menghapus kategori ini?');
    if (!confirmed) return;
    try {
      final response = await _service.deleteCategory(id);
      if (response['status'] == 'success') {
        _showSnackBar('Kategori berhasil dihapus', true);
        _loadCategories();
      } else {
        _showSnackBar(response['message'] ?? 'Error deleting category', false);
      }
    } catch (e) {
      _showSnackBar('Error: $e', false);
    }
  }

  void _clearForm() {
    _namaController.clear();
    _deskripsiController.clear();
    _isActiveController = true;
    _formKey.currentState?.reset();
  }

  void _showSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor:
            isSuccess ? const Color(0xFF38A169) : const Color(0xFFE53E3E),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String message) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 22),
                const SizedBox(width: 8),
                const Text('Konfirmasi',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(message,
                style: const TextStyle(
                    fontSize: 14, color: _textMuted)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal',
                    style: TextStyle(color: _textMuted)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53E3E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Ya, Hapus'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showEditDialog(Map<String, dynamic> category) {
    _namaController.text = category['nama_c'] ?? '';
    _deskripsiController.text = category['description'] ?? '';
    _isActiveController = (category['is_active'] == 1);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 40,
            vertical: isMobile ? 24 : 40,
          ),
          child: Container(
            width: isMobile ? double.infinity : 500,
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dialog header bar
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _blue50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _blue100),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: _blue600, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Text('Edit Kategori',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _dialogField('Nama Kategori *', _namaController,
                          'Nama Kategori'),
                      const SizedBox(height: 14),
                      _dialogField(
                          'Deskripsi', _deskripsiController, 'Deskripsi',
                          maxLines: 3),
                      const SizedBox(height: 14),

                      const Text('Status',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary)),
                      const SizedBox(height: 8),
                      _buildStatusSelector(
                        _isActiveController,
                        (val) => setDialogState(
                            () => _isActiveController = val),
                      ),
                      const SizedBox(height: 22),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _clearForm();
                            },
                            child: const Text('Batal',
                                style: TextStyle(color: _textMuted)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _updateCategory(category['id_c']);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Update'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 600;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SingleChildScrollView(
        // ← Kunci utama: seluruh halaman bisa di-scroll
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isMobile),
            SizedBox(height: isMobile ? 12 : 20),
            _buildFormCard(isMobile),
            SizedBox(height: isMobile ? 12 : 18),
            _buildTableCard(isMobile),
            SizedBox(height: isMobile ? 24 : 32), // padding bawah agar tidak terpotong
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 16 : 20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_headerMid, _headerBg],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _headerBg.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -24, right: -24,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -18, left: -16,
            child: Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: isMobile ? 42 : 50,
                height: isMobile ? 42 : 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.25), width: 1),
                ),
                child: Icon(Icons.category_rounded,
                    color: Colors.white, size: isMobile ? 20 : 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manajemen Kategori',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Kelola kategori dengan mudah dan efisien',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
                        color: Colors.white.withOpacity(0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.22), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF9AE6B4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '$_totalRecords Kategori',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Form Card ────────────────────────────────────────────────────────────

  Widget _buildFormCard(bool isMobile) {
    return _card(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section label
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _blue50,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _blue100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_circle_outline_rounded,
                      size: 17, color: _blue600),
                  const SizedBox(width: 7),
                  const Text(
                    'Tambah kategori baru',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _blue600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── MOBILE: susun field secara vertikal ──
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldGroup(
                    label: 'Nama Kategori',
                    child: TextFormField(
                      controller: _namaController,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Nama kategori tidak boleh kosong'
                              : null,
                      decoration: _inputDeco('Nama Kategori'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _fieldGroup(
                    label: 'Deskripsi',
                    child: TextFormField(
                      controller: _deskripsiController,
                      decoration: _inputDeco('Deskripsi'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _fieldGroup(
                    label: 'Status',
                    child: StatefulBuilder(
                      builder: (_, set) => _buildStatusSelector(
                        _isActiveController,
                        (val) => set(
                            () => setState(() => _isActiveController = val)),
                      ),
                    ),
                  ),
                ],
              )
            // ── DESKTOP: susun field secara horizontal ──
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _fieldGroup(
                      label: 'Nama Kategori',
                      child: TextFormField(
                        controller: _namaController,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Nama kategori tidak boleh kosong'
                                : null,
                        decoration: _inputDeco('Nama Kategori'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
                    child: _fieldGroup(
                      label: 'Deskripsi',
                      child: TextFormField(
                        controller: _deskripsiController,
                        decoration: _inputDeco('Deskripsi'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: _fieldGroup(
                      label: 'Status',
                      child: StatefulBuilder(
                        builder: (_, set) => _buildStatusSelector(
                          _isActiveController,
                          (val) => set(
                              () => setState(() => _isActiveController = val)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Tombol simpan — full width di mobile
            SizedBox(
              width: isMobile ? double.infinity : null,
              child: Align(
                alignment: isMobile
                    ? Alignment.center
                    : Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _addCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: isMobile
                        ? const Size(double.infinity, 44)
                        : const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Simpan',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Table Card ───────────────────────────────────────────────────────────

  Widget _buildTableCard(bool isMobile) {
    return _card(
      child: Column(
        children: [
          // Controls row — stack secara vertikal di mobile
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show entries
                Row(
                  children: [
                    const Text('Show',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: _blue100, width: 1.5),
                        borderRadius: BorderRadius.circular(7),
                        color: Colors.white,
                      ),
                      child: DropdownButton<int>(
                        value: _itemsPerPage,
                        underline: const SizedBox(),
                        isDense: true,
                        style: const TextStyle(
                            fontSize: 13, color: _textPrimary),
                        items: [5, 10, 25, 50].map((v) {
                          return DropdownMenuItem<int>(
                              value: v, child: Text(v.toString()));
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            _itemsPerPage = v!;
                            _currentPage = 1;
                          });
                          _loadCategories();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Entries',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary)),
                  ],
                ),
                const SizedBox(height: 10),
                // Search
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search :',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: Color(0xFFADB5BD)),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: Color(0xFFADB5BD)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: _blue100, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: _blue100, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: _blue400, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (v) {
                    setState(() {
                      _searchQuery = v;
                      _currentPage = 1;
                    });
                    _loadCategories();
                  },
                ),
              ],
            )
          else
            // Desktop: controls row horizontal
            Row(
              children: [
                const Text('Show',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: _blue100, width: 1.5),
                    borderRadius: BorderRadius.circular(7),
                    color: Colors.white,
                  ),
                  child: DropdownButton<int>(
                    value: _itemsPerPage,
                    underline: const SizedBox(),
                    isDense: true,
                    style: const TextStyle(
                        fontSize: 13, color: _textPrimary),
                    items: [5, 10, 25, 50].map((v) {
                      return DropdownMenuItem<int>(
                          value: v, child: Text(v.toString()));
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        _itemsPerPage = v!;
                        _currentPage = 1;
                      });
                      _loadCategories();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Entries',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
                const Spacer(),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search :',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFFADB5BD)),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: Color(0xFFADB5BD)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: _blue100, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: _blue100, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: _blue400, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (v) {
                      setState(() {
                        _searchQuery = v;
                        _currentPage = 1;
                      });
                      _loadCategories();
                    },
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // ── Konten tabel / list ──
          if (_isLoading)
            const SizedBox(
              height: 260,
              child: Center(
                child: CircularProgressIndicator(color: _blue400),
              ),
            )
          else if (_categories.isEmpty)
            SizedBox(
              height: 260,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_rounded,
                        size: 44, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('Tidak ada data kategori',
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 14)),
                  ],
                ),
              ),
            )
          // ── MOBILE: tampilkan sebagai card list ──
          else if (isMobile)
            _buildMobileCategoryList()
          // ── DESKTOP: tampilkan sebagai tabel dengan scroll horizontal ──
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 96,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _blue100),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Table(
                      // Lebar kolom tetap agar tidak terpotong
                      columnWidths: const {
                        0: FixedColumnWidth(50),
                        1: FixedColumnWidth(180),
                        2: FixedColumnWidth(240),
                        3: FixedColumnWidth(110),
                        4: FixedColumnWidth(160),
                        5: FixedColumnWidth(120),
                      },
                      border: TableBorder(
                        horizontalInside: BorderSide(
                            color: const Color(0xFFEDF2F7), width: 1),
                      ),
                      children: [
                        TableRow(
                          decoration:
                              const BoxDecoration(color: Color(0xFFF0F6FD)),
                          children: [
                            'No',
                            'Nama Kategori',
                            'Deskripsi',
                            'Status',
                            'Tanggal dibuat',
                            'Aksi',
                          ].map(_headerCell).toList(),
                        ),
                        ..._categories.asMap().entries.map((e) {
                          final i = e.key;
                          final cat = e.value;
                          return TableRow(
                            decoration: BoxDecoration(
                              color: i % 2 == 0
                                  ? Colors.white
                                  : const Color(0xFFFAFCFF),
                            ),
                            children: [
                              _dataCell(
                                '${(_currentPage - 1) * _itemsPerPage + i + 1}',
                                center: true,
                              ),
                              _dataCell(cat['nama_c'] ?? ''),
                              _dataCell(cat['description'] ?? '..'),
                              _statusCell(cat['is_active'] == 1),
                              _dataCell(cat['created_at'] ?? '..',
                                  center: true),
                              _actionCell(cat),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Pagination ──
          if (!_isLoading && _categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (isMobile)
              // Mobile: pagination susun vertikal
              Column(
                children: [
                  Text(
                    'Showing ${(_currentPage - 1) * _itemsPerPage + 1} '
                    'to ${(_currentPage - 1) * _itemsPerPage + _categories.length} '
                    'of $_totalRecords entries',
                    style: const TextStyle(fontSize: 12, color: _textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _pgBtn('Previous',
                          enabled: _currentPage > 1,
                          onPressed: () {
                            setState(() => _currentPage--);
                            _loadCategories();
                          }),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _blue600,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text('$_currentPage',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      _pgBtn('Next',
                          enabled: _currentPage < _totalPages,
                          onPressed: () {
                            setState(() => _currentPage++);
                            _loadCategories();
                          }),
                    ],
                  ),
                ],
              )
            else
              // Desktop: pagination row
              Row(
                children: [
                  Text(
                    'Showing ${(_currentPage - 1) * _itemsPerPage + 1} '
                    'to ${(_currentPage - 1) * _itemsPerPage + _categories.length} '
                    'of $_totalRecords entries',
                    style: const TextStyle(
                        fontSize: 13, color: _textMuted),
                  ),
                  const Spacer(),
                  _pgBtn('Previous',
                      enabled: _currentPage > 1,
                      onPressed: () {
                        setState(() => _currentPage--);
                        _loadCategories();
                      }),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _blue600,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text('$_currentPage',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  const SizedBox(width: 6),
                  _pgBtn('Next',
                      enabled: _currentPage < _totalPages,
                      onPressed: () {
                        setState(() => _currentPage++);
                        _loadCategories();
                      }),
                ],
              ),
          ],
        ],
      ),
    );
  }

  // ─── Mobile category list ─────────────────────────────────────────────────

  Widget _buildMobileCategoryList() {
    return ListView.builder(
      // shrinkWrap + NeverScrollableScrollPhysics agar scroll
      // ditangani oleh SingleChildScrollView di atas (tidak nested scroll)
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final cat = _categories[index];
        final no = (_currentPage - 1) * _itemsPerPage + index + 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _blue100),
            boxShadow: [
              BoxShadow(
                color: _blue400.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card header dengan nomor & status
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _blue50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border(
                      bottom: BorderSide(color: _blue100)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _blue600,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '#$no',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    _statusBadge(cat['is_active'] == 1),
                  ],
                ),
              ),

              // Card body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama kategori
                    Text(
                      cat['nama_c'] ?? '-',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Deskripsi
                    Text(
                      cat['description'] ?? '-',
                      style: const TextStyle(
                        fontSize: 13,
                        color: _textMuted,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),

                    // Tanggal dibuat
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 13, color: _textMuted),
                        const SizedBox(width: 5),
                        Text(
                          cat['created_at'] ?? '-',
                          style: const TextStyle(
                              fontSize: 12, color: _textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Tombol aksi — full width di mobile
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showEditDialog(cat),
                            icon: const Icon(Icons.edit_rounded, size: 15),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _blue600,
                              side: const BorderSide(color: _blue100),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _deleteCategory(cat['id_c']),
                            icon: const Icon(Icons.delete_rounded, size: 15),
                            label: const Text('Hapus'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53E3E),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Shared widget helpers ────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _blue100.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B8DB8).withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      );

  Widget _fieldGroup({required String label, required Widget child}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary)),
          const SizedBox(height: 6),
          child,
        ],
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFADB5BD), fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue100, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue100, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue400, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: Color(0xFFFC8181), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        filled: true,
        fillColor: const Color(0xFFFAFCFF),
        isDense: true,
      );

  Widget _dialogField(
      String label, TextEditingController ctrl, String hint,
      {int maxLines = 1}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary)),
          const SizedBox(height: 6),
          TextFormField(
              controller: ctrl,
              maxLines: maxLines,
              decoration: _inputDeco(hint)),
        ],
      );

  Widget _buildStatusSelector(
    bool isActive,
    ValueChanged<bool> onChanged,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return Column(
        children: [
          GestureDetector(
            onTap: () => onChanged(true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive ? Colors.green : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isActive
                    ? const Color(0xFFF0FFF4)
                    : Colors.white,
              ),
              child: Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: isActive,
                    onChanged: (v) => onChanged(v!),
                  ),
                  const Text("Aktif"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => onChanged(false),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: !isActive ? Colors.red : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(8),
                color: !isActive
                    ? const Color(0xFFFFF5F5)
                    : Colors.white,
              ),
              child: Row(
                children: [
                  Radio<bool>(
                    value: false,
                    groupValue: isActive,
                    onChanged: (v) => onChanged(v!),
                  ),
                  const Text("Tidak Aktif"),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Desktop
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive ? Colors.green : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isActive
                    ? const Color(0xFFF0FFF4)
                    : Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: isActive,
                    onChanged: (v) => onChanged(v!),
                  ),
                  const Text("Aktif"),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(
                  color: !isActive ? Colors.red : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(8),
                color: !isActive
                    ? const Color(0xFFFFF5F5)
                    : Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<bool>(
                    value: false,
                    groupValue: isActive,
                    onChanged: (v) => onChanged(v!),
                  ),
                  const Text("Tidak Aktif"),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Status badge khusus mobile card ──
  Widget _statusBadge(bool isActive) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFC6F6D5)
              : const Color(0xFFFED7D7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? const Color(0xFF276749)
                    : const Color(0xFF9B2C2C),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              isActive ? 'Aktif' : 'Tidak Aktif',
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF276749)
                    : const Color(0xFF9B2C2C),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );

  Widget _headerCell(String text) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF4A5568))),
      );

  Widget _dataCell(String text, {bool center = false}) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        alignment:
            center ? Alignment.center : Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, color: _textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      );

  Widget _statusCell(bool isActive) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        alignment: Alignment.center,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFC6F6D5)
                : const Color(0xFFFED7D7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isActive ? 'aktif' : 'tidak aktif',
            style: TextStyle(
              color: isActive
                  ? const Color(0xFF276749)
                  : const Color(0xFF9B2C2C),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      );

  Widget _actionCell(Map<String, dynamic> category) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _showEditDialog(category),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _blue50,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _blue100),
                ),
                child: const Text('Edit',
                    style: TextStyle(
                        color: _blue600,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _deleteCategory(category['id_c']),
              borderRadius: BorderRadius.circular(5),
              child: const Icon(Icons.delete_rounded,
                  color: Color(0xFFFC8181), size: 20),
            ),
          ],
        ),
      );

  Widget _pgBtn(String text,
      {required bool enabled, required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: enabled
                  ? const Color(0xFFCBD5E0)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(text,
              style: TextStyle(
                color: enabled
                    ? _textPrimary
                    : const Color(0xFFCBD5E0),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              )),
        ),
      ),
    );
  }
}