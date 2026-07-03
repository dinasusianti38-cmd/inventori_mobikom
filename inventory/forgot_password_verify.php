<?php
include 'conn.php'; // sudah set header JSON, charset, timezone

$email = trim($_POST['email'] ?? '');
$otp   = trim($_POST['otp'] ?? '');

if (empty($email) || empty($otp)) {
    echo json_encode(['status' => 'error', 'message' => 'Data tidak lengkap']);
    exit;
}

// Validasi format OTP — harus 6 digit angka
if (!preg_match('/^\d{6}$/', $otp)) {
    echo json_encode(['status' => 'error', 'message' => 'Format OTP tidak valid']);
    exit;
}

$now  = date('Y-m-d H:i:s');
$stmt = $connect->prepare(
    "SELECT id FROM password_resets
     WHERE email = ? AND otp = ? AND expires_at > ?
     LIMIT 1"
);
$stmt->bind_param('sss', $email, $otp, $now);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode([
        'status'  => 'error',
        'message' => 'Kode OTP salah atau sudah kadaluarsa. Silakan minta kode baru.',
    ]);
} else {
    echo json_encode([
        'status'  => 'success',
        'message' => 'Kode OTP valid',
    ]);
}

$stmt->close();
$connect->close();