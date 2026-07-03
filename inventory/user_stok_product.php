<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'conn.php';

// Get JSON input
$input = json_decode(file_get_contents('php://input'), true);
$action = $input['action'] ?? '';

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

switch ($action) {
    case 'fetch_product_stocks':
        fetchProductStocks($connect, $input);
        break;
    case 'get_total_count':
        getTotalCount($connect, $input);
        break;
    case 'fetch_categories':
        fetchCategories($connect);
        break;
    default:
        echo json_encode([
            'status' => 'error',
            'message' => 'Invalid action: ' . $action
        ]);
        break;
}

function fetchProductStocks($connect, $input) {
    try {
        $search = $input['search'] ?? '';
        $category = $input['category'] ?? '';
        $limit = intval($input['limit'] ?? 10);
        $offset = intval($input['offset'] ?? 0);

        // Debug log
        error_log("=== FETCH PRODUCT STOCKS DEBUG ===");
        error_log("Search: " . $search);
        error_log("Category: " . $category);
        error_log("Limit: " . $limit);
        error_log("Offset: " . $offset);

        // Fixed query - removed problematic p.category_id reference
        // Assuming basic structure without category relationship
        $query = "SELECT 
                    ps.id_sp,
                    ps.product_id,
                    COALESCE(p.code_p, CONCAT('PRD-', ps.product_id)) as code_p,
                    COALESCE(p.name_p, 'Unknown Product') as name_p,
                    COALESCE(p.description, 'No description') as description,
                    ps.stok_minimal,
                    ps.stok_tersedia,
                    'General' as category_name,
                    CASE 
                        WHEN ps.stok_tersedia = 0 THEN 'stok habis'
                        WHEN ps.stok_tersedia <= ps.stok_minimal THEN 'stok menipis'
                        ELSE 'stok normal'
                    END as status,
                    COALESCE(DATE_FORMAT(ps.last_updated, '%Y-%m-%d'), CURDATE()) as last_updated
                  FROM product_stocks ps
                  LEFT JOIN products p ON ps.product_id = p.id_p
                  WHERE 1=1";

        $params = [];
        $types = '';

        // Add search condition if provided
        if (!empty($search)) {
            $query .= " AND (LOWER(p.name_p) LIKE LOWER(?) OR LOWER(p.code_p) LIKE LOWER(?) OR LOWER(ps.product_id) LIKE LOWER(?))";
            $searchParam = "%$search%";
            $params[] = $searchParam;
            $params[] = $searchParam; 
            $params[] = $searchParam;
            $types .= 'sss';
        }

        // Skip category filter for now since structure is unclear
        // Add it back when you confirm database structure

        // Add ordering
        $query .= " ORDER BY ps.last_updated DESC, ps.id_sp DESC";

        // Add pagination
        $query .= " LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        $types .= 'ii';

        error_log("Final Query: " . $query);
        error_log("Parameters: " . json_encode($params));

        $stmt = $connect->prepare($query);
        if (!$stmt) {
            throw new Exception("Prepare failed: " . $connect->error);
        }

        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        
        if (!$stmt->execute()) {
            throw new Exception("Execute failed: " . $stmt->error);
        }

        $result = $stmt->get_result();
        
        $products = [];
        while ($row = $result->fetch_assoc()) {
            // Ensure all fields are properly set
            $row['id_sp'] = intval($row['id_sp']);
            $row['product_id'] = intval($row['product_id']);
            $row['stok_minimal'] = intval($row['stok_minimal']);
            $row['stok_tersedia'] = intval($row['stok_tersedia']);
            
            $products[] = $row;
        }

        error_log("Found " . count($products) . " products");

        echo json_encode([
            'status' => 'success',
            'data' => $products,
            'message' => 'Data loaded successfully',
            'debug' => [
                'query' => $query,
                'params_count' => count($params),
                'result_count' => count($products)
            ]
        ]);

    } catch (Exception $e) {
        error_log("Error in fetchProductStocks: " . $e->getMessage());
        error_log("Stack trace: " . $e->getTraceAsString());
        
        echo json_encode([
            'status' => 'error',
            'message' => 'Database error: ' . $e->getMessage(),
            'debug' => [
                'error_line' => $e->getLine(),
                'error_file' => basename($e->getFile())
            ]
        ]);
    }
}

function getTotalCount($connect, $input) {
    try {
        $search = $input['search'] ?? '';
        $category = $input['category'] ?? '';

        $query = "SELECT COUNT(*) as total
                  FROM product_stocks ps
                  LEFT JOIN products p ON ps.product_id = p.id_p
                  WHERE 1=1";

        $params = [];
        $types = '';

        // Add search condition
        if (!empty($search)) {
            $query .= " AND (LOWER(p.name_p) LIKE LOWER(?) OR LOWER(p.code_p) LIKE LOWER(?) OR LOWER(ps.product_id) LIKE LOWER(?))";
            $searchParam = "%$search%";
            $params[] = $searchParam;
            $params[] = $searchParam;
            $params[] = $searchParam;
            $types .= 'sss';
        }

        // Skip category filter for now

        $stmt = $connect->prepare($query);
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();

        echo json_encode([
            'status' => 'success',
            'total' => intval($row['total'])
        ]);

    } catch (Exception $e) {
        error_log("Error in getTotalCount: " . $e->getMessage());
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to get total count: ' . $e->getMessage()
        ]);
    }
}

function fetchCategories($connect) {
    try {
        // Return default categories for now, or empty array if categories table doesn't exist
        $categories = [
            ['id_c' => 1, 'nama_c' => 'Elektronik', 'description' => 'Kategori Elektronik', 'is_active' => 1],
            ['id_c' => 2, 'nama_c' => 'Aksesoris', 'description' => 'Kategori Aksesoris', 'is_active' => 1],
            ['id_c' => 3, 'nama_c' => 'General', 'description' => 'Kategori Umum', 'is_active' => 1]
        ];

        // Try to fetch from categories table if it exists
        $query = "SHOW TABLES LIKE 'categories'";
        $result = $connect->query($query);
        
        if ($result && $result->num_rows > 0) {
            // Categories table exists, try to fetch
            $query = "SELECT id_c, nama_c, description, is_active 
                      FROM categories 
                      WHERE is_active = 1 
                      ORDER BY nama_c ASC";
            
            $result = $connect->query($query);
            if ($result) {
                $categories = [];
                while ($row = $result->fetch_assoc()) {
                    $categories[] = $row;
                }
            }
        }

        echo json_encode([
            'status' => 'success',
            'data' => $categories
        ]);

    } catch (Exception $e) {
        error_log("Error in fetchCategories: " . $e->getMessage());
        
        // Return default categories on error
        echo json_encode([
            'status' => 'success',
            'data' => [
                ['id_c' => 1, 'nama_c' => 'General', 'description' => 'Default Category', 'is_active' => 1]
            ],
            'message' => 'Using default categories due to: ' . $e->getMessage()
        ]);
    }
}

// Close connection
if (isset($connect)) {
    $connect->close();
}
?>