<?php
require_once 'conn.php';

header('Content-Type: application/json');

try {
    // Check if table exists first
    $check_table = $connect->query("SHOW TABLES LIKE 'assembly_history'");
    
    if ($check_table->num_rows == 0) {
        // Table doesn't exist, return empty array
        echo json_encode([
            'status' => 'success',
            'message' => 'Assembly history loaded (table not created yet)',
            'data' => [],
            'count' => 0
        ]);
        exit;
    }
    
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 100;
    
    $sql = "SELECT 
                ah.id_ah,
                ah.product_id,
                ah.quantity,
                ah.assembly_date,
                ah.status,
                ah.notes,
                ah.created_by,
                p.code_p,
                p.name_p,
                p.description,
                u.nama_u as created_by_name
            FROM assembly_history ah
            INNER JOIN products p ON ah.product_id = p.id_p
            LEFT JOIN users u ON ah.created_by = u.id_u
            ORDER BY ah.assembly_date DESC
            LIMIT ?";
    
    $stmt = $connect->prepare($sql);
    
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $connect->error);
    }
    
    $stmt->bind_param("i", $limit);
    
    if (!$stmt->execute()) {
        throw new Exception("Execute failed: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    
    $history = [];
    while ($row = $result->fetch_assoc()) {
        $history[] = [
            'id_ah' => (int)$row['id_ah'],
            'product_id' => (int)$row['product_id'],
            'product_code' => $row['code_p'],
            'product_name' => $row['name_p'],
            'product_description' => $row['description'],
            'quantity' => (int)$row['quantity'],
            'assembly_date' => $row['assembly_date'],
            'status' => $row['status'],
            'notes' => $row['notes'],
            'created_by' => (int)$row['created_by'],
            'created_by_name' => $row['created_by_name']
        ];
    }
    
    $stmt->close();
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Assembly history loaded successfully',
        'data' => $history,
        'count' => count($history)
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'data' => []
    ]);
}

if (isset($connect)) {
    $connect->close();
}
?>