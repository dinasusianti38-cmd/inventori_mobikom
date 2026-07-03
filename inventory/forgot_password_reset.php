<?php
include 'conn.php'; // sudah set header JSON, charset, timezone

$email       = trim($_POST['email'] ?? '');
$otp         = trim($_POST['otp'] ?? '');
$newPassword = $_POST['new_password'] ?? '';

if (empty($email) || empty($otp) || empty($newPassword)) {
    echo json_encode(['status' => 'error', 'message' => 'Data tidak lengkap']);
    exit;
}
if (strlen($newPassword) < 6) {
    echo json_encode(['status' => 'error', 'message' => 'Password minimal 6 karakter']);
    exit;
}

// ─── Verifikasi OTP masih valid ────────────────────────────────────────
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
        'message' => 'Sesi kadaluarsa. Silakan ulangi proses dari awal.',
    ]);
    $stmt->close();
    $connect->close();
    exit;
}
$stmt->close();

// ─── Update password (plain text sesuai login.php) ────────────────────
// CATATAN: jika login.php Anda menggunakan password_verify(), ganti baris ini:
//   $newPassword → password_hash($newPassword, PASSWORD_DEFAULT)
// dan kolom SET password_ = ? tetap sama.
$stmt = $connect->prepare("UPDATE users SET password_ = ? WHERE email = ?");
$stmt->bind_param('ss', $newPassword, $email);
$stmt->execute();

if ($stmt->affected_rows > 0) {
    // Hapus OTP setelah berhasil digunakan
    $connect->query(
        "DELETE FROM password_resets WHERE email = '"
        . $connect->real_escape_string($email) . "'"
    );
    echo json_encode([
        'status'  => 'success',
        'message' => 'Password berhasil diperbarui! Silakan login dengan password baru.',
    ]);
} else {
    echo json_encode([
        'status'  => 'error',
        'message' => 'Gagal memperbarui password. Coba lagi.',
    ]);
}

$stmt->close();
$connect->close();