<?php
require_once 'conn.php';

try {
    // Get materials with stock information
    $query = "SELECT 
                m.id_m,
                m.code_m,
                m.nama_m,
                m.satuan,
                m.description,
                c.nama_c as kategory,
                COALESCE(ms.stok_tersedia, 0) as jumlah,
                COALESCE(ms.stok_minimal, 0) as stok_minimal,
                CASE 
                    WHEN COALESCE(ms.stok_tersedia, 0) = 0 THEN 'stok habis'
                    WHEN COALESCE(ms.stok_tersedia, 0) <= COALESCE(ms.stok_minimal, 0) AND COALESCE(ms.stok_minimal, 0) > 0 THEN 'stok menipis'
                    ELSE 'stok normal'
                END as status,
                DATE_FORMAT(COALESCE(ms.last_updated, NOW()), '%d/%m/%Y %H:%i') as last_update
              FROM materials m
              LEFT JOIN categories c ON m.category_id = c.id_c
              LEFT JOIN material_stocks ms ON m.id_m = ms.material_id
              WHERE m.id_m IS NOT NULL
              ORDER BY m.nama_m ASC";
    
    $result = $connect->query($query);
    
    if ($result) {
        $materials = [];
        while ($row = $result->fetch_assoc()) {
            // Double check status logic untuk memastikan konsistensi
            $jumlah = intval($row['jumlah']);
            $stokMinimal = intval($row['stok_minimal']);
            
            if ($jumlah == 0) {
                $status = 'stok habis';
            } elseif ($jumlah <= $stokMinimal && $stokMinimal > 0) {
                $status = 'stok menipis';
            } else {
                $status = 'stok normal';
            }
            
            $materials[] = [
                'id' => $row['id_m'],
                'kodeMaterial' => $row['code_m'] ?: '-',
                'namaMaterial' => $row['nama_m'] ?: '-',
                'satuan' => $row['satuan'] ?: 'pcs',
                'kategory' => $row['kategory'] ?: 'Tidak ada kategori',
                'jumlah' => $jumlah,
                'stokMinimal' => $stokMinimal,
                'status' => $status,
                'lastUpdate' => $row['last_update'] ?: date('d/m/Y H:i')
            ];
        }
        
        // Get summary statistics dengan pengecekan yang benar
        $totalMaterials = count($materials);
        $stokNormal = 0;
        $stokMenipis = 0;
        $stokHabis = 0;
        
        foreach ($materials as $material) {
            switch ($material['status']) {
                case 'stok normal':
                    $stokNormal++;
                    break;
                case 'stok menipis':
                    $stokMenipis++;
                    break;
                case 'stok habis':
                    $stokHabis++;
                    break;
            }
        }
        
        echo json_encode([
            'status' => 'success',
            'data' => $materials,
            'summary' => [
                'totalMaterials' => $totalMaterials,
                'stokNormal' => $stokNormal,
                'stokMenipis' => $stokMenipis,
                'stokHabis' => $stokHabis
            ]
        ]);
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'Gagal mengambil data material: ' . $connect->error
        ]);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Error: ' . $e->getMessage()
    ]);
}

$connect->close();
?>