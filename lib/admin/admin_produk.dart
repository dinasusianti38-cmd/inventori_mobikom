import 'package:flutter/material.dart';
import '../models/product_models.dart';
import '../models/material_models.dart' as MaterialModel;
import '../service/admin_produk_service.dart';

const _primary = Color(0xFFB42B2B);
const _primaryLight = Color(0xFFFDF2F2);
const _surface = Color(0xFFF8F9FB);
const _border = Color(0xFFE8ECF0);
const _textPrimary = Color(0xFF1A1D23);
const _textSecondary = Color(0xFF6B7280);
const _textMuted = Color(0xFF9CA3AF);

class AdminProduct extends StatefulWidget {
  @override
  _AdminProductState createState() => _AdminProductState();
}

class _AdminProductState extends State<AdminProduct>
    with SingleTickerProviderStateMixin {
  List<Product> products = [];
  List<Product> _filteredProducts = [];
  List<MaterialModel.Material> materials = [];
  bool isLoading = true;
  bool isProcessing = false;

  final _searchController = TextEditingController();
  int _currentPage = 1;
  int _entriesPerPage = 5;

  final _formKey = GlobalKey<FormState>();
  final _nameProductController = TextEditingController();
  final _codeProductController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Map<String, dynamic>> productMaterials = [];
  bool isEditMode = false;
  int? editingProductId;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadData();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _nameProductController.dispose();
    _codeProductController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _currentPage = 1;
      _filteredProducts = products.where((p) {
        return p.nameP.toLowerCase().contains(query) ||
            p.codeP.toLowerCase().contains(query) ||
            (p.description ?? '').toLowerCase().contains(query);
      }).toList();
    });
  }

  List<Product> get _pagedProducts {
    final start = (_currentPage - 1) * _entriesPerPage;
    final end = (start + _entriesPerPage).clamp(0, _filteredProducts.length);
    if (start >= _filteredProducts.length) return [];
    return _filteredProducts.sublist(start, end);
  }

  int get _totalPages =>
      (_filteredProducts.length / _entriesPerPage).ceil().clamp(1, 99999);

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    _animController.reset();
    try {
      final productsData = await ProductService.getAllProducts();
      final materialsData = await ProductService.getAllMaterials();
      if (!mounted) return;
      setState(() {
        products = productsData;
        _filteredProducts = productsData;
        materials = materialsData;
        isLoading = false;
      });
      _animController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showErrorSnackBar('Gagal memuat data: $e');
    }
  }

  void _clearForm() {
    if (!mounted) return;
    setState(() {
      _nameProductController.clear();
      _codeProductController.clear();
      _descriptionController.clear();
      productMaterials.clear();
      isEditMode = false;
      editingProductId = null;
    });
  }

  void _fillFormForEdit(Product product) {
    if (!mounted) return;
    setState(() {
      _nameProductController.text = product.nameP;
      _codeProductController.text = product.codeP;
      _descriptionController.text = product.description ?? '';
      productMaterials.clear();
      if (product.materials != null && product.materials!.isNotEmpty) {
        for (var material in product.materials!) {
          productMaterials.add({
            'material_id': material.materialId,
            'quantity': material.quantity,
            'material_name': material.materialName,
            'material_code': material.materialCode,
          });
        }
      }
      isEditMode = true;
      editingProductId = product.idP;
    });
    // Scroll to top after filling form
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        Scrollable.ensureVisible(
          _formKey.currentContext ?? context,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  void _addMaterialRow() {
    setState(() {
      productMaterials.add({
        'material_id': null,
        'quantity': 1,
        'material_name': null,
        'material_code': null,
      });
    });
  }

  void _removeMaterialRow(int index) {
    setState(() => productMaterials.removeAt(index));
  }

  void _updateMaterial(int index, int? materialId) {
    if (materialId == null) return;
    final material = materials.firstWhere(
      (m) => m.idM == materialId,
      orElse: () => throw Exception('Material not found'),
    );
    setState(() {
      productMaterials[index]['material_id'] = material.idM;
      productMaterials[index]['material_name'] = material.namaM;
      productMaterials[index]['material_code'] = material.codeM;
    });
  }

  void _updateQuantity(int index, String value) {
    setState(() {
      productMaterials[index]['quantity'] = int.tryParse(value) ?? 1;
    });
  }

  Future<void> _saveProduct() async {
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) return;
    if (productMaterials.isEmpty) {
      _showErrorSnackBar('Tambahkan minimal satu barang terlebih dahulu');
      return;
    }
    for (int i = 0; i < productMaterials.length; i++) {
      if (productMaterials[i]['material_id'] == null) {
        _showErrorSnackBar('Barang ke-${i + 1} belum dipilih');
        return;
      }
    }

    setState(() => isProcessing = true);
    try {
      final product = Product(
        idP: editingProductId,
        codeP: _codeProductController.text.trim(),
        nameP: _nameProductController.text.trim(),
        description: _descriptionController.text.trim(),
        materials: productMaterials
            .map((pm) => ProductMaterial(
                  materialId: pm['material_id'],
                  quantity: pm['quantity'],
                  productId: editingProductId ?? 0,
                ))
            .toList(),
      );

      Map<String, dynamic> result;
      if (isEditMode) {
        result = await ProductService.updateProduct(product);
      } else {
        result = await ProductService.addProduct(product);
      }

      if (!mounted) return;
      if (result['status'] == 'success') {
        setState(() => isProcessing = false);
        _clearForm();
        _showSuccessSnackBar(result['message'] ?? 'Projek berhasil disimpan');
        await _loadData();
      } else {
        setState(() => isProcessing = false);
        _showErrorSnackBar(result['message'] ?? 'Gagal menyimpan projek');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isProcessing = false);
      _showErrorSnackBar('Terjadi kesalahan: $e');
    }
  }

  Future<void> _deleteProduct(int id) async {
    if (!mounted) return;
    final confirm = await _showConfirmDialog(
      'Hapus Projek',
      'Projek ini akan dihapus secara permanen beserta data barangnya. Lanjutkan?',
    );
    if (confirm != true) return;
    if (!mounted) return;

    try {
      final result = await ProductService.deleteProduct(id);
      if (!mounted) return;
      if (result['status'] == 'success') {
        setState(() => isProcessing = false);
        if (editingProductId == id) _clearForm();
        _showSuccessSnackBar(result['message'] ?? 'Projek berhasil dihapus');
        await _loadData();
      } else {
        setState(() => isProcessing = false);
        _showErrorSnackBar(result['message'] ?? 'Gagal menghapus projek');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isProcessing = false);
      _showErrorSnackBar('Terjadi kesalahan: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.close, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.delete_forever, color: _primary, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: _textSecondary, height: 1.5)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text('Batal',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('Ya, Hapus',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: isLoading ? const AlwaysStoppedAnimation(1.0) : _fadeAnim,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Page Header ──
                _buildPageHeader(isMobile),
                SizedBox(height: isMobile ? 16 : 24),

                // ── Form Card ──
                _buildFormCard(isMobile),
                SizedBox(height: isMobile ? 16 : 20),

                // ── Table Card ──
                _buildTableCard(isMobile),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader(bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.work_outline, color: _primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manajemen Projek',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              Text(
                'Kelola data projek dan barang yang digunakan',
                style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── FORM CARD ────────────────────────────────
  Widget _buildFormCard(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form header
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20,
                vertical: isMobile ? 14 : 16),
            decoration: const BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isEditMode ? Icons.edit_note : Icons.add_circle_outline,
                  color: _primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditMode ? 'Edit Projek' : 'Tambah Projek Baru',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
                if (isEditMode) ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: isProcessing ? null : _clearForm,
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Batal Edit',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: _textSecondary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Form body
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─ Basic Info Section ─
                  _sectionLabel('Informasi Projek'),
                  const SizedBox(height: 12),

                  if (isMobile) ...[
                    _buildTextField(
                      label: 'Nama Projek',
                      controller: _nameProductController,
                      hint: 'Contoh: Pemasangan Kabel Fiber Optik',
                      required: true,
                      icon: Icons.work_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      label: 'Kode Projek',
                      controller: _codeProductController,
                      hint: 'Contoh: PRJ-001',
                      icon: Icons.tag,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      label: 'Deskripsi (Opsional)',
                      controller: _descriptionController,
                      hint: 'Keterangan tambahan tentang projek ini',
                      icon: Icons.notes,
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            label: 'Nama Projek',
                            controller: _nameProductController,
                            hint: 'Contoh: Pemasangan Kabel Fiber Optik',
                            required: true,
                            icon: Icons.work_outline,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            label: 'Kode Projek',
                            controller: _codeProductController,
                            hint: 'Contoh: PRJ-001',
                            icon: Icons.tag,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            label: 'Deskripsi (Opsional)',
                            controller: _descriptionController,
                            hint: 'Keterangan tambahan',
                            icon: Icons.notes,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ─ Materials Section ─
                  _buildMaterialsSection(isMobile),

                  const SizedBox(height: 20),

                  // ─ Save Button ─
                  SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _primary.withOpacity(0.5),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 0 : 28,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                        elevation: 0,
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isEditMode
                                      ? Icons.save_outlined
                                      : Icons.check_circle_outline,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isEditMode
                                      ? 'Simpan Perubahan'
                                      : 'Simpan Projek',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsSection(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Materials header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    color: Color(0xFF1D4ED8), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Barang yang Digunakan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      Text(
                        'Tentukan barang dan jumlah kebutuhan',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4B7BB5),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isProcessing ? null : _addMaterialRow,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Tambah',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),

          if (productMaterials.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFBFDBFE),
                      style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Icon(Icons.add_box_outlined,
                        size: 32, color: Colors.blue[200]),
                    const SizedBox(height: 6),
                    Text(
                      'Belum ada barang ditambahkan',
                      style: TextStyle(
                          color: _textMuted,
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                    ),
                    Text(
                      'Tekan "+ Tambah" untuk menambahkan barang',
                      style: TextStyle(
                          color: _textMuted,
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: productMaterials.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> material = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border),
                      ),
                      child: isMobile
                          ? _buildMaterialRowMobile(
                              index, material)
                          : _buildMaterialRowDesktop(
                              index, material),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMaterialRowDesktop(
      int index, Map<String, dynamic> material) {
    return Row(
      children: [
        _materialIndexBadge(index),
        const SizedBox(width: 10),
        Expanded(
          flex: 4,
          child: _materialDropdown(index, material),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 80, child: _qtyField(index, material)),
        const SizedBox(width: 10),
        _removeButton(index),
      ],
    );
  }

  Widget _buildMaterialRowMobile(
      int index, Map<String, dynamic> material) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _materialIndexBadge(index),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Barang ke-${index + 1}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary),
              ),
            ),
            _removeButton(index),
          ],
        ),
        const SizedBox(height: 8),
        _materialDropdown(index, material),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Jumlah:',
                style: TextStyle(fontSize: 12, color: _textSecondary)),
            const SizedBox(width: 10),
            SizedBox(width: 80, child: _qtyField(index, material)),
          ],
        ),
      ],
    );
  }

  Widget _materialIndexBadge(int index) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        '${index + 1}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF1D4ED8),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _materialDropdown(int index, Map<String, dynamic> material) {
    return DropdownButtonFormField<int>(
      value: material['material_id'],
      isExpanded: true,
      decoration: InputDecoration(
        hintText: 'Pilih barang...',
        hintStyle:
            TextStyle(fontSize: 12, color: _textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide:
              const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
      ),
      style:
          const TextStyle(fontSize: 13, color: _textPrimary),
      items: materials
          .map((m) => DropdownMenuItem<int>(
                value: m.idM,
                child: Text(
                  '${m.codeM} – ${m.namaM}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged:
          isProcessing ? null : (value) => _updateMaterial(index, value),
    );
  }

  Widget _qtyField(int index, Map<String, dynamic> material) {
    return TextFormField(
      initialValue: material['quantity'].toString(),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: 'Qty',
        labelStyle:
            const TextStyle(fontSize: 11, color: _textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide:
              const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
      ),
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600),
      keyboardType: TextInputType.number,
      onChanged: (v) => _updateQuantity(index, v),
      enabled: !isProcessing,
    );
  }

  Widget _removeButton(int index) {
    return Tooltip(
      message: 'Hapus barang ini',
      child: InkWell(
        onTap:
            isProcessing ? null : () => _removeMaterialRow(index),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Icon(Icons.delete_outline,
              color: Colors.red[400], size: 16),
        ),
      ),
    );
  }

  // ─── TABLE CARD ───────────────────────────────
  Widget _buildTableCard(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.table_rows_outlined,
                    color: _primary, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Daftar Projek',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const Spacer(),
                if (!isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${products.length} projek',
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Divider(height: 1, color: _border),

          // Controls
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20, vertical: 12),
            child: isMobile
                ? Column(
                    children: [
                      _buildSearchField(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('Tampilkan',
                              style: TextStyle(
                                  fontSize: 12, color: _textSecondary)),
                          const SizedBox(width: 8),
                          _buildEntriesDropdown(),
                          const SizedBox(width: 6),
                          Text('data',
                              style: TextStyle(
                                  fontSize: 12, color: _textSecondary)),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Text('Tampilkan',
                          style: TextStyle(
                              fontSize: 13, color: _textSecondary)),
                      const SizedBox(width: 8),
                      _buildEntriesDropdown(),
                      const SizedBox(width: 6),
                      Text('data per halaman',
                          style: TextStyle(
                              fontSize: 13, color: _textSecondary)),
                      const Spacer(),
                      SizedBox(
                          width: 240,
                          child: _buildSearchField()),
                    ],
                  ),
          ),

          Divider(height: 1, color: _border),

          // Content
          if (isLoading)
            _buildLoadingState()
          else if (_filteredProducts.isEmpty)
            _buildEmptyState()
          else
            isMobile
                ? _buildMobileList()
                : _buildTable(),

          if (!isLoading && _filteredProducts.isNotEmpty)
            _buildPagination(isMobile),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Cari nama, kode, atau deskripsi...',
        hintStyle:
            TextStyle(fontSize: 12, color: _textMuted),
        prefixIcon:
            Icon(Icons.search, size: 18, color: _textMuted),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, size: 16, color: _textMuted),
                onPressed: () {
                  _searchController.clear();
                  _onSearch();
                },
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        filled: true,
        fillColor: _surface,
      ),
    );
  }

  Widget _buildEntriesDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(7),
        color: _surface,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _entriesPerPage,
          isDense: true,
          style:
              const TextStyle(fontSize: 13, color: _textPrimary),
          items: [5, 10, 25, 50]
              .map((e) =>
                  DropdownMenuItem(value: e, child: Text('$e')))
              .toList(),
          onChanged: (v) {
            if (v != null)
              setState(() {
                _entriesPerPage = v;
                _currentPage = 1;
              });
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
                color: _primary, strokeWidth: 2.5),
            SizedBox(height: 14),
            Text('Memuat data projek...',
                style:
                    TextStyle(fontSize: 13, color: _textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isEmpty = _searchController.text.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(
              isEmpty ? Icons.work_off_outlined : Icons.search_off,
              size: 48,
              color: _textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              isEmpty ? 'Belum ada projek' : 'Projek tidak ditemukan',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              isEmpty
                  ? 'Tambahkan projek pertama menggunakan form di atas'
                  : 'Coba kata kunci lain',
              style:
                  const TextStyle(fontSize: 12, color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MOBILE CARD LIST ─────────────────────────
  Widget _buildMobileList() {
    final rows = _pagedProducts;
    final startIndex = (_currentPage - 1) * _entriesPerPage;

    return Column(
      children: rows.asMap().entries.map((entry) {
        final int globalIndex = startIndex + entry.key;
        final Product product = entry.value;
        final int jumlahJenis = product.materials?.length ?? 0;
        final int totalQty =
            product.materials?.fold(0, (s, m) => s! + m.quantity) ?? 0;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '#${globalIndex + 1}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: _primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.nameP,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  // Actions
                  _actionButton(
                    icon: Icons.edit_outlined,
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                    tooltip: 'Edit projek',
                    onTap: () => _fillFormForEdit(product),
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    icon: Icons.delete_outline,
                    color: Colors.red[600]!,
                    bgColor: Colors.red.shade50,
                    tooltip: 'Hapus projek',
                    onTap: product.idP == null
                        ? null
                        : () => _deleteProduct(product.idP!),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (product.codeP.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.tag, size: 12, color: _textMuted),
                    const SizedBox(width: 4),
                    Text(product.codeP,
                        style: TextStyle(
                            fontSize: 12, color: _textSecondary)),
                  ],
                ),
              if (product.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(
                  product.description!,
                  style: TextStyle(
                      fontSize: 12, color: _textMuted, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Divider(height: 1, color: _border),
              const SizedBox(height: 10),
              Row(
                children: [
                  _infoBadge(
                    label: '$jumlahJenis jenis barang',
                    color: const Color(0xFF1D4ED8),
                    bgColor: const Color(0xFFEFF6FF),
                    icon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(width: 8),
                  _infoBadge(
                    label: 'Total $totalQty unit',
                    color: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFF0FDF4),
                    icon: Icons.numbers,
                  ),
                ],
              ),
              if (product.materials != null &&
                  product.materials!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: product.materials!.map((m) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: Colors.orange.shade100),
                      ),
                      child: Text(
                        'x${m.quantity}  ${m.materialName ?? '-'}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange[800]),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _infoBadge(
      {required String label,
      required Color color,
      required Color bgColor,
      required IconData icon}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }

  // ─── DESKTOP TABLE ────────────────────────────
  Widget _buildTable() {
    final rows = _pagedProducts;
    final startIndex = (_currentPage - 1) * _entriesPerPage;

    const headers = ['No', 'Nama Projek', 'Kode', 'Deskripsi', 'Barang', 'Detail Barang', 'Aksi'];
    const colFlex = [1, 3, 2, 3, 2, 4, 2];

    return Column(
      children: [
        // Header row
        Container(
          decoration: BoxDecoration(
            color: _surface,
            border: Border(
              top: BorderSide(color: _border),
              bottom: BorderSide(color: _border),
            ),
          ),
          child: Row(
            children: List.generate(headers.length, (i) {
              return Expanded(
                flex: colFlex[i],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  child: Text(
                    headers[i],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Data rows
        ...rows.asMap().entries.map((entry) {
          final int localIndex = entry.key;
          final int globalIndex = startIndex + localIndex;
          final Product product = entry.value;
          final bool isEven = localIndex % 2 == 0;
          final int jumlahJenis = product.materials?.length ?? 0;
          final int totalQty =
              product.materials?.fold(0, (s, m) => s! + m.quantity) ?? 0;

          return Container(
            color: isEven ? Colors.white : const Color(0xFFFAFBFC),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // No
                  Expanded(
                    flex: colFlex[0],
                    child: _tableCell(
                      Text('${globalIndex + 1}',
                          style: const TextStyle(
                              fontSize: 13, color: _textSecondary)),
                    ),
                  ),
                  // Nama
                  Expanded(
                    flex: colFlex[1],
                    child: _tableCell(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          product.nameP,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    )),
                  ),
                  // Kode
                  Expanded(
                    flex: colFlex[2],
                    child: _tableCell(
                      product.codeP.isEmpty
                          ? Text('—',
                              style: TextStyle(
                                  fontSize: 12, color: _textMuted))
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: _border),
                              ),
                              child: Text(
                                product.codeP,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: _textPrimary),
                              ),
                            ),
                    ),
                  ),
                  // Deskripsi
                  Expanded(
                    flex: colFlex[3],
                    child: _tableCell(
                      Text(
                        product.description?.isEmpty ?? true
                            ? '—'
                            : product.description!,
                        style: TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                            height: 1.4),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ),
                  // Barang count
                  Expanded(
                    flex: colFlex[4],
                    child: _tableCell(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _infoBadge(
                          label: '$jumlahJenis jenis',
                          color: const Color(0xFF1D4ED8),
                          bgColor: const Color(0xFFEFF6FF),
                          icon: Icons.inventory_2_outlined,
                        ),
                        const SizedBox(height: 4),
                        _infoBadge(
                          label: '$totalQty unit',
                          color: const Color(0xFF16A34A),
                          bgColor: const Color(0xFFF0FDF4),
                          icon: Icons.numbers,
                        ),
                      ],
                    )),
                  ),
                  // Detail
                  Expanded(
                    flex: colFlex[5],
                    child: _tableCell(
                      product.materials == null ||
                              product.materials!.isEmpty
                          ? Text('—',
                              style: TextStyle(
                                  color: _textMuted, fontSize: 12))
                          : Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: product.materials!.map((m) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius:
                                        BorderRadius.circular(5),
                                    border: Border.all(
                                        color: Colors.orange.shade100),
                                  ),
                                  child: Text(
                                    'x${m.quantity} ${m.materialName ?? '-'}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange[800]),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                  // Aksi
                  Expanded(
                    flex: colFlex[6],
                    child: _tableCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionButton(
                          icon: Icons.edit_outlined,
                          color: const Color(0xFF2563EB),
                          bgColor: const Color(0xFFEFF6FF),
                          tooltip: 'Edit projek',
                          onTap: () => _fillFormForEdit(product),
                        ),
                        const SizedBox(width: 8),
                        _actionButton(
                          icon: Icons.delete_outline,
                          color: Colors.red[600]!,
                          bgColor: Colors.red.shade50,
                          tooltip: 'Hapus projek',
                          onTap: product.idP == null
                              ? null
                              : () => _deleteProduct(product.idP!),
                        ),
                      ],
                    )),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _tableCell(Widget child) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: _border, width: 0.5)),
      ),
      child: child,
    );
  }

  // ─── PAGINATION ───────────────────────────────
  Widget _buildPagination(bool isMobile) {
    final start = (_currentPage - 1) * _entriesPerPage + 1;
    final end = (start + _entriesPerPage - 1)
        .clamp(0, _filteredProducts.length);
    final totalPages = _totalPages;

    // For mobile, show condensed pagination
    List<int> pageNumbers;
    if (totalPages <= 5) {
      pageNumbers = List.generate(totalPages, (i) => i + 1);
    } else {
      final around = {
        _currentPage - 1,
        _currentPage,
        _currentPage + 1,
      }.where((p) => p >= 1 && p <= totalPages).toList();
      pageNumbers = around;
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: isMobile
          ? Column(
              children: [
                Text(
                  'Data $start–$end dari ${_filteredProducts.length}',
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
                const SizedBox(height: 10),
                _paginationButtons(pageNumbers),
              ],
            )
          : Row(
              children: [
                Text(
                  'Menampilkan $start–$end dari ${_filteredProducts.length} projek',
                  style:
                      TextStyle(fontSize: 12, color: _textSecondary),
                ),
                const Spacer(),
                _paginationButtons(pageNumbers),
              ],
            ),
    );
  }

  Widget _paginationButtons(List<int> pageNumbers) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pgBtn(
          Icons.chevron_left,
          _currentPage > 1,
          () => setState(() => _currentPage--),
        ),
        const SizedBox(width: 4),
        if (_currentPage > 2 && _totalPages > 5) ...[
          _pageNumBtn(1),
          const SizedBox(width: 2),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4),
            child: Text('…',
                style: TextStyle(
                    color: _textMuted, fontSize: 13)),
          ),
        ],
        ...pageNumbers
            .map((p) => Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: _pageNumBtn(p),
                ))
            .toList(),
        if (_currentPage < _totalPages - 1 &&
            _totalPages > 5) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('…',
                style: TextStyle(
                    color: _textMuted, fontSize: 13)),
          ),
          _pageNumBtn(_totalPages),
        ],
        const SizedBox(width: 4),
        _pgBtn(
          Icons.chevron_right,
          _currentPage < _totalPages,
          () => setState(() => _currentPage++),
        ),
      ],
    );
  }

  Widget _pgBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : _surface,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon,
            size: 16,
            color: enabled ? _textPrimary : _textMuted),
      ),
    );
  }

  Widget _pageNumBtn(int page) {
    final isActive = page == _currentPage;
    return InkWell(
      onTap: () => setState(() => _currentPage = page),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? _primary : Colors.white,
          border: Border.all(
              color: isActive ? _primary : _border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          '$page',
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────
  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool required = false,
    IconData? icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: _textSecondary,
              ),
            ),
            if (required)
              const Text(' *',
                  style: TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: !isProcessing,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13, color: _textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                fontSize: 12, color: _textMuted),
            prefixIcon: icon != null
                ? Icon(icon, size: 16, color: _textMuted)
                : null,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: _primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFFDC2626), width: 1.5),
            ),
            filled: true,
            fillColor: isProcessing
                ? _surface
                : Colors.white,
          ),
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Kolom ini wajib diisi';
                  return null;
                }
              : null,
        ),
      ],
    );
  }
}