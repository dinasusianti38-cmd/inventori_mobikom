<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

require_once 'conn.php';

$action = $_GET['action'] ?? $_POST['action'] ?? '';

try {
    switch($action) {
        case 'getAll':
            getAllMaterials();
            break;
        case 'getCategories':
            getAllCategories();
            break;
        case 'add':
            addMaterial();
            break;
        case 'update':
            updateMaterial();
            break;
        case 'delete':
            deleteMaterial();
            break;
        case 'getById':
            getMaterialById();
            break;
        default:
            echo json_encode([
                'status' => 'error',
                'message' => 'Invalid action'
            ]);
    }
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}

function getAllMaterials() {
    global $connect;
    
    try {
        $sql = "SELECT m.*, c.nama_c as category_name 
                FROM materials m 
                LEFT JOIN categories c ON m.category_id = c.id_c 
                ORDER BY m.created_at DESC";
        
        $result = $connect->query($sql);
        
        if ($result) {
            $materials = [];
            while ($row = $result->fetch_assoc()) {
                $materials[] = $row;
            }
            
            echo json_encode([
                'status' => 'success',
                'data' => $materials,
                'count' => count($materials)
            ]);
        } else {
            throw new Exception('Failed to fetch materials: ' . $connect->error);
        }
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => $e->getMessage()
        ]);
    }
}

function getAllCategories() {
    global $connect;
    
    try {
        $sql = "SELECT * FROM categories WHERE is_active = 1 ORDER BY nama_c ASC";
        $result = $connect->query($sql);
        
        if ($result) {
            $categories = [];
            while ($row = $result->fetch_assoc()) {
                $categories[] = $row;
            }
            
            echo json_encode([
                'status' => 'success',
                'data' => $categories
            ]);
        } else {
            throw new Exception('Failed to fetch categories: ' . $connect->error);
        }
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => $e->getMessage()
        ]);
    }
}

function addMaterial() {
    global $connect;
    
    try {
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!$input) {
            throw new Exception('Invalid input data');
        }
        
        $codeM = trim($input['code_m'] ?? '');
        $namaM = trim($input['nama_m'] ?? '');
        $satuan = trim($input['satuan'] ?? '');
        $description = trim($input['description'] ?? '');
        $categoryId = intval($input['category_id'] ?? 0);
        
        // Validate required fields
        if (empty($namaM) || empty($satuan) || empty($categoryId)) {
            throw new Exception('All required fields must be filled');
        }
        
        
        
        $sql = "INSERT INTO materials (code_m, nama_m, satuan, description, category_id, created_at) VALUES (?, ?, ?, ?, ?, NOW())";
        $stmt = $connect->prepare($sql);
        if (!$stmt) {
            throw new Exception('Prepare statement failed: ' . $connect->error);
        }
        
        $stmt->bind_param("ssssi", $codeM, $namaM, $satuan, $description, $categoryId);
        
        if ($stmt->execute()) {
            echo json_encode([
                'status' => 'success',
                'message' => 'Material added successfully',
                'id' => $connect->insert_id
            ]);
        } else {
            throw new Exception('Failed to add material: ' . $stmt->error);
        }
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => $e->getMessage()
        ]);
    }
}

function updateMaterial() {
    global $connect;
    
    try {
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!$input) {
            throw new Exception('Invalid input data');
        }
        
        $idM = intval($input['id_m'] ?? 0);
        $codeM = trim($input['code_m'] ?? '');
        $namaM = trim($input['nama_m'] ?? '');
        $satuan = trim($input['satuan'] ?? '');
        $description = trim($input['description'] ?? '');
        $categoryId = intval($input['category_id'] ?? 0);
        
        // Validate required fields
        if (empty($idM) || empty($namaM) || empty($satuan) || empty($categoryId)) {
            throw new Exception('All required fields must be filled');
        }
        
        $sql = "UPDATE materials SET code_m = ?, nama_m = ?, satuan = ?, description = ?, category_id = ?, updated_at = NOW() WHERE id_m = ?";
        $stmt = $connect->prepare($sql);
        if (!$stmt) {
            throw new Exception('Prepare statement failed: ' . $connect->error);
        }
        
        $stmt->bind_param("ssssii", $codeM, $namaM, $satuan, $description, $categoryId, $idM);
        
        if ($stmt->execute()) {
            if ($stmt->affected_rows > 0) {
                echo json_encode([
                    'status' => 'success',
                    'message' => 'Material updated successfully'
                ]);
            } else {
                throw new Exception('Material not found or no changes made');
            }
        } else {
            throw new Exception('Failed to update material: ' . $stmt->error);
        }
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => $e->getMessage()
        ]);
    }
}

function deleteMaterial() {
    global $connect;
    
    try {
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!$input) {
            throw new Exception('Invalid input data');
        }
        
        $idM = intval($input['id_m'] ?? 0);
        
        if (empty($idM)) {
            throw new Exception('Material ID is required');
        }
        
        // Start transaction
        $connect->autocommit(false);
        
        try {
            // First check if material exists and get material info
            $checkSql = "SELECT id_m, nama_m FROM materials WHERE id_m = ?";
            $checkStmt = $connect->prepare($checkSql);
            if (!$checkStmt) {
                throw new Exception('Prepare statement failed: ' . $connect->error);
            }
            
            $checkStmt->bind_param("i", $idM);
            $checkStmt->execute();
            $checkResult = $checkStmt->get_result();
            
            if ($checkResult->num_rows === 0) {
                throw new Exception('Material tidak ditemukan');
            }
            
            $materialData = $checkResult->fetch_assoc();
            $materialName = $materialData['nama_m'];
            
            // Check if material is being used in other tables (foreign key references)
            $referenceTables = [];
            
            // Check product_materials table
            $checkProductMaterialsSql = "SELECT COUNT(*) as count FROM product_materials WHERE material_id = ?";
            $checkProductMaterialsStmt = $connect->prepare($checkProductMaterialsSql);
            if ($checkProductMaterialsStmt) {
                $checkProductMaterialsStmt->bind_param("i", $idM);
                $checkProductMaterialsStmt->execute();
                $productMaterialsResult = $checkProductMaterialsStmt->get_result();
                $productMaterialsCount = $productMaterialsResult->fetch_assoc()['count'];
                
                if ($productMaterialsCount > 0) {
                    $referenceTables[] = "produk ($productMaterialsCount referensi)";
                }
            }
            
            // Add other foreign key checks here if needed
            // Example: Check orders table, production table, etc.
            /*
            $checkOrdersSql = "SELECT COUNT(*) as count FROM orders WHERE material_id = ?";
            $checkOrdersStmt = $connect->prepare($checkOrdersSql);
            if ($checkOrdersStmt) {
                $checkOrdersStmt->bind_param("i", $idM);
                $checkOrdersStmt->execute();
                $ordersResult = $checkOrdersStmt->get_result();
                $ordersCount = $ordersResult->fetch_assoc()['count'];
                
                if ($ordersCount > 0) {
                    $referenceTables[] = "pesanan ($ordersCount referensi)";
                }
            }
            */
            
            // If material is being referenced, throw custom error
            if (!empty($referenceTables)) {
                $referenceList = implode(', ', $referenceTables);
                throw new Exception("Material \"$materialName\" sedang digunakan di $referenceList dan tidak dapat dihapus. Hapus terlebih dahulu data yang menggunakan material ini.");
            }
            
            // Count related records for information
            $deletedCounts = [
                'transactions' => 0,
                'stocks' => 0
            ];
            
            // 1. Delete from material_transactions first
            $deleteTransactionsSql = "DELETE FROM material_transactions WHERE material_id = ?";
            $deleteTransactionsStmt = $connect->prepare($deleteTransactionsSql);
            if (!$deleteTransactionsStmt) {
                throw new Exception('Prepare statement failed for transactions deletion: ' . $connect->error);
            }
            
            $deleteTransactionsStmt->bind_param("i", $idM);
            if (!$deleteTransactionsStmt->execute()) {
                throw new Exception('Failed to delete material transactions: ' . $deleteTransactionsStmt->error);
            }
            $deletedCounts['transactions'] = $deleteTransactionsStmt->affected_rows;
            
            // 2. Delete from material_stocks
            $deleteStocksSql = "DELETE FROM material_stocks WHERE material_id = ?";
            $deleteStocksStmt = $connect->prepare($deleteStocksSql);
            if (!$deleteStocksStmt) {
                throw new Exception('Prepare statement failed for stocks deletion: ' . $connect->error);
            }
            
            $deleteStocksStmt->bind_param("i", $idM);
            if (!$deleteStocksStmt->execute()) {
                throw new Exception('Failed to delete material stocks: ' . $deleteStocksStmt->error);
            }
            $deletedCounts['stocks'] = $deleteStocksStmt->affected_rows;
            
            // 3. Finally delete the material
            $deleteMaterialSql = "DELETE FROM materials WHERE id_m = ?";
            $deleteMaterialStmt = $connect->prepare($deleteMaterialSql);
            if (!$deleteMaterialStmt) {
                throw new Exception('Prepare statement failed for material deletion: ' . $connect->error);
            }
            
            $deleteMaterialStmt->bind_param("i", $idM);
            if (!$deleteMaterialStmt->execute()) {
                // Check if it's a foreign key constraint error
                $error = $deleteMaterialStmt->error;
                if (strpos($error, 'foreign key constraint fails') !== false || 
                    strpos($error, 'FOREIGN KEY') !== false ||
                    strpos($error, 'Cannot delete or update a parent row') !== false) {
                    throw new Exception("Material \"$materialName\" sedang digunakan oleh data lain dan tidak dapat dihapus. Hapus terlebih dahulu data yang menggunakan material ini.");
                }
                throw new Exception('Failed to delete material: ' . $error);
            }
            
            if ($deleteMaterialStmt->affected_rows === 0) {
                throw new Exception('Gagal menghapus material - tidak ada data yang terpengaruh');
            }
            
            // Commit transaction
            $connect->commit();
            
            // Create detailed success message
            $message = 'Material "' . $materialName . '" berhasil dihapus';
            $details = [];
            
            if ($deletedCounts['transactions'] > 0) {
                $details[] = $deletedCounts['transactions'] . ' record transaksi';
            }
            
            if ($deletedCounts['stocks'] > 0) {
                $details[] = $deletedCounts['stocks'] . ' record stok';
            }
            
            if (!empty($details)) {
                $message .= ' beserta ' . implode(' dan ', $details);
            }
            
            echo json_encode([
                'status' => 'success',
                'message' => $message,
                'deleted_data' => [
                    'material_name' => $materialName,
                    'transactions_deleted' => $deletedCounts['transactions'],
                    'stocks_deleted' => $deletedCounts['stocks']
                ]
            ]);
            
        } catch (Exception $e) {
            // Rollback transaction on error
            $connect->rollback();
            throw $e;
        }
        
    } catch (Exception $e) {
        // Handle foreign key constraint errors specifically
        $errorMessage = $e->getMessage();
        
        // Check if it's a foreign key constraint error and convert to user-friendly message
        if (strpos($errorMessage, 'foreign key constraint fails') !== false || 
            strpos($errorMessage, 'FOREIGN KEY') !== false ||
            strpos($errorMessage, 'Cannot delete or update a parent row') !== false) {
            $errorMessage = "Material ini sedang digunakan dan tidak dapat dihapus. Hapus terlebih dahulu data yang menggunakan material ini.";
        }
        
        echo json_encode([
            'status' => 'error',
            'message' => $errorMessage
        ]);
    } finally {
        // Restore autocommit
        $connect->autocommit(true);
    }
}

// Optional: Function to get deletion preview (what will be deleted)
function getDeletePreview() {
    global $connect;
    
    try {
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!$input) {
            throw new Exception('Invalid input data');
        }
        
        $idM = intval($input['id_m'] ?? 0);
        
        if (empty($idM)) {
            throw new Exception('Material ID is required');
        }
        
        // Check if material exists
        $checkSql = "SELECT id_m, nama_m FROM materials WHERE id_m = ?";
        $checkStmt = $connect->prepare($checkSql);
        if (!$checkStmt) {
            throw new Exception('Prepare statement failed: ' . $connect->error);
        }
        
        $checkStmt->bind_param("i", $idM);
        $checkStmt->execute();
        $checkResult = $checkStmt->get_result();
        
        if ($checkResult->num_rows === 0) {
            throw new Exception('Material not found');
        }
        
        $materialData = $checkResult->fetch_assoc();
        
        // Count related records
        $transactionCountSql = "SELECT COUNT(*) as count FROM material_transactions WHERE material_id = ?";
        $transactionStmt = $connect->prepare($transactionCountSql);
        $transactionStmt->bind_param("i", $idM);
        $transactionStmt->execute();
        $transactionResult = $transactionStmt->get_result();
        $transactionCount = $transactionResult->fetch_assoc()['count'];
        
        $stockCountSql = "SELECT COUNT(*) as count FROM material_stocks WHERE material_id = ?";
        $stockStmt = $connect->prepare($stockCountSql);
        $stockStmt->bind_param("i", $idM);
        $stockStmt->execute();
        $stockResult = $stockStmt->get_result();
        $stockCount = $stockResult->fetch_assoc()['count'];
        
        echo json_encode([
            'status' => 'success',
            'data' => [
                'material_name' => $materialData['nama_m'],
                'transaction_count' => $transactionCount,
                'stock_count' => $stockCount,
                'warning' => 'This will permanently delete the material and all related data. This action cannot be undone.'
            ]
        ]);
        
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => $e->getMessage()
        ]);
    }
}

function getMaterialById() {
    global $connect;
    
    try {
        $id = intval($_GET['id'] ?? 0);
        
        if (empty($id)) {
            throw new Exception('Material ID is required');
        }
        
        $sql = "SELECT m.*, c.nama_c as category_name 
                FROM materials m 
                LEFT JOIN categories c ON m.category_id = c.id_c 
                WHERE m.id_m = ?";
        
        $stmt = $connect->prepare($sql);
        if (!$stmt) {
            throw new Exception('Prepare statement failed: ' . $connect->error);
        }
        
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result && $result->num_rows > 0) {
            $material = $result->fetch_assoc();
            echo json_encode([
                'status' => 'success',
                'data' => $material
            ]);
        } else {
            throw new Exception('Material not found');
        }
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => $e->getMessage()
        ]);
    }
}
?>