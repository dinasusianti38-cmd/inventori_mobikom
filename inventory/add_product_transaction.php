<?php
require_once 'conn.php';

try {
    // Get JSON input
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    // Validate required fields
    $required_fields = ['product_name', 'product_code', 'quantity', 'transaction_type', 'created_by'];
    foreach ($required_fields as $field) {
        if (!isset($input[$field]) || $input[$field] === '') {
            throw new Exception("Field '$field' is required");
        }
    }
    
    $product_name = $input['product_name'];
    $product_code = $input['product_code'];
    $quantity = (int)$input['quantity'];
    $transaction_type = $input['transaction_type'];
    $created_by = (int)$input['created_by'];
    
    // Validate transaction type
    if (!in_array($transaction_type, ['in', 'out', 'adjustment'])) {
        throw new Exception('Invalid transaction type');
    }
    
    $connect->autocommit(false);
    
    // Check if product exists, if not create it
    $check_product = "SELECT id_p FROM products WHERE code_p = ? OR name_p = ?";
    $stmt_check = $connect->prepare($check_product);
    $stmt_check->bind_param("ss", $product_code, $product_name);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();
    
    if ($result_check->num_rows > 0) {
        $product = $result_check->fetch_assoc();
        $product_id = $product['id_p'];
    } else {
        // Create new product
        $insert_product = "INSERT INTO products (code_p, name_p, created_at, updated_at) VALUES (?, ?, NOW(), NOW())";
        $stmt_product = $connect->prepare($insert_product);
        $stmt_product->bind_param("ss", $product_code, $product_name);
        
        if (!$stmt_product->execute()) {
            throw new Exception('Failed to create product: ' . $stmt_product->error);
        }
        
        $product_id = $connect->insert_id;
        $stmt_product->close();
    }
    $stmt_check->close();
    
    // Get current stock
    $get_stock = "SELECT stok_tersedia FROM product_stocks WHERE product_id = ?";
    $stmt_stock = $connect->prepare($get_stock);
    $stmt_stock->bind_param("i", $product_id);
    $stmt_stock->execute();
    $result_stock = $stmt_stock->get_result();
    
    $current_stock = 0;
    if ($result_stock->num_rows > 0) {
        $stock_data = $result_stock->fetch_assoc();
        $current_stock = (int)$stock_data['stok_tersedia'];
    }
    $stmt_stock->close();
    
    // Calculate new stock
    $stock_before = $current_stock;
    if ($transaction_type == 'in') {
        $stock_after = $current_stock + $quantity;
    } else if ($transaction_type == 'out') {
        $stock_after = $current_stock - $quantity;
        if ($stock_after < 0) {
            throw new Exception('Insufficient stock. Available: ' . $current_stock);
        }
    } else { // adjustment
        $stock_after = $quantity;
    }
    
    // Generate transaction code
    $transaction_code = 'PT-' . date('YmdHis') . '-' . str_pad($product_id, 4, '0', STR_PAD_LEFT);
    
    // Note: The product_transactions table has 'material_id' field which seems to be a mistake
    // Based on the structure, it should probably be 'product_id', but I'll use what's defined
    // Insert transaction
    $insert_transaction = "INSERT INTO product_transactions 
                          (transaction_code, material_id, transaction_type, jumlah, stok_sebelum, stok_sesudah, transaction_date, created_by, created_at, updated_at) 
                          VALUES (?, ?, ?, ?, ?, ?, CURDATE(), ?, NOW(), NOW())";
    
    $stmt_trans = $connect->prepare($insert_transaction);
    $stmt_trans->bind_param("sisiiiii", $transaction_code, $product_id, $transaction_type, $quantity, $stock_before, $stock_after, $created_by);
    
    if (!$stmt_trans->execute()) {
        throw new Exception('Failed to insert transaction: ' . $stmt_trans->error);
    }
    $stmt_trans->close();
    
    // Update or insert stock
    if ($result_stock->num_rows > 0) {
        // Update existing stock
        $update_stock = "UPDATE product_stocks SET stok_tersedia = ?, last_updated = NOW(), updated_by = ? WHERE product_id = ?";
        $stmt_update = $connect->prepare($update_stock);
        $stmt_update->bind_param("iii", $stock_after, $created_by, $product_id);
        
        if (!$stmt_update->execute()) {
            throw new Exception('Failed to update stock: ' . $stmt_update->error);
        }
        $stmt_update->close();
    } else {
        // Insert new stock record
        $insert_stock = "INSERT INTO product_stocks (product_id, stok_minimal, stok_tersedia, last_updated, updated_by) VALUES (?, 0, ?, NOW(), ?)";
        $stmt_insert = $connect->prepare($insert_stock);
        $stmt_insert->bind_param("iii", $product_id, $stock_after, $created_by);
        
        if (!$stmt_insert->execute()) {
            throw new Exception('Failed to insert stock: ' . $stmt_insert->error);
        }
        $stmt_insert->close();
    }
    
    $connect->commit();
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Product transaction added successfully',
        'data' => [
            'transaction_code' => $transaction_code,
            'product_id' => $product_id,
            'stock_before' => $stock_before,
            'stock_after' => $stock_after
        ]
    ]);
    
} catch (Exception $e) {
    if (isset($connect)) {
        $connect->rollback();
    }
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
} finally {
    if (isset($connect)) {
        $connect->autocommit(true);
        $connect->close();
    }
}
?>
