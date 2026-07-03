<?php
require_once 'conn.php';

// Function to get current stock with status calculation
function getCurrentStock($materialId) {
    global $connect;
    
    // Get total stock from transactions
    $query = "SELECT 
                COALESCE(SUM(CASE WHEN transaction_type = 'in' THEN jumlah ELSE 0 END), 0) -
                COALESCE(SUM(CASE WHEN transaction_type = 'out' THEN jumlah ELSE 0 END), 0) +
                COALESCE(SUM(CASE WHEN transaction_type = 'adjustment' THEN jumlah ELSE 0 END), 0) as current_stock
              FROM material_transactions 
              WHERE material_id = ?";
    
    $stmt = $connect->prepare($query);
    $stmt->bind_param("i", $materialId);
    $stmt->execute();
    $result = $stmt->get_result();
    $stock = $result->fetch_assoc();
    
    return $stock['current_stock'] ?? 0;
}

// Function to determine stock status
function getStockStatus($currentStock) {
    if ($currentStock <= 0) {
        return 'stok habis';
    } elseif ($currentStock <= 10) {
        return 'stok menipis';
    } else {
        return 'stok normal';
    }
}

// Function to format date for display
function formatDate($date) {
    return date('d/m/Y', strtotime($date));
}

// Handle different actions
$action = $_GET['action'] ?? $_POST['action'] ?? '';

switch ($action) {
    case 'get_stock':
        getStockData();
        break;
    case 'get_categories':
        getCategories();
        break;
    case 'search':
        searchMaterials();
        break;
    case 'filter':
        filterMaterials();
        break;
    case 'get_transactions':
        getMaterialTransactions();
        break;
    case 'update_stock':
        updateMaterialStock();
        break;
    case 'export_pdf':
        exportToPDF();
        break;
    default:
        echo json_encode([
            'status' => 'error',
            'message' => 'Invalid action'
        ]);
        break;
}

// Get all materials with current stock
function getStockData() {
    global $connect;
    
    try {
        $query = "SELECT m.*, c.nama_c as kategory 
                  FROM materials m 
                  LEFT JOIN categories c ON m.category_id = c.id_c 
                  ORDER BY m.nama_m ASC";
        
        $result = $connect->query($query);
        $materials = [];
        
        while ($row = $result->fetch_assoc()) {
            $currentStock = getCurrentStock($row['id_m']);
            $status = getStockStatus($currentStock);
            
            $materials[] = [
                'id_m' => $row['id_m'],
                'code_m' => $row['code_m'],
                'nama_m' => $row['nama_m'],
                'satuan' => $row['satuan'],
                'description' => $row['description'],
                'category_id' => $row['category_id'],
                'kategory' => $row['kategory'] ?? 'Tidak Berkategori',
                'jumlah' => $currentStock,
                'status' => $status,
                'last_update' => formatDate($row['updated_at']),
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at']
            ];
        }
        
        echo json_encode([
            'status' => 'success',
            'data' => $materials,
            'total' => count($materials)
        ]);
        
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to fetch stock data: ' . $e->getMessage()
        ]);
    }
}

// Get all categories
function getCategories() {
    global $connect;
    
    try {
        $query = "SELECT * FROM categories WHERE is_active = 1 ORDER BY nama_c ASC";
        $result = $connect->query($query);
        $categories = [];
        
        while ($row = $result->fetch_assoc()) {
            $categories[] = [
                'id_c' => $row['id_c'],
                'nama_c' => $row['nama_c'],
                'description' => $row['description'],
                'is_active' => $row['is_active'],
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at']
            ];
        }
        
        echo json_encode([
            'status' => 'success',
            'data' => $categories,
            'total' => count($categories)
        ]);
        
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to fetch categories: ' . $e->getMessage()
        ]);
    }
}

// Search materials
function searchMaterials() {
    global $connect;
    
    try {
        $query = $_GET['query'] ?? '';
        
        if (empty($query)) {
            getStockData();
            return;
        }
        
        $searchTerm = '%' . $query . '%';
        $sql = "SELECT m.*, c.nama_c as kategory 
                FROM materials m 
                LEFT JOIN categories c ON m.category_id = c.id_c 
                WHERE m.nama_m LIKE ? OR m.code_m LIKE ? 
                ORDER BY m.nama_m ASC";
        
        $stmt = $connect->prepare($sql);
        $stmt->bind_param("ss", $searchTerm, $searchTerm);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $materials = [];
        while ($row = $result->fetch_assoc()) {
            $currentStock = getCurrentStock($row['id_m']);
            $status = getStockStatus($currentStock);
            
            $materials[] = [
                'id_m' => $row['id_m'],
                'code_m' => $row['code_m'],
                'nama_m' => $row['nama_m'],
                'satuan' => $row['satuan'],
                'description' => $row['description'],
                'category_id' => $row['category_id'],
                'kategory' => $row['kategory'] ?? 'Tidak Berkategori',
                'jumlah' => $currentStock,
                'status' => $status,
                'last_update' => formatDate($row['updated_at']),
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at']
            ];
        }
        
        echo json_encode([
            'status' => 'success',
            'data' => $materials,
            'total' => count($materials)
        ]);
        
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to search materials: ' . $e->getMessage()
        ]);
    }
}

// Filter materials
function filterMaterials() {
    global $connect;
    
    try {
        $category = $_GET['category'] ?? '';
        $status = $_GET['status'] ?? '';
        $search = $_GET['search'] ?? '';
        
        $whereConditions = [];
        $params = [];
        $types = '';
        
        // Base query
        $sql = "SELECT m.*, c.nama_c as kategory 
                FROM materials m 
                LEFT JOIN categories c ON m.category_id = c.id_c";
        
        // Add search condition
        if (!empty($search)) {
            $whereConditions[] = "(m.nama_m LIKE ? OR m.code_m LIKE ?)";
            $searchTerm = '%' . $search . '%';
            $params[] = $searchTerm;
            $params[] = $searchTerm;
            $types .= 'ss';
        }
        
        // Add category condition
        if (!empty($category) && $category !== 'semua kategory') {
            $whereConditions[] = "c.nama_c = ?";
            $params[] = $category;
            $types .= 's';
        }
        
        // Build WHERE clause
        if (!empty($whereConditions)) {
            $sql .= " WHERE " . implode(" AND ", $whereConditions);
        }
        
        $sql .= " ORDER BY m.nama_m ASC";
        
        $stmt = $connect->prepare($sql);
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        
        $materials = [];
        while ($row = $result->fetch_assoc()) {
            $currentStock = getCurrentStock($row['id_m']);
            $stockStatus = getStockStatus($currentStock);
            
            // Filter by status if specified
            if (!empty($status) && $status !== 'semua status') {
                if ($stockStatus !== $status) {
                    continue;
                }
            }
            
            $materials[] = [
                'id_m' => $row['id_m'],
                'code_m' => $row['code_m'],
                'nama_m' => $row['nama_m'],
                'satuan' => $row['satuan'],
                'description' => $row['description'],
                'category_id' => $row['category_id'],
                'kategory' => $row['kategory'] ?? 'Tidak Berkategori',
                'jumlah' => $currentStock,
                'status' => $stockStatus,
                'last_update' => formatDate($row['updated_at']),
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at']
            ];
        }
        
        echo json_encode([
            'status' => 'success',
            'data' => $materials,
            'total' => count($materials)
        ]);
        
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to filter materials: ' . $e->getMessage()
        ]);
    }
}

// Get material transactions
function getMaterialTransactions() {
    global $connect;
    
    try {
        $materialId = $_GET['material_id'] ?? 0;
        
        if (empty($materialId)) {
            throw new Exception('Material ID is required');
        }
        
        $query = "SELECT mt.*, m.nama_m, u.full_name as user_name 
                  FROM material_transactions mt
                  LEFT JOIN materials m ON mt.material_id = m.id_m
                  LEFT JOIN users u ON mt.created_by = u.id_u
                  WHERE mt.material_id = ?
                  ORDER BY mt.created_at DESC
                  LIMIT 20";
        
        $stmt = $connect->prepare($query);
        $stmt->bind_param("i", $materialId);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $transactions = [];
        while ($row = $result->fetch_assoc()) {
            $transactions[] = [
                'id_tm' => $row['id_tm'],
                'transaction_code' => $row['transaction_code'],
                'material_id' => $row['material_id'],
                'transaction_type' => $row['transaction_type'],
                'jumlah' => $row['jumlah'],
                'stok_sebelum' => $row['stok_sebelum'],
                'stok_sesudah' => $row['stok_sesudah'],
                'transaction_date' => $row['transaction_date'],
                'notes' => $row['notes'],
                'created_by' => $row['created_by'],
                'user_name' => $row['user_name'],
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at']
            ];
        }
        
        echo json_encode([
            'status' => 'success',
            'data' => $transactions,
            'total' => count($transactions)
        ]);
        
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to fetch transactions: ' . $e->getMessage()
        ]);
    }
}

// Update material stock
function updateMaterialStock() {
    global $connect;
    
    try {
        $input = json_decode(file_get_contents('php://input'), true);
        
        $materialId = $input['material_id'] ?? 0;
        $newStock = $input['new_stock'] ?? 0;
        $transactionType = $input['transaction_type'] ?? '';
        $notes = $input['notes'] ?? '';
        $userId = $input['user_id'] ?? 0;
        
        if (empty($materialId) || empty($transactionType) || empty($userId)) {
            throw new Exception('Missing required fields');
        }
        
        // Start transaction
        $connect->begin_transaction();
        
        // Get current stock
        $currentStock = getCurrentStock($materialId);
        
        // Calculate stock difference
        $stockDifference = 0;
        switch ($transactionType) {
            case 'in':
                $stockDifference = $newStock;
                break;
            case 'out':
                $stockDifference = -$newStock;
                break;
            case 'adjustment':
                $stockDifference = $newStock - $currentStock;
                break;
        }
        
        $newCurrentStock = $currentStock + $stockDifference;
        
        // Generate transaction code
        $transactionCode = 'TXN-' . date('Ymd') . '-' . sprintf('%06d', rand(1, 999999));
        
        // Insert transaction record
        $query = "INSERT INTO material_transactions 
                  (transaction_code, material_id, transaction_type, jumlah, stok_sebelum, stok_sesudah, transaction_date, notes, created_by) 
                  VALUES (?, ?, ?, ?, ?, ?, CURDATE(), ?, ?)";
        
        $stmt = $connect->prepare($query);
        $actualAmount = ($transactionType === 'adjustment') ? $stockDifference : $newStock;
        $stmt->bind_param("sisiiisi", $transactionCode, $materialId, $transactionType, $actualAmount, $currentStock, $newCurrentStock, $notes, $userId);
        
        if (!$stmt->execute()) {
            throw new Exception('Failed to create transaction record');
        }
        
        // Update material updated_at timestamp
        $updateQuery = "UPDATE materials SET updated_at = CURRENT_TIMESTAMP WHERE id_m = ?";
        $updateStmt = $connect->prepare($updateQuery);
        $updateStmt->bind_param("i", $materialId);
        $updateStmt->execute();
        
        $connect->commit();
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Stock updated successfully',
            'transaction_code' => $transactionCode,
            'new_stock' => $newCurrentStock
        ]);
        
    } catch (Exception $e) {
        $connect->rollback();
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to update stock: ' . $e->getMessage()
        ]);
    }
}

// Export to PDF (placeholder)
function exportToPDF() {
    try {
        // This is a placeholder for PDF export functionality
        // You would need to implement actual PDF generation here using libraries like TCPDF or FPDF
        
        echo json_encode([
            'status' => 'success',
            'message' => 'PDF export functionality will be implemented soon',
            'file_url' => ''
        ]);
        
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to export PDF: ' . $e->getMessage()
        ]);
    }
}

$connect->close();
?>
