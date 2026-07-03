<?php
// Set header JSON di bagian paling atas script
header('Content-Type: application/json; charset=utf-8');

include 'conn.php';

// Get POST data
$username = isset($_POST['username']) ? $_POST['username'] : '';
$password = isset($_POST['password']) ? $_POST['password'] : '';

// Validate input
if (empty($username) || empty($password)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Username dan password harus diisi'
    ]);
    exit();
}

// Query to check user credentials
$query = "SELECT * FROM users WHERE username = ? AND password_ = ? AND is_active = 1";
$stmt = $connect->prepare($query);
$stmt->bind_param("ss", $username, $password);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $user = $result->fetch_assoc();
    
    // Update last login time
    $update_query = "UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE id_u = ?";
    $update_stmt = $connect->prepare($update_query);
    $update_stmt->bind_param("i", $user['id_u']);
    $update_stmt->execute();
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Login berhasil',
        'data' => [
            'id' => (int)$user['id_u'], // Dipaksa jadi int agar konsisten
            'username' => $user['username'],
            'email' => $user['email'],
            'full_name' => $user['full_name'],
            'role' => $user['role']
        ]
    ]);
} else {
    echo json_encode([
        'status' => 'error',
        'message' => 'Username atau password salah'
    ]);
}

$stmt->close();
$connect->close();
?>