<?php
require_once 'conn.php';

// Only allow POST method
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode([
        'status' => 'error',
        'message' => 'Only POST method allowed'
    ]);
    exit;
}

try {
    // Get JSON input
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    // Validate required fields
    $required_fields = ['id_sp', 'stok_tersedia', 'updated_by'];
    foreach ($required_fields as $field) {
        if (!isset($input[$field]) || $input[$field] === '') {
            throw new Exception("Field '$field' is required");
        }
    }
    
    $id_sp = (int)$input['id_sp'];
    $stok_tersedia = (int)$input['stok_tersedia'];
    $updated_by = (int)$input['updated_by'];
    
    // Validate positive values
    if ($id_sp <= 0) {
        throw new Exception('Invalid product stock ID');
    }
    
    if ($stok_tersedia < 0) {
        throw new Exception('Stock quantity cannot be negative');
    }
    
    if ($updated_by <= 0) {
        throw new Exception('Invalid user ID');
    }
    
    // Check if product stock exists
    $check_query = "SELECT id_sp FROM product_stocks WHERE id_sp = ?";
    $check_stmt = $connect->prepare($check_query);
    $check_stmt->bind_param('i', $id_sp);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();
    
    if ($check_result->num_rows === 0) {
        throw new Exception('Product stock not found');
    }
    
    // Update product stock
    $update_query = "UPDATE product_stocks 
                     SET stok_tersedia = ?, 
                         updated_by = ?, 
                         last_updated = CURRENT_TIMESTAMP 
                     WHERE id_sp = ?";
    
    $update_stmt = $connect->prepare($update_query);
    $update_stmt->bind_param('iii', $stok_tersedia, $updated_by, $id_sp);
    
    if ($update_stmt->execute()) {
        if ($update_stmt->affected_rows > 0) {
            echo json_encode([
                'status' => 'success',
                'message' => 'Product stock updated successfully',
                'data' => [
                    'id_sp' => $id_sp,
                    'stok_tersedia' => $stok_tersedia,
                    'updated_by' => $updated_by
                ]
            ]);
        } else {
            throw new Exception('No changes made to product stock');
        }
    } else {
        throw new Exception('Failed to update product stock: ' . $update_stmt->error);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'data' => null
    ]);
}

if (isset($check_stmt)) {
    $check_stmt->close();
}
if (isset($update_stmt)) {
    $update_stmt->close();
}
$connect->close();
?>
