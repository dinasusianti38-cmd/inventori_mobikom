import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../models/user_assembly_model.dart';
import '../service/user_assembly_service.dart';

class UserAssemblyPage extends StatefulWidget {
  final bool isTeamView;
  const UserAssemblyPage({Key? key, this.isTeamView = true}) : super(key: key);

  @override
  _UserAssemblyPageState createState() => _UserAssemblyPageState();
}

class _UserAssemblyPageState extends State<UserAssemblyPage> {
  final UserAssemblyService _service = UserAssemblyService();

  List<AssemblyProject> _projects       = [];
  AssemblyProject?      _selectedProject;
  bool                  _isLoading      = true;
  bool                  _isAssembling   = false;
  String                _errorMessage   = '';

  // ── Banner di atas: muncul sebentar saat ada update dari admin ──────────
  bool   _showSyncBanner = false;
  String _syncBannerMsg  = '';

  @override
  void initState() {
    super.initState();
    _loadProjects(initial: true);
  }

  @override
  void dispose() {
    _service.dispose(); // hentikan polling
    super.dispose();
  }

  bool get isMobile {
    if (kIsWeb) return MediaQuery.of(context).size.width < 800;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Load projects (initial = true → tampilkan spinner + mulai polling)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadProjects({bool initial = false, bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading    = true;
        _errorMessage = '';
      });
    }

    try {
      // forceRefresh agar selalu dapat data baru saat manual refresh
      final projects =
          await _service.getAssemblyProjects(forceRefresh: true);

      if (!mounted) return;
      setState(() {
        _projects  = projects;
        _isLoading = false;

        // Pertahankan selected project jika masih ada
        if (_selectedProject != null) {
          _selectedProject = _projects.firstWhere(
            (p) => p.idP == _selectedProject!.idP,
            orElse: () => _projects.isNotEmpty ? _projects.first : _selectedProject!,
          );
        }
      });

      // Mulai polling hanya saat pertama load
      if (initial) {
        _service.startPolling(_onPollingUpdate);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading    = false;
      });
    }
  }

  // ── Dipanggil service saat polling mendeteksi perubahan dari admin ───────
  void _onPollingUpdate(List<AssemblyProject> updatedProjects) {
    if (!mounted) return;
    setState(() {
      _projects = updatedProjects;

      // Sinkronkan selected project jika ada perubahan
      if (_selectedProject != null) {
        final updated = _projects.where((p) => p.idP == _selectedProject!.idP);
        if (updated.isNotEmpty) _selectedProject = updated.first;
      }

      // Tampilkan banner notifikasi update
      _syncBannerMsg  = 'Data diperbarui oleh admin';
      _showSyncBanner = true;
    });

    // Sembunyikan banner setelah 3 detik
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSyncBanner = false);
    });
  }

  void _selectProject(AssemblyProject project) {
    setState(() => _selectedProject = project);
    if (isMobile) _showMobileDetailSheet(project);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Assemble Dialog
  // ─────────────────────────────────────────────────────────────────────────
  void _showAssembleDialog(AssemblyProject project) {
    final allAvailable = project.materials.every((m) => m.isAvailable);
    if (!allAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Material tidak mencukupi untuk melakukan assembly'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    int quantity = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.build, color: Color(0xFF1976D2)),
            SizedBox(width: 8),
            Expanded(
              child: Text('Proses Assembly',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Produk: ${project.nameP}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Kode: ${project.codeP}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 20),
              const Text('Jumlah yang akan dirakit:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: quantity > 1
                        ? () => setDialogState(() => quantity--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: const Color(0xFF1976D2),
                    iconSize: 32,
                  ),
                  Container(
                    width: 60,
                    alignment: Alignment.center,
                    child: Text('$quantity',
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2))),
                  ),
                  IconButton(
                    onPressed: () => setDialogState(() => quantity++),
                    icon: const Icon(Icons.add_circle_outline),
                    color: const Color(0xFF1976D2),
                    iconSize: 32,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF1976D2), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Material akan dikurangi sesuai kebutuhan per unit × $quantity',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Batal', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton.icon(
              onPressed: _isAssembling
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _processAssembly(project, quantity);
                    },
              icon: const Icon(Icons.build, size: 18),
              label: const Text('Rakit Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Proses Assembly
  // ── Server langsung kembalikan 'data' terbaru → update UI tanpa fetch ulang
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _processAssembly(AssemblyProject project, int quantity) async {
    setState(() => _isAssembling = true);
    try {
      final result = await _service.assembleProduct(project.idP, quantity);

      if (result['status'] == 'success') {
        // ── Langsung gunakan data segar dari response ──────────────────
        if (result['data'] != null) {
          final updated = (result['data'] as List)
              .map((j) =>
                  AssemblyProject.fromJson(j as Map<String, dynamic>))
              .toList();
          setState(() {
            _projects = updated;
            _selectedProject = updated.firstWhere(
              (p) => p.idP == project.idP,
              orElse: () => updated.isNotEmpty ? updated.first : project,
            );
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  '$quantity unit ${project.nameP} berhasil dirakit.'
                  '${result['transaction_code'] != null ? ' (${result['transaction_code']})' : ''}'),
            ),
          ]),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Assembly gagal'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isAssembling = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mobile Detail Bottom Sheet
  // ─────────────────────────────────────────────────────────────────────────
  void _showMobileDetailSheet(AssemblyProject project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.archive, color: Color(0xFF1976D2), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Material untuk ${project.nameP}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800]),
                      ),
                    ),
                    if (!widget.isTeamView &&
                        project.materials.every((m) => m.isAvailable))
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAssembleDialog(project);
                        },
                        icon: const Icon(Icons.build, size: 14),
                        label: const Text('Rakit',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildStatusBanner(project),
                    const SizedBox(height: 16),
                    _buildProjectInfoCard(project),
                    const SizedBox(height: 16),
                    const Text('Daftar Material',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.grey)),
                    const SizedBox(height: 10),
                    ..._buildMaterialCards(project),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Status Banner ────────────────────────────────────────────────────────
  Widget _buildStatusBanner(AssemblyProject project) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: project.getStatusColor().withOpacity(0.1),
        border: Border.all(color: project.getStatusColor().withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(project.getStatusIcon(),
                  color: project.getStatusColor(), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Status: ${project.statusMessage}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: project.getStatusColor()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatusChip(Icons.check_circle, 'Tersedia', Colors.green),
              const SizedBox(width: 12),
              _buildStatusChip(
                  Icons.warning_amber_rounded, 'Terbatas', Colors.orange),
              const SizedBox(width: 12),
              _buildStatusChip(Icons.cancel, 'Kurang', Colors.red),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Total: ${project.totalMaterial}  |  Tersedia: ${project.availableMaterial}'
            '  |  Kurang: ${project.totalMaterial - project.availableMaterial}',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  // ─── Project Info Card ────────────────────────────────────────────────────
  Widget _buildProjectInfoCard(AssemblyProject project) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Kode: ${project.codeP}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Stok: ${project.stokTersedia}',
                  style: const TextStyle(
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          if (project.description != null &&
              project.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(project.description!,
                style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ],
        ],
      ),
    );
  }

  // ─── Material Cards ───────────────────────────────────────────────────────
  List<Widget> _buildMaterialCards(AssemblyProject project) {
    if (project.materials.isEmpty) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Tidak ada material yang dibutuhkan',
                style: TextStyle(color: Colors.grey)),
          ),
        )
      ];
    }

    return project.materials.map((material) {
      final ratio = material.quantityRequired > 0
          ? material.stokTersedia / material.quantityRequired
          : 1.0;
      Color statusColor;
      IconData statusIcon;
      if (ratio >= 1) {
        statusColor = Colors.green;
        statusIcon  = Icons.check_circle;
      } else if (ratio > 0) {
        statusColor = Colors.orange;
        statusIcon  = Icons.warning_amber_rounded;
      } else {
        statusColor = Colors.red;
        statusIcon  = Icons.cancel;
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: statusColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(material.namaM,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(material.codeM,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatBox('Dibutuhkan',
                        '${material.quantityRequired}', material.satuan,
                        Colors.grey.shade800, Colors.grey.shade50),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatBox('Tersedia',
                        '${material.stokTersedia}', material.satuan,
                        statusColor, statusColor.withOpacity(0.06)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildStatBox(
      String label, String value, String unit, Color valueColor, Color bg) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: valueColor)),
          if (unit.isNotEmpty)
            Text(unit,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ─── Project List Item ────────────────────────────────────────────────────
  Widget _buildProjectListItem(AssemblyProject project) {
    final isSelected = _selectedProject?.idP == project.idP;

    return GestureDetector(
      onTap: () => _selectProject(project),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1976D2)
                : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(project.nameP,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isSelected
                              ? const Color(0xFF1976D2)
                              : Colors.grey[800])),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        project.getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(project.getStatusIcon(),
                          color: project.getStatusColor(), size: 14),
                      const SizedBox(width: 4),
                      Text(project.statusMessage,
                          style: TextStyle(
                              color: project.getStatusColor(),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Kode: ${project.codeP}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            if (project.description != null &&
                project.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(project.description!,
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${project.availableMaterial}/${project.totalMaterial} material',
                    style: const TextStyle(
                        color: Color(0xFF1976D2),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text('Stok: ${project.stokTersedia}',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Desktop Detail Panel ─────────────────────────────────────────────────
  Widget _buildDesktopDetailPanel() {
    if (_selectedProject == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Pilih projek untuk melihat detail material',
                style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          ],
        ),
      );
    }

    final project      = _selectedProject!;
    final allAvailable = project.materials.every((m) => m.isAvailable);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.archive,
                  color: Color(0xFF1976D2), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Material untuk ${project.nameP}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                ),
              ),
              if (!widget.isTeamView && allAvailable)
                ElevatedButton.icon(
                  onPressed: _isAssembling
                      ? null
                      : () => _showAssembleDialog(project),
                  icon: _isAssembling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.build, size: 18),
                  label: const Text('Proses Assembly'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildStatusBanner(project),
              const SizedBox(height: 16),
              _buildProjectInfoCard(project),
              const SizedBox(height: 16),
              const Text('Daftar Material',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.grey)),
              const SizedBox(height: 10),
              ..._buildMaterialCards(project),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Error & Empty Views ──────────────────────────────────────────────────
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text('Terjadi Kesalahan',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _loadProjects(),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Belum ada Projek',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  // ─── Sync Banner (muncul saat polling deteksi update admin) ──────────────
  Widget _buildSyncBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _showSyncBanner
          ? Container(
              key: const ValueKey('banner'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1976D2),
              child: Row(
                children: [
                  const Icon(Icons.sync, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_syncBannerMsg,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showSyncBanner = false),
                    child: const Icon(Icons.close,
                        color: Colors.white70, size: 16),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('empty')),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: isMobile ? 12 : 16,
            ),
            child: Row(
              children: [
                Icon(Icons.visibility,
                    size: isMobile ? 22 : 28,
                    color: const Color(0xFF1976D2)),
                const SizedBox(width: 10),
                Text(
                  widget.isTeamView ? 'Monitoring Assembly' : 'Assembly',
                  style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800]),
                ),
                const Spacer(),
                // ── Indikator polling aktif ────────────────────────────
                Tooltip(
                  message: 'Auto-sync aktif (setiap 10 detik)',
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync, color: Colors.green, size: 13),
                        SizedBox(width: 4),
                        Text('Live',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                isMobile
                    ? IconButton(
                        onPressed: () => _loadProjects(),
                        icon: const Icon(Icons.refresh,
                            color: Color(0xFF1976D2)),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _loadProjects(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
              ],
            ),
          ),

          // ── Sync banner (muncul saat ada update dari admin) ────────────
          _buildSyncBanner(),

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF1976D2)))
                : _errorMessage.isNotEmpty
                    ? _buildErrorView()
                    : _projects.isEmpty
                        ? _buildEmptyView()
                        : isMobile
                            ? _buildMobileLayout()
                            : _buildDesktopLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Text('Daftar Projek',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.grey)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_projects.length} projek',
                  style: const TextStyle(
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        ..._projects.map((p) => _buildProjectListItem(p)).toList(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            border:
                Border(right: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    const Text('Daftar Projek',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_projects.length} projek',
                        style: const TextStyle(
                            color: Color(0xFF1976D2),
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: _projects
                      .map((p) => _buildProjectListItem(p))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: _buildDesktopDetailPanel(),
          ),
        ),
      ],
    );
  }
}