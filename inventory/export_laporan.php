<?php
require_once 'conn.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

class ExportLaporanHandler {
    private $connect;

    public function __construct($connection) {
        $this->connect = $connection;
    }

    public function handleRequest() {
        $action = $_GET['action'] ?? '';

        switch ($action) {
            case 'get_materials':
                $this->getMaterials();
                break;
            case 'get_transactions':
                $this->getTransactions();
                break;
            case 'get_summary':
                $this->getTransactionSummary();
                break;
            case 'get_export_data':        // ← ACTION BARU untuk export PDF
                $this->getExportData();
                break;
            case 'export':
                $this->exportData();
                break;
            default:
                $this->sendError('Invalid action');
                break;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // ACTION BARU: get_export_data
    // Mengembalikan transaksi + filter aktif yang dipakai admin
    // sehingga PDF bisa menyesuaikan isi & judulnya
    // ─────────────────────────────────────────────────────────────
    private function getExportData() {
        try {
            // Kumpulkan filter yang dikirim
            $startDate       = !empty($_GET['start_date'])       ? $_GET['start_date']       : null;
            $endDate         = !empty($_GET['end_date'])         ? $_GET['end_date']         : null;
            $materialId      = !empty($_GET['material_id'])      ? (int)$_GET['material_id'] : null;
            $transactionType = !empty($_GET['transaction_type']) ? $_GET['transaction_type'] : null;

            // Bangun query transaksi
            $query = "SELECT
                        mt.*,
                        m.nama_m  AS material_name,
                        m.code_m  AS material_code,
                        m.satuan,
                        u.full_name AS created_by_name
                     FROM material_transactions mt
                     LEFT JOIN materials m ON mt.material_id = m.id_m
                     LEFT JOIN users     u ON mt.created_by  = u.id_u
                     WHERE 1=1";

            $params = [];
            $types  = '';

            if ($startDate !== null) {
                $query   .= " AND mt.transaction_date >= ?";
                $params[] = $startDate;
                $types   .= 's';
            }
            if ($endDate !== null) {
                $query   .= " AND mt.transaction_date <= ?";
                $params[] = $endDate;
                $types   .= 's';
            }
            if ($materialId !== null) {
                $query   .= " AND mt.material_id = ?";
                $params[] = $materialId;
                $types   .= 'i';
            }
            if ($transactionType !== null) {
                $query   .= " AND mt.transaction_type = ?";
                $params[] = $transactionType;
                $types   .= 's';
            }

            $query .= " ORDER BY mt.transaction_date ASC, mt.created_at ASC";

            $stmt = $this->connect->prepare($query);
            if (!$stmt) {
                throw new Exception("Prepare failed: " . $this->connect->error);
            }

            if (!empty($params)) {
                $stmt->bind_param($types, ...$params);
            }

            $stmt->execute();
            $result = $stmt->get_result();

            $transactions = [];
            while ($row = $result->fetch_assoc()) {
                $transactions[] = $row;
            }

            // Ambil nama material jika filter material aktif
            $materialName = null;
            if ($materialId !== null) {
                $mStmt = $this->connect->prepare("SELECT nama_m FROM materials WHERE id_m = ?");
                $mStmt->bind_param('i', $materialId);
                $mStmt->execute();
                $mRow = $mStmt->get_result()->fetch_assoc();
                if ($mRow) $materialName = $mRow['nama_m'];
            }

            // Label jenis transaksi untuk ditampilkan di PDF
            $typeLabel = null;
            if ($transactionType !== null) {
                switch ($transactionType) {
                    case 'in':         $typeLabel = 'Transaksi Masuk';  break;
                    case 'out':        $typeLabel = 'Transaksi Keluar'; break;
                    case 'adjustment': $typeLabel = 'Penyesuaian';      break;
                    default:           $typeLabel = $transactionType;
                }
            }

            // Kembalikan data + info filter aktif
            $this->sendSuccess([
                'transactions' => $transactions,
                'filters' => [
                    'start_date'       => $startDate,
                    'end_date'         => $endDate,
                    'material_id'      => $materialId,
                    'material_name'    => $materialName,
                    'transaction_type' => $transactionType,
                    'type_label'       => $typeLabel,     // ← label siap pakai untuk PDF
                ],
            ]);

        } catch (Exception $e) {
            $this->sendError("Failed to get export data: " . $e->getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────
    // EXISTING: getMaterials (tidak berubah)
    // ─────────────────────────────────────────────────────────────
    private function getMaterials() {
        try {
            $query = "SELECT m.*, c.nama_c AS category_name
                     FROM materials m
                     LEFT JOIN categories c ON m.category_id = c.id_c
                     ORDER BY m.nama_m ASC";

            $result = $this->connect->query($query);
            if (!$result) {
                throw new Exception("Query failed: " . $this->connect->error);
            }

            $materials = [];
            while ($row = $result->fetch_assoc()) {
                $materials[] = $row;
            }
            $this->sendSuccess($materials);

        } catch (Exception $e) {
            $this->sendError("Failed to get materials: " . $e->getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────
    // EXISTING: getTransactions (tidak berubah)
    // ─────────────────────────────────────────────────────────────
    private function getTransactions() {
        try {
            $query = "SELECT
                        mt.*,
                        m.nama_m  AS material_name,
                        m.code_m  AS material_code,
                        m.satuan,
                        u.full_name AS created_by_name
                     FROM material_transactions mt
                     LEFT JOIN materials m ON mt.material_id = m.id_m
                     LEFT JOIN users     u ON mt.created_by  = u.id_u
                     WHERE 1=1";

            $params = [];
            $types  = '';

            if (!empty($_GET['start_date'])) {
                $query   .= " AND mt.transaction_date >= ?";
                $params[] = $_GET['start_date'];
                $types   .= 's';
            }
            if (!empty($_GET['end_date'])) {
                $query   .= " AND mt.transaction_date <= ?";
                $params[] = $_GET['end_date'];
                $types   .= 's';
            }
            if (!empty($_GET['material_id'])) {
                $query   .= " AND mt.material_id = ?";
                $params[] = (int)$_GET['material_id'];
                $types   .= 'i';
            }
            if (!empty($_GET['transaction_type'])) {
                $query   .= " AND mt.transaction_type = ?";
                $params[] = $_GET['transaction_type'];
                $types   .= 's';
            }

            $query .= " ORDER BY mt.transaction_date DESC, mt.created_at DESC";

            $stmt = $this->connect->prepare($query);
            if (!$stmt) {
                throw new Exception("Prepare failed: " . $this->connect->error);
            }
            if (!empty($params)) {
                $stmt->bind_param($types, ...$params);
            }

            $stmt->execute();
            $result = $stmt->get_result();

            $transactions = [];
            while ($row = $result->fetch_assoc()) {
                $transactions[] = $row;
            }
            $this->sendSuccess($transactions);

        } catch (Exception $e) {
            $this->sendError("Failed to get transactions: " . $e->getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────
    // EXISTING: getTransactionSummary (tidak berubah)
    // ─────────────────────────────────────────────────────────────
    private function getTransactionSummary() {
        try {
            $query = "SELECT
                        COUNT(*) AS total_transactions,
                        SUM(CASE WHEN transaction_type = 'in'         THEN 1 ELSE 0 END) AS in_transactions,
                        SUM(CASE WHEN transaction_type = 'out'        THEN 1 ELSE 0 END) AS out_transactions,
                        SUM(CASE WHEN transaction_type = 'adjustment' THEN 1 ELSE 0 END) AS adjustment_transactions,
                        SUM(CASE WHEN transaction_type = 'in'  THEN jumlah ELSE 0 END)   AS total_quantity_in,
                        SUM(CASE WHEN transaction_type = 'out' THEN jumlah ELSE 0 END)   AS total_quantity_out
                     FROM material_transactions
                     WHERE 1=1";

            $params = [];
            $types  = '';

            if (!empty($_GET['start_date'])) {
                $query   .= " AND transaction_date >= ?";
                $params[] = $_GET['start_date'];
                $types   .= 's';
            }
            if (!empty($_GET['end_date'])) {
                $query   .= " AND transaction_date <= ?";
                $params[] = $_GET['end_date'];
                $types   .= 's';
            }
            if (!empty($_GET['material_id'])) {
                $query   .= " AND material_id = ?";
                $params[] = (int)$_GET['material_id'];
                $types   .= 'i';
            }
            if (!empty($_GET['transaction_type'])) {
                $query   .= " AND transaction_type = ?";
                $params[] = $_GET['transaction_type'];
                $types   .= 's';
            }

            $stmt = $this->connect->prepare($query);
            if (!$stmt) {
                throw new Exception("Prepare failed: " . $this->connect->error);
            }
            if (!empty($params)) {
                $stmt->bind_param($types, ...$params);
            }

            $stmt->execute();
            $result  = $stmt->get_result();
            $summary = $result->fetch_assoc();

            foreach ($summary as $key => $value) {
                $summary[$key] = (int)$value;
            }
            $this->sendSuccess($summary);

        } catch (Exception $e) {
            $this->sendError("Failed to get summary: " . $e->getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────
    // EXISTING: exportData / exportToCSV (tidak berubah)
    // ─────────────────────────────────────────────────────────────
    private function exportData() {
        try {
            $format = $_GET['format'] ?? 'csv';

            $query = "SELECT
                        mt.transaction_code,
                        m.nama_m  AS material_name,
                        m.code_m  AS material_code,
                        m.satuan,
                        mt.transaction_type,
                        mt.jumlah,
                        mt.stok_sebelum,
                        mt.stok_sesudah,
                        mt.transaction_date,
                        mt.notes,
                        u.full_name AS created_by_name,
                        mt.created_at
                     FROM material_transactions mt
                     LEFT JOIN materials m ON mt.material_id = m.id_m
                     LEFT JOIN users     u ON mt.created_by  = u.id_u
                     WHERE 1=1";

            $params = [];
            $types  = '';

            if (!empty($_GET['start_date'])) {
                $query   .= " AND mt.transaction_date >= ?";
                $params[] = $_GET['start_date'];
                $types   .= 's';
            }
            if (!empty($_GET['end_date'])) {
                $query   .= " AND mt.transaction_date <= ?";
                $params[] = $_GET['end_date'];
                $types   .= 's';
            }
            if (!empty($_GET['material_id'])) {
                $query   .= " AND mt.material_id = ?";
                $params[] = (int)$_GET['material_id'];
                $types   .= 'i';
            }
            if (!empty($_GET['transaction_type'])) {
                $query   .= " AND mt.transaction_type = ?";
                $params[] = $_GET['transaction_type'];
                $types   .= 's';
            }

            $query .= " ORDER BY mt.transaction_date DESC, mt.created_at DESC";

            $stmt = $this->connect->prepare($query);
            if (!$stmt) {
                throw new Exception("Prepare failed: " . $this->connect->error);
            }
            if (!empty($params)) {
                $stmt->bind_param($types, ...$params);
            }

            $stmt->execute();
            $result = $stmt->get_result();

            if ($format === 'csv') {
                $this->exportToCSV($result);
            } else {
                $this->sendError("Unsupported export format");
            }

        } catch (Exception $e) {
            $this->sendError("Failed to export data: " . $e->getMessage());
        }
    }

    private function exportToCSV($result) {
        $filename = 'laporan_transaksi_material_' . date('Y-m-d_H-i-s') . '.csv';

        header('Content-Type: text/csv');
        header('Content-Disposition: attachment; filename="' . $filename . '"');

        $output = fopen('php://output', 'w');
        fprintf($output, chr(0xEF) . chr(0xBB) . chr(0xBF));

        fputcsv($output, [
            'Kode Transaksi', 'Nama Material', 'Kode Material', 'Satuan',
            'Jenis Transaksi', 'Jumlah', 'Stok Sebelum', 'Stok Sesudah',
            'Tanggal Transaksi', 'Catatan', 'Dibuat Oleh', 'Tanggal Dibuat',
        ]);

        while ($row = $result->fetch_assoc()) {
            switch ($row['transaction_type']) {
                case 'in':         $tl = 'Masuk';       break;
                case 'out':        $tl = 'Keluar';      break;
                case 'adjustment': $tl = 'Penyesuaian'; break;
                default:           $tl = $row['transaction_type'];
            }
            fputcsv($output, [
                $row['transaction_code'], $row['material_name'], $row['material_code'],
                $row['satuan'], $tl, $row['jumlah'], $row['stok_sebelum'],
                $row['stok_sesudah'], $row['transaction_date'], $row['notes'] ?? '',
                $row['created_by_name'], $row['created_at'],
            ]);
        }

        fclose($output);
        exit;
    }

    private function sendSuccess($data) {
        echo json_encode(['status' => 'success', 'data' => $data]);
    }

    private function sendError($message) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => $message]);
    }
}

try {
    $handler = new ExportLaporanHandler($connect);
    $handler->handleRequest();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Server error: ' . $e->getMessage()]);
}
?>