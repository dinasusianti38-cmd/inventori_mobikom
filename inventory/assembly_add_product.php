<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'db_connection.php'; // sesuaikan path koneksi DB

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
    exit();
}

$input = json_decode(file_get_contents('php://input'), true);

if (!$input) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid JSON body']);
    exit();
}

$code_p       = trim($input['code_p']       ?? '');
$name_p       = trim($input['name_p']       ?? '');
$description  = trim($input['description']  ?? '');
$stok_minimal = intval($input['stok_minimal'] ?? 0);
$stok_awal    = intval($input['stok_awal']    ?? 0);
$created_by   = intval($input['created_by']   ?? 1);

// ── Validasi wajib ──────────────────────────────────────────────
if (empty($code_p) || empty($name_p)) {
    echo json_encode([
        'status'  => 'error',
        'message' => 'Kode produk dan nama produk wajib diisi.',
    ]);
    exit();
}

// ── Cek duplikat kode ──────────────────────────────────────────
$stmtCheck = $conn->prepare("SELECT id_p FROM products WHERE code_p = ?");
$stmtCheck->bind_param('s', $code_p);
$stmtCheck->execute();
$stmtCheck->store_result();
if ($stmtCheck->num_rows > 0) {
    echo json_encode([
        'status'  => 'error',
        'message' => "Kode produk \"$code_p\" sudah digunakan. Gunakan kode lain.",
    ]);
    $stmtCheck->close();
    exit();
}
$stmtCheck->close();

// ── Mulai transaksi ────────────────────────────────────────────
$conn->begin_transaction();

try {
    // 1. Insert ke tabel products
    $stmtProduct = $conn->prepare(
        "INSERT INTO products (code_p, name_p, description, created_at, updated_at)
         VALUES (?, ?, ?, NOW(), NOW())"
    );
    $stmtProduct->bind_param('sss', $code_p, $name_p, $description);
    $stmtProduct->execute();
    $product_id = $conn->insert_id;
    $stmtProduct->close();

    // 2. Insert ke product_stocks
    $stmtStock = $conn->prepare(
        "INSERT INTO product_stocks (product_id, stok_minimal, stok_tersedia, last_updated, updated_by)
         VALUES (?, ?, ?, NOW(), ?)"
    );
    $stmtStock->bind_param('iiii', $product_id, $stok_minimal, $stok_awal, $created_by);
    $stmtStock->execute();
    $stmtStock->close();

    // 3. Catat transaksi stok awal (hanya jika stok_awal > 0)
    if ($stok_awal > 0) {
        $transaction_code = 'TRX-INIT-' . strtoupper(uniqid());
        $notes            = 'Stok awal saat produk ditambahkan ke sistem assembly';
        $stok_sebelum     = 0;

        $stmtTrx = $conn->prepare(
            "INSERT INTO product_transactions
                (transaction_code, product_id, transaction_type, jumlah,
                 stok_sebelum, stok_sesudah, transaction_date, notes, created_by, created_at)
             VALUES (?, ?, 'in', ?, 0, ?, NOW(), ?, ?, NOW())"
        );
        $stmtTrx->bind_param('ssiisi',
            $transaction_code,
            $product_id,
            $stok_awal,
            $stok_awal,
            $notes,
            $created_by
        );
        $stmtTrx->execute();
        $stmtTrx->close();
    }

    $conn->commit();

    echo json_encode([
        'status'  => 'success',
        'message' => "Produk \"$name_p\" berhasil ditambahkan.",
        'data'    => [
            'id_p'        => $product_id,
            'code_p'      => $code_p,
            'name_p'      => $name_p,
            'description' => $description,
            'stok_awal'   => $stok_awal,
        ],
    ]);

} catch (Exception $e) {
    $conn->rollback();
    echo json_encode([
        'status'  => 'error',
        'message' => 'Gagal menyimpan data: ' . $e->getMessage(),
    ]);
}

$conn->close();
?>
