<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
include 'conn.php'; // sudah set header JSON, charset, timezone

require_once __DIR__ . '/vendor/autoload.php';
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

// ─── Konfigurasi Gmail SMTP ────────────────────────────────────────────
// Gunakan App Password (bukan password Gmail biasa!)
// Cara buat: myaccount.google.com → Security → 2-Step Verification → App Passwords
define('GMAIL_USER',      'dinasusianti38@gmail.com');
define('GMAIL_PASS',      'khiahebuzfsakbfc');   // App Password 16 karakter
define('GMAIL_FROM_NAME', 'InventoryMobilkom');

// Pastikan tabel password_resets ada
$connect->query("
    CREATE TABLE IF NOT EXISTS password_resets (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        email      VARCHAR(255) NOT NULL,
        otp        VARCHAR(10)  NOT NULL,
        expires_at DATETIME     NOT NULL,
        created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_email (email)
    )
");

// ─── Validasi input ────────────────────────────────────────────────────
$email = trim($_POST['email'] ?? '');
if (empty($email) || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode(['status' => 'error', 'message' => 'Format email tidak valid']);
    exit;
}

// ─── Cek email terdaftar ───────────────────────────────────────────────
$stmt = $connect->prepare("SELECT id_u, full_name FROM users WHERE email = ? LIMIT 1");
$stmt->bind_param('s', $email);
$stmt->execute();
$result = $stmt->get_result();
if ($result->num_rows === 0) {
    echo json_encode(['status' => 'error', 'message' => 'Email tidak terdaftar']);
    $stmt->close();
    exit;
}
$user = $result->fetch_assoc();
$stmt->close();

// ─── Generate OTP 6 digit & simpan ke DB ──────────────────────────────
$otp       = str_pad(random_int(0, 999999), 6, '0', STR_PAD_LEFT);
$expiresAt = date('Y-m-d H:i:s', strtotime('+15 minutes'));

// Hapus OTP lama milik email ini dulu
$connect->query(
    "DELETE FROM password_resets WHERE email = '"
    . $connect->real_escape_string($email) . "'"
);

$stmt = $connect->prepare(
    "INSERT INTO password_resets (email, otp, expires_at) VALUES (?, ?, ?)"
);
$stmt->bind_param('sss', $email, $otp, $expiresAt);
$stmt->execute();
$stmt->close();

// ─── Kirim email via Gmail SMTP ────────────────────────────────────────
$mail = new PHPMailer(true);
try {
    $mail->isSMTP();
    $mail->Host       = 'smtp.gmail.com';
    $mail->SMTPAuth   = true;
    $mail->Username   = GMAIL_USER;
    $mail->Password   = GMAIL_PASS;
    $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
    $mail->Port       = 587;
    $mail->CharSet    = 'UTF-8';
    $mail->SMTPDebug  = 0; // WAJIB 0 di production — kalau > 0 merusak JSON response

    $mail->setFrom(GMAIL_USER, GMAIL_FROM_NAME);
    $mail->addAddress($email, $user['full_name']);

    $mail->isHTML(true);
    $mail->Subject = 'Kode Verifikasi Reset Password - Inventory Mobilkom';
    $mail->Body    = _getEmailTemplate($user['full_name'], $otp);
    $mail->AltBody = "Halo {$user['full_name']},\n\nKode OTP Anda: $otp\nBerlaku 15 menit.\n\nAbaikan jika tidak meminta reset password.";

    $mail->send();

    echo json_encode([
        'status'  => 'success',
        'message' => 'Kode OTP berhasil dikirim ke ' . _maskEmail($email),
    ]);
} catch (Exception $e) {
    // Hapus OTP jika email gagal terkirim agar user bisa coba lagi
    $connect->query(
        "DELETE FROM password_resets WHERE email = '"
        . $connect->real_escape_string($email) . "'"
    );
    echo json_encode([
        'status'  => 'error',
        'message' => 'Gagal mengirim email: ' . $mail->ErrorInfo,
    ]);
}

$connect->close();

// ─── Helper: template email HTML ──────────────────────────────────────
function _getEmailTemplate(string $name, string $otp): string {
    return "
<!DOCTYPE html>
<html>
<head><meta charset='UTF-8'></head>
<body style='margin:0;padding:0;background:#f4f6f8;font-family:Arial,sans-serif;'>
  <table width='100%' cellpadding='0' cellspacing='0'>
    <tr>
      <td align='center' style='padding:40px 20px;'>
        <table width='480' cellpadding='0' cellspacing='0'
               style='background:#ffffff;border-radius:16px;overflow:hidden;
                      box-shadow:0 8px 30px rgba(0,0,0,0.1);'>
          <tr>
            <td style='background:linear-gradient(135deg,#1D4861,#2A6585);
                        padding:32px 40px;text-align:center;'>
              <div style='background:#fff;display:inline-block;
                          padding:10px 24px;border-radius:10px;'>
                <span style='font-size:20px;font-weight:900;color:#1D4861;'>MOBIL</span>
                <span style='font-size:20px;font-weight:900;color:#E74C3C;'>KOM</span>
              </div>
              <p style='color:#ffffff;margin:12px 0 0;font-size:14px;opacity:.85;'>
                Inventory Management System
              </p>
            </td>
          </tr>
          <tr>
            <td style='padding:36px 40px;'>
              <p style='color:#333;font-size:15px;margin:0 0 8px;'>
                Halo, <strong>$name</strong>!
              </p>
              <p style='color:#555;font-size:14px;line-height:1.6;margin:0 0 28px;'>
                Kami menerima permintaan untuk mereset password akun Anda.
                Gunakan kode OTP berikut untuk melanjutkan:
              </p>
              <div style='background:#f0f4f8;border:2px dashed #1D4861;
                          border-radius:12px;padding:24px;text-align:center;
                          margin-bottom:24px;'>
                <p style='margin:0 0 4px;font-size:12px;color:#888;
                           letter-spacing:1px;text-transform:uppercase;'>
                  Kode Verifikasi Anda
                </p>
                <span style='font-size:42px;font-weight:900;letter-spacing:10px;
                              color:#1D4861;display:block;margin:8px 0;'>
                  $otp
                </span>
                <p style='margin:0;font-size:12px;color:#E74C3C;'>
                  &#x23F1; Berlaku selama <strong>15 menit</strong>
                </p>
              </div>
              <p style='color:#888;font-size:12px;line-height:1.6;
                         border-top:1px solid #eee;padding-top:20px;margin:0;'>
                Jika Anda tidak meminta reset password, abaikan email ini.
                Akun Anda tetap aman.<br><br>
                Salam,<br><strong style='color:#1D4861;'>Tim Inventory Mobilkom</strong>
              </p>
            </td>
          </tr>
          <tr>
            <td style='background:#f8f9fa;padding:16px 40px;text-align:center;'>
              <p style='margin:0;font-size:11px;color:#aaa;'>
                &copy; 2024 Mobilkom. Semua hak dilindungi.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>";
}

// ─── Helper: sensor email ──────────────────────────────────────────────
function _maskEmail(string $email): string {
    [$local, $domain] = explode('@', $email);
    $masked = substr($local, 0, 2)
            . str_repeat('*', max(strlen($local) - 4, 2))
            . substr($local, -2);
    return $masked . '@' . $domain;
}