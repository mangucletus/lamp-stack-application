<?php
// Database configuration
$host = 'localhost';
$dbname = 'blog_db';
$username = 'blog_user';
$password = 'your_secure_password';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch(PDOException $e) {
    die("Connection failed: " . $e->getMessage());
}

// Handle form submission
if ($_POST['action'] ?? '' === 'add_post') {
    $title = $_POST['title'] ?? '';
    $content = $_POST['content'] ?? '';
    
    if (!empty($title) && !empty($content)) {
        $stmt = $pdo->prepare("INSERT INTO posts (title, content, created_at) VALUES (?, ?, NOW())");
        $stmt->execute([$title, $content]);
        header("Location: index.php");
        exit;
    }
}

// Fetch all posts
$stmt = $pdo->query("SELECT * FROM posts ORDER BY created_at DESC");
$posts = $stmt->fetchAll(PDO::FETCH_ASSOC);
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Simple Blog</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
            margin-bottom: 30px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
            color: #555;
        }
        input[type="text"], textarea {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 16px;
        }
        textarea {
            height: 100px;
            resize: vertical;
        }
        button {
            background-color: #007cba;
            color: white;
            padding: 12px 24px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
        }
        button:hover {
            background-color: #005a87;
        }
        .post {
            border: 1px solid #eee;
            padding: 20px;
            margin: 20px 0;
            border-radius: 5px;
            background: #fafafa;
        }
        .post h3 {
            margin-top: 0;
            color: #333;
        }
        .post-meta {
            color: #666;
            font-size: 14px;
            margin-bottom: 10px;
        }
        .post-content {
            line-height: 1.6;
        }
        .no-posts {
            text-align: center;
            color: #666;
            font-style: italic;
            margin: 40px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Simple Blog Application</h1>
        
        <form method="POST">
            <input type="hidden" name="action" value="add_post">
            
            <div class="form-group">
                <label for="title">Post Title:</label>
                <input type="text" id="title" name="title" required>
            </div>
            
            <div class="form-group">
                <label for="content">Post Content:</label>
                <textarea id="content" name="content" required></textarea>
            </div>
            
            <button type="submit">Add Post</button>
        </form>
        
        <hr style="margin: 30px 0;">
        
        <h2>Recent Posts</h2>
        
        <?php if (empty($posts)): ?>
            <div class="no-posts">
                No posts yet. Add your first post above!
            </div>
        <?php else: ?>
            <?php foreach ($posts as $post): ?>
                <div class="post">
                    <h3><?php echo htmlspecialchars($post['title']); ?></h3>
                    <div class="post-meta">
                        Posted on <?php echo date('F j, Y, g:i a', strtotime($post['created_at'])); ?>
                    </div>
                    <div class="post-content">
                        <?php echo nl2br(htmlspecialchars($post['content'])); ?>
                    </div>
                </div>
            <?php endforeach; ?>
        <?php endif; ?>
    </div>
</body>
</html>