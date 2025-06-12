<?php
include 'config.php';

// Fetch all tasks
$sql = "SELECT * FROM tasks ORDER BY created_at DESC";
$result = $conn->query($sql);
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LAMP Stack To-Do App</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <header>
            <h1> LAMP Stack To-Do Application</h1>
            <p>Built with Linux, Apache, MySQL, and PHP on AWS</p>
        </header>

        <div class="add-task-form">
            <form action="add.php" method="POST">
                <input type="text" name="task" placeholder="Enter a new task..." required>
                <button type="submit">Add Task</button>
            </form>
        </div>

        <div class="tasks-container">
            <h2>Your Tasks</h2>
            
            <?php if ($result->num_rows > 0): ?>
                <ul class="task-list">
                    <?php while($row = $result->fetch_assoc()): ?>
                        <li class="task-item">
                            <div class="task-content">
                                <span class="task-text"><?php echo htmlspecialchars($row['task']); ?></span>
                                <small class="task-date">Added: <?php echo date('M j, Y g:i A', strtotime($row['created_at'])); ?></small>
                            </div>
                            <div class="task-actions">
                                <a href="delete.php?id=<?php echo $row['id']; ?>" 
                                   class="delete-btn" 
                                   onclick="return confirm('Are you sure you want to delete this task?')">
                                    Delete
                                </a>
                            </div>
                        </li>
                    <?php endwhile; ?>
                </ul>
            <?php else: ?>
                <div class="no-tasks">
                    <p> No tasks yet! Add your first task above.</p>
                </div>
            <?php endif; ?>
        </div>

        <footer>
            <p>Deployed on AWS EC2 with Terraform | Region: eu-west-1</p>
        </footer>
    </div>
</body>
</html>

<?php
$conn->close();
?>