<?php
require_once 'conn.php';

try {
    $query = "SELECT id_p, code_p, name_p, description, created_at, updated_at
              FROM products 
              ORDER BY name_p ASC";
    
    $result = $connect->query($query);
    
    if ($result) {
        $products = [];
        while ($row = $result->fetch_assoc()) {
            $products[] = [
                'id_p' => (int)$row['id_p'],
                'code_p' => $row['code_p'],
                'name_p' => $row['name_p'],
                'description' => $row['description'],
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at']
            ];
        }
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Products retrieved successfully',
            'data' => $products
        ]);
    } else {
        throw new Exception('Failed to execute query: ' . $connect->error);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
} finally {
    if (isset($connect)) {
        $connect->close();
    }
}
?>
