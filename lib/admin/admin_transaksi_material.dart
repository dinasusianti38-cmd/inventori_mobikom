import 'package:flutter/material.dart';
import '../service/admin_transaksi_material_service.dart';
import '../models/material_transaksi_model.dart';

class TransaksiMaterial extends StatefulWidget {
  @override
  _TransaksiMaterialState createState() => _TransaksiMaterialState();
}

class _TransaksiMaterialState extends State<TransaksiMaterial> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _kodeTransaksiController = TextEditingController();
  final TextEditingController _jumlahController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  MaterialModel? selectedMaterial;
  String selectedJenis = 'in';
  List<MaterialModel> materials = [];
  List<MaterialTransaksiModel> transactions = [];
  List<MaterialTransaksiModel> filteredTransactions = [];
  bool isLoading = false;
  bool isEditMode = false;
  int? editingTransactionId;
  int currentPage = 1;
  int itemsPerPage = 5;
  int totalPages = 1;

  // ─── Responsive helpers ───────────────────────────────────
  bool get _isMobile => _screenWidth < 600;
  bool get _isTablet => _screenWidth >= 600 && _screenWidth < 900;
  double _screenWidth = 0;

  static const Color _blue = Color(0xFF1976D2);
  static const Color _blueLight = Color(0xFFE3F2FD);
  static const Color _green = Color(0xFF4CAF50);
  static const Color _orange = Color(0xFFFF5722);
  static const Color _red = Color(0xFFD32F2F);
  static const Color _textDark = Color(0xFF1A1D23);
  static const Color _textMid = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _tanggalController.text = DateTime.now().toString().split(' ')[0];
    _loadMaterials();
    _loadTransactions();
    searchController.addListener(_filterTransactions);
  }

  @override
  void dispose() {
    _kodeTransaksiController.dispose();
    _jumlahController.dispose();
    _deskripsiController.dispose();
    _tanggalController.dispose();
    searchController.dispose();
    super.dispose();
  }

  // ─── DATA ─────────────────────────────────────────────────
  Future<void> _loadMaterials() async {
    try {
      final list = await AdminTransaksiMaterialService.getMaterials();
      setState(() => materials = list);
    } catch (e) {
      _showSnack('Gagal memuat data barang: $e', error: true);
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => isLoading = true);
    try {
      final list = await AdminTransaksiMaterialService.getTransactions();
      setState(() {
        transactions = list;
        filteredTransactions = list;
        _calcPages();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showSnack('Gagal memuat transaksi: $e', error: true);
    }
  }

  void _filterTransactions() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filteredTransactions = q.isEmpty
          ? transactions
          : transactions.where((t) =>
              (t.namaMaterial ?? '').toLowerCase().contains(q) ||
              (t.transactionCode ?? '').toLowerCase().contains(q) ||
              (t.notes ?? '').toLowerCase().contains(q)).toList();
      currentPage = 1;
      _calcPages();
    });
  }

  void _calcPages() {
    totalPages = (filteredTransactions.length / itemsPerPage).ceil();
    if (totalPages < 1) totalPages = 1;
  }

  List<MaterialTransaksiModel> get _pageRows {
    final s = (currentPage - 1) * itemsPerPage;
    final e = (s + itemsPerPage).clamp(0, filteredTransactions.length);
    return filteredTransactions.sublist(s, e);
  }

  // ─── CRUD ─────────────────────────────────────────────────
  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedMaterial == null) {
      _showSnack('Pilih barang terlebih dahulu', error: true);
      return;
    }
    setState(() => isLoading = true);
    try {
      Map<String, dynamic> response;
      if (isEditMode && editingTransactionId != null) {
        response = await AdminTransaksiMaterialService.updateTransaction(
          idTm: editingTransactionId!,
          materialId: selectedMaterial!.idM!,
          transactionType: selectedJenis,
          jumlah: int.parse(_jumlahController.text),
          transactionDate: _tanggalController.text,
          notes: _deskripsiController.text,
          createdBy: 1,
          transactionCode: _kodeTransaksiController.text.isEmpty
              ? AdminTransaksiMaterialService.generateTransactionCode()
              : _kodeTransaksiController.text,
        );
        if (response['status'] == 'success') {
          _showSnack('Transaksi berhasil diperbarui');
          _cancelEdit();
          await _loadTransactions();
          await _loadMaterials();
        } else {
          _showSnack(response['message'] ?? 'Gagal memperbarui', error: true);
        }
      } else {
        response = await AdminTransaksiMaterialService.createTransaction(
          materialId: selectedMaterial!.idM!,
          transactionType: selectedJenis,
          jumlah: int.parse(_jumlahController.text),
          transactionDate: _tanggalController.text,
          notes: _deskripsiController.text,
          createdBy: 1,
          transactionCode: _kodeTransaksiController.text.isEmpty
              ? null
              : _kodeTransaksiController.text,
        );
        if (response['status'] == 'success') {
          _showSnack('Transaksi berhasil ditambahkan');
          _clearForm();
          await _loadTransactions();
          await _loadMaterials();
        } else {
          _showSnack(response['message'] ?? 'Gagal menambahkan', error: true);
        }
      }
    } catch (e) {
      _showSnack('Error: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteTransaction(int idTm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
          const SizedBox(width: 8),
          const Text('Hapus Transaksi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
            'Apakah kamu yakin ingin menghapus transaksi ini? Stok akan disesuaikan kembali.'),
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
    try {
      final r = await AdminTransaksiMaterialService.deleteTransaction(idTm);
      if (r['status'] == 'success') {
        _showSnack('Transaksi dihapus');
        await _loadTransactions();
        await _loadMaterials();
      } else {
        _showSnack(r['message'] ?? 'Gagal menghapus', error: true);
      }
    } catch (e) {
      _showSnack('Error: $e', error: true);
    }
  }

  void _editTransaction(MaterialTransaksiModel t) {
    setState(() {
      isEditMode = true;
      editingTransactionId = t.idTm;
      _kodeTransaksiController.text = t.transactionCode ?? '';
      _jumlahController.text = t.jumlah?.toString() ?? '';
      _deskripsiController.text = t.notes ?? '';
      _tanggalController.text = t.transactionDate ?? '';
      selectedJenis = t.transactionType ?? 'in';
      selectedMaterial = materials.isNotEmpty && t.materialId != null
          ? materials.firstWhere((m) => m.idM == t.materialId,
              orElse: () => materials.first)
          : null;
    });
    // On mobile: scroll to top / show form bottom sheet
    if (_isMobile) _showMobileFormSheet();
  }

  void _cancelEdit() {
    setState(() {
      isEditMode = false;
      editingTransactionId = null;
    });
    _clearForm();
  }

  void _clearForm() {
    _kodeTransaksiController.clear();
    _jumlahController.clear();
    _deskripsiController.clear();
    _tanggalController.text = DateTime.now().toString().split(' ')[0];
    setState(() {
      selectedMaterial = null;
      selectedJenis = 'in';
    });
  }

  // ─── MOBILE FORM BOTTOM SHEET ─────────────────────────────
  void _showMobileFormSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MobileFormSheet(
        formKey: _formKey,
        kodeController: _kodeTransaksiController,
        jumlahController: _jumlahController,
        deskripsiController: _deskripsiController,
        tanggalController: _tanggalController,
        materials: materials,
        selectedMaterial: selectedMaterial,
        selectedJenis: selectedJenis,
        isEditMode: isEditMode,
        isLoading: isLoading,
        onMaterialChanged: (v) => setState(() => selectedMaterial = v),
        onJenisChanged: (v) => setState(() => selectedJenis = v!),
        onSubmit: () {
          Navigator.pop(context);
          _submitTransaction();
        },
        onCancel: () {
          Navigator.pop(context);
          _cancelEdit();
        },
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────
  void _showSnack(String msg, {bool error = false}) {
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

  // ─── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // FAB hanya di mobile untuk tambah transaksi
      floatingActionButton: _isMobile
          ? FloatingActionButton.extended(
              onPressed: () {
                if (isEditMode) _cancelEdit();
                _showMobileFormSheet();
              },
              backgroundColor: _blue,
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

  // ─── MOBILE LAYOUT ────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Search bar sticky
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            controller: searchController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari transaksi...',
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
                  borderSide: const BorderSide(color: _blue, width: 1.5)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ),
        const Divider(height: 1),

        // Transaction list
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _blue))
              : filteredTransactions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: _pageRows.length,
                      itemBuilder: (_, i) => _buildMobileCard(_pageRows[i],
                          (currentPage - 1) * itemsPerPage + i),
                    ),
        ),

        // Pagination strip
        if (!isLoading && filteredTransactions.isNotEmpty)
          _buildMobilePagination(),
      ],
    );
  }

  Widget _buildMobileCard(MaterialTransaksiModel t, int index) {
    final isIn = t.transactionType == 'in';
    final typeColor = isIn ? _green : _orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: typeColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          isIn ? Icons.trending_up : Icons.trending_down,
                          size: 13,
                          color: typeColor),
                      const SizedBox(width: 4),
                      Text(isIn ? 'Masuk' : 'Keluar',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: typeColor)),
                    ],
                  ),
                ),
                const Spacer(),
                Text(t.transactionDate ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.namaMaterial ?? 'N/A',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _textDark)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.tag, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(t.transactionCode ?? '-',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const Spacer(),
                  Text('${t.jumlah ?? 0} ${t.satuan ?? ''}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: typeColor)),
                ]),
                if ((t.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(t.notes!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editTransaction(t),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: _blue),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteTransaction(t.idTm!),
                    icon: const Icon(Icons.delete_outline, size: 14),
                    label: const Text('Hapus',
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: const BorderSide(color: _red),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePagination() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            '${(currentPage - 1) * itemsPerPage + 1}–'
            '${((currentPage - 1) * itemsPerPage + _pageRows.length)} '
            'dari ${filteredTransactions.length}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const Spacer(),
          _pgChip('‹', currentPage > 1, () => setState(() => currentPage--)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: _blue, borderRadius: BorderRadius.circular(6)),
            child: Text('$currentPage',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 6),
          _pgChip('›', currentPage < totalPages,
              () => setState(() => currentPage++)),
        ],
      ),
    );
  }

  // ─── DESKTOP LAYOUT ───────────────────────────────────────
  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        children: [
          _buildDesktopFormCard(),
          const SizedBox(height: 24),
          _buildDesktopTableCard(),
        ],
      ),
    );
  }

  Widget _buildDesktopFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecor(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isEditMode
                          ? Colors.orange.withOpacity(0.1)
                          : _blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                        isEditMode ? Icons.edit : Icons.add_box,
                        color: isEditMode ? Colors.orange : _blue,
                        size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditMode
                        ? 'Edit Transaksi Barang'
                        : 'Tambah Transaksi Barang',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800]),
                  ),
                ]),
                if (isEditMode)
                  TextButton.icon(
                    onPressed: _cancelEdit,
                    icon: const Icon(Icons.close, size: 15),
                    label: const Text('Batal'),
                    style: TextButton.styleFrom(foregroundColor: _red),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Row 1
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: _fieldWrap('Nama Barang', _dropdownMaterial())),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: _fieldWrap('Jumlah', _jumlahField())),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _fieldWrap('Deskripsi', _deskripsiField())),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: _fieldWrap('Tanggal', _tanggalField())),
            ]),
            const SizedBox(height: 16),

            // Row 2
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                flex: 2,
                child: _fieldWrap('Kode Transaksi (opsional)', _kodeField()),
              ),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _fieldWrap('Jenis', _jenisRadioDesktop())),
              const SizedBox(width: 16),
              _submitButton(),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTableCard() {
    return Container(
      width: double.infinity,
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Text('Daftar Transaksi Barang',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800])),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('Show', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(width: 8),
              _entriesDropdown(),
              const SizedBox(width: 8),
              Text('Entries', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const Spacer(),
              SizedBox(width: 240, child: _searchField()),
            ]),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: _blue)))
          else if (filteredTransactions.isEmpty)
            _buildEmptyState()
          else
            _buildDesktopTable(),
          if (!isLoading && filteredTransactions.isNotEmpty)
            _buildDesktopPagination(),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    const headers = [
      'No', 'Nama Barang', 'Kode Transaksi',
      'Deskripsi', 'Jumlah', 'Tanggal', 'Aksi'
    ];
    const flex = [1, 3, 2, 3, 2, 2, 2];
    final rows = _pageRows;
    final start = (currentPage - 1) * itemsPerPage;

    return Column(children: [
      // Header
      Container(
        decoration: BoxDecoration(
          color: _blue.withOpacity(0.06),
          border: Border(
              top: BorderSide(color: Colors.grey.shade200),
              bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: List.generate(headers.length, (i) => Expanded(
            flex: flex[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Text(headers[i],
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _blue)),
            ),
          )),
        ),
      ),
      // Rows
      ...rows.asMap().entries.map((e) {
        final i = e.key;
        final t = e.value;
        final isIn = t.transactionType == 'in';
        final tc = isIn ? _green : _orange;
        return Column(children: [
          Container(
            color: i % 2 == 0 ? Colors.white : const Color(0xFFFAFBFC),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _dCell(flex[0], Text('${start + i + 1}',
                    style: const TextStyle(fontSize: 13, color: _textMid))),
                _dCell(flex[1], Text(t.namaMaterial ?? '-',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _textDark),
                    overflow: TextOverflow.ellipsis, maxLines: 2)),
                _dCell(flex[2], Text(t.transactionCode ?? '-',
                    style: const TextStyle(fontSize: 12, color: _textMid),
                    overflow: TextOverflow.ellipsis)),
                _dCell(flex[3], Text(t.notes ?? '-',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis, maxLines: 2)),
                _dCell(flex[4], Row(children: [
                  Icon(isIn ? Icons.trending_up : Icons.trending_down,
                      size: 13, color: tc),
                  const SizedBox(width: 4),
                  Text('${t.jumlah ?? 0} ${t.satuan ?? ''}',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: tc)),
                ])),
                _dCell(flex[5], Text(t.transactionDate ?? '-',
                    style: const TextStyle(fontSize: 12, color: _textMid))),
                _dCell(flex[6], Row(mainAxisSize: MainAxisSize.min, children: [
                  _actionBtn(Icons.edit_outlined, _blue, () => _editTransaction(t)),
                  const SizedBox(width: 6),
                  _actionBtn(Icons.delete_outline, _red, () => _deleteTransaction(t.idTm!)),
                ])),
              ]),
            ),
          ),
          Divider(height: 1, thickness: 0.8, color: Colors.grey.shade200),
        ]);
      }),
    ]);
  }

  Widget _buildDesktopPagination() {
    final start = (currentPage - 1) * itemsPerPage + 1;
    final end = (start + itemsPerPage - 1).clamp(0, filteredTransactions.length);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Text('Showing $start to $end of ${filteredTransactions.length} entries',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const Spacer(),
        Row(children: [
          _pgChip('Previous', currentPage > 1, () => setState(() => currentPage--)),
          const SizedBox(width: 4),
          ...List.generate(_totalPages.clamp(0, 5), (i) {
            final p = i + 1;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => setState(() => currentPage = p),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 32, height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: currentPage == p ? _blue : Colors.white,
                    border: Border.all(color: currentPage == p ? _blue : _border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$p',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: currentPage == p ? Colors.white : _textMid)),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          _pgChip('Next', currentPage < totalPages, () => setState(() => currentPage++)),
        ]),
      ]),
    );
  }

  // ─── MICRO WIDGETS ────────────────────────────────────────
  Widget _dropdownMaterial() => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50]),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<MaterialModel>(
        value: selectedMaterial,
        hint: Text('Pilih Barang',
            style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        isExpanded: true,
        icon: const Icon(Icons.expand_more, color: _blue, size: 18),
        style: const TextStyle(fontSize: 13, color: _textDark),
        items: materials.map((m) => DropdownMenuItem(
          value: m,
          child: Text(
              '${m.namaM ?? '-'} (Stok: ${m.stokTersedia ?? 0})',
              overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (v) => setState(() => selectedMaterial = v),
      ),
    ),
  );

  Widget _jumlahField() => TextFormField(
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
  );

  Widget _deskripsiField() => TextFormField(
    controller: _deskripsiController,
    style: const TextStyle(fontSize: 13),
    decoration: _deco('Tambahkan deskripsi...'),
  );

  Widget _tanggalField() => TextFormField(
    controller: _tanggalController,
    readOnly: true,
    style: const TextStyle(fontSize: 13),
    decoration: _deco('Pilih tanggal').copyWith(
      suffixIcon: const Icon(Icons.calendar_today_rounded, color: _blue, size: 16),
    ),
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: _blue)),
          child: child!,
        ),
      );
      if (d != null) {
        _tanggalController.text = d.toString().split(' ')[0];
      }
    },
    validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
  );

  Widget _kodeField() => TextFormField(
    controller: _kodeTransaksiController,
    style: const TextStyle(fontSize: 13),
    decoration: _deco('Auto generate jika kosong'),
  );

  Widget _jenisRadioDesktop() => Row(children: [
    _radioChip('in', 'Masuk', _green),
    const SizedBox(width: 8),
    _radioChip('out', 'Keluar', _orange),
  ]);

  Widget _radioChip(String value, String label, Color color) {
    final selected = selectedJenis == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedJenis = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? color : _border,
                width: selected ? 1.5 : 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(value == 'in' ? Icons.trending_up : Icons.trending_down,
                color: selected ? color : Colors.grey[400], size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? color : _textMid)),
          ]),
        ),
      ),
    );
  }

  Widget _submitButton() => ElevatedButton.icon(
    onPressed: isLoading ? null : _submitTransaction,
    style: ElevatedButton.styleFrom(
      backgroundColor: isEditMode ? Colors.orange : _blue,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
    ),
    icon: isLoading
        ? const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white)))
        : Icon(isEditMode ? Icons.save_outlined : Icons.add, size: 16),
    label: Text(isEditMode ? 'Update' : 'Simpan',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  );

  Widget _entriesDropdown() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: itemsPerPage,
        isDense: true,
        style: const TextStyle(fontSize: 13, color: _textDark),
        items: [5, 10, 25, 50]
            .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() { itemsPerPage = v; currentPage = 1; _calcPages(); });
        },
      ),
    ),
  );

  Widget _searchField() => TextField(
    controller: searchController,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      hintText: 'Search :',
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
      prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[400]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue, width: 1.5)),
      filled: true,
      fillColor: Colors.grey[50],
    ),
  );

  Widget _fieldWrap(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700])),
      const SizedBox(height: 5),
      child,
    ],
  );

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _blue, width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade300)),
    filled: true,
    fillColor: Colors.grey[50],
    isDense: true,
  );

  Widget _dCell(int flex, Widget child) => Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.centerLeft,
      child: child,
    ),
  );

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) =>
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

  Widget _pgChip(String label, bool enabled, VoidCallback onTap) =>
      InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: enabled ? Colors.white : const Color(0xFFF3F4F6),
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(6)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: enabled ? _textDark : Colors.grey[400])),
        ),
      );

  Widget _buildEmptyState() => Padding(
    padding: const EdgeInsets.all(40),
    child: Center(
      child: Column(children: [
        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text('Belum ada transaksi',
            style: TextStyle(fontSize: 14, color: Colors.grey[500])),
      ]),
    ),
  );

  BoxDecoration _cardDecor() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2))
    ],
  );

  int get _totalPages => totalPages;
}

// ─── MOBILE FORM BOTTOM SHEET ─────────────────────────────
class _MobileFormSheet extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController kodeController;
  final TextEditingController jumlahController;
  final TextEditingController deskripsiController;
  final TextEditingController tanggalController;
  final List<MaterialModel> materials;
  final MaterialModel? selectedMaterial;
  final String selectedJenis;
  final bool isEditMode;
  final bool isLoading;
  final ValueChanged<MaterialModel?> onMaterialChanged;
  final ValueChanged<String?> onJenisChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _MobileFormSheet({
    required this.formKey,
    required this.kodeController,
    required this.jumlahController,
    required this.deskripsiController,
    required this.tanggalController,
    required this.materials,
    required this.selectedMaterial,
    required this.selectedJenis,
    required this.isEditMode,
    required this.isLoading,
    required this.onMaterialChanged,
    required this.onJenisChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<_MobileFormSheet> createState() => _MobileFormSheetState();
}

class _MobileFormSheetState extends State<_MobileFormSheet> {
  static const Color _blue = Color(0xFF1976D2);
  static const Color _border = Color(0xFFE0E0E0);
  static const Color _green = Color(0xFF4CAF50);
  static const Color _orange = Color(0xFFFF5722);

  late MaterialModel? _selMat;
  late String _selJenis;

  @override
  void initState() {
    super.initState();
    _selMat = widget.selectedMaterial;
    _selJenis = widget.selectedJenis;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomPad),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: widget.isEditMode
                      ? Colors.orange.withOpacity(0.1)
                      : _blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                    widget.isEditMode ? Icons.edit : Icons.add_box,
                    color: widget.isEditMode ? Colors.orange : _blue,
                    size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                widget.isEditMode ? 'Edit Transaksi' : 'Tambah Transaksi',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, size: 20),
                padding: EdgeInsets.zero,
              ),
            ]),
          ),

          const Divider(height: 16),

          // Form fields
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Form(
                key: widget.formKey,
                child: Column(children: [
                  _mLabel('Nama Barang'),
                  _materialDropdown(),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _mLabel('Jumlah'),
                      TextFormField(
                        controller: widget.jumlahController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14),
                        decoration: _mdeco('Masukkan jumlah'),
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
                      _mLabel('Tanggal'),
                      TextFormField(
                        controller: widget.tanggalController,
                        readOnly: true,
                        style: const TextStyle(fontSize: 14),
                        decoration: _mdeco('Pilih tanggal').copyWith(
                          suffixIcon: const Icon(Icons.calendar_today, color: _blue, size: 16),
                        ),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) {
                            widget.tanggalController.text =
                                d.toString().split(' ')[0];
                          }
                        },
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Wajib diisi' : null,
                      ),
                    ])),
                  ]),
                  const SizedBox(height: 14),
                  _mLabel('Deskripsi (opsional)'),
                  TextFormField(
                    controller: widget.deskripsiController,
                    style: const TextStyle(fontSize: 14),
                    decoration: _mdeco('Tambahkan keterangan...'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  _mLabel('Kode Transaksi (opsional)'),
                  TextFormField(
                    controller: widget.kodeController,
                    style: const TextStyle(fontSize: 14),
                    decoration: _mdeco('Auto generate jika kosong'),
                  ),
                  const SizedBox(height: 14),
                  _mLabel('Jenis Transaksi'),
                  Row(children: [
                    Expanded(child: _mRadio('in', 'Masuk', _green)),
                    const SizedBox(width: 10),
                    Expanded(child: _mRadio('out', 'Keluar', _orange)),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.isLoading ? null : widget.onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            widget.isEditMode ? Colors.orange : _blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.isEditMode ? 'Update Transaksi' : 'Simpan Transaksi',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mLabel(String t) => Padding(
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

  Widget _materialDropdown() => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey[50]),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<MaterialModel>(
        value: _selMat,
        hint: Text('Pilih Barang',
            style: TextStyle(fontSize: 14, color: Colors.grey[400])),
        isExpanded: true,
        icon: const Icon(Icons.expand_more, color: _blue, size: 20),
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        items: widget.materials.map((m) => DropdownMenuItem(
          value: m,
          child: Text('${m.namaM ?? '-'} (Stok: ${m.stokTersedia ?? 0})',
              overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (v) {
          setState(() => _selMat = v);
          widget.onMaterialChanged(v);
        },
      ),
    ),
  );

  Widget _mRadio(String value, String label, Color color) {
    final sel = _selJenis == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selJenis = value);
        widget.onJenisChanged(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 46,
        decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel ? color : _border, width: sel ? 1.5 : 1)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(value == 'in' ? Icons.trending_up : Icons.trending_down,
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

  InputDecoration _mdeco(String hint) => InputDecoration(
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
        borderSide: const BorderSide(color: _blue, width: 1.5)),
    filled: true,
    fillColor: Colors.grey[50],
    isDense: true,
  );
}