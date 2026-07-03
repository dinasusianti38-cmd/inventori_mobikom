<?php
// Add CORS headers
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'conn.php';

// Add error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Get JSON input
$input = json_decode(file_get_contents('php://input'), true);

// Log the input for debugging
error_log("Received input: " . json_encode($input));

if (!$input) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Invalid JSON input']);
    exit;
}

$action = $input['action'] ?? '';

switch ($action) {
    case 'get_categories':
        getCategories($connect, $input);
        break;
    case 'add_category':
        addCategory($connect, $input);
        break;
    case 'update_category':
        updateCategory($connect, $input);
        break;
    case 'delete_category':
        deleteCategory($connect, $input);
        break;
    case 'toggle_status':
        toggleCategoryStatus($connect, $input);
        break;
    default:
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
        break;
}

function getCategories($connect, $input) {
    try {
        error_log("getCategories called with input: " . json_encode($input));
        
        $page = intval($input['page'] ?? 1);
        $limit = intval($input['limit'] ?? 10);
        $search = $input['search'] ?? '';
        
        $offset = ($page - 1) * $limit;
        
        // Base query
        $whereClause = '';
        $params = [];
        
        if (!empty($search)) {
            $whereClause = "WHERE nama_c LIKE ? OR description LIKE ?";
            $params[] = "%$search%";
            $params[] = "%$search%";
        }
        
        // Count total records
        $countQuery = "SELECT COUNT(*) as total FROM categories $whereClause";
        $countStmt = $connect->prepare($countQuery);
        
        if (!empty($params)) {
            $countStmt->bind_param(str_repeat('s', count($params)), ...$params);
        }
        
        $countStmt->execute();
        $countResult = $countStmt->get_result();
        $totalRecords = $countResult->fetch_assoc()['total'];
        $totalPages = ceil($totalRecords / $limit);
        
        // Get categories with pagination
        $query = "SELECT id_c, nama_c, description, is_active, 
                         DATE_FORMAT(created_at, '%d/%m/%Y %H:%i') as created_at,
                         DATE_FORMAT(updated_at, '%d/%m/%Y %H:%i') as updated_at
                  FROM categories 
                  $whereClause 
                  ORDER BY created_at DESC 
                  LIMIT ? OFFSET ?";
        
        $stmt = $connect->prepare($query);
        
        if (!empty($params)) {
            $allParams = array_merge($params, [$limit, $offset]);
            $types = str_repeat('s', count($params)) . 'ii';
            $stmt->bind_param($types, ...$allParams);
        } else {
            $stmt->bind_param('ii', $limit, $offset);
        }
        
        $stmt->execute();
        $result = $stmt->get_result();
        
        $categories = [];
        while ($row = $result->fetch_assoc()) {
            $categories[] = $row;
        }
        
        $response = [
            'status' => 'success',
            'data' => $categories,
            'total_records' => $totalRecords,
            'total_pages' => $totalPages,
            'current_page' => $page,
            'per_page' => $limit
        ];
        
        error_log("Response: " . json_encode($response));
        
        echo json_encode($response);
        
    } catch (Exception $e) {
        error_log("Error in getCategories: " . $e->getMessage());
        echo json_encode([
            'status' => 'error',
            'message' => 'Error fetching categories: ' . $e->getMessage()
        ]);
    }
}

function addCategory($connect, $input) {
    try {
        $nama_c = trim($input['nama_c'] ?? '');
        $description = trim($input['description'] ?? '');
        // FIX: Properly handle is_active parameter
        $is_active = isset($input['is_active']) ? intval($input['is_active']) : 1;
        
        error_log("addCategory - nama_c: $nama_c, description: $description, is_active: $is_active");
        
        if (empty($nama_c)) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Nama kategori tidak boleh kosong'
            ]);
            return;
        }
        
        // Check if category name already exists
        $checkQuery = "SELECT id_c FROM categories WHERE nama_c = ?";
        $checkStmt = $connect->prepare($checkQuery);
        $checkStmt->bind_param('s', $nama_c);
        $checkStmt->execute();
        $checkResult = $checkStmt->get_result();
        
        if ($checkResult->num_rows > 0) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Nama kategori sudah ada'
            ]);
            return;
        }
        
        // Insert new category with is_active parameter
        $query = "INSERT INTO categories (nama_c, description, is_active, created_at, updated_at) 
                  VALUES (?, ?, ?, NOW(), NOW())";
        $stmt = $connect->prepare($query);
        $stmt->bind_param('ssi', $nama_c, $description, $is_active);
        
        if ($stmt->execute()) {
            echo json_encode([
                'status' => 'success',
                'message' => 'Kategori berhasil ditambahkan',
                'id' => $connect->insert_id
            ]);
        } else {
            echo json_encode([
                'status' => 'error',
                'message' => 'Gagal menambahkan kategori'
            ]);
        }
        
    } catch (Exception $e) {
        error_log("Error in addCategory: " . $e->getMessage());
        echo json_encode([
            'status' => 'error',
            'message' => 'Error adding category: ' . $e->getMessage()
        ]);
    }
}

function updateCategory($connect, $input) {
    try {
        $id_c = intval($input['id_c'] ?? 0);
        $nama_c = trim($input['nama_c'] ?? '');
        $description = trim($input['description'] ?? '');
        // FIX: Properly handle is_active parameter
        $is_active = isset($input['is_active']) ? intval($input['is_active']) : 1;
        
        error_log("updateCategory - id_c: $id_c, nama_c: $nama_c, description: $description, is_active: $is_active");
        
        if ($id_c <= 0) {
            echo json_encode([
                'status' => 'error',
                'message' => 'ID kategori tidak valid'
            ]);
            return;
        }
        
        if (empty($nama_c)) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Nama kategori tidak boleh kosong'
            ]);
            return;
        }
        
        // Check if category exists
        $checkQuery = "SELECT id_c FROM categories WHERE id_c = ?";
        $checkStmt = $connect->prepare($checkQuery);
        $checkStmt->bind_param('i', $id_c);
        $checkStmt->execute();
        $checkResult = $checkStmt->get_result();
        
        if ($checkResult->num_rows === 0) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Kategori tidak ditemukan'
            ]);
            return;
        }
        
        // Check if category name already exists (excluding current record)
        $checkNameQuery = "SELECT id_c FROM categories WHERE nama_c = ? AND id_c != ?";
        $checkNameStmt = $connect->prepare($checkNameQuery);
        $checkNameStmt->bind_param('si', $nama_c, $id_c);
        $checkNameStmt->execute();
        $checkNameResult = $checkNameStmt->get_result();
        
        if ($checkNameResult->num_rows > 0) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Nama kategori sudah ada'
            ]);
            return;
        }
        
        // Update category with is_active parameter
        $query = "UPDATE categories SET nama_c = ?, description = ?, is_active = ?, updated_at = NOW() WHERE id_c = ?";
        $stmt = $connect->prepare($query);
        $stmt->bind_param('ssii', $nama_c, $description, $is_active, $id_c);
        
        if ($stmt->execute()) {
            echo json_encode([
                'status' => 'success',
                'message' => 'Kategori berhasil diupdate'
            ]);
        } else {
            echo json_encode([
                'status' => 'error',
                'message' => 'Gagal mengupdate kategori'
            ]);
        }
        
    } catch (Exception $e) {
        error_log("Error in updateCategory: " . $e->getMessage());
        echo json_encode([
            'status' => 'error',
            'message' => 'Error updating category: ' . $e->getMessage()
        ]);
    }
}

function deleteCategory($connect, $input) {
    try {
        $id_c = intval($input['id_c'] ?? 0);
        
        if ($id_c <= 0) {
            echo json_encode(['status' => 'error', 'message' => 'ID kategori tidak valid']);
            return;
        }

        // Jalankan perintah hapus secara langsung
        $query = "DELETE FROM categories WHERE id_c = ?";
        $stmt = $connect->prepare($query);
        $stmt->bind_param('i', $id_c);
        
        if ($stmt->execute()) {
            // JIKA BERHASIL (Berarti benar-benar tidak digunakan di tabel manapun)
            echo json_encode([
                'status' => 'success',
                'message' => 'Kategori berhasil dihapus'
            ]);
        } else {
            // JIKA GAGAL (Karena error database umum)
            echo json_encode(['status' => 'error', 'message' => 'Gagal menghapus kategori']);
        }
        
    } catch (Exception $e) {
        error_log("Error in deleteCategory: " . $e->getMessage());
        
        // --- BAGIAN YANG ANDA MINTA ---
        // Jika error mengandung kata 'foreign key' atau 'constraint', 
        // berarti kategori sedang digunakan di tabel manapun (materials, products, dll)
        if (strpos(strtolower($e->getMessage()), 'foreign key') !== false || 
            strpos(strtolower($e->getMessage()), 'constraint') !== false) {
            
            echo json_encode([
                'status' => 'error',
                'message' => 'kategori ini sedang digunakan oleh material atau projek'
            ]);
        } else {
            // Jika error lain (misal koneksi terputus)
            echo json_encode([
                'status' => 'error',
                'message' => 'Gagal menghapus kategori: ' . $e->getMessage()
            ]);
        }
    }
}
function toggleCategoryStatus($connect, $input) {
    try {
        $id_c = intval($input['id_c'] ?? 0);
        
        if ($id_c <= 0) {
            echo json_encode([
                'status' => 'error',
                'message' => 'ID kategori tidak valid'
            ]);
            return;
        }
        
        // Check if category exists and get current status
        $checkQuery = "SELECT is_active FROM categories WHERE id_c = ?";
        $checkStmt = $connect->prepare($checkQuery);
        $checkStmt->bind_param('i', $id_c);
        $checkStmt->execute();
        $checkResult = $checkStmt->get_result();
        
        if ($checkResult->num_rows === 0) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Kategori tidak ditemukan'
            ]);
            return;
        }
        
        $currentStatus = $checkResult->fetch_assoc()['is_active'];
        $newStatus = $currentStatus == 1 ? 0 : 1;
        
        // Update status
        $query = "UPDATE categories SET is_active = ?, updated_at = NOW() WHERE id_c = ?";
        $stmt = $connect->prepare($query);
        $stmt->bind_param('ii', $newStatus, $id_c);
        
        if ($stmt->execute()) {
            $statusText = $newStatus == 1 ? 'diaktifkan' : 'dinonaktifkan';
            echo json_encode([
                'status' => 'success',
                'message' => "Kategori berhasil $statusText"
            ]);
        } else {
            echo json_encode([
                'status' => 'error',
                'message' => 'Gagal mengubah status kategori'
            ]);
        }
        
    } catch (Exception $e) {
        error_log("Error in toggleCategoryStatus: " . $e->getMessage());
        echo json_encode([
            'status' => 'error',
            'message' => 'Error toggling category status: ' . $e->getMessage()
        ]);
    }
}

// Close database connection
$connect->close();
?>