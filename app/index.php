<?php
// Include the database configuration file to establish a connection
include 'config.php';

// Prepare an SQL query to fetch all tasks from the 'tasks' table
// The tasks are ordered by 'created_at' in descending order (most recent first)
$sql = "SELECT * FROM tasks ORDER BY created_at DESC";

// Execute the query and store the result
$result = $conn->query($sql);
?>

<!-- Start of the HTML document -->
<!DOCTYPE html>
<html lang="en">
<head>
    <!-- Basic HTML document setup -->
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LAMP Stack To-Do App</title>

    <!-- Link to external stylesheet (style.css should define layout and styles) -->
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <!-- Page header with title and description -->
        <header>
            <h1>LAMP Stack To-Do Application</h1>
            <p>Built with Linux, Apache, MySQL, and PHP on AWS</p>
        </header>

        <!-- Form to add a new task -->
        <div class="add-task-form">
            <form action="add.php" method="POST">
                <!-- Input field for the task description -->
                <input type="text" name="task" placeholder="Enter a new task..." required>
                
                <!-- Submit button to send the task to add.php -->
                <button type="submit">Add Task</button>
            </form>
        </div>

        <!-- Section to display tasks -->
        <div class="tasks-container">
            <h2>Your Tasks</h2>
            
            <?php if ($result->num_rows > 0): ?>
                <!-- If there are tasks, loop through each one and display -->
                <ul class="task-list">
                    <?php while($row = $result->fetch_assoc()): ?>
                        <li class="task-item">
                            <div class="task-content">
                                <!-- Sanitize and display the task text -->
                                <span class="task-text"><?php echo htmlspecialchars($row['task']); ?></span>
                                
                                <!-- Display formatted creation date of the task -->
                                <small class="task-date">
                                    Added: <?php echo date('M j, Y g:i A', strtotime($row['created_at'])); ?>
                                </small>
                            </div>
                            <div class="task-actions">
                                <!-- Delete button, links to delete.php with task ID as parameter -->
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
                <!-- Message to show when there are no tasks -->
                <div class="no-tasks">
                    <p>No tasks yet! Add your first task above.</p>
                </div>
            <?php endif; ?>
        </div>

        <!-- Footer with deployment note -->
        <footer>
            <p>Deployed on AWS EC2 with Terraform</p>
        </footer>
    </div>
</body>
</html>
