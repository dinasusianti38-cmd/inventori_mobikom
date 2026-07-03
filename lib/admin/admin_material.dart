import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/material_models.dart' as MaterialModel;
import '../service/admin_material_service.dart';

class AdminMaterial extends StatefulWidget {
  @override
  _AdminMaterialState createState() => _AdminMaterialState();
}

class _AdminMaterialState extends State<AdminMaterial> {
  List<MaterialModel.Material> materials = [];
  List<MaterialModel.Category> categories = [];
  bool isLoading = true;
  bool isSaving = false;

  static const _timeout = Duration(seconds: 15);

  final _formKey = GlobalKey<FormState>();
  final _namaMaterialController = TextEditingController();
  final _kodeMaterialController = TextEditingController();
  final _satuanController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _selectedCategoryId;

  bool isEditMode = false;
  int? editingMaterialId;

  int _currentPage = 0;
  int _rowsPerPage = 10;
  final List<int> _rowsPerPageOptions = [5, 10, 25, 50];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _namaMaterialController.dispose();
    _kodeMaterialController.dispose();
    _satuanController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _friendlyError(Object e) {
    if (e is TimeoutException) {
      return 'Koneksi ke server terlalu lama (timeout). '
          'Periksa internet Anda lalu coba lagi.';
    }
    return '$e';
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final materialsData =
          await MaterialService.getAllMaterials().timeout(_timeout);
      final categoriesData =
          await MaterialService.getAllCategories().timeout(_timeout);

      if (!mounted) return;
      setState(() {
        materials = materialsData;
        categories = categoriesData;
        isLoading = false;
        _currentPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showErrorDialog('Gagal memuat data: ${_friendlyError(e)}');
    }
  }

  void _clearForm() {
    _namaMaterialController.clear();
    _kodeMaterialController.clear();
    _satuanController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCategoryId = null;
      isEditMode = false;
      editingMaterialId = null;
    });
  }

  void _fillFormForEdit(MaterialModel.Material material) {
    final categoryStillExists =
        categories.any((c) => c.idC == material.categoryId);

    setState(() {
      _namaMaterialController.text = material.namaM;
      _kodeMaterialController.text = material.codeM;
      _satuanController.text = material.satuan;
      _descriptionController.text = material.description ?? '';
      _selectedCategoryId = categoryStillExists ? material.categoryId : null;
      isEditMode = true;
      editingMaterialId = material.idM;
    });

    if (!categoryStillExists) {
      _showErrorDialog(
        'Kategori untuk barang ini sudah tidak tersedia (mungkin sudah dihapus). '
        'Silakan pilih kategori baru sebelum menyimpan.',
      );
    }
  }

  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showErrorDialog('Pilih kategori terlebih dahulu');
      return;
    }

    setState(() => isSaving = true);

    try {
      final material = MaterialModel.Material(
        idM: editingMaterialId,
        codeM: _kodeMaterialController.text.trim(),
        namaM: _namaMaterialController.text.trim(),
        satuan: _satuanController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: _selectedCategoryId!,
      );

      Map<String, dynamic> result;
      if (isEditMode) {
        result =
            await MaterialService.updateMaterial(material).timeout(_timeout);
      } else {
        result =
            await MaterialService.addMaterial(material).timeout(_timeout);
      }

      if (!mounted) return;

      if (result['status'] == 'success') {
        _clearForm();
        await _loadData();
        if (mounted) {
          _showSuccessDialog(
            result['message'] ??
                (isEditMode
                    ? 'Material berhasil diperbarui'
                    : 'Material berhasil ditambahkan'),
          );
        }
      } else {
        if (mounted) _showErrorDialog(result['message'] ?? 'Operasi gagal');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error menyimpan material: ${_friendlyError(e)}');
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _deleteMaterial(int id, String materialName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus Barang', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus "$materialName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: Icon(Icons.delete_forever, size: 18),
            label: Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isSaving = true);

    try {
      final result =
          await MaterialService.deleteMaterial(id).timeout(_timeout);

      if (!mounted) return;

      if (result['status'] == 'success') {
        String successMessage =
            result['message'] ?? 'Material berhasil dihapus';

        if (result['deleted_data'] != null) {
          final deletedData = result['deleted_data'];
          final transactionsDeleted = deletedData['transactions_deleted'] ?? 0;
          final stocksDeleted = deletedData['stocks_deleted'] ?? 0;

          if (transactionsDeleted > 0 || stocksDeleted > 0) {
            successMessage += '\n\nData yang dihapus:';
            if (transactionsDeleted > 0)
              successMessage += '\n• $transactionsDeleted transaksi';
            if (stocksDeleted > 0)
              successMessage += '\n• $stocksDeleted record stok';
          }
        }

        if (editingMaterialId == id) _clearForm();
        await _loadData();
        if (mounted) _showSuccessDialog(successMessage);
      } else {
        if (mounted)
          _showErrorDialog(result['message'] ?? 'Gagal menghapus material');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(
          'Terjadi kesalahan saat menghapus Barang: ${_friendlyError(e)}');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Berhasil'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Kesalahan'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // ─── Pagination helpers ───────────────────────────────────────────────────

  int get _totalPages =>
      (_materials.length / _rowsPerPage).ceil().clamp(1, 9999);

  List<MaterialModel.Material> get _materials => materials;

  List<MaterialModel.Material> get _pagedMaterials {
    final start = _currentPage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, _materials.length);
    return _materials.sublist(start, end);
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MOBILE LAYOUT — satu halaman bisa di-scroll penuh
  // ══════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    return CustomScrollView(
      slivers: [
        // Form di bagian atas
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: _buildMobileForm(),
          ),
        ),
        // Tabel mengikuti konten (tidak pakai Expanded)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _buildMobileTableSection(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileForm() {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header form
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: (isEditMode ? Colors.orange : Color(0xFF1976D2))
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isEditMode ? Icons.edit : Icons.inventory_2,
                    color: isEditMode ? Colors.orange : Color(0xFF1976D2),
                    size: 18,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  isEditMode ? 'Edit Barang' : 'Input Barang Baru',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Spacer(),
                if (isEditMode)
                  TextButton.icon(
                    onPressed: _clearForm,
                    icon: Icon(Icons.close, size: 14),
                    label: Text('Batal', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: EdgeInsets.zero),
                  ),
              ],
            ),
            SizedBox(height: 14),

            // Nama Barang — full width
            _buildTextField(
              label: 'Nama Barang',
              controller: _namaMaterialController,
              hint: 'Masukkan nama barang',
              required: true,
            ),
            SizedBox(height: 10),

            // Kode + Kategori — 2 kolom
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Kode',
                    controller: _kodeMaterialController,
                    hint: 'Kode barang',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(child: _buildCategoryDropdown()),
              ],
            ),
            SizedBox(height: 10),

            // Satuan + Deskripsi — 2 kolom
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Satuan',
                    controller: _satuanController,
                    hint: 'kg, pcs, liter',
                    required: true,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    label: 'Deskripsi',
                    controller: _descriptionController,
                    hint: 'Opsional',
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),

            // Tombol Simpan — full width
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _saveMaterial,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(isEditMode ? Icons.save : Icons.add, size: 18),
                label: Text(
                  isEditMode ? 'Update Barang' : 'Simpan Barang',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tabel mobile tanpa Expanded — tinggi mengikuti konten
  Widget _buildMobileTableSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header tabel
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFF1976D2).withOpacity(0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: Color(0xFF1976D2), size: 18),
                SizedBox(width: 8),
                Text(
                  'Data Barang',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                if (!isLoading && materials.isNotEmpty) ...[
                  SizedBox(width: 12),
                  _buildShowDropdown(),
                ],
                Spacer(),
                IconButton(
                  onPressed: isLoading ? null : _loadData,
                  icon: Icon(Icons.refresh, color: Color(0xFF1976D2)),
                  iconSize: 18,
                  splashRadius: 18,
                  tooltip: 'Muat ulang',
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF1976D2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${materials.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Isi
          if (isLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading...',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          else if (materials.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 54, color: Colors.grey[300]),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada data Barang',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600]),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Tambahkan melalui form di atas',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          else ...[
            _buildMobileListStatic(),
            _buildPaginationBar(),
          ],
        ],
      ),
    );
  }

  // Daftar barang mobile — pakai Column bukan ListView
  // supaya tidak ada nested scroll
  Widget _buildMobileListStatic() {
    final rows = _pagedMaterials;
    final pageOffset = _currentPage * _rowsPerPage;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: List.generate(rows.length, (index) {
          final material = rows[index];
          final globalIndex = pageOffset + index;

          return Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nomor urut
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color(0xFF1976D2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${globalIndex + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),

                    // Info barang
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material.namaM,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 5),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              _mobileChip(
                                  'Kode: ${material.codeM}', Colors.blue),
                              _mobileChip(
                                  material.categoryName ?? '-', Colors.purple),
                              _mobileChip(material.satuan, Colors.teal),
                            ],
                          ),
                          if (material.description != null &&
                              material.description!.isNotEmpty) ...[
                            SizedBox(height: 4),
                            Text(
                              material.description!,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          SizedBox(height: 4),
                          Text(
                            _formatDate(material.createdAt),
                            style:
                                TextStyle(fontSize: 10, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),

                    // Tombol aksi
                    Column(
                      children: [
                        _buildCompactButton(
                          icon: Icons.edit,
                          color: Colors.blue,
                          onPressed: isSaving
                              ? null
                              : () => _fillFormForEdit(material),
                        ),
                        SizedBox(height: 6),
                        _buildCompactButton(
                          icon: Icons.delete,
                          color: Colors.red,
                          onPressed: material.idM == null
                              ? null
                              : () =>
                                  _deleteMaterial(material.idM!, material.namaM),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _mobileChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT
  // ══════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                _buildDesktopForm(),
                SizedBox(height: 20),
                _buildDesktopTableContainer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopForm() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isEditMode ? Colors.orange : Colors.green)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isEditMode ? Icons.edit : Icons.inventory_2,
                    color: isEditMode ? Colors.orange : Color(0xFF1976D2),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  isEditMode ? 'Edit Barang' : 'Input Barang Baru',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Spacer(),
                if (isEditMode)
                  TextButton.icon(
                    onPressed: _clearForm,
                    icon: Icon(Icons.close, size: 16),
                    label: Text('Batal'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600]),
                  ),
              ],
            ),
            SizedBox(height: 20),

            // Baris 1: Nama, Kode, Kategori
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    label: 'Nama Barang',
                    controller: _namaMaterialController,
                    hint: 'Masukkan Nama Barang',
                    required: true,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    label: 'Kode',
                    controller: _kodeMaterialController,
                    hint: 'Kode barang',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(child: _buildCategoryDropdown()),
              ],
            ),
            SizedBox(height: 12),

            // Baris 2: Satuan, Deskripsi, Tombol
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Satuan',
                    controller: _satuanController,
                    hint: 'kg, pcs, liter',
                    required: true,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    label: 'Deskripsi (Opsional)',
                    controller: _descriptionController,
                    hint: 'Deskripsi Barang',
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  margin: EdgeInsets.only(top: 24),
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : _saveMaterial,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: isSaving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                        : Icon(isEditMode ? Icons.save : Icons.add,
                            size: 18),
                    label: Text(
                      isEditMode ? 'Update' : 'Simpan',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTableContainer() {
    return Container(
      constraints: BoxConstraints(
        minHeight: 400,
        maxHeight: MediaQuery.of(context).size.height - 380,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header tabel
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Color(0xFF1976D2).withOpacity(0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: Color(0xFF1976D2), size: 20),
                SizedBox(width: 10),
                Text(
                  'Data Barang',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                if (!isLoading && materials.isNotEmpty) ...[
                  SizedBox(width: 20),
                  Text('Show:',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[600])),
                  SizedBox(width: 8),
                  _buildShowDropdown(),
                ],
                Spacer(),
                IconButton(
                  onPressed: isLoading ? null : _loadData,
                  icon: Icon(Icons.refresh, color: Color(0xFF1976D2)),
                  tooltip: 'Muat ulang',
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF1976D2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${materials.length} items',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Isi tabel
          Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading Barang...',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : materials.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 64, color: Colors.grey[300]),
                            SizedBox(height: 16),
                            Text(
                              'Belum ada data Barang',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600]),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tambahkan Barang baru menggunakan form di atas',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(child: _buildDesktopTable()),
                          _buildPaginationBar(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    final rows = _pagedMaterials;
    final pageOffset = _currentPage * _rowsPerPage;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 16,
                horizontalMargin: 20,
                headingRowHeight: 48,
                dataRowHeight: 56,
                headingRowColor: MaterialStateProperty.all(
                    Color(0xFF1976D2).withOpacity(0.08)),
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                  fontSize: 13,
                ),
                dataTextStyle:
                    TextStyle(fontSize: 13, color: Colors.grey[800]),
                columns: [
                  DataColumn(
                      label: SizedBox(width: 36, child: Text('No.'))),
                  DataColumn(label: Text('Nama Barang')),
                  DataColumn(
                      label: SizedBox(width: 80, child: Text('Kode'))),
                  DataColumn(
                      label: SizedBox(
                          width: 140, child: Text('Deskripsi'))),
                  DataColumn(
                      label: SizedBox(
                          width: 100, child: Text('Kategori'))),
                  DataColumn(
                      label:
                          SizedBox(width: 60, child: Text('Satuan'))),
                  DataColumn(
                      label:
                          SizedBox(width: 85, child: Text('Tanggal'))),
                  DataColumn(
                    label: SizedBox(
                      width: 90,
                      child: Text('Aksi', textAlign: TextAlign.center),
                    ),
                  ),
                ],
                rows: rows.asMap().entries.map((entry) {
                  final localIndex = entry.key;
                  final globalIndex = pageOffset + localIndex;
                  final material = entry.value;
                  final isEven = localIndex % 2 == 0;

                  return DataRow(
                    color: MaterialStateProperty.all(
                        isEven ? Colors.white : Colors.grey[50]),
                    cells: [
                      DataCell(SizedBox(
                          width: 36,
                          child: Text('${globalIndex + 1}'))),
                      DataCell(ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 200),
                        child: Text(
                          material.namaM,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      )),
                      DataCell(SizedBox(
                        width: 80,
                        child: Text(material.codeM,
                            overflow: TextOverflow.ellipsis),
                      )),
                      DataCell(SizedBox(
                        width: 140,
                        child: Text(
                          material.description ?? '-',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: material.description != null
                                ? Colors.grey[800]
                                : Colors.grey[400],
                            fontStyle: material.description != null
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      )),
                      DataCell(SizedBox(
                        width: 100,
                        child: Text(
                          material.categoryName ?? 'Unknown',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                      DataCell(SizedBox(
                          width: 60, child: Text(material.satuan))),
                      DataCell(SizedBox(
                        width: 85,
                        child: Text(
                          _formatDate(material.createdAt),
                          style: TextStyle(fontSize: 12),
                        ),
                      )),
                      DataCell(SizedBox(
                        width: 90,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildCompactButton(
                              icon: Icons.edit,
                              color: Colors.blue,
                              onPressed: isSaving
                                  ? null
                                  : () => _fillFormForEdit(material),
                            ),
                            SizedBox(width: 6),
                            _buildCompactButton(
                              icon: Icons.delete,
                              color: Colors.red,
                              onPressed: material.idM == null
                                  ? null
                                  : () => _deleteMaterial(
                                      material.idM!, material.namaM),
                            ),
                          ],
                        ),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════

  Widget _buildCategoryDropdown() {
    final validValue = (_selectedCategoryId != null &&
            categories.any((c) => c.idC == _selectedCategoryId))
        ? _selectedCategoryId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori *',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 6),
        DropdownButtonFormField<int>(
          value: validValue,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: 'Pilih kategori',
            hintStyle: TextStyle(fontSize: 13),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: categories.map((category) {
            return DropdownMenuItem<int>(
              value: category.idC,
              child:
                  Text(category.namaC, style: TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: isSaving
              ? null
              : (v) => setState(() => _selectedCategoryId = v),
          validator: (v) => v == null ? 'Wajib dipilih' : null,
        ),
      ],
    );
  }

  Widget _buildShowDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _rowsPerPage,
          isDense: true,
          style: TextStyle(fontSize: 13, color: Colors.grey[800]),
          items: _rowsPerPageOptions
              .map((v) =>
                  DropdownMenuItem<int>(value: v, child: Text('$v')))
              .toList(),
          onChanged: (v) {
            if (v != null)
              setState(() {
                _rowsPerPage = v;
                _currentPage = 0;
              });
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: !isSaving,
          style: TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Wajib diisi';
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: onPressed == null
              ? Colors.grey[300]
              : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: onPressed == null
                ? Colors.grey[400]!
                : color.withOpacity(0.3),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onPressed == null ? Colors.grey[500] : color,
        ),
      ),
    );
  }

  // ── Pagination bar ────────────────────────────────────────────────────────
  Widget _buildPaginationBar() {
    final start = _currentPage * _rowsPerPage + 1;
    final end =
        ((_currentPage + 1) * _rowsPerPage).clamp(0, materials.length);
    final total = materials.length;
    final totalPages = _totalPages;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 20, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFF1976D2).withOpacity(0.04),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          if (!isMobile)
            Text(
              'Menampilkan $start–$end dari $total data',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          if (!isMobile) Spacer(),
          _paginationButton(
            label: isMobile ? '' : 'Previous',
            icon: Icons.chevron_left,
            enabled: _currentPage > 0,
            onTap: () => setState(() => _currentPage--),
            isLeft: true,
          ),
          SizedBox(width: 4),
          ...List.generate(totalPages, (i) {
            final isActive = i == _currentPage;
            if (totalPages <= 7 ||
                i == 0 ||
                i == totalPages - 1 ||
                (i >= _currentPage - 1 && i <= _currentPage + 1)) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => setState(() => _currentPage = i),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Color(0xFF1976D2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive
                            ? Color(0xFF1976D2)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              );
            } else if (i == _currentPage - 2 || i == _currentPage + 2) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child:
                    Text('...', style: TextStyle(color: Colors.grey)),
              );
            }
            return SizedBox.shrink();
          }),
          SizedBox(width: 4),
          _paginationButton(
            label: isMobile ? '' : 'Next',
            icon: Icons.chevron_right,
            enabled: _currentPage < totalPages - 1,
            onTap: () => setState(() => _currentPage++),
            isLeft: false,
          ),
          if (isMobile) ...[
            Spacer(),
            Text(
              '$start–$end / $total',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paginationButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    final showLabel = label.isNotEmpty;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 10 : 6, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: enabled ? Colors.grey[300]! : Colors.grey[200]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: isLeft
              ? [
                  Icon(icon,
                      size: 16,
                      color: enabled
                          ? Color(0xFF1976D2)
                          : Colors.grey[400]),
                  if (showLabel) ...[
                    SizedBox(width: 4),
                    Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            color: enabled
                                ? Color(0xFF1976D2)
                                : Colors.grey[400])),
                  ],
                ]
              : [
                  if (showLabel) ...[
                    Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            color: enabled
                                ? Color(0xFF1976D2)
                                : Colors.grey[400])),
                    SizedBox(width: 4),
                  ],
                  Icon(icon,
                      size: 16,
                      color: enabled
                          ? Color(0xFF1976D2)
                          : Colors.grey[400]),
                ],
        ),
      ),
    );
  }
}