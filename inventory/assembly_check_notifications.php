<?php
ini_set('display_errors', 0);
error_reporting(E_ALL);
ini_set('log_errors', 1);

require_once 'conn.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    if (!$connect) throw new Exception("Koneksi database gagal");

    // ── Pastikan tabel product_assembly_status ada ───────────
    $connect->query(
        "CREATE TABLE IF NOT EXISTS product_assembly_status (
            id              INT AUTO_INCREMENT PRIMARY KEY,
            product_id      INT NOT NULL UNIQUE,
            assembly_status VARCHAR(20) NOT NULL DEFAULT 'ready',
            assembled_at    DATETIME,
            assembled_qty   INT DEFAULT 0,
            updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
                ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (product_id) REFERENCES products(id_p) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    );

    // ── Ambil semua produk + status assembly + cek stok ─────
    //
    // Logika status:
    //   'done'        → sudah pernah di-assembly (dari product_assembly_status)
    //   'blocked'     → ada material stok = 0 (belum pernah done)
    //   'in_progress' → tidak dipakai di sini (hanya runtime Flutter)
    //   'ready'       → semua stok ada dan cukup, siap diproses
    //   'limited'     → stok ada tapi kurang dari yang dibutuhkan
    //
    $sql = "
        SELECT
            p.id_p,
            p.code_p,
            p.name_p,
            p.description,

            -- Status dari tabel dedicated (done = pernah di-assembly)
            COALESCE(pas.assembly_status, 'ready') AS saved_status,

            -- Jumlah material yang dibutuhkan produk ini
            COUNT(DISTINCT pm.material_id) AS total_materials,

            -- Material yang stok = 0 (HARD BLOCK)
            SUM(
                CASE
                    WHEN COALESCE(latest_stock.stok, 0) <= 0
                         AND pm.quantity > 0
                    THEN 1 ELSE 0
                END
            ) AS zero_stock_count,

            -- Material yang stok ada tapi kurang dari kebutuhan
            SUM(
                CASE
                    WHEN COALESCE(latest_stock.stok, 0) > 0
                         AND COALESCE(latest_stock.stok, 0) < pm.quantity
                    THEN 1 ELSE 0
                END
            ) AS limited_stock_count

        FROM products p
        LEFT JOIN product_materials pm
               ON p.id_p = pm.product_id
        LEFT JOIN (
            -- Ambil stok terbaru per material (1 row per material_id)
            SELECT ms.material_id,
                   ms.stok_tersedia AS stok
            FROM material_stocks ms
            INNER JOIN (
                SELECT material_id, MAX(id_sm) AS max_id
                FROM material_stocks
                GROUP BY material_id
            ) latest ON ms.material_id = latest.material_id
                     AND ms.id_sm      = latest.max_id
        ) latest_stock ON pm.material_id = latest_stock.material_id
        LEFT JOIN product_assembly_status pas
               ON p.id_p = pas.product_id

        GROUP BY p.id_p, p.code_p, p.name_p, p.description, pas.assembly_status
        ORDER BY p.name_p ASC
    ";

    $result = $connect->query($sql);
    if ($result === false) {
        throw new Exception("Query gagal: " . $connect->error);
    }

    $products       = [];
    $total_pending  = 0;  // ready + limited (butuh perhatian tapi bisa jalan)
    $total_blocked  = 0;  // zero_stock atau done
    $total_done     = 0;

    while ($row = $result->fetch_assoc()) {
        $saved_status      = $row['saved_status'];        // 'ready' | 'done'
        $zero_count        = (int)$row['zero_stock_count'];
        $limited_count     = (int)$row['limited_stock_count'];
        $total_mat         = (int)$row['total_materials'];

        // Tentukan assembly_status final
        if ($saved_status === 'done') {
            $assembly_status = 'done';
            $total_done++;
        } elseif ($zero_count > 0) {
            $assembly_status = 'blocked';
            $total_blocked++;
        } elseif ($limited_count > 0) {
            $assembly_status = 'limited';
            $total_pending++;
        } else {
            $assembly_status = 'ready';
            $total_pending++;
        }

        $products[] = [
            'id_p'            => (int)$row['id_p'],
            'code_p'          => $row['code_p'],
            'name_p'          => $row['name_p'],
            'description'     => $row['description'],
            'assembly_status' => $assembly_status,
            'total_materials' => $total_mat,
        ];
    }

    echo json_encode([
        'status'  => 'success',
        'message' => 'Notifikasi berhasil dimuat',
        'data'    => [
            'summary'  => [
                'total_pending' => $total_pending,
                'total_blocked' => $total_blocked,
                'total_done'    => $total_done,
                'total_all'     => count($products),
            ],
            'products' => $products,
        ],
    ], JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    error_log("assembly_check_notifications ERROR: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'status'  => 'error',
        'message' => $e->getMessage(),
    ], JSON_UNESCAPED_UNICODE);
}

if (isset($connect)) $connect->close();
?>