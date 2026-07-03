<?php
// Disable error display to prevent HTML errors in JSON response
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);

// Set content type header at the beginning
header('Content-Type: application/json; charset=UTF-8');

require_once 'conn.php';

$method = $_SERVER['REQUEST_METHOD'];

try {
    switch ($method) {
        case 'GET':
            handleGet();
            break;
        case 'POST':
            handlePost();
            break;
        case 'PUT':
            handlePut();
            break;
        case 'DELETE':
            handleDelete();
            break;
        default:
            http_response_code(405);
            echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
            break;
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Server error: ' . $e->getMessage()]);
}

// ... (fungsi GET, POST, PUT tetap sama)

function handleDelete() {
    global $connect;
    
    try {
        // Get raw input
        $rawInput = file_get_contents('php://input');
        
        // Check if input is empty
        if (empty($rawInput) || trim($rawInput) === '') {
            http_response_code(400);
            echo json_encode([
                'status' => 'error', 
                'message' => 'No data received',
                'debug' => 'Raw input is empty'
            ]);
            return;
        }
        
        // Try to decode JSON
        $input = json_decode($rawInput, true);
        
        // Check if JSON parsing failed
        if (json_last_error() !== JSON_ERROR_NONE) {
            http_response_code(400);
            echo json_encode([
                'status' => 'error', 
                'message' => 'Invalid JSON data: ' . json_last_error_msg(),
                'debug' => 'Raw input: ' . substr($rawInput, 0, 200)
            ]);
            return;
        }
        
        // Validate required fields
        if (!isset($input['id_sp']) || empty($input['id_sp'])) {
            http_response_code(400);
            echo json_encode([
                'status' => 'error', 
                'message' => 'ID is required',
                'debug' => 'id_sp not found in input'
            ]);
            return;
        }
        
        $idSp = (int)$input['id_sp'];
        
        // Check database connection
        if (!$connect || $connect->connect_error) {
            http_response_code(500);
            echo json_encode([
                'status' => 'error', 
                'message' => 'Database connection failed'
            ]);
            return;
        }
        
        // First check if record exists
        $checkQuery = "SELECT id_sp, product_id FROM product_stocks WHERE id_sp = ?";
        $checkStmt = $connect->prepare($checkQuery);
        
        if (!$checkStmt) {
            http_response_code(500);
            echo json_encode([
                'status' => 'error', 
                'message' => 'Database prepare error: ' . $connect->error
            ]);
            return;
        }
        
        $checkStmt->bind_param("i", $idSp);
        
        if (!$checkStmt->execute()) {
            http_response_code(500);
            echo json_encode([
                'status' => 'error', 
                'message' => 'Database execute error: ' . $checkStmt->error
            ]);
            return;
        }
        
        $checkResult = $checkStmt->get_result();
        
        if ($checkResult->num_rows == 0) {
            http_response_code(404);
            echo json_encode([
                'status' => 'error', 
                'message' => 'Data dengan ID ' . $idSp . ' tidak ditemukan'
            ]);
            return;
        }
        
        // Close check statement
        $checkStmt->close();
        
        // Proceed with deletion
        $deleteQuery = "DELETE FROM product_stocks WHERE id_sp = ?";
        $deleteStmt = $connect->prepare($deleteQuery);
        
        if (!$deleteStmt) {
            http_response_code(500);
            echo json_encode([
                'status' => 'error', 
                'message' => 'Database prepare error: ' . $connect->error
            ]);
            return;
        }
        
        $deleteStmt->bind_param("i", $idSp);
        
        if (!$deleteStmt->execute()) {
            http_response_code(500);
            echo json_encode([
                'status' => 'error', 
                'message' => 'Gagal menghapus data: ' . $deleteStmt->error
            ]);
            return;
        }
        
        if ($deleteStmt->affected_rows > 0) {
            // Success response
            echo json_encode([
                'status' => 'success', 
                'message' => 'Data berhasil dihapus',
                'deleted_id' => $idSp
            ]);
        } else {
            // No rows affected
            echo json_encode([
                'status' => 'error', 
                'message' => 'Data tidak dapat dihapus atau sudah tidak ada'
            ]);
        }
        
        // Close delete statement
        $deleteStmt->close();
        
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode([
            'status' => 'error', 
            'message' => 'Exception: ' . $e->getMessage(),
            'trace' => $e->getTraceAsString()
        ]);
    }
}

// Copy all other functions (handleGet, handlePost, handlePut) exactly as they are
function handleGet() {
    global $connect;
    
    $search = isset($_GET['search']) ? $_GET['search'] : '';
    $status_filter = isset($_GET['status']) ? $_GET['status'] : '';
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 10;
    $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;
    
    // Base query with INNER JOIN instead of LEFT JOIN to avoid NULL values
    $query = "SELECT 
                ps.id_sp,
                ps.product_id,
                COALESCE(p.code_p, '') as code_p,
                COALESCE(p.name_p, 'Unknown Product') as name_p,
                COALESCE(ps.stok_minimal, 0) as stok_minimal,
                COALESCE(ps.stok_tersedia, 0) as stok_tersedia,
                ps.last_updated,
                COALESCE(u.full_name, 'Unknown User') as updated_by_name,
                CASE 
                    WHEN COALESCE(ps.stok_tersedia, 0) <= COALESCE(ps.stok_minimal, 0) THEN 'stok habis'
                    WHEN COALESCE(ps.stok_tersedia, 0) <= (COALESCE(ps.stok_minimal, 0) * 1.5) THEN 'stok menipis'
                    ELSE 'stok normal'
                END as status
              FROM product_stocks ps
              INNER JOIN products p ON ps.product_id = p.id_p
              LEFT JOIN users u ON ps.updated_by = u.id_u
              WHERE ps.product_id IS NOT NULL 
              AND ps.stok_minimal IS NOT NULL 
              AND ps.stok_tersedia IS NOT NULL";
    
    $conditions = [];
    $params = [];
    $types = "";
    
    // Search filter
    if (!empty($search)) {
        $conditions[] = "(p.name_p LIKE ? OR p.code_p LIKE ?)";
        $searchParam = "%$search%";
        $params[] = $searchParam;
        $params[] = $searchParam;
        $types .= "ss";
    }
    
    // Status filter
    if (!empty($status_filter)) {
        if ($status_filter === 'stok habis') {
            $conditions[] = "COALESCE(ps.stok_tersedia, 0) <= COALESCE(ps.stok_minimal, 0)";
        } elseif ($status_filter === 'stok menipis') {
            $conditions[] = "COALESCE(ps.stok_tersedia, 0) <= (COALESCE(ps.stok_minimal, 0) * 1.5) AND COALESCE(ps.stok_tersedia, 0) > COALESCE(ps.stok_minimal, 0)";
        } elseif ($status_filter === 'stok normal') {
            $conditions[] = "COALESCE(ps.stok_tersedia, 0) > (COALESCE(ps.stok_minimal, 0) * 1.5)";
        }
    }
    
    // Add conditions to query
    if (!empty($conditions)) {
        $query .= " AND " . implode(" AND ", $conditions);
    }
    
    $query .= " ORDER BY ps.last_updated DESC";
    
    // Get total count for pagination
    $countQuery = "SELECT COUNT(*) as total FROM product_stocks ps
                   INNER JOIN products p ON ps.product_id = p.id_p
                   WHERE ps.product_id IS NOT NULL 
                   AND ps.stok_minimal IS NOT NULL 
                   AND ps.stok_tersedia IS NOT NULL";
    
    if (!empty($conditions)) {
        $countQuery .= " AND " . implode(" AND ", $conditions);
    }
    
    if (!empty($params)) {
        $countStmt = $connect->prepare($countQuery);
        $countStmt->bind_param($types, ...$params);
        $countStmt->execute();
        $countResult = $countStmt->get_result();
        $totalRecords = $countResult->fetch_assoc()['total'];
    } else {
        $countResult = $connect->query($countQuery);
        $totalRecords = $countResult->fetch_assoc()['total'];
    }
    
    // Add limit and offset
    $query .= " LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";
    
    // Execute main query
    if (!empty($params)) {
        $stmt = $connect->prepare($query);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
    } else {
        $result = $connect->query($query);
    }
    
    $data = [];
    while ($row = $result->fetch_assoc()) {
        // Additional NULL check and sanitization
        $data[] = [
            'id_sp' => (int)($row['id_sp'] ?? 0),
            'product_id' => (int)($row['product_id'] ?? 0),
            'code_p' => $row['code_p'] ?? '',
            'name_p' => $row['name_p'] ?? 'Unknown Product',
            'stok_minimal' => (int)($row['stok_minimal'] ?? 0),
            'stok_tersedia' => (int)($row['stok_tersedia'] ?? 0),
            'last_updated' => $row['last_updated'] ?? '',
            'updated_by_name' => $row['updated_by_name'] ?? 'Unknown User',
            'status' => $row['status'] ?? 'unknown'
        ];
    }
    
    echo json_encode([
        'status' => 'success',
        'data' => $data,
        'total' => (int)$totalRecords,
        'limit' => $limit,
        'offset' => $offset
    ]);
}

function handlePost() {
    global $connect;
    
    $input = json_decode(file_get_contents('php://input'), true);
    
    // Check if JSON parsing failed
    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid JSON data']);
        return;
    }
    
    if (!isset($input['product_id']) || !isset($input['stok_minimal']) || !isset($input['stok_tersedia'])) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Missing required fields']);
        return;
    }
    
    // Validate that product exists
    $checkProduct = "SELECT id_p FROM products WHERE id_p = ?";
    $checkStmt = $connect->prepare($checkProduct);
    $checkStmt->bind_param("i", $input['product_id']);
    $checkStmt->execute();
    $productResult = $checkStmt->get_result();
    
    if ($productResult->num_rows == 0) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Product not found']);
        return;
    }
    
    $query = "INSERT INTO product_stocks (product_id, stok_minimal, stok_tersedia, updated_by) VALUES (?, ?, ?, ?)";
    $stmt = $connect->prepare($query);
    $stmt->bind_param("iiii", 
        $input['product_id'],
        $input['stok_minimal'],
        $input['stok_tersedia'],
        $input['updated_by'] ?? 1
    );
    
    if ($stmt->execute()) {
        echo json_encode(['status' => 'success', 'message' => 'Data berhasil ditambahkan']);
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Gagal menambahkan data: ' . $stmt->error]);
    }
}

function handlePut() {
    global $connect;
    
    $input = json_decode(file_get_contents('php://input'), true);
    
    // Check if JSON parsing failed
    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Invalid JSON data']);
        return;
    }
    
    if (!isset($input['id_sp'])) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'ID is required']);
        return;
    }
    
    $query = "UPDATE product_stocks SET ";
    $params = [];
    $types = "";
    $updates = [];
    
    if (isset($input['stok_minimal'])) {
        $updates[] = "stok_minimal = ?";
        $params[] = (int)$input['stok_minimal'];
        $types .= "i";
    }
    
    if (isset($input['stok_tersedia'])) {
        $updates[] = "stok_tersedia = ?";
        $params[] = (int)$input['stok_tersedia'];
        $types .= "i";
    }
    
    if (isset($input['updated_by'])) {
        $updates[] = "updated_by = ?";
        $params[] = (int)$input['updated_by'];
        $types .= "i";
    }
    
    $updates[] = "last_updated = CURRENT_TIMESTAMP";
    
    $query .= implode(", ", $updates) . " WHERE id_sp = ?";
    $params[] = (int)$input['id_sp'];
    $types .= "i";
    
    $stmt = $connect->prepare($query);
    $stmt->bind_param($types, ...$params);
    
    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            echo json_encode(['status' => 'success', 'message' => 'Data berhasil diupdate']);
        } else {
            echo json_encode(['status' => 'error', 'message' => 'Data tidak ditemukan atau tidak ada perubahan']);
        }
    } else {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Gagal mengupdate data: ' . $stmt->error]);
    }
}
?>