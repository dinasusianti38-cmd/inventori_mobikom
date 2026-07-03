<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

require_once 'conn.php';

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'getAll':
        getAllProducts();
        break;
    case 'add':
        addProduct();
        break;
    case 'update':
        updateProduct();
        break;
    case 'delete':
        deleteProduct();
        break;
    default:
        echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
        break;
}

function getAllProducts()
{
    global $connect;

    try {
        $query = "SELECT p.*, 
                  GROUP_CONCAT(CONCAT(pm.material_id, ':', pm.quantity, ':', m.nama_m, ':', m.code_m) SEPARATOR ';') as material_data
                  FROM products p
                  LEFT JOIN product_materials pm ON p.id_p = pm.product_id
                  LEFT JOIN materials m ON pm.material_id = m.id_m
                  GROUP BY p.id_p";

        $result = $connect->query($query);

        if (!$result) {
            throw new Exception("Database query failed: " . $connect->error);
        }

        $products = [];
        while ($row = $result->fetch_assoc()) {
            $materials = [];
            if (!empty($row['material_data'])) {
                $materialItems = explode(';', $row['material_data']);
                foreach ($materialItems as $item) {
                    if (empty($item)) continue;
                    $parts = explode(':', $item);
                    if (count($parts) >= 4) {
                        $materials[] = [
                            'material_id' => $parts[0],
                            'quantity' => $parts[1],
                            'material_name' => $parts[2],
                            'material_code' => $parts[3]
                        ];
                    }
                }
            }

            $products[] = [
                'id_p' => $row['id_p'],
                'code_p' => $row['code_p'],
                'name_p' => $row['name_p'],
                'description' => $row['description'],
                'created_at' => $row['created_at'],
                'updated_at' => $row['updated_at'],
                'materials' => $materials
            ];
        }

        echo json_encode([
            'status' => 'success',
            'data' => $products
        ]);
    } catch (Exception $e) {
        echo json_encode([
            'status' => 'error',
            'message' => $e->getMessage()
        ]);
    }
}

function addProduct()
{
    global $connect;

    try {
        $data = json_decode(file_get_contents('php://input'), true);

        if (!$data) {
            throw new Exception("Invalid JSON data");
        }

        // Validate required fields
        if (empty($data['name_p'])) {
            throw new Exception("Product name is required");
        }

        // Begin transaction
        $connect->begin_transaction();

        // Check if product name already exists
        $checkStmt = $connect->prepare("SELECT id_p FROM products WHERE name_p = ?");
        $checkStmt->bind_param("s", $data['name_p']);
        $checkStmt->execute();
        $result = $checkStmt->get_result();
        
        if ($result->num_rows > 0) {
            $checkStmt->close();
            throw new Exception("Nama produk sudah digunakan. Silakan gunakan nama yang berbeda.");
        }
        $checkStmt->close();

        // Insert product
        $stmt = $connect->prepare("INSERT INTO products (code_p, name_p, description) VALUES (?, ?, ?)");
        $stmt->bind_param("sss", $data['code_p'], $data['name_p'], $data['description']);

        if (!$stmt->execute()) {
            throw new Exception("Failed to insert product: " . $stmt->error);
        }

        $productId = $stmt->insert_id;
        $stmt->close();

        // Insert product materials
        if (!empty($data['materials'])) {
            $stmt = $connect->prepare("INSERT INTO product_materials (product_id, material_id, quantity) VALUES (?, ?, ?)");

            foreach ($data['materials'] as $material) {
                if (isset($material['material_id']) && isset($material['quantity'])) {
                    $stmt->bind_param("iii", $productId, $material['material_id'], $material['quantity']);
                    if (!$stmt->execute()) {
                        throw new Exception("Failed to insert material: " . $stmt->error);
                    }
                }
            }

            $stmt->close();
        }

        // Commit transaction
        $connect->commit();

        echo json_encode(['status' => 'success', 'message' => 'Product added successfully']);
    } catch (Exception $e) {
        $connect->rollback();
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }
}

function updateProduct()
{
    global $connect;

    try {
        $data = json_decode(file_get_contents('php://input'), true);

        if (!$data) {
            throw new Exception("Invalid JSON data");
        }

        // Validate required fields
        if (empty($data['id_p']) || empty($data['code_p']) || empty($data['name_p'])) {
            throw new Exception("Product ID, code and name are required");
        }

        // Begin transaction
        $connect->begin_transaction();

        // Check if product name already exists (excluding current product)
        $checkStmt = $connect->prepare("SELECT id_p FROM products WHERE name_p = ? AND id_p != ?");
        $checkStmt->bind_param("si", $data['name_p'], $data['id_p']);
        $checkStmt->execute();
        $result = $checkStmt->get_result();
        
        if ($result->num_rows > 0) {
            $checkStmt->close();
            throw new Exception("Nama produk sudah digunakan. Silakan gunakan nama yang berbeda.");
        }
        $checkStmt->close();

        // Update product
        $stmt = $connect->prepare("UPDATE products SET code_p = ?, name_p = ?, description = ? WHERE id_p = ?");
        $stmt->bind_param("sssi", $data['code_p'], $data['name_p'], $data['description'], $data['id_p']);

        if (!$stmt->execute()) {
            throw new Exception("Failed to update product: " . $stmt->error);
        }
        $stmt->close();

        // Delete existing materials
        $stmt = $connect->prepare("DELETE FROM product_materials WHERE product_id = ?");
        $stmt->bind_param("i", $data['id_p']);

        if (!$stmt->execute()) {
            throw new Exception("Failed to delete existing materials: " . $stmt->error);
        }
        $stmt->close();

        // Insert new materials
        if (!empty($data['materials'])) {
            $stmt = $connect->prepare("INSERT INTO product_materials (product_id, material_id, quantity) VALUES (?, ?, ?)");

            foreach ($data['materials'] as $material) {
                if (isset($material['material_id']) && isset($material['quantity'])) {
                    $stmt->bind_param("iii", $data['id_p'], $material['material_id'], $material['quantity']);
                    if (!$stmt->execute()) {
                        throw new Exception("Failed to insert material: " . $stmt->error);
                    }
                }
            }

            $stmt->close();
        }

        // Commit transaction
        $connect->commit();

        echo json_encode(['status' => 'success', 'message' => 'Product updated successfully']);
    } catch (Exception $e) {
        $connect->rollback();
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }
}
function deleteProduct()
{
    global $connect;

    try {
        $id = $_GET['id'] ?? null;

        if (empty($id) || !is_numeric($id)) {
            throw new Exception("ID produk yang valid diperlukan");
        }

        // Check if product exists
        $checkStmt = $connect->prepare("SELECT id_p FROM products WHERE id_p = ?");
        $checkStmt->bind_param("i", $id);
        $checkStmt->execute();
        $result = $checkStmt->get_result();

        if ($result->num_rows == 0) {
            throw new Exception("Produk tidak ditemukan");
        }
        $checkStmt->close();

        // Check if product is being used in transactions
        $transactionCheck = $connect->prepare("SELECT COUNT(*) as count FROM product_transactions WHERE product_id = ?");
        $transactionCheck->bind_param("i", $id);
        $transactionCheck->execute();
        $transactionResult = $transactionCheck->get_result();
        $transactionCount = $transactionResult->fetch_assoc()['count'];
        $transactionCheck->close();

        if ($transactionCount > 0) {
            throw new Exception("Tidak dapat menghapus produk karena sedang digunakan dalam transaksi");
        }

        // Begin transaction
        $transactionStarted = false;
        $connect->begin_transaction();
        $transactionStarted = true;

        // First delete product materials
        $stmt = $connect->prepare("DELETE FROM product_materials WHERE product_id = ?");
        $stmt->bind_param("i", $id);

        if (!$stmt->execute()) {
            throw new Exception("Gagal menghapus material produk: " . $stmt->error);
        }
        $stmt->close();

        // Then delete product
        $stmt = $connect->prepare("DELETE FROM products WHERE id_p = ?");
        $stmt->bind_param("i", $id);

        if (!$stmt->execute()) {
            throw new Exception("Gagal menghapus produk: " . $stmt->error);
        }

        if ($stmt->affected_rows == 0) {
            throw new Exception("Tidak ada produk yang dihapus");
        }

        $stmt->close();

        // Commit transaction
        $connect->commit();

        echo json_encode([
            'status' => 'success',
            'message' => 'Produk berhasil dihapus'
        ]);
    } catch (Exception $e) {
        // Rollback transaction if we started one
        if (isset($transactionStarted) && $transactionStarted && isset($connect)) {
            $connect->rollback();
        }

        // Make error messages more user-friendly
        $errorMessage = $e->getMessage();

        // Check for foreign key constraint error
        if (strpos($errorMessage, 'foreign key constraint fails') !== false) {
            $errorMessage = "Tidak dapat menghapus produk ini karena sedang digunakan dalam sistem";
        } elseif (strpos($errorMessage, 'Cannot delete or update a parent row') !== false) {
            $errorMessage = "Tidak dapat menghapus produk ini karena memiliki data terkait dalam sistem";
        }

        echo json_encode([
            'status' => 'error',
            'message' => $errorMessage
        ]);
    }
}
