<?php
include 'conn.php';

try {
    $query = "SELECT nama_c FROM categories WHERE is_active = 1 ORDER BY nama_c ASC";
    $result = $connect->query($query);
    
    $categories = [];
    if ($result->num_rows > 0) {
        while ($row = $result->fetch_assoc()) {
            $categories[] = $row['nama_c'];
        }
    }
    
    echo json_encode([
        'status' => 'success',
        'data' => $categories
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$connect->close();
?>
