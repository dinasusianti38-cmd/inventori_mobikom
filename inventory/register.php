<?php
include 'conn.php';

// Get POST data
$full_name = isset($_POST['full_name']) ? trim($_POST['full_name']) : '';
$username = isset($_POST['username']) ? trim($_POST['username']) : '';
$email = isset($_POST['email']) ? trim($_POST['email']) : '';
$password = isset($_POST['password']) ? $_POST['password'] : '';
$role = isset($_POST['role']) ? $_POST['role'] : 'staff';

// Validate input
if (empty($full_name) || empty($username) || empty($email) || empty($password)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Semua field harus diisi'
    ]);
    exit();
}

// Validasi email format
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Format email tidak valid'
    ]);
    exit();
}

// Validasi username (minimal 3 karakter, hanya huruf, angka, underscore)
if (!preg_match('/^[a-zA-Z0-9_]{3,}$/', $username)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Username minimal 3 karakter, hanya boleh huruf, angka, dan underscore'
    ]);
    exit();
}

// Validasi password (minimal 6 karakter)
if (strlen($password) < 6) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Password minimal 6 karakter'
    ]);
    exit();
}

// Cek apakah username sudah ada
$check_username = "SELECT id_u FROM users WHERE username = ?";
$stmt = $connect->prepare($check_username);
$stmt->bind_param("s", $username);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Username sudah digunakan'
    ]);
    exit();
}

// Cek apakah email sudah ada
$check_email = "SELECT id_u FROM users WHERE email = ?";
$stmt = $connect->prepare($check_email);
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Email sudah terdaftar'
    ]);
    exit();
}

// Insert user baru (password plain text sesuai dengan login.php)
$query = "INSERT INTO users (username, email, password_, full_name, role, is_active) VALUES (?, ?, ?, ?, ?, 1)";
$stmt = $connect->prepare($query);
$stmt->bind_param("sssss", $username, $email, $password, $full_name, $role);

if ($stmt->execute()) {
    $new_user_id = $stmt->insert_id;
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Registrasi berhasil! Silakan login.',
        'data' => [
            'id' => $new_user_id,
            'username' => $username,
            'email' => $email,
            'full_name' => $full_name,
            'role' => $role
        ]
    ]);
} else {
    echo json_encode([
        'status' => 'error',
        'message' => 'Gagal melakukan registrasi: ' . $stmt->error
    ]);
}

$stmt->close();
$connect->close();
?>