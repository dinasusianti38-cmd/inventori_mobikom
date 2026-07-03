import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_assembly_model.dart';
import '../config/api_config.dart';

class UserAssemblyService {
  static const String baseUrl = ApiConfig.baseUrl;

  // ── Polling interval: cek perubahan tiap 10 detik ──────────────────────
  static const Duration _pollInterval = Duration(seconds: 10);

  Timer?  _pollTimer;
  String? _lastSync; // timestamp terakhir dari server

  void Function(List<AssemblyProject>)? _onUpdate;

  // ─────────────────────────────────────────────────────────────────────────
  // Mulai background polling.
  // [onUpdate] dipanggil HANYA saat server punya data lebih baru dari admin.
  // ─────────────────────────────────────────────────────────────────────────
  void startPolling(void Function(List<AssemblyProject> projects) onUpdate) {
    _onUpdate = onUpdate;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkAndSync());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ── Langkah 1: tanya server apakah ada update (payload kecil) ───────────
  // ── Langkah 2: baru fetch data lengkap jika memang ada update ──────────
  Future<void> _checkAndSync() async {
    try {
      final syncParam =
          _lastSync != null ? '&last_sync=${Uri.encodeComponent(_lastSync!)}' : '';
      final uri = Uri.parse(
          '$baseUrl/user_assembly.php?action=check_updates$syncParam');

      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      if (data['status'] != 'success') return;

      if (data['has_update'] == true) {
        // Ada perubahan dari admin — ambil data terbaru
        final projects = await getAssemblyProjects(forceRefresh: true);
        _onUpdate?.call(projects);
      }
    } catch (_) {
      // Gagal polling — diam, coba lagi di interval berikutnya
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET projects
  // ── Dengan last_sync: server balas 'no_change' jika belum ada update
  //    → hemat bandwidth, tidak parse JSON besar sia-sia
  // ── [forceRefresh] = true → abaikan last_sync, paksa ambil semua data
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<AssemblyProject>> getAssemblyProjects(
      {bool forceRefresh = false}) async {
    try {
      final syncParam =
          (!forceRefresh && _lastSync != null)
              ? '&last_sync=${Uri.encodeComponent(_lastSync!)}'
              : '';
      final uri = Uri.parse(
          '$baseUrl/user_assembly.php?action=get_projects$syncParam');

      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      // Tidak ada perubahan sejak last_sync → UI tidak perlu diupdate
      if (data['status'] == 'no_change') return [];

      if (data['status'] == 'success') {
        // Simpan timestamp dari server untuk polling & conditional fetch berikutnya
        if (data['last_update'] != null) {
          _lastSync = data['last_update'] as String;
        }
        return (data['data'] as List)
            .map((j) => AssemblyProject.fromJson(j as Map<String, dynamic>))
            .toList();
      }

      throw Exception(data['message'] ?? 'Gagal memuat data');
    } on TimeoutException {
      throw Exception('Koneksi timeout, coba lagi');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST assemble
  // ── Response dari server sudah berisi 'data' (projects terbaru)
  // ── Caller (UserAssemblyPage) cukup pakai data itu — tidak perlu fetch lagi
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> assembleProduct(
    int productId,
    int quantity, {
    int? userId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/user_assembly.php'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'action'    : 'assemble',
              'product_id': productId,
              'quantity'  : quantity,
              if (userId != null) 'user_id': userId,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // Perbarui lastSync dari response assembly
      // → polling berikutnya tidak akan re-fetch sia-sia
      if (data['last_update'] != null) {
        _lastSync = data['last_update'] as String;
      }

      return data;
    } on TimeoutException {
      throw Exception('Koneksi timeout, coba lagi');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  void dispose() => stopPolling();
}