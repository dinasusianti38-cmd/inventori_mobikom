<?php
require_once 'conn.php';

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $id = $input['id'] ?? 0;
    $product_name = $input['product_name'] ?? '';
    $product_code = $input['product_code'] ?? '';
    $stock_quantity = $input['stock_quantity'] ?? 0;
    $min_stock = $input['min_stock'] ?? 0;
    $description = $input['description'] ?? '';
    
    if (empty($id) || empty($product_name) || empty($product_code)) {
        throw new Exception('ID, product name and code are required');
    }
    
    // Check if product stock exists
    $check_sql = "SELECT ps.product_id FROM product_stocks ps WHERE ps.id_sp = ?";
    $check_stmt = $connect->prepare($check_sql);
    $check_stmt->bind_param("i", $id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();
    
    if ($check_result->num_rows == 0) {
        throw new Exception('Product stock not found');
    }
    
    $product_row = $check_result->fetch_assoc();
    $product_id = $product_row['product_id'];
    
    // Check if product code already exists for different product
    $check_code_sql = "SELECT id_p FROM products WHERE code_p = ? AND id_p != ?";
    $check_code_stmt = $connect->prepare($check_code_sql);
    $check_code_stmt->bind_param("si", $product_code, $product_id);
    $check_code_stmt->execute();
    $check_code_result = $check_code_stmt->get_result();
    
    if ($check_code_result->num_rows > 0) {
        throw new Exception('Product code already exists for another product');
    }
    
    // Start transaction
    $connect->begin_transaction();
    
    // Update products table
    $update_product_sql = "UPDATE products SET code_p = ?, name_p = ?, description = ?, updated_at = NOW() WHERE id_p = ?";
    $update_product_stmt = $connect->prepare($update_product_sql);
    $update_product_stmt->bind_param("sssi", $product_code, $product_name, $description, $product_id);
    
    if (!$update_product_stmt->execute()) {
        throw new Exception('Failed to update product: ' . $update_product_stmt->error);
    }
    
    // Update product_stocks table
    $update_stock_sql = "UPDATE product_stocks SET stok_minimal = ?, stok_tersedia = ?, last_updated = NOW(), updated_by = 1 WHERE id_sp = ?";
    $update_stock_stmt = $connect->prepare($update_stock_sql);
    $update_stock_stmt->bind_param("iii", $min_stock, $stock_quantity, $id);
    
    if (!$update_stock_stmt->execute()) {
        throw new Exception('Failed to update product stock: ' . $update_stock_stmt->error);
    }
    
    // Commit transaction
    $connect->commit();
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Product stock updated successfully'
    ]);
    
} catch (Exception $e) {
    // Rollback transaction on error
    if ($connect->error) {
        $connect->rollback();
    }
    
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}

$connect->close();
?>
