<?php
require_once 'conn.php';

$method = $_SERVER['REQUEST_METHOD'];
$input = json_decode(file_get_contents('php://input'), true);

switch ($method) {
    case 'GET':
        handleGet();
        break;
    case 'POST':
        handlePost($input);
        break;
    case 'DELETE':
        handleDelete();
        break;
    default:
        http_response_code(405);
        echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
        break;
}

function handleGet() {
    global $connect;
    $action = $_GET['action'] ?? '';
    
    switch ($action) {
        case 'get_materials':
            getMaterials();
            break;
        case 'get_transactions':
            getTransactions();
            break;
        case 'get_transaction':
            getTransactionById();
            break;
        default:
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
            break;
    }
}

function getMaterials() {
    global $connect;
    
    // FIXED: Query untuk mendapatkan materials yang unik tanpa duplikasi
    // Menggunakan GROUP BY untuk memastikan tidak ada duplikasi berdasarkan id_m
    $query = "SELECT m.id_m, m.nama_m, m.code_m, m.satuan, 
          COALESCE(ms.stok_tersedia, 0) as stok_tersedia 
          FROM materials m 
          LEFT JOIN (
              SELECT material_id, stok_tersedia 
              FROM material_stocks ms1
              WHERE last_updated = (
                  SELECT MAX(last_updated) 
                  FROM material_stocks ms2 
                  WHERE ms2.material_id = ms1.material_id
              )
          ) ms ON m.id_m = ms.material_id 
          ORDER BY m.nama_m";
    
    $result = $connect->query($query);
    
    if ($result) {
        $materials = [];
        while ($row = $result->fetch_assoc()) {
            // Pastikan tidak ada duplikasi dengan menggunakan id_m sebagai key
            $materials[$row['id_m']] = $row;
        }
        
        // Convert associative array back to indexed array
        $materials = array_values($materials);
        
        echo json_encode([
            'status' => 'success',
            'data' => $materials
        ]);
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to fetch materials: ' . $connect->error
        ]);
    }
}

function getTransactions() {
    global $connect;
    
    // Query untuk mendapatkan data transaksi dengan informasi material
    $query = "SELECT mt.id_tm, mt.transaction_code, mt.material_id, mt.transaction_type, 
              mt.jumlah, mt.stok_sebelum, mt.stok_sesudah, mt.transaction_date, 
              mt.notes, mt.created_at, mt.updated_at,
              m.nama_m, m.code_m, m.satuan 
              FROM material_transactions mt
              LEFT JOIN materials m ON mt.material_id = m.id_m
              ORDER BY mt.created_at DESC";
    
    $result = $connect->query($query);
    
    if ($result) {
        $transactions = [];
        while ($row = $result->fetch_assoc()) {
            $transactions[] = $row;
        }
        echo json_encode([
            'status' => 'success',
            'data' => $transactions
        ]);
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to fetch transactions: ' . $connect->error
        ]);
    }
}

function getTransactionById() {
    global $connect;
    
    $id = $_GET['id'] ?? '';
    if (empty($id)) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Transaction ID is required'
        ]);
        return;
    }
    
    $id = intval($id);
    
    $query = "SELECT mt.id_tm, mt.transaction_code, mt.material_id, mt.transaction_type, 
              mt.jumlah, mt.stok_sebelum, mt.stok_sesudah, mt.transaction_date, 
              mt.notes, mt.created_at, mt.updated_at,
              m.nama_m, m.code_m, m.satuan 
              FROM material_transactions mt
              LEFT JOIN materials m ON mt.material_id = m.id_m
              WHERE mt.id_tm = ?";
    
    $stmt = $connect->prepare($query);
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $transaction = $result->fetch_assoc();
        echo json_encode([
            'status' => 'success',
            'data' => $transaction
        ]);
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'Transaction not found'
        ]);
    }
}

function handlePost($input) {
    global $connect;
    $action = $input['action'] ?? '';
    
    switch ($action) {
        case 'create_transaction':
            createTransaction($input);
            break;
        case 'update_transaction':
            updateTransaction($input);
            break;
        case 'edit_transaction':
            editTransaction($input);
            break;
        default:
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
            break;
    }
}

function createTransaction($input) {
    global $connect;
    
    // Validate input
    $required_fields = ['material_id', 'transaction_type', 'jumlah', 'transaction_date', 'created_by'];
    foreach ($required_fields as $field) {
        if (!isset($input[$field]) || ($input[$field] === '' && $field !== 'notes')) {
            echo json_encode([
                'status' => 'error',
                'message' => "Field $field is required"
            ]);
            return;
        }
    }
    
    $material_id = intval($input['material_id']);
    $transaction_type = $input['transaction_type'];
    $jumlah = intval($input['jumlah']);
    $transaction_date = $input['transaction_date'];
    $notes = $input['notes'] ?? '';
    $created_by = intval($input['created_by']);
    
    // FIXED: Transaction code dapat diisi manual atau kosong
    $transaction_code = '';
    if (isset($input['transaction_code']) && !empty(trim($input['transaction_code']))) {
        $transaction_code = trim($input['transaction_code']);
        
        // Validasi apakah transaction code sudah ada
        if (isTransactionCodeExists($transaction_code)) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Transaction code already exists. Please use a different code.'
            ]);
            return;
        }
    } else {
        // Generate otomatis hanya jika kosong
        $transaction_code = generateUniqueTransactionCode();
    }
    
    // Start transaction
    $connect->begin_transaction();
    
    try {
        // Get current stock - FIXED: tambah ORDER BY dan LIMIT untuk memastikan data terbaru
        $stock_query = "SELECT stok_tersedia FROM material_stocks WHERE material_id = ? ORDER BY last_updated DESC LIMIT 1";
        $stock_stmt = $connect->prepare($stock_query);
        $stock_stmt->bind_param("i", $material_id);
        $stock_stmt->execute();
        $stock_result = $stock_stmt->get_result();
        
        $current_stock = 0;
        if ($stock_result->num_rows > 0) {
            $stock_row = $stock_result->fetch_assoc();
            $current_stock = intval($stock_row['stok_tersedia']);
        }
        
        // Calculate new stock based on transaction type
        $stok_sebelum = $current_stock;
        switch ($transaction_type) {
            case 'in':
                $stok_sesudah = $current_stock + $jumlah;
                break;
            case 'out':
                if ($current_stock < $jumlah) {
                    throw new Exception('Insufficient stock. Available: ' . $current_stock . ', Required: ' . $jumlah);
                }
                $stok_sesudah = $current_stock - $jumlah;
                break;
            case 'adjustment':
                $stok_sesudah = $jumlah;
                $jumlah = $stok_sesudah - $stok_sebelum;
                break;
            default:
                throw new Exception('Invalid transaction type');
        }
        
        // Insert transaction record
        $trans_query = "INSERT INTO material_transactions (transaction_code, material_id, transaction_type, jumlah, stok_sebelum, stok_sesudah, transaction_date, notes, created_by, created_at) 
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())";
        $trans_stmt = $connect->prepare($trans_query);
        $trans_stmt->bind_param("sssiiissi", $transaction_code, $material_id, $transaction_type, $jumlah, $stok_sebelum, $stok_sesudah, $transaction_date, $notes, $created_by);
        
        if (!$trans_stmt->execute()) {
            throw new Exception('Failed to insert transaction: ' . $trans_stmt->error);
        }
        
        // Update or insert stock record
        $update_stock_query = "INSERT INTO material_stocks (material_id, stok_tersedia, updated_by, last_updated) 
                              VALUES (?, ?, ?, NOW()) 
                              ON DUPLICATE KEY UPDATE 
                              stok_tersedia = VALUES(stok_tersedia), 
                              last_updated = NOW(), 
                              updated_by = VALUES(updated_by)";
        $update_stock_stmt = $connect->prepare($update_stock_query);
        $update_stock_stmt->bind_param("iii", $material_id, $stok_sesudah, $created_by);
        
        if (!$update_stock_stmt->execute()) {
            throw new Exception('Failed to update stock: ' . $update_stock_stmt->error);
        }
        
        // Commit transaction
        $connect->commit();
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Transaction created successfully',
            'data' => [
                'transaction_id' => $connect->insert_id,
                'transaction_code' => $transaction_code,
                'stok_sebelum' => $stok_sebelum,
                'stok_sesudah' => $stok_sesudah
            ]
        ]);
        
    } catch (Exception $e) {
        // Rollback transaction
        $connect->rollback();
        
        echo json_encode([
            'status' => 'error',
            'message' => $e->getMessage()
        ]);
    }
}

function updateTransaction($input) {
    global $connect;
    
    // Validate input
    $required_fields = ['id_tm', 'material_id', 'transaction_type', 'jumlah', 'transaction_date', 'created_by'];
    foreach ($required_fields as $field) {
        if (!isset($input[$field])) {
            echo json_encode([
                'status' => 'error',
                'message' => "Field $field is required"
            ]);
            return;
        }
    }
    
    $id_tm = intval($input['id_tm']);
    $material_id = intval($input['material_id']);
    $transaction_type = $input['transaction_type'];
    $jumlah = intval($input['jumlah']);
    $transaction_date = $input['transaction_date'];
    $notes = $input['notes'] ?? '';
    $created_by = intval($input['created_by']);
    
    // FIXED: Handle transaction code update
    $transaction_code = '';
    if (isset($input['transaction_code']) && !empty(trim($input['transaction_code']))) {
        $transaction_code = trim($input['transaction_code']);
        
        // Validasi apakah transaction code sudah ada (kecuali untuk record yang sedang diupdate)
        if (isTransactionCodeExistsExcept($transaction_code, $id_tm)) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Transaction code already exists. Please use a different code.'
            ]);
            return;
        }
    }
    
    // Start transaction
    $connect->begin_transaction();
    
    try {
        // Get the original transaction to reverse its effect on stock
        $get_original_query = "SELECT * FROM material_transactions WHERE id_tm = ?";
        $get_original_stmt = $connect->prepare($get_original_query);
        $get_original_stmt->bind_param("i", $id_tm);
        $get_original_stmt->execute();
        $original_result = $get_original_stmt->get_result();
        
        if ($original_result->num_rows === 0) {
            throw new Exception('Transaction not found');
        }
        
        $original_transaction = $original_result->fetch_assoc();
        
        // Jika transaction code kosong, gunakan yang lama
        if (empty($transaction_code)) {
            $transaction_code = $original_transaction['transaction_code'];
        }
        
        // Get current stock and reverse the original transaction effect
        $stock_query = "SELECT stok_tersedia FROM material_stocks WHERE material_id = ?";
        $stock_stmt = $connect->prepare($stock_query);
        $stock_stmt->bind_param("i", $material_id);
        $stock_stmt->execute();
        $stock_result = $stock_stmt->get_result();
        
        $current_stock = 0;
        if ($stock_result->num_rows > 0) {
            $stock_row = $stock_result->fetch_assoc();
            $current_stock = intval($stock_row['stok_tersedia']);
        }
        
        // Reverse the original transaction effect to get the stock before any transaction
        $original_jumlah = intval($original_transaction['jumlah']);
        $original_type = $original_transaction['transaction_type'];
        
        switch ($original_type) {
            case 'in':
                $stock_before_original = $current_stock - $original_jumlah;
                break;
            case 'out':
                $stock_before_original = $current_stock + $original_jumlah;
                break;
            case 'adjustment':
                $stock_before_original = intval($original_transaction['stok_sebelum']);
                break;
            default:
                $stock_before_original = intval($original_transaction['stok_sebelum']);
                break;
        }
        
        // Apply the new transaction
        $stok_sebelum = $stock_before_original;
        switch ($transaction_type) {
            case 'in':
                $stok_sesudah = $stock_before_original + $jumlah;
                break;
            case 'out':
                if ($stock_before_original < $jumlah) {
                    throw new Exception('Insufficient stock. Available: ' . $stock_before_original . ', Required: ' . $jumlah);
                }
                $stok_sesudah = $stock_before_original - $jumlah;
                break;
            case 'adjustment':
                $stok_sesudah = $jumlah;
                $jumlah = $stok_sesudah - $stok_sebelum;
                break;
            default:
                throw new Exception('Invalid transaction type');
        }
        
        // Update transaction record
        $update_trans_query = "UPDATE material_transactions 
                              SET transaction_code = ?, material_id = ?, transaction_type = ?, jumlah = ?, 
                                  stok_sebelum = ?, stok_sesudah = ?, transaction_date = ?, 
                                  notes = ?, updated_at = NOW() 
                              WHERE id_tm = ?";
        $update_trans_stmt = $connect->prepare($update_trans_query);
        $update_trans_stmt->bind_param("ssisisssi", $transaction_code, $material_id, $transaction_type, $jumlah, $stok_sebelum, $stok_sesudah, $transaction_date, $notes, $id_tm);
        
        if (!$update_trans_stmt->execute()) {
            throw new Exception('Failed to update transaction: ' . $update_trans_stmt->error);
        }
        
        // Update stock record
        $update_stock_query = "UPDATE material_stocks 
                              SET stok_tersedia = ?, last_updated = NOW(), updated_by = ? 
                              WHERE material_id = ?";
        $update_stock_stmt = $connect->prepare($update_stock_query);
        $update_stock_stmt->bind_param("iii", $stok_sesudah, $created_by, $material_id);
        
        if (!$update_stock_stmt->execute()) {
            throw new Exception('Failed to update stock: ' . $update_stock_stmt->error);
        }
        
        // Commit transaction
        $connect->commit();
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Transaction updated successfully',
            'data' => [
                'transaction_code' => $transaction_code,
                'stok_sebelum' => $stok_sebelum,
                'stok_sesudah' => $stok_sesudah
            ]
        ]);
        
    } catch (Exception $e) {
        // Rollback transaction
        $connect->rollback();
        
        echo json_encode([
            'status' => 'error',
            'message' => $e->getMessage()
        ]);
    }
}

function editTransaction($input) {
    // Use the same logic as updateTransaction
    updateTransaction($input);
}

function handleDelete() {
    global $connect;
    $action = $_GET['action'] ?? '';
    
    switch ($action) {
        case 'delete_transaction':
            deleteTransaction();
            break;
        default:
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
            break;
    }
}

function deleteTransaction() {
    global $connect;
    
    $id = $_GET['id'] ?? '';
    if (empty($id)) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Transaction ID is required'
        ]);
        return;
    }
    
    $id = intval($id);
    
    // Start transaction
    $connect->begin_transaction();
    
    try {
        // Get transaction details before deletion
        $get_query = "SELECT * FROM material_transactions WHERE id_tm = ?";
        $get_stmt = $connect->prepare($get_query);
        $get_stmt->bind_param("i", $id);
        $get_stmt->execute();
        $result = $get_stmt->get_result();
        
        if ($result->num_rows === 0) {
            throw new Exception('Transaction not found');
        }
        
        $transaction = $result->fetch_assoc();
        
        // Reverse the stock changes
        $material_id = $transaction['material_id'];
        $stok_sebelum = intval($transaction['stok_sebelum']);
        
        // Update stock back to previous amount
        $update_stock_query = "UPDATE material_stocks SET stok_tersedia = ?, last_updated = NOW() WHERE material_id = ?";
        $update_stock_stmt = $connect->prepare($update_stock_query);
        $update_stock_stmt->bind_param("ii", $stok_sebelum, $material_id);
        
        if (!$update_stock_stmt->execute()) {
            throw new Exception('Failed to reverse stock changes: ' . $update_stock_stmt->error);
        }
        
        // Delete transaction record
        $delete_query = "DELETE FROM material_transactions WHERE id_tm = ?";
        $delete_stmt = $connect->prepare($delete_query);
        $delete_stmt->bind_param("i", $id);
        
        if (!$delete_stmt->execute()) {
            throw new Exception('Failed to delete transaction: ' . $delete_stmt->error);
        }
        
        // Commit transaction
        $connect->commit();
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Transaction deleted successfully'
        ]);
        
    } catch (Exception $e) {
        // Rollback transaction
        $connect->rollback();
        
        echo json_encode([
            'status' => 'error',
            'message' => $e->getMessage()
        ]);
    }
}

// ADDED: Helper function to generate unique transaction code
function generateUniqueTransactionCode() {
    global $connect;
    
    do {
        $now = new DateTime();
        $timestamp = $now->format('His'); // Hours, minutes, seconds
        $random = str_pad(rand(0, 999), 3, '0', STR_PAD_LEFT);
        $transaction_code = 'TM' . $now->format('Ymd') . $timestamp . $random;
    } while (isTransactionCodeExists($transaction_code));
    
    return $transaction_code;
}

// ADDED: Helper function to check if transaction code exists
function isTransactionCodeExists($transaction_code) {
    global $connect;
    
    $query = "SELECT COUNT(*) as count FROM material_transactions WHERE transaction_code = ?";
    $stmt = $connect->prepare($query);
    $stmt->bind_param("s", $transaction_code);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    
    return $row['count'] > 0;
}

// ADDED: Helper function to check if transaction code exists except for specific ID
function isTransactionCodeExistsExcept($transaction_code, $except_id) {
    global $connect;
    
    $query = "SELECT COUNT(*) as count FROM material_transactions WHERE transaction_code = ? AND id_tm != ?";
    $stmt = $connect->prepare($query);
    $stmt->bind_param("si", $transaction_code, $except_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    
    return $row['count'] > 0;
}
?>