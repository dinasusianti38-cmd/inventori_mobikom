<?php
ini_set('display_errors', 0);
error_reporting(E_ALL);
ini_set('log_errors', 1);

require_once 'conn.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    $json = file_get_contents('php://input');
    error_log("assembly_process INPUT: " . $json);

    $data = json_decode($json, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception("Invalid JSON: " . json_last_error_msg());
    }

    if (!isset($data['product_id']) || !isset($data['quantity'])) {
        throw new Exception("product_id dan quantity wajib diisi");
    }

    $product_id = (int)$data['product_id'];
    $quantity   = (int)$data['quantity'];
    $user_id    = isset($data['user_id']) ? (int)$data['user_id'] : 1;

    if ($product_id <= 0) throw new Exception("Product ID tidak valid");
    if ($quantity <= 0)   throw new Exception("Quantity harus lebih dari 0");

    if (!$connect) throw new Exception("Koneksi database gagal");

    $connect->begin_transaction();

    try {
        // ── 1. Get product info ──────────────────────────────
        $stmt = $connect->prepare("SELECT id_p, name_p FROM products WHERE id_p = ?");
        if (!$stmt) throw new Exception("Prepare step1 gagal: " . $connect->error);
        $stmt->bind_param("i", $product_id);
        $stmt->execute();
        $product_info = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$product_info) throw new Exception("Produk tidak ditemukan (id=$product_id)");

        // ── 1b. Cek apakah produk sudah berstatus 'done' ─────
        // Jika sudah done (pernah di-assembly), BLOKIR langsung
        $stmt = $connect->prepare(
            "SELECT assembly_status FROM product_assembly_status WHERE product_id = ? LIMIT 1"
        );
        // Jika tabel belum ada, skip pengecekan ini (graceful degradation)
        if ($stmt) {
            $stmt->bind_param("i", $product_id);
            $stmt->execute();
            $status_row = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            if ($status_row && $status_row['assembly_status'] === 'done') {
                $connect->rollback();
                http_response_code(200);
                echo json_encode([
                    'status'      => 'error',
                    'result_type' => 'blocked',
                    'message'     => 'Produk ini sudah pernah di-assembly dan telah selesai. Assembly tidak dapat diproses ulang.',
                    'data'        => [
                        'product_id'   => $product_id,
                        'product_name' => $product_info['name_p'],
                        'reason'       => 'already_done',
                    ],
                ], JSON_UNESCAPED_UNICODE);
                exit();
            }
        }

        // ── 2. Ambil semua material ──────────────────────────
        $stmt = $connect->prepare(
            "SELECT pm.material_id, m.nama_m,
                    pm.quantity AS required_qty,
                    COALESCE(
                        (SELECT ms2.stok_tersedia
                         FROM material_stocks ms2
                         WHERE ms2.material_id = m.id_m
                         ORDER BY ms2.last_updated DESC, ms2.id_sm DESC
                         LIMIT 1),
                    0) AS available_qty
             FROM product_materials pm
             INNER JOIN materials m ON pm.material_id = m.id_m
             WHERE pm.product_id = ?
             GROUP BY pm.material_id, m.nama_m, pm.quantity"
        );
        if (!$stmt) throw new Exception("Prepare step2 gagal: " . $connect->error);
        $stmt->bind_param("i", $product_id);
        $stmt->execute();
        $result = $stmt->get_result();

        $materials         = [];
        $insufficient      = []; // material stok = 0
        $warning_materials = []; // material stok ada tapi kurang

        while ($row = $result->fetch_assoc()) {
            $total_req = (int)$row['required_qty'] * $quantity;
            $avail     = (int)$row['available_qty'];

            error_log("assembly_process MATERIAL: {$row['nama_m']} | required_qty={$row['required_qty']} | total_req=$total_req | avail=$avail");

            $materials[] = [
                'material_id'   => (int)$row['material_id'],
                'material_name' => $row['nama_m'],
                'required_qty'  => $total_req,
                'available_qty' => $avail,
            ];

            if ($avail <= 0 && $total_req > 0) {
                $insufficient[] = [
                    'nama'       => $row['nama_m'],
                    'dibutuhkan' => $total_req,
                    'tersedia'   => 0,
                ];
            }
        }
        $stmt->close();

        $total_materials_count = count($materials);
        error_log("assembly_process SUMMARY: total_materials=$total_materials_count | insufficient=" . count($insufficient));

        // ── HARD BLOCK: ada material dengan stok = 0 ────────
        if (!empty($insufficient)) {
            $connect->rollback();
            http_response_code(200);
            echo json_encode([
                'status'      => 'error',
                'result_type' => 'blocked',
                'message'     => 'Assembly tidak dapat diproses karena stok material berikut telah habis (0): '
                                 . implode(', ', array_column($insufficient, 'nama')),
                'data'        => [
                    'product_id'             => $product_id,
                    'product_name'           => $product_info['name_p'],
                    'insufficient_materials' => $insufficient,
                ],
            ], JSON_UNESCAPED_UNICODE);
            exit();
        }

        // ── Susun daftar material yang akan dikurangi ────────
        $to_update = [];

        foreach ($materials as $mat) {
            $total_req     = $mat['required_qty'];
            $avail         = $mat['available_qty'];
            $actual_deduct = min($avail, $total_req);

            if ($avail < $total_req) {
                $warning_materials[] = [
                    'nama'      => $mat['material_name'],
                    'dibutuhkan'=> $total_req,
                    'tersedia'  => $avail,
                    'dikurangi' => $actual_deduct,
                    'kurang'    => $total_req - $avail,
                ];
                error_log("assembly_process WARNING: stok kurang untuk {$mat['material_name']} (butuh:$total_req ada:$avail, pakai:$actual_deduct)");
            }

            if ($actual_deduct > 0) {
                $to_update[] = [
                    'material_id'   => $mat['material_id'],
                    'material_name' => $mat['material_name'],
                    'quantity'      => $actual_deduct,
                    'before_stock'  => $avail,
                ];
            }
        }

        if (empty($to_update) && empty($warning_materials)) {
            throw new Exception("Tidak ada material terdaftar untuk produk ini");
        }

        // ── 3. Update stok material ──────────────────────────
        foreach ($to_update as $item) {
            $stmt = $connect->prepare(
                "UPDATE material_stocks
                 SET stok_tersedia = GREATEST(stok_tersedia - ?, 0),
                     last_updated  = NOW()
                 WHERE material_id = ?
                 ORDER BY last_updated DESC, id_sm DESC
                 LIMIT 1"
            );
            if (!$stmt) throw new Exception("Prepare update material gagal: " . $connect->error);
            $stmt->bind_param("ii", $item['quantity'], $item['material_id']);
            if (!$stmt->execute()) {
                throw new Exception("Update material gagal [{$item['material_name']}]: " . $stmt->error);
            }
            $stmt->close();

            $trans_code   = 'ASM-' . date('Ymd') . '-' . $product_id . '-' . $item['material_id'];
            $stok_sesudah = $item['before_stock'] - $item['quantity'];
            $notes_mat    = "Assembly: " . $product_info['name_p'] . " qty:" . $quantity;

            $stmt = $connect->prepare(
                "INSERT INTO material_transactions
                    (transaction_code, material_id, transaction_type, jumlah,
                     stok_sebelum, stok_sesudah, transaction_date, notes)
                 VALUES (?, ?, 'out', ?, ?, ?, CURDATE(), ?)"
            );
            if ($stmt) {
                $stmt->bind_param("siiiis",
                    $trans_code,
                    $item['material_id'],
                    $item['quantity'],
                    $item['before_stock'],
                    $stok_sesudah,
                    $notes_mat
                );
                if (!$stmt->execute()) {
                    error_log("assembly_process: Insert material_transaction gagal (skip): " . $stmt->error);
                }
                $stmt->close();
            }
        }

        // ── 4. Update stok produk ────────────────────────────
        $stmt = $connect->prepare("SELECT COUNT(*) as cnt FROM product_stocks WHERE product_id = ?");
        if (!$stmt) throw new Exception("Prepare cek product_stocks gagal: " . $connect->error);
        $stmt->bind_param("i", $product_id);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $pstok_exists = (int)$row['cnt'] > 0;
        $stmt->close();

        if ($pstok_exists) {
            $stmt = $connect->prepare(
                "UPDATE product_stocks
                 SET stok_tersedia = stok_tersedia + ?,
                     last_updated  = NOW()
                 WHERE product_id = ?"
            );
            if (!$stmt) throw new Exception("Prepare update product_stocks gagal: " . $connect->error);
            $stmt->bind_param("ii", $quantity, $product_id);
        } else {
            $stmt = $connect->prepare(
                "INSERT INTO product_stocks (product_id, stok_tersedia, last_updated)
                 VALUES (?, ?, NOW())"
            );
            if (!$stmt) throw new Exception("Prepare insert product_stocks gagal: " . $connect->error);
            $stmt->bind_param("ii", $product_id, $quantity);
        }
        if (!$stmt->execute()) {
            throw new Exception("Update product_stocks gagal: " . $stmt->error);
        }
        $stmt->close();

        // ── 5. Catat transaksi produk ────────────────────────
        $trans_code_p = 'ASM-' . date('Ymd') . '-' . $product_id . '-' . time();

        if (!empty($warning_materials)) {
            $warning_names = [];
            foreach ($warning_materials as $w) {
                $warning_names[] = $w['nama'] . ' (tersedia:' . $w['tersedia'] . ', butuh:' . $w['dibutuhkan'] . ')';
            }
            $notes_prod = "Assembly partial - stok kurang: " . implode('; ', $warning_names);
        } else {
            $notes_prod = "Assembly completed: " . $product_info['name_p'];
        }

        $stmt = $connect->prepare(
            "INSERT INTO product_transactions
                (transaction_code, product_id, transaction_type, jumlah,
                 transaction_date, notes)
             VALUES (?, ?, 'in', ?, CURDATE(), ?)"
        );
        if ($stmt) {
            $stmt->bind_param("siis",
                $trans_code_p,
                $product_id,
                $quantity,
                $notes_prod
            );
            if (!$stmt->execute()) {
                error_log("assembly_process: Insert product_transaction gagal (skip): " . $stmt->error);
            }
            $stmt->close();
        }

        // ── 6. Tandai produk sebagai 'done' ──────────────────
        // Logika "done" berlaku untuk SEMUA produk (1 material maupun multi):
        // setelah berhasil di-assembly 1x, status = done → BLOKIR di proses berikutnya.
        //
        // Coba buat tabel jika belum ada (idempotent)
        $connect->query(
            "CREATE TABLE IF NOT EXISTS product_assembly_status (
                id            INT AUTO_INCREMENT PRIMARY KEY,
                product_id    INT NOT NULL UNIQUE,
                assembly_status VARCHAR(20) NOT NULL DEFAULT 'ready',
                assembled_at  DATETIME,
                assembled_qty INT DEFAULT 0,
                updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (product_id) REFERENCES products(id_p) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
        );

        $stmt = $connect->prepare(
            "INSERT INTO product_assembly_status
                (product_id, assembly_status, assembled_at, assembled_qty)
             VALUES (?, 'done', NOW(), ?)
             ON DUPLICATE KEY UPDATE
                assembly_status = 'done',
                assembled_at    = NOW(),
                assembled_qty   = assembled_qty + VALUES(assembled_qty)"
        );
        if ($stmt) {
            $stmt->bind_param("ii", $product_id, $quantity);
            if (!$stmt->execute()) {
                error_log("assembly_process: Insert product_assembly_status gagal (skip): " . $stmt->error);
            }
            $stmt->close();
        }

        // ── 7. Commit ────────────────────────────────────────
        $connect->commit();
        error_log("assembly_process: COMMIT sukses!");

        // ── 8. Susun daftar lengkap material yang dikonsumsi ─
        // Dikirim ke Flutter supaya dialog hasil bisa tampilkan semua material
        $consumed_materials = [];
        foreach ($to_update as $item) {
            $consumed_materials[] = [
                'nama'      => $item['material_name'],
                'dikurangi' => $item['quantity'],
                'sebelum'   => $item['before_stock'],
                'sesudah'   => max(0, $item['before_stock'] - $item['quantity']),
            ];
        }

        $has_warning = !empty($warning_materials);

        echo json_encode([
            'status'      => 'success',
            'result_type' => $has_warning ? 'warning' : 'success',
            'message'     => $has_warning
                ? 'Assembly diproses dengan stok terbatas. Beberapa material stok kurang.'
                : 'Assembly berhasil diproses',
            'data'        => [
                'product_id'          => $product_id,
                'product_name'        => $product_info['name_p'],
                'quantity'            => $quantity,
                'total_materials'     => $total_materials_count,
                'materials_updated'   => count($to_update),
                'has_warning'         => $has_warning,
                'warning_materials'   => $warning_materials,
                'consumed_materials'  => $consumed_materials,  // ← BARU: semua material yg dikonsumsi
                'assembly_now_done'   => true,                 // ← BARU: sinyal ke Flutter bahwa produk sudah done
            ]
        ], JSON_UNESCAPED_UNICODE);

    } catch (Exception $e) {
        $connect->rollback();
        throw $e;
    }

} catch (Exception $e) {
    if (isset($connect) && $connect->ping()) {
        $connect->rollback();
    }
    error_log("assembly_process ERROR: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'status'  => 'error',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}

if (isset($connect)) $connect->close();
?>