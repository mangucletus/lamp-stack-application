<?php
include 'config.php';

if (isset($_GET['id']) && is_numeric($_GET['id'])) {
    $id = intval($_GET['id']);
    
    // Prepare and bind
    $stmt = $conn->prepare("DELETE FROM tasks WHERE id = ?");
    $stmt->bind_param("i", $id);
    
    if ($stmt->execute()) {
        header("Location: index.php?deleted=1");
    } else {
        header("Location: index.php?error=3");
    }
    
    $stmt->close();
} else {
    header("Location: index.php?error=4");
}

$conn->close();
exit();
?>