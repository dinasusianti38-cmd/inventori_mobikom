<?php
ini_set('display_errors', 0);
ini_set('log_errors', 1);
error_reporting(E_ALL);
header('Content-Type: application/json');

require_once 'conn.php';

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

switch ($method) {
    case 'GET':
        handleGet($action);
        break;
    case 'POST':
        handlePost();
        break;
    case 'PUT':
        handlePut();
        break;
    case 'DELETE':
        handleDelete($action);
        break;
    default:
        http_response_code(405);
        echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
        break;
}

function handleGet($action) {
    switch ($action) {
        case 'get_products':
            getProducts();
            break;
        case 'get_transactions':
            getTransactions();
            break;
        default:
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
            break;
    }
}

function getProducts() {
    global $connect;

    $query = "SELECT p.id_p, p.code_p, p.name_p, p.description,
                     COALESCE(ps.stok_tersedia, 0) as stok_tersedia
              FROM products p
              LEFT JOIN product_stocks ps ON p.id_p = ps.product_id
              ORDER BY p.name_p";

    $result = $connect->query($query);

    if ($result) {
        $products = [];
        while ($row = $result->fetch_assoc()) {
            $products[] = $row;
        }
        echo json_encode(['status' => 'success', 'data' => $products]);
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to fetch products: ' . $connect->error]);
    }
}

function getTransactions() {
    global $connect;

    $query = "SELECT pt.id_pm, pt.transaction_code, pt.product_id, p.name_p as product_name,
                     pt.transaction_type, pt.jumlah, pt.stok_sebelum, pt.stok_sesudah,
                     pt.transaction_date, pt.notes, pt.created_by, pt.created_at
              FROM product_transactions pt
              JOIN products p ON pt.product_id = p.id_p
              ORDER BY pt.created_at DESC";

    $result = $connect->query($query);

    if ($result) {
        $transactions = [];
        while ($row = $result->fetch_assoc()) {
            $transactions[] = $row;
        }
        echo json_encode(['status' => 'success', 'data' => $transactions]);
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Failed to fetch transactions: ' . $connect->error]);
    }
}

function handlePost() {
    $input  = json_decode(file_get_contents('php://input'), true);
    $action = $input['action'] ?? '';

    switch ($action) {
        case 'add_transaction':
            addTransaction($input['data'] ?? []);
            break;
        default:
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
            break;
    }
}

function handlePut() {
    $input  = json_decode(file_get_contents('php://input'), true);
    $action = $input['action'] ?? '';

    switch ($action) {
        case 'update_transaction':
            updateTransaction($input['data'] ?? []);
            break;
        default:
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
            break;
    }
}

function addTransaction($data) {
    global $connect;

    // FIX 1: Validate — jangan pakai empty() untuk jumlah karena "0" dianggap empty
    if (empty($data['product_id']) ||
        empty($data['transaction_type']) ||
        !isset($data['jumlah']) || $data['jumlah'] === '' ||
        empty($data['transaction_date'])) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Semua field wajib diisi']);
        return;
    }

    if ($data['transaction_type'] === 'in') {
        http_response_code(403);
        echo json_encode([
            'status'  => 'error',
            'message' => 'Transaksi masuk tidak diizinkan. Stok projek diperbarui otomatis melalui proses assembly.'
        ]);
        return;
    }

    if (!in_array($data['transaction_type'], ['out', 'adjustment'])) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Jenis transaksi tidak valid.']);
        return;
    }

    // FIX 2: Auto-generate transaction_code jika kosong (PHP tidak ada logikanya)
    $transactionCode = !empty($data['transaction_code'])
        ? $data['transaction_code']
        : 'TRX-' . strtoupper(uniqid());

    // FIX 3: Pastikan notes tidak null — bind_param "s" tidak suka null di beberapa versi PHP
    $notes = isset($data['notes']) && $data['notes'] !== '' ? $data['notes'] : null;

    $connect->begin_transaction();

    try {
        // Get current stock
        $stockQuery  = "SELECT stok_tersedia FROM product_stocks WHERE product_id = ?";
        $stockStmt   = $connect->prepare($stockQuery);
        if (!$stockStmt) throw new Exception('Prepare failed: ' . $connect->error);

        $stockStmt->bind_param("i", $data['product_id']);
        $stockStmt->execute();
        $stockResult = $stockStmt->get_result();

        // FIX 4: Simpan flag SEBELUM fetch_assoc() menghabiskan cursor
        $stockExists  = ($stockResult->num_rows > 0);
        $currentStock = 0;
        if ($stockExists) {
            $currentStock = (int) $stockResult->fetch_assoc()['stok_tersedia'];
        }

        // Hitung stok baru
        $jumlah       = (int) $data['jumlah'];
        $newStock     = $currentStock;
        $actualJumlah = $jumlah;

        if ($data['transaction_type'] === 'out') {
            if ($currentStock < $jumlah) {
                throw new Exception('Stok tidak mencukupi. Stok tersedia: ' . $currentStock);
            }
            $newStock = $currentStock - $jumlah;
        } elseif ($data['transaction_type'] === 'adjustment') {
            $newStock     = $jumlah;
            $actualJumlah = abs($newStock - $currentStock);
        }

        // FIX 5: Semua variabel dideklarasikan SEBELUM bind_param
        $createdBy   = 1;
        $productId   = (int) $data['product_id'];
        $transType   = $data['transaction_type'];
        $transDate   = $data['transaction_date'];

        $insertQuery = "INSERT INTO product_transactions
                       (transaction_code, product_id, transaction_type, jumlah,
                        stok_sebelum, stok_sesudah, transaction_date, notes, created_by)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";

        $insertStmt = $connect->prepare($insertQuery);
        if (!$insertStmt) throw new Exception('Prepare insert failed: ' . $connect->error);

        $insertStmt->bind_param("sisiiissi",
            $transactionCode,
            $productId,
            $transType,
            $actualJumlah,
            $currentStock,
            $newStock,
            $transDate,
            $notes,
            $createdBy
        );

        if (!$insertStmt->execute()) {
            throw new Exception('Failed to insert transaction: ' . $insertStmt->error);
        }

        // Update or insert stock
        if ($stockExists) {
            $updateStockQuery = "UPDATE product_stocks
                                SET stok_tersedia = ?, last_updated = CURRENT_TIMESTAMP, updated_by = ?
                                WHERE product_id = ?";
            $updateStockStmt = $connect->prepare($updateStockQuery);
            if (!$updateStockStmt) throw new Exception('Prepare update stock failed: ' . $connect->error);
            $updateStockStmt->bind_param("iii", $newStock, $createdBy, $productId);
            if (!$updateStockStmt->execute()) {
                throw new Exception('Failed to update stock: ' . $updateStockStmt->error);
            }
        } else {
            $insertStockQuery = "INSERT INTO product_stocks (product_id, stok_minimal, stok_tersedia, updated_by)
                                VALUES (?, 0, ?, ?)";
            $insertStockStmt = $connect->prepare($insertStockQuery);
            if (!$insertStockStmt) throw new Exception('Prepare insert stock failed: ' . $connect->error);
            $insertStockStmt->bind_param("iii", $productId, $newStock, $createdBy);
            if (!$insertStockStmt->execute()) {
                throw new Exception('Failed to insert stock: ' . $insertStockStmt->error);
            }
        }

        $connect->commit();

        echo json_encode([
            'status'  => 'success',
            'message' => 'Transaksi berhasil ditambahkan',
            'data'    => ['stok_sebelum' => $currentStock, 'stok_sesudah' => $newStock]
        ]);

    } catch (Exception $e) {
        $connect->rollback();
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }
}

function updateTransaction($data) {
    global $connect;

    if (empty($data['id']) || empty($data['product_id']) ||
        empty($data['transaction_type']) ||
        !isset($data['jumlah']) || $data['jumlah'] === '' ||
        empty($data['transaction_date'])) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Semua field wajib diisi']);
        return;
    }

    if ($data['transaction_type'] === 'in') {
        http_response_code(403);
        echo json_encode([
            'status'  => 'error',
            'message' => 'Transaksi masuk tidak diizinkan.'
        ]);
        return;
    }

    if (!in_array($data['transaction_type'], ['out', 'adjustment'])) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Jenis transaksi tidak valid.']);
        return;
    }

    $transactionCode = !empty($data['transaction_code'])
        ? $data['transaction_code']
        : 'TRX-' . strtoupper(uniqid());

    $notes = isset($data['notes']) && $data['notes'] !== '' ? $data['notes'] : null;

    $connect->begin_transaction();

    try {
        $id        = (int) $data['id'];
        $productId = (int) $data['product_id'];
        $jumlah    = (int) $data['jumlah'];
        $transType = $data['transaction_type'];
        $transDate = $data['transaction_date'];

        // Get original transaction
        $originalStmt = $connect->prepare("SELECT * FROM product_transactions WHERE id_pm = ?");
        if (!$originalStmt) throw new Exception('Prepare failed: ' . $connect->error);
        $originalStmt->bind_param("i", $id);
        $originalStmt->execute();
        $originalResult = $originalStmt->get_result();

        if ($originalResult->num_rows == 0) {
            throw new Exception('Transaksi tidak ditemukan');
        }

        $originalTransaction = $originalResult->fetch_assoc();

        if ($originalTransaction['transaction_type'] === 'in') {
            throw new Exception('Transaksi assembly tidak dapat diedit secara manual.');
        }

        // Get current stock
        $stockStmt = $connect->prepare("SELECT stok_tersedia FROM product_stocks WHERE product_id = ?");
        if (!$stockStmt) throw new Exception('Prepare failed: ' . $connect->error);
        $stockStmt->bind_param("i", $productId);
        $stockStmt->execute();
        $stockResult = $stockStmt->get_result();

        $stockExists  = ($stockResult->num_rows > 0);
        $currentStock = 0;
        if ($stockExists) {
            $currentStock = (int) $stockResult->fetch_assoc()['stok_tersedia'];
        }

        // Balik efek transaksi lama
        $stockAfterReverse = $currentStock;
        if ($originalTransaction['transaction_type'] === 'out') {
            $stockAfterReverse = $currentStock + (int)$originalTransaction['jumlah'];
        } elseif ($originalTransaction['transaction_type'] === 'adjustment') {
            $stockAfterReverse = (int)$originalTransaction['stok_sebelum'];
        }

        // Terapkan transaksi baru
        $newStock     = $stockAfterReverse;
        $actualJumlah = $jumlah;

        if ($transType === 'out') {
            if ($stockAfterReverse < $jumlah) {
                throw new Exception('Stok tidak mencukupi. Stok tersedia: ' . $stockAfterReverse);
            }
            $newStock = $stockAfterReverse - $jumlah;
        } elseif ($transType === 'adjustment') {
            $newStock     = $jumlah;
            $actualJumlah = abs($newStock - $stockAfterReverse);
        }

        $updateStmt = $connect->prepare(
            "UPDATE product_transactions
             SET transaction_code = ?, product_id = ?, transaction_type = ?,
                 jumlah = ?, stok_sebelum = ?, stok_sesudah = ?,
                 transaction_date = ?, notes = ?
             WHERE id_pm = ?"
        );
        if (!$updateStmt) throw new Exception('Prepare failed: ' . $connect->error);

        $updateStmt->bind_param("sisiiissi",
            $transactionCode,
            $productId,
            $transType,
            $actualJumlah,
            $stockAfterReverse,
            $newStock,
            $transDate,
            $notes,
            $id
        );

        if (!$updateStmt->execute()) {
            throw new Exception('Failed to update transaction: ' . $updateStmt->error);
        }

        $createdBy = 1;
        if ($stockExists) {
            $updateStockStmt = $connect->prepare(
                "UPDATE product_stocks SET stok_tersedia = ?, last_updated = CURRENT_TIMESTAMP, updated_by = ? WHERE product_id = ?"
            );
            if (!$updateStockStmt) throw new Exception('Prepare failed: ' . $connect->error);
            $updateStockStmt->bind_param("iii", $newStock, $createdBy, $productId);
            if (!$updateStockStmt->execute()) {
                throw new Exception('Failed to update stock: ' . $updateStockStmt->error);
            }
        } else {
            $insertStockStmt = $connect->prepare(
                "INSERT INTO product_stocks (product_id, stok_minimal, stok_tersedia, updated_by) VALUES (?, 0, ?, ?)"
            );
            if (!$insertStockStmt) throw new Exception('Prepare failed: ' . $connect->error);
            $insertStockStmt->bind_param("iii", $productId, $newStock, $createdBy);
            if (!$insertStockStmt->execute()) {
                throw new Exception('Failed to insert stock: ' . $insertStockStmt->error);
            }
        }

        $connect->commit();

        echo json_encode([
            'status'  => 'success',
            'message' => 'Transaksi berhasil diupdate',
            'data'    => ['stok_sebelum' => $stockAfterReverse, 'stok_sesudah' => $newStock]
        ]);

    } catch (Exception $e) {
        $connect->rollback();
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }
}

function handleDelete($action) {
    switch ($action) {
        case 'delete_transaction':
            $id = $_GET['id'] ?? '';
            if (empty($id)) {
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => 'ID is required']);
                return;
            }
            deleteTransaction($id);
            break;
        default:
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
            break;
    }
}

function deleteTransaction($id) {
    global $connect;

    $connect->begin_transaction();

    try {
        $id = (int) $id;

        $getStmt = $connect->prepare("SELECT * FROM product_transactions WHERE id_pm = ?");
        if (!$getStmt) throw new Exception('Prepare failed: ' . $connect->error);
        $getStmt->bind_param("i", $id);
        $getStmt->execute();
        $result = $getStmt->get_result();

        if ($result->num_rows == 0) {
            throw new Exception('Transaksi tidak ditemukan');
        }

        $transaction = $result->fetch_assoc();
        $productId   = (int) $transaction['product_id'];

        // Check other transactions for this product
        $checkStmt = $connect->prepare(
            "SELECT COUNT(*) as count FROM product_transactions WHERE product_id = ? AND id_pm != ?"
        );
        if (!$checkStmt) throw new Exception('Prepare failed: ' . $connect->error);
        $checkStmt->bind_param("ii", $productId, $id);
        $checkStmt->execute();
        $otherCount = (int) $checkStmt->get_result()->fetch_assoc()['count'];

        // Get current stock
        $stockStmt = $connect->prepare("SELECT stok_tersedia FROM product_stocks WHERE product_id = ?");
        if (!$stockStmt) throw new Exception('Prepare failed: ' . $connect->error);
        $stockStmt->bind_param("i", $productId);
        $stockStmt->execute();
        $stockResult = $stockStmt->get_result();

        if ($stockResult->num_rows > 0) {
            $currentStock = (int) $stockResult->fetch_assoc()['stok_tersedia'];

            $newStock = $currentStock;
            if ($transaction['transaction_type'] === 'in') {
                $newStock = $currentStock - (int)$transaction['jumlah'];
            } elseif ($transaction['transaction_type'] === 'out') {
                $newStock = $currentStock + (int)$transaction['jumlah'];
            } elseif ($transaction['transaction_type'] === 'adjustment') {
                $newStock = (int)$transaction['stok_sebelum'];
            }
            if ($newStock < 0) $newStock = 0;

            if ($otherCount == 0) {
                $deleteStockStmt = $connect->prepare("DELETE FROM product_stocks WHERE product_id = ?");
                if (!$deleteStockStmt) throw new Exception('Prepare failed: ' . $connect->error);
                $deleteStockStmt->bind_param("i", $productId);
                if (!$deleteStockStmt->execute()) {
                    throw new Exception('Failed to delete stock: ' . $deleteStockStmt->error);
                }
            } else {
                $updateStockStmt = $connect->prepare(
                    "UPDATE product_stocks SET stok_tersedia = ?, last_updated = CURRENT_TIMESTAMP WHERE product_id = ?"
                );
                if (!$updateStockStmt) throw new Exception('Prepare failed: ' . $connect->error);
                $updateStockStmt->bind_param("ii", $newStock, $productId);
                if (!$updateStockStmt->execute()) {
                    throw new Exception('Failed to update stock: ' . $updateStockStmt->error);
                }
            }
        }

        $deleteStmt = $connect->prepare("DELETE FROM product_transactions WHERE id_pm = ?");
        if (!$deleteStmt) throw new Exception('Prepare failed: ' . $connect->error);
        $deleteStmt->bind_param("i", $id);
        if (!$deleteStmt->execute()) {
            throw new Exception('Failed to delete transaction: ' . $deleteStmt->error);
        }

        $connect->commit();

        echo json_encode([
            'status'        => 'success',
            'message'       => 'Transaksi berhasil dihapus',
            'stock_deleted' => $otherCount == 0
        ]);

    } catch (Exception $e) {
        $connect->rollback();
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }
}
?>