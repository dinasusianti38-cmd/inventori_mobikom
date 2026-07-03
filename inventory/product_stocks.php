<?php
require_once 'conn.php';

$query = "SELECT ps.*, p.code_p, p.name_p 
          FROM product_stocks ps
          JOIN products p ON ps.product_id = p.id_p
          ORDER BY ps.last_updated DESC";

$result = $connect->query($query);

$data = array();
while ($row = $result->fetch_assoc()) {
    $data[] = $row;
}

echo json_encode($data);
?>
