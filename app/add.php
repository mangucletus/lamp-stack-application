<?php
include 'config.php';

if ($_SERVER["REQUEST_METHOD"] == "POST" && !empty($_POST['task'])) {
    $task = trim($_POST['task']);
    
    // Prepare and bind
    $stmt = $conn->prepare("INSERT INTO tasks (task) VALUES (?)");
    $stmt->bind_param("s", $task);
    
    if ($stmt->execute()) {
        header("Location: index.php?success=1");
    } else {
        header("Location: index.php?error=1");
    }
    
    $stmt->close();
} else {
    header("Location: index.php?error=2");
}

$conn->close();
exit();
?>