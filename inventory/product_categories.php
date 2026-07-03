<?php
require_once 'conn.php';

// This is a simplified example - you might need to adjust based on how categories are stored
$query = "SELECT DISTINCT 'Elektronik' as category FROM products 
          UNION SELECT 'Aksesoris' as category FROM products";

$result = $connect->query($query);

$categories = array();
while ($row = $result->fetch_assoc()) {
    $categories[] = $row['category'];
}

echo json_encode($categories);
?>
