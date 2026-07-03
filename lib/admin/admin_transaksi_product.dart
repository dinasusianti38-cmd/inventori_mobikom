import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../service/admin_transaksi_product_service.dart';
import '../models/product_transaction_models.dart';

const _red       = Color(0xFFB42B2B);
const _redLight  = Color(0xFFFFF0F0);
const _bg        = Color(0xFFF4F6F8);
const _surface   = Colors.white;
const _border    = Color(0xFFEAECF0);
const _textDark  = Color(0xFF1A1D23);
const _textMid   = Color(0xFF6B7280);
const _textLight = Color(0xFF9CA3AF);
const _green     = Color(0xFF16A34A);
const _orange    = Color(0xFFD97706);

class TransaksiProduct extends StatefulWidget {
  const TransaksiProduct({Key? key}) : super(key: key);

  @override
  _TransaksiProductState createState() => _TransaksiProductState();
}

class _TransaksiProductState extends State<TransaksiProduct> {
  final _formKey                   = GlobalKey<FormState>();
  final _transactionCodeController = TextEditingController();
  final _jumlahController          = TextEditingController();
  final _notesController           = TextEditingController();
  final _dateController            = TextEditingController();
  final _searchController          = TextEditingController();

  List<ProductModel>            _products             = [];
  List<ProductTransactionModel> _transactions         = [];
  List<ProductTransactionModel> _filteredTransactions = [];

  ProductModel? _selectedProduct;
  String        _selectedType   = 'out';
  bool          _isLoading      = false;
  bool          _isLoadingTable = false;
  bool          _isEditMode     = false;
  ProductTransactionModel? _editing;

  int _currentPage  = 1;
  int _itemsPerPage = 10;
  int _totalPages   = 1;

  // ─── Responsive ───────────────────────────────────────────
  bool get _isMobile => _screenWidth < 600;
  double _screenWidth = 0;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _searchController.addListener(_filterTransactions);
    _loadInitialData();
  }

  @override
  void dispose() {
    _transactionCodeController.dispose();
    _jumlahController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ─── DATA ──────────────────────────────────────────────────
  Future<void> _loadInitialData() async {
    await _loadProducts();
    await _loadTransactions();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoading = true);
      final p = await AdminTransaksiProductService.getProducts();
      setState(() { _products = p; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
      _snack('Error memuat projek: $e', error: true);
    }
  }

  Future<void> _loadTransactions() async {
    try {
      setState(() => _isLoadingTable = true);
      final t = await AdminTransaksiProductService.getProductTransactions();
      setState(() {
        _transactions         = t;
        _filteredTransactions = t;
        _currentPage          = 1;
        _calcPages();
        _isLoadingTable = false;
      });
    } catch (e) {
      setState(() => _isLoadingTable = false);
      _snack('Error memuat transaksi: $e', error: true);
    }
  }

  void _filterTransactions() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredTransactions = q.isEmpty
          ? _transactions
          : _transactions.where((t) =>
              t.productName.toLowerCase().contains(q) ||
              t.transactionCode.toLowerCase().contains(q) ||
              (t.notes ?? '').toLowerCase().contains(q)).toList();
      _currentPage = 1;
      _calcPages();
    });
  }

  void _calcPages() {
    _totalPages = (_filteredTransactions.length / _itemsPerPage).ceil();
    if (_totalPages < 1) _totalPages = 1;
  }

  List<ProductTransactionModel> get _pageRows {
    final s = (_currentPage - 1) * _itemsPerPage;
    final e = (s + _itemsPerPage).clamp(0, _filteredTransactions.length);
    return _filteredTransactions.sublist(s, e);
  }

  // ─── CRUD ──────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      _snack('Pilih Projek terlebih dahulu', error: true);
      return;
    }
    if (_selectedType == 'in') {
      _snack('Transaksi masuk diperbarui otomatis melalui assembly.', error: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final t = ProductTransactionModel(
        id: _editing?.id,
        transactionCode: _transactionCodeController.text,
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        transactionType: _selectedType,
        jumlah: int.parse(_jumlahController.text),
        transactionDate: _dateController.text,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      final result = _isEditMode
          ? await AdminTransaksiProductService.updateProductTransaction(t)
          : await AdminTransaksiProductService.addProductTransaction(t);

      if (result['status'] == 'success') {
        _snack(result['message'] ?? (_isEditMode ? 'Transaksi diperbarui' : 'Transaksi ditambahkan'));
        _clearForm();
        await _loadTransactions();
        await _loadProducts();
      } else {
        _snack(result['message'] ?? 'Gagal', error: true);
      }
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startEdit(ProductTransactionModel t) {
    final editType = t.transactionType == 'in' ? 'out' : t.transactionType;
    setState(() {
      _isEditMode = true;
      _editing = t;
      _transactionCodeController.text = t.transactionCode;
      _jumlahController.text = t.jumlah.toString();
      _notesController.text = t.notes ?? '';
      _dateController.text = t.transactionDate;
      _selectedType = editType;
      _selectedProduct = _products.firstWhere(
        (p) => p.id == t.productId,
        orElse: () => _products.first,
      );
    });
    if (_isMobile) _showMobileFormSheet();
  }

  void _clearForm() {
    _transactionCodeController.clear();
    _jumlahController.clear();
    _notesController.clear();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    setState(() {
      _selectedProduct = null;
      _selectedType = 'out';
      _isEditMode = false;
      _editing = null;
    });
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Hapus Transaksi', style: TextStyle(fontSize: 16)),
        ]),
        content: const Text(
            'Apakah Anda yakin ingin menghapus transaksi ini? Stok akan disesuaikan kembali.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                elevation: 0),
            child: const Text('Hapus'),
          ),
        ],
      ),
    ) ?? false;
    if (!ok) return;

    setState(() => _isLoadingTable = true);
    try {
      final r = await AdminTransaksiProductService.deleteProductTransaction(id);
      if (r['status'] == 'success') {
        _snack(r['message'] ?? 'Transaksi dihapus');
        await _loadTransactions();
        await _loadProducts();
      } else {
        _snack(r['message'] ?? 'Gagal menghapus', error: true);
      }
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      setState(() => _isLoadingTable = false);
    }
  }

  // ─── HELPERS ───────────────────────────────────────────────
  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: error ? _red : _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(12),
    ));
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'in': return _green;
      case 'out': return _red;
      case 'adjustment': return _orange;
      default: return _textMid;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'in': return Icons.trending_up_rounded;
      case 'out': return Icons.trending_down_rounded;
      case 'adjustment': return Icons.tune_rounded;
      default: return Icons.sync;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'in': return 'Masuk';
      case 'out': return 'Keluar';
      case 'adjustment': return 'Penyesuaian';
      default: return t;
    }
  }

  // ─── MOBILE FORM SHEET ─────────────────────────────────────
  void _showMobileFormSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ProductMobileFormSheet(
          formKey: _formKey,
          kodeController: _transactionCodeController,
          jumlahController: _jumlahController,
          notesController: _notesController,
          dateController: _dateController,
          products: _products,
          selectedProduct: _selectedProduct,
          selectedType: _selectedType,
          isEditMode: _isEditMode,
          isLoading: _isLoading,
          onProductChanged: (v) => setState(() => _selectedProduct = v),
          onTypeChanged: (v) => setState(() => _selectedType = v),
          onSubmit: () {
            Navigator.pop(ctx);
            _submit();
          },
          onCancel: () {
            Navigator.pop(ctx);
            _clearForm();
          },
        );
      },
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: _isMobile
          ? FloatingActionButton.extended(
              onPressed: () {
                if (_isEditMode) _clearForm();
                _showMobileFormSheet();
              },
              backgroundColor: _red,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Tambah',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: SafeArea(
        child: _isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
      ),
    );
  }

  // ─── MOBILE LAYOUT ─────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Column(children: [
      // Info banner
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _orange.withOpacity(0.35)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: _orange, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Stok masuk diperbarui otomatis melalui assembly.',
              style: TextStyle(fontSize: 11, color: _orange),
            ),
          ),
        ]),
      ),

      // Search
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        color: Colors.transparent,
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Cari transaksi projek...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[400]),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _red, width: 1.5)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ),

      // List
      Expanded(
        child: _isLoadingTable
            ? const Center(child: CircularProgressIndicator(color: _red))
            : _filteredTransactions.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: _pageRows.length,
                    itemBuilder: (_, i) => _mobileCard(
                        _pageRows[i], (_currentPage - 1) * _itemsPerPage + i),
                  ),
      ),

      if (!_isLoadingTable && _filteredTransactions.isNotEmpty)
        _mobilePagination(),
    ]);
  }

  Widget _mobileCard(ProductTransactionModel t, int index) {
    final tc = _typeColor(t.transactionType);
    final isAssemblyIn = t.transactionType == 'in';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // Header strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: tc.withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tc.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tc.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_typeIcon(t.transactionType), size: 12, color: tc),
                const SizedBox(width: 4),
                Text(_typeLabel(t.transactionType),
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: tc)),
              ]),
            ),
            if (isAssemblyIn) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Assembly',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ),
            ],
            const Spacer(),
            Text(
              DateFormat('dd/MM/yyyy').format(DateTime.parse(t.transactionDate)),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.productName,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: _textDark)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.tag, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(t.transactionCode,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const Spacer(),
              Icon(_typeIcon(t.transactionType), size: 14, color: tc),
              const SizedBox(width: 4),
              Text('${t.jumlah}',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: tc)),
            ]),
            if ((t.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(t.notes!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),

        // Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(children: [
            Expanded(
              child: isAssemblyIn
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.edit_off_outlined, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => _startEdit(t),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _delete(t.id!),
                icon: const Icon(Icons.delete_outline, size: 14),
                label: const Text('Hapus', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _red,
                  side: const BorderSide(color: _red),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _mobilePagination() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Text(
          '${(_currentPage - 1) * _itemsPerPage + 1}–'
          '${((_currentPage - 1) * _itemsPerPage + _pageRows.length)} '
          'dari ${_filteredTransactions.length}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const Spacer(),
        _pgBtn2('‹', _currentPage > 1, () => setState(() => _currentPage--)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration:
              BoxDecoration(color: _red, borderRadius: BorderRadius.circular(6)),
          child: Text('$_currentPage',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
        const SizedBox(width: 6),
        _pgBtn2('›', _currentPage < _totalPages,
            () => setState(() => _currentPage++)),
      ]),
    );
  }

  // ─── DESKTOP LAYOUT ────────────────────────────────────────
  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(children: [
        _buildDesktopForm(),
        const SizedBox(height: 24),
        _buildDesktopTable(),
      ]),
    );
  }

  Widget _buildDesktopForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecor(),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: _redLight,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(_isEditMode ? Icons.edit : Icons.add,
                  color: _red, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              _isEditMode ? 'Edit Transaksi Projek' : 'Tambah Transaksi Projek',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800]),
            ),
            if (_isEditMode) ...[
              const Spacer(),
              TextButton.icon(
                onPressed: _clearForm,
                icon: const Icon(Icons.close, size: 15),
                label: const Text('Batal'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              ),
            ],
          ]),
          const SizedBox(height: 12),

          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _orange.withOpacity(0.35)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: _orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Transaksi masuk stok projek diperbarui otomatis melalui proses assembly.',
                  style: TextStyle(fontSize: 12, color: _orange),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Row 1
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: _fw('Nama Projek', _dropdownProduct())),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _fw('Jumlah', TextFormField(
              controller: _jumlahController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: _deco('Masukkan jumlah'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Wajib diisi';
                if (int.tryParse(v) == null) return 'Harus angka';
                if (int.parse(v) <= 0) return 'Harus > 0';
                return null;
              },
            ))),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: _fw('Deskripsi', TextFormField(
              controller: _notesController,
              style: const TextStyle(fontSize: 13),
              decoration: _deco('Tambahkan deskripsi...'),
            ))),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _fw('Tanggal', TextFormField(
              controller: _dateController,
              readOnly: true,
              style: const TextStyle(fontSize: 13),
              decoration: _deco('Pilih tanggal').copyWith(
                suffixIcon: const Icon(Icons.calendar_today_rounded,
                    color: _red, size: 16),
              ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(primary: _red)),
                    child: child!,
                  ),
                );
                if (d != null) {
                  _dateController.text = DateFormat('yyyy-MM-dd').format(d);
                }
              },
              validator: (v) =>
                  v == null || v.isEmpty ? 'Wajib diisi' : null,
            ))),
          ]),
          const SizedBox(height: 16),

          // Row 2
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(flex: 3, child: _fw(
              'Kode Transaksi (opsional)',
              TextFormField(
                controller: _transactionCodeController,
                style: const TextStyle(fontSize: 13),
                decoration: _deco('Auto generate jika kosong'),
              ),
            )),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: _fw('Jenis', Row(children: [
              _chip('out', 'Keluar', _red),
              const SizedBox(width: 8),
              _chip('adjustment', 'Penyesuaian', _orange),
            ]))),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditMode ? _orange : _red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : Icon(_isEditMode ? Icons.save_outlined : Icons.add, size: 16),
              label: Text(_isEditMode ? 'Update' : 'Simpan',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      width: double.infinity,
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text('Daftar Transaksi Projek',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[850])),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text('Show', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(6)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _itemsPerPage,
                  isDense: true,
                  style: const TextStyle(fontSize: 13, color: _textDark),
                  items: [5, 10, 25, 50]
                      .map((e) =>
                          DropdownMenuItem(value: e, child: Text('$e')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() { _itemsPerPage = v; _currentPage = 1; _calcPages(); });
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('Entries', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const Spacer(),
            SizedBox(width: 220, child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search :',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[400]),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _red, width: 1.5)),
                filled: true, fillColor: const Color(0xFFFAFAFC),
              ),
            )),
          ]),
        ),
        const SizedBox(height: 12),
        if (_isLoadingTable)
          const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: _red)))
        else if (_filteredTransactions.isEmpty)
          _emptyState()
        else
          _desktopTableRows(),
        if (!_isLoadingTable && _filteredTransactions.isNotEmpty)
          _desktopPagination(),
      ]),
    );
  }

  Widget _desktopTableRows() {
    const colHeaders = [
      'No', 'Nama Projek', 'Kode Transaksi',
      'Deskripsi', 'Jumlah', 'Jenis', 'Tanggal', 'Aksi'
    ];
    const colFlex = [1, 3, 3, 3, 2, 2, 2, 2];
    final rows = _pageRows;
    final start = (_currentPage - 1) * _itemsPerPage;

    return Column(children: [
      Container(
        decoration: BoxDecoration(
          color: _red.withOpacity(0.06),
          border: Border(
              top: BorderSide(color: Colors.grey.shade200),
              bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: List.generate(colHeaders.length, (i) => Expanded(
            flex: colFlex[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Text(colHeaders[i],
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: _red)),
            ),
          )),
        ),
      ),
      ...rows.asMap().entries.map((entry) {
        final localIdx = entry.key;
        final t = entry.value;
        final tc = _typeColor(t.transactionType);
        final isAssemblyIn = t.transactionType == 'in';

        return Column(children: [
          Container(
            color: localIdx % 2 == 0 ? _surface : const Color(0xFFFAFBFC),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _dc(colFlex[0], Text('${start + localIdx + 1}',
                    style: const TextStyle(fontSize: 13, color: _textMid))),
                _dc(colFlex[1], Text(t.productName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
                    overflow: TextOverflow.ellipsis, maxLines: 2)),
                _dc(colFlex[2], Text(t.transactionCode,
                    style: const TextStyle(fontSize: 12, color: _textMid),
                    overflow: TextOverflow.ellipsis)),
                _dc(colFlex[3], Text(t.notes ?? '-',
                    style: TextStyle(fontSize: 12, color: _textMid),
                    overflow: TextOverflow.ellipsis, maxLines: 2)),
                _dc(colFlex[4], Row(children: [
                  Icon(_typeIcon(t.transactionType), size: 13, color: tc),
                  const SizedBox(width: 4),
                  Text('${t.jumlah}',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: tc)),
                ])),
                _dc(colFlex[5], FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tc.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tc.withOpacity(0.3)),
                    ),
                    child: Text(_typeLabel(t.transactionType),
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, color: tc)),
                  ),
                )),
                _dc(colFlex[6], Text(
                  DateFormat('dd/MM/yyyy').format(DateTime.parse(t.transactionDate)),
                  style: const TextStyle(fontSize: 12, color: _textMid),
                )),
                _dc(colFlex[7], Row(mainAxisSize: MainAxisSize.min, children: [
                  if (!isAssemblyIn)
                    _actBtn(Icons.edit_outlined, Colors.blue, () => _startEdit(t))
                  else
                    Tooltip(
                      message: 'Transaksi assembly tidak dapat diedit',
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Icon(Icons.edit_off_outlined,
                            color: Colors.grey.shade400, size: 15),
                      ),
                    ),
                  const SizedBox(width: 6),
                  _actBtn(Icons.delete_outline, _red, () => _delete(t.id!)),
                ])),
              ]),
            ),
          ),
          Divider(height: 1, thickness: 0.8, color: Colors.grey.shade200),
        ]);
      }),
    ]);
  }

  Widget _desktopPagination() {
    final start = (_currentPage - 1) * _itemsPerPage + 1;
    final end = (start + _itemsPerPage - 1).clamp(0, _filteredTransactions.length);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Text('Showing $start to $end of ${_filteredTransactions.length} entries',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const Spacer(),
        Row(children: [
          _pgBtn('Previous', _currentPage > 1, () => setState(() => _currentPage--)),
          const SizedBox(width: 4),
          ...List.generate(_totalPages.clamp(0, 5), (i) {
            final p = i + 1;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => setState(() => _currentPage = p),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 32, height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _currentPage == p ? _red : _surface,
                    border: Border.all(
                        color: _currentPage == p ? _red : _border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$p',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _currentPage == p ? Colors.white : _textMid)),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          _pgBtn('Next', _currentPage < _totalPages,
              () => setState(() => _currentPage++)),
        ]),
      ]),
    );
  }

  // ─── MICRO WIDGETS ─────────────────────────────────────────
  Widget _dropdownProduct() => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFFAFAFC)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<ProductModel>(
        value: _selectedProduct,
        hint: Text('Pilih Projek',
            style: TextStyle(fontSize: 13, color: _textLight)),
        isExpanded: true,
        icon: const Icon(Icons.expand_more, color: _red, size: 18),
        style: const TextStyle(fontSize: 13, color: _textDark),
        items: _products.map((p) => DropdownMenuItem(
          value: p,
          child: Text(p.name, overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (v) => setState(() => _selectedProduct = v),
      ),
    ),
  );

  Widget _chip(String value, String label, Color color) {
    final selected = _selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 42,
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : const Color(0xFFFAFAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : _border, width: selected ? 1.5 : 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_typeIcon(value), color: selected ? color : _textLight, size: 13),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : _textMid)),
          ]),
        ),
      ),
    );
  }

  Widget _fw(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700])),
      const SizedBox(height: 5),
      child,
    ],
  );

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 12, color: _textLight),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _red, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade300)),
    filled: true,
    fillColor: const Color(0xFFFAFAFC),
    isDense: true,
  );

  Widget _dc(int flex, Widget child) => Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.centerLeft,
      child: child,
    ),
  );

  Widget _actBtn(IconData icon, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Icon(icon, color: color, size: 15),
        ),
      );

  Widget _pgBtn(String label, bool enabled, VoidCallback onTap) =>
      InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: enabled ? _surface : const Color(0xFFF3F4F6),
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(6)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: enabled ? _textDark : _textLight)),
        ),
      );

  Widget _pgBtn2(String label, bool enabled, VoidCallback onTap) =>
      InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32, height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: enabled ? Colors.white : const Color(0xFFF3F4F6),
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(6)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 16,
                  color: enabled ? _textDark : _textLight)),
        ),
      );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.all(40),
    child: Center(child: Column(children: [
      Icon(Icons.inbox_outlined, size: 48, color: _textLight),
      const SizedBox(height: 10),
      Text('Belum ada transaksi',
          style: TextStyle(fontSize: 14, color: _textMid)),
    ])),
  );

  BoxDecoration _cardDecor() => BoxDecoration(
    color: _surface,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2))
    ],
  );
}

// ─── PRODUCT MOBILE FORM SHEET ────────────────────────────
class _ProductMobileFormSheet extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController kodeController;
  final TextEditingController jumlahController;
  final TextEditingController notesController;
  final TextEditingController dateController;
  final List<ProductModel> products;
  final ProductModel? selectedProduct;
  final String selectedType;
  final bool isEditMode;
  final bool isLoading;
  final ValueChanged<ProductModel?> onProductChanged;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _ProductMobileFormSheet({
    required this.formKey,
    required this.kodeController,
    required this.jumlahController,
    required this.notesController,
    required this.dateController,
    required this.products,
    required this.selectedProduct,
    required this.selectedType,
    required this.isEditMode,
    required this.isLoading,
    required this.onProductChanged,
    required this.onTypeChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<_ProductMobileFormSheet> createState() =>
      _ProductMobileFormSheetState();
}

class _ProductMobileFormSheetState extends State<_ProductMobileFormSheet> {
  static const Color _red = Color(0xFFB42B2B);
  static const Color _border = Color(0xFFEAECF0);
  static const Color _orange = Color(0xFFD97706);

  late ProductModel? _selProd;
  late String _selType;

  @override
  void initState() {
    super.initState();
    _selProd = widget.selectedProduct;
    _selType = widget.selectedType;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomPad),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: widget.isEditMode
                      ? Colors.orange.withOpacity(0.1)
                      : _red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(
                  widget.isEditMode ? Icons.edit : Icons.add,
                  color: widget.isEditMode ? Colors.orange : _red,
                  size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              widget.isEditMode ? 'Edit Transaksi Projek' : 'Tambah Transaksi Projek',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close, size: 20),
              padding: EdgeInsets.zero,
            ),
          ]),
        ),

        // Assembly info
        Container(
          margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _orange.withOpacity(0.35)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, color: _orange, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Stok masuk diperbarui otomatis melalui assembly.',
                style: TextStyle(fontSize: 11, color: _orange),
              ),
            ),
          ]),
        ),

        const Divider(height: 20),

        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Form(
              key: widget.formKey,
              child: Column(children: [
                _ml('Nama Projek'),
                _prodDropdown(),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _ml('Jumlah'),
                    TextFormField(
                      controller: widget.jumlahController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                      decoration: _md('Masukkan jumlah'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Wajib diisi';
                        if (int.tryParse(v) == null || int.parse(v) <= 0)
                          return 'Harus > 0';
                        return null;
                      },
                    ),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _ml('Tanggal'),
                    TextFormField(
                      controller: widget.dateController,
                      readOnly: true,
                      style: const TextStyle(fontSize: 14),
                      decoration: _md('Pilih tanggal').copyWith(
                        suffixIcon: const Icon(Icons.calendar_today, color: _red, size: 16),
                      ),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.light(primary: _red)),
                            child: child!,
                          ),
                        );
                        if (d != null) {
                          widget.dateController.text =
                              DateFormat('yyyy-MM-dd').format(d);
                        }
                      },
                      validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                  ])),
                ]),
                const SizedBox(height: 14),
                _ml('Deskripsi (opsional)'),
                TextFormField(
                  controller: widget.notesController,
                  style: const TextStyle(fontSize: 14),
                  decoration: _md('Tambahkan keterangan...'),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                _ml('Kode Transaksi (opsional)'),
                TextFormField(
                  controller: widget.kodeController,
                  style: const TextStyle(fontSize: 14),
                  decoration: _md('Auto generate jika kosong'),
                ),
                const SizedBox(height: 14),
                _ml('Jenis Transaksi'),
                Row(children: [
                  Expanded(child: _typeChip('out', 'Keluar', _red)),
                  const SizedBox(width: 10),
                  Expanded(child: _typeChip('adjustment', 'Penyesuaian', _orange)),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.isLoading ? null : widget.onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isEditMode ? Colors.orange : _red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.isEditMode ? 'Update Transaksi' : 'Simpan Transaksi',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _ml(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(t,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700])),
    ),
  );

  Widget _prodDropdown() => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey[50]),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<ProductModel>(
        value: _selProd,
        hint: Text('Pilih Projek',
            style: TextStyle(fontSize: 14, color: Colors.grey[400])),
        isExpanded: true,
        icon: const Icon(Icons.expand_more, color: _red, size: 20),
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        items: widget.products.map((p) => DropdownMenuItem(
          value: p,
          child: Text(p.name, overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (v) {
          setState(() => _selProd = v);
          widget.onProductChanged(v);
        },
      ),
    ),
  );

  Widget _typeChip(String value, String label, Color color) {
    final sel = _selType == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selType = value);
        widget.onTypeChanged(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 46,
        decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? color : _border, width: sel ? 1.5 : 1)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(value == 'out' ? Icons.trending_down_rounded : Icons.tune_rounded,
              color: sel ? color : Colors.grey[400], size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? color : Colors.grey[600])),
        ]),
      ),
    );
  }

  InputDecoration _md(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _red, width: 1.5)),
    filled: true,
    fillColor: Colors.grey[50],
    isDense: true,
  );
}