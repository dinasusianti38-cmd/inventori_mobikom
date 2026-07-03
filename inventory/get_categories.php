<?php
require_once 'conn.php';

try {
    $query = "SELECT id_c, nama_c, description, is_active, created_at, updated_at 
              FROM categories 
              WHERE is_active = TRUE 
              ORDER BY nama_c ASC";
    
    $result = $connect->query($query);
    
    if ($result) {
        $categories = [];
        while ($row = $result->fetch_assoc()) {
            $categories[] = [
                'id_c' => (int)$row['id_c'],
                'nama_c' => $row['nama_c'],
                'description' => $row['description'],
                'is_active' => (bool)$row['is_active'],
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at']
            ];
        }
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Categories retrieved successfully',
            'data' => $categories
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