<?php
require_once 'conn.php';

// ═══════════════════════════════════════════════════════════════════════════
// HELPER: Ambil timestamp update terakhir dari semua tabel yang relevan
// Dipakai Flutter untuk mendeteksi apakah ada perubahan dari admin
// ═══════════════════════════════════════════════════════════════════════════
function getLastUpdateTimestamp($connect) {
    $sql = "SELECT GREATEST(
                COALESCE((SELECT MAX(updated_at)   FROM products),          '1970-01-01 00:00:00'),
                COALESCE((SELECT MAX(updated_at)   FROM materials),         '1970-01-01 00:00:00'),
                COALESCE((SELECT MAX(updated_at)   FROM product_materials), '1970-01-01 00:00:00'),
                COALESCE((SELECT MAX(last_updated) FROM material_stocks),   '1970-01-01 00:00:00'),
                COALESCE((SELECT MAX(last_updated) FROM product_stocks),    '1970-01-01 00:00:00')
            ) AS last_update";
    $row = $connect->query($sql)->fetch_assoc();
    return $row['last_update'] ?? null;
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER: Bangun array projects lengkap dengan material & status
// ═══════════════════════════════════════════════════════════════════════════
function buildProjects($connect) {
    $query = "SELECT 
                p.id_p, 
                p.code_p, 
                p.name_p, 
                p.description, 
                COALESCE(ps.stok_tersedia, 0) AS stok_tersedia
              FROM products p
              LEFT JOIN product_stocks ps ON p.id_p = ps.product_id
              ORDER BY p.name_p";

    $result = $connect->query($query);
    if (!$result) {
        throw new Exception('Gagal mengambil data produk: ' . $connect->error);
    }

    $projects = [];
    $seenIds  = [];

    while ($row = $result->fetch_assoc()) {
        $productId = $row['id_p'];
        if (in_array($productId, $seenIds)) continue;
        $seenIds[] = $productId;

        // ── Material per produk ──────────────────────────────────────────
        $materialQuery = "SELECT 
                            m.id_m, 
                            m.code_m, 
                            m.nama_m, 
                            m.satuan,
                            SUM(pm.quantity)              AS quantity_required,
                            COALESCE(ms.stok_tersedia, 0) AS stok_tersedia,
                            CASE 
                                WHEN COALESCE(ms.stok_tersedia, 0) >= SUM(pm.quantity) THEN 1 
                                ELSE 0 
                            END                           AS is_available
                          FROM product_materials pm
                          JOIN  materials m         ON pm.material_id = m.id_m
                          LEFT JOIN material_stocks ms ON m.id_m      = ms.material_id
                          WHERE pm.product_id = ?
                          GROUP BY m.id_m, m.code_m, m.nama_m, m.satuan, ms.stok_tersedia
                          ORDER BY m.nama_m";

        $stmt = $connect->prepare($materialQuery);
        $stmt->bind_param("i", $productId);
        $stmt->execute();
        $matResult = $stmt->get_result();
        $stmt->close();

        $materials       = [];
        $seenMaterialIds = [];
        $totalMaterial   = 0;

        while ($mat = $matResult->fetch_assoc()) {
            $matId = $mat['id_m'];
            if (isset($seenMaterialIds[$matId])) {
                $idx = $seenMaterialIds[$matId];
                $materials[$idx]['quantity_required'] += $mat['quantity_required'];
                $materials[$idx]['is_available'] =
                    ($materials[$idx]['stok_tersedia'] >= $materials[$idx]['quantity_required']) ? 1 : 0;
            } else {
                $seenMaterialIds[$matId] = $totalMaterial;
                $materials[]             = $mat;
                $totalMaterial++;
            }
        }

        $availableMaterial = 0;
        foreach ($materials as $m) {
            if ($m['is_available']) $availableMaterial++;
        }

        if (empty($materials)) {
            $status  = 'pending'; $status_message = 'Tidak ada material';
        } elseif ($availableMaterial === $totalMaterial) {
            $status  = 'ready';   $status_message = 'Siap Dirakit';
        } elseif ($availableMaterial > 0) {
            $status  = 'partial'; $status_message = 'Material Kurang';
        } else {
            $status  = 'blocked'; $status_message = 'Material Habis';
        }

        $row['status']             = $status;
        $row['status_message']     = $status_message;
        $row['available_material'] = $availableMaterial;
        $row['total_material']     = $totalMaterial;
        $row['materials']          = array_values($materials);
        $projects[]                = $row;
    }

    return $projects;
}

// ═══════════════════════════════════════════════════════════════════════════
// GET: action=get_projects
// ── Mendukung ?last_sync=<timestamp> → kalau belum berubah, balas no_change
// ═══════════════════════════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'GET'
    && isset($_GET['action'])
    && $_GET['action'] === 'get_projects') {

    try {
        $lastUpdate = getLastUpdateTimestamp($connect);

        // Kalau client kirim last_sync dan data belum berubah → hemat query
        if (!empty($_GET['last_sync'])) {
            if ($lastUpdate !== null
                && strtotime($lastUpdate) <= strtotime($_GET['last_sync'])) {
                echo json_encode([
                    'status'      => 'no_change',
                    'last_update' => $lastUpdate,
                ]);
                $connect->close();
                exit;
            }
        }

        $projects = buildProjects($connect);
        echo json_encode([
            'status'      => 'success',
            'last_update' => $lastUpdate,   // ← Flutter simpan ini sebagai last_sync
            'data'        => $projects,
        ]);

    } catch (Exception $e) {
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// GET: action=check_updates  (endpoint polling ringan)
// ── Flutter polling tiap N detik, hanya kirim last_sync
// ── Server balas {has_update: true/false} — TANPA data besar
// ═══════════════════════════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'GET'
    && isset($_GET['action'])
    && $_GET['action'] === 'check_updates') {

    try {
        $lastUpdate = getLastUpdateTimestamp($connect);
        $hasUpdate  = false;

        if (!empty($_GET['last_sync'])) {
            $hasUpdate = ($lastUpdate !== null
                && strtotime($lastUpdate) > strtotime($_GET['last_sync']));
        }

        echo json_encode([
            'status'      => 'success',
            'has_update'  => $hasUpdate,
            'last_update' => $lastUpdate,
        ]);

    } catch (Exception $e) {
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// POST: action=assemble
// ── Catat transaksi ke material_transactions & product_transactions
// ── Response langsung berisi data terbaru → Flutter tidak perlu fetch ulang
// ═══════════════════════════════════════════════════════════════════════════
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);

    if (isset($input['action']) && $input['action'] === 'assemble') {
        $productId = (int)($input['product_id'] ?? 0);
        $quantity  = (int)($input['quantity']   ?? 0);
        $userId    = isset($input['user_id']) ? (int)$input['user_id'] : null;

        if ($productId <= 0 || $quantity <= 0) {
            echo json_encode(['status' => 'error', 'message' => 'Parameter tidak valid']);
            $connect->close();
            exit;
        }

        try {
            $connect->begin_transaction();

            // ── 1. Lock baris material_stocks agar tidak race condition ──
            $checkQuery = "SELECT 
                            m.id_m,
                            m.nama_m,
                            SUM(pm.quantity)              AS required,
                            COALESCE(ms.stok_tersedia, 0) AS available
                          FROM product_materials pm
                          JOIN  materials m         ON pm.material_id = m.id_m
                          LEFT JOIN material_stocks ms ON m.id_m      = ms.material_id
                          WHERE pm.product_id = ?
                          GROUP BY m.id_m, m.nama_m, ms.stok_tersedia
                          FOR UPDATE";

            $stmt = $connect->prepare($checkQuery);
            $stmt->bind_param("i", $productId);
            $stmt->execute();
            $result = $stmt->get_result();
            $stmt->close();

            $materials    = [];
            $seenMats     = [];
            $insufficient = [];

            while ($row = $result->fetch_assoc()) {
                $matId         = $row['id_m'];
                $totalRequired = (int)$row['required'] * $quantity;

                if (isset($seenMats[$matId])) {
                    $materials[$seenMats[$matId]]['required'] += $totalRequired;
                } else {
                    $seenMats[$matId] = count($materials);
                    $materials[] = [
                        'id'        => $matId,
                        'nama'      => $row['nama_m'],
                        'required'  => $totalRequired,
                        'available' => (int)$row['available'],
                    ];
                }
            }

            foreach ($materials as $mat) {
                if ($mat['available'] < $mat['required']) {
                    $kurang         = $mat['required'] - $mat['available'];
                    $insufficient[] = "{$mat['nama']} (kurang {$kurang})";
                }
            }

            if (!empty($insufficient)) {
                throw new Exception('Material tidak mencukupi: ' . implode(', ', $insufficient));
            }

            // ── 2. Kode transaksi unik ───────────────────────────────────
            $txCode = 'ASM-' . date('Ymd') . '-' . strtoupper(substr(uniqid(), -6));
            $txDate = date('Y-m-d');

            // ── 3. Kurangi stok material + catat material_transactions ───
            foreach ($materials as $mat) {
                $stokSebelum = $mat['available'];
                $stokSesudah = $stokSebelum - $mat['required'];

                // Update stok
                $upd = $connect->prepare(
                    "UPDATE material_stocks 
                     SET stok_tersedia = stok_tersedia - ?, last_updated = NOW()
                     WHERE material_id = ?"
                );
                $upd->bind_param("ii", $mat['required'], $mat['id']);
                $upd->execute();
                $upd->close();

                // Catat transaksi keluar
                $notes = "Assembly {$txCode} — {$quantity} unit produk";
                $tx = $connect->prepare(
                    "INSERT INTO material_transactions
                        (transaction_code, material_id, transaction_type,
                         jumlah, stok_sebelum, stok_sesudah,
                         transaction_date, notes, created_by)
                     VALUES (?, ?, 'out', ?, ?, ?, ?, ?, ?)"
                );
                $tx->bind_param(
                    "siiiiisi",
                    $txCode, $mat['id'], $mat['required'],
                    $stokSebelum, $stokSesudah, $txDate, $notes, $userId
                );
                $tx->execute();
                $tx->close();
            }

            // ── 4. Ambil stok produk sebelum update ──────────────────────
            $ps = $connect->prepare(
                "SELECT COALESCE(stok_tersedia, 0) AS stok 
                 FROM product_stocks WHERE product_id = ?"
            );
            $ps->bind_param("i", $productId);
            $ps->execute();
            $psRow       = $ps->get_result()->fetch_assoc();
            $prodBefore  = $psRow ? (int)$psRow['stok'] : 0;
            $prodAfter   = $prodBefore + $quantity;
            $ps->close();

            // ── 5. Upsert product_stocks ─────────────────────────────────
            $ups = $connect->prepare(
                "INSERT INTO product_stocks 
                    (product_id, stok_tersedia, stok_minimal, last_updated, updated_by)
                 VALUES (?, ?, 0, NOW(), ?)
                 ON DUPLICATE KEY UPDATE 
                    stok_tersedia = stok_tersedia + ?,
                    last_updated  = NOW(),
                    updated_by    = ?"
            );
            $ups->bind_param("iiiii", $productId, $quantity, $userId, $quantity, $userId);
            $ups->execute();
            $ups->close();

            // ── 6. Catat product_transactions ────────────────────────────
            $ptNotes = "Hasil assembly {$txCode}";
            $pt = $connect->prepare(
                "INSERT INTO product_transactions
                    (transaction_code, product_id, transaction_type,
                     jumlah, stok_sebelum, stok_sesudah,
                     transaction_date, notes, created_by)
                 VALUES (?, ?, 'in', ?, ?, ?, ?, ?, ?)"
            );
            $pt->bind_param(
                "siiiiisi",
                $txCode, $productId, $quantity,
                $prodBefore, $prodAfter, $txDate, $ptNotes, $userId
            );
            $pt->execute();
            $pt->close();

            $connect->commit();

            // ── 7. Kembalikan data SEGAR langsung → Flutter langsung update UI
            $projects   = buildProjects($connect);
            $lastUpdate = getLastUpdateTimestamp($connect);

            echo json_encode([
                'status'           => 'success',
                'message'          => 'Assembly berhasil',
                'transaction_code' => $txCode,
                'last_update'      => $lastUpdate,
                'data'             => $projects, // ← Flutter pakai ini, tidak perlu fetch lagi
            ]);

        } catch (Exception $e) {
            $connect->rollback();
            echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
        }
    }
}

$connect->close();
?>