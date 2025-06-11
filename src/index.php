<?php
/**
 * Main Blog Application File
 * 
 * This is the main entry point for the blog application.
 * It displays blog posts and provides the interface for creating new posts.
 * Post creation logic is handled by create_post.php for better code organization.
 */

// Include database configuration
require_once 'config.php';

// Initialize variables for messages
$message = '';
$error = '';
$messageType = '';

// Handle success/error messages from URL parameters
if (isset($_GET['success']) && $_GET['success'] == '1') {
    $message = $_GET['message'] ?? 'Post created successfully!';
    $messageType = 'success';
}

if (isset($_GET['error']) && $_GET['error'] == '1') {
    $error = $_GET['message'] ?? 'An error occurred. Please try again.';
    $messageType = 'error';
}

// Fetch all posts from database, ordered by creation date (newest first)
try {
    $stmt = $pdo->query("SELECT * FROM posts ORDER BY created_at DESC");
    $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    error_log("Error fetching posts: " . $e->getMessage());
    $posts = [];
    if (empty($error)) {
        $error = "Sorry, there was an error loading the posts.";
        $messageType = 'error';
    }
}

// Get total post count for statistics
$totalPosts = count($posts);

// Get recent posts (last 24 hours) count
$recentPostsCount = 0;
$yesterday = date('Y-m-d H:i:s', strtotime('-24 hours'));
foreach ($posts as $post) {
    if ($post['created_at'] >= $yesterday) {
        $recentPostsCount++;
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="A simple blog application built with PHP and MySQL">
    <title>Simple Blog - Share Your Thoughts</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <div class="container">
        <!-- Header Section -->
        <header>
            <h1>🌟 My Simple Blog</h1>
            <p>Share your thoughts with the world</p>
            
            <!-- Blog Statistics -->
            <div class="blog-stats">
                <span class="stat-item">📝 <?php echo $totalPosts; ?> Total Posts</span>
                <?php if ($recentPostsCount > 0): ?>
                    <span class="stat-item">🆕 <?php echo $recentPostsCount; ?> New (24h)</span>
                <?php endif; ?>
                <span class="stat-item">📅 <?php echo date('F j, Y'); ?></span>
            </div>
        </header>

        <main>
            <!-- Success and Error Messages -->
            <div id="message-container">
                <?php if (!empty($message)): ?>
                    <div class="alert alert-success" id="message-alert">
                        <span class="alert-icon">✅</span>
                        <span class="alert-text"><?php echo htmlspecialchars($message); ?></span>
                        <button class="alert-close" onclick="closeAlert()">&times;</button>
                    </div>
                <?php endif; ?>

                <?php if (!empty($error)): ?>
                    <div class="alert alert-error" id="error-alert">
                        <span class="alert-icon">❌</span>
                        <span class="alert-text"><?php echo htmlspecialchars($error); ?></span>
                        <button class="alert-close" onclick="closeAlert()">&times;</button>
                    </div>
                <?php endif; ?>
            </div>

            <!-- Create Post Form Section -->
            <section class="create-post">
                <h2>✍️ Create New Post</h2>
                <form id="post-form" method="POST" action="create_post.php" class="post-form">
                    <div class="form-group">
                        <label for="title">Post Title:</label>
                        <input 
                            type="text" 
                            id="title"
                            name="title" 
                            placeholder="Enter an engaging title..." 
                            required 
                            maxlength="255"
                            autocomplete="off"
                        >
                        <small class="char-counter" id="title-counter">0/255 characters</small>
                    </div>
                    
                    <div class="form-group">
                        <label for="content">Post Content:</label>
                        <textarea 
                            id="content"
                            name="content" 
                            placeholder="Write your post here..." 
                            required
                            maxlength="10000"
                            rows="6"
                        ></textarea>
                        <small class="char-counter" id="content-counter">0/10000 characters</small>
                    </div>
                    
                    <div class="form-actions">
                        <button type="submit" class="btn-primary" id="submit-btn">
                            <span class="btn-text">📝 Publish Post</span>
                            <span class="btn-loading" style="display: none;">🔄 Publishing...</span>
                        </button>
                        <button type="button" class="btn-secondary" id="clear-btn">
                            🗑️ Clear Form
                        </button>
                    </div>
                </form>
            </section>

            <!-- Display Posts Section -->
            <section class="posts">
                <div class="posts-header">
                    <h2>📚 Recent Posts</h2>
                    <?php if ($totalPosts > 0): ?>
                        <div class="posts-actions">
                            <button class="btn-filter" onclick="toggleSort()">
                                <span id="sort-text">🔽 Newest First</span>
                            </button>
                        </div>
                    <?php endif; ?>
                </div>
                
                <div id="posts-container">
                    <?php if (empty($posts)): ?>
                        <!-- Empty state when no posts exist -->
                        <div class="empty-state">
                            <div class="empty-icon">📝</div>
                            <h3>No posts yet!</h3>
                            <p>Be the first to share something amazing with the world.</p>
                            <p>Use the form above to create your first post.</p>
                        </div>
                    <?php else: ?>
                        <!-- Display all posts -->
                        <?php foreach ($posts as $index => $post): ?>
                            <article class="post" data-post-id="<?php echo $post['id']; ?>" data-date="<?php echo strtotime($post['created_at']); ?>">
                                <!-- Post Header -->
                                <header class="post-header">
                                    <h3><?php echo htmlspecialchars($post['title']); ?></h3>
                                    <div class="post-meta">
                                        <span class="post-id">Post #<?php echo $post['id']; ?></span>
                                        <span class="post-date">
                                            📅 <?php echo date('F j, Y \a\t g:i A', strtotime($post['created_at'])); ?>
                                        </span>
                                        <span class="reading-time">
                                            ⏱️ <?php echo max(1, ceil(str_word_count($post['content']) / 200)); ?> min read
                                        </span>
                                    </div>
                                </header>
                                
                                <!-- Post Content -->
                                <div class="post-content">
                                    <?php 
                                    // Convert line breaks to HTML breaks and escape special characters
                                    $content = nl2br(htmlspecialchars($post['content']));
                                    
                                    // Show preview for long posts
                                    $wordCount = str_word_count(strip_tags($content));
                                    if ($wordCount > 50) {
                                        $words = explode(' ', strip_tags($content));
                                        $preview = implode(' ', array_slice($words, 0, 50));
                                        echo '<div class="post-preview">' . nl2br(htmlspecialchars($preview)) . '...</div>';
                                        echo '<div class="post-full" style="display: none;">' . $content . '</div>';
                                        echo '<button class="read-more-btn" onclick="togglePost(this)">Read More</button>';
                                    } else {
                                        echo $content;
                                    }
                                    ?>
                                </div>
                                
                                <!-- Post Footer -->
                                <footer class="post-footer">
                                    <div class="post-actions">
                                        <span class="word-count">📝 <?php echo str_word_count($post['content']); ?> words</span>
                                        <span class="char-count">🔤 <?php echo strlen($post['content']); ?> characters</span>
                                    </div>
                                </footer>
                            </article>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </div>
                
                <?php if ($totalPosts > 0): ?>
                    <!-- Post Statistics -->
                    <div class="post-stats">
                        <div class="stats-grid">
                            <div class="stat-card">
                                <div class="stat-number"><?php echo $totalPosts; ?></div>
                                <div class="stat-label">Total Posts</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-number"><?php echo $recentPostsCount; ?></div>
                                <div class="stat-label">Last 24h</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-number">
                                    <?php 
                                    $totalWords = 0;
                                    foreach ($posts as $post) {
                                        $totalWords += str_word_count($post['content']);
                                    }
                                    echo number_format($totalWords);
                                    ?>
                                </div>
                                <div class="stat-label">Total Words</div>
                            </div>
                            <div class="stat-card">
                                <div class="stat-number">
                                    <?php echo $totalPosts > 0 ? date('M j', strtotime($posts[0]['created_at'])) : 'N/A'; ?>
                                </div>
                                <div class="stat-label">Latest Post</div>
                            </div>
                        </div>
                    </div>
                <?php endif; ?>
            </section>
        </main>

        <!-- Footer Section -->
        <footer>
            <p>&copy; <?php echo date('Y'); ?> Simple Blog. Built with ❤️ using PHP & MySQL on AWS EC2.</p>
            <p class="footer-stats">
                Server uptime: <span id="server-time"><?php echo date('H:i:s'); ?></span> | 
                Page loaded in: <span id="load-time">calculating...</span>
            </p>
        </footer>
    </div>

    <!-- JavaScript for Enhanced Functionality -->
    <script>
        // Track page load time
        window.addEventListener('load', function() {
            const loadTime = (performance.now() / 1000).toFixed(3);
            document.getElementById('load-time').textContent = loadTime + 's';
        });

        // Update server time every second
        setInterval(function() {
            const now = new Date();
            document.getElementById('server-time').textContent = now.toTimeString().split(' ')[0];
        }, 1000);

        // Character counters for form inputs
        document.getElementById('title').addEventListener('input', function() {
            updateCharCounter('title', 255);
        });

        document.getElementById('content').addEventListener('input', function() {
            updateCharCounter('content', 10000);
        });

        function updateCharCounter(fieldId, maxLength) {
            const field = document.getElementById(fieldId);
            const counter = document.getElementById(fieldId + '-counter');
            const currentLength = field.value.length;
            
            counter.textContent = currentLength + '/' + maxLength + ' characters';
            
            if (currentLength > maxLength * 0.9) {
                counter.style.color = '#e74c3c';
            } else if (currentLength > maxLength * 0.7) {
                counter.style.color = '#f39c12';
            } else {
                counter.style.color = '#7f8c8d';
            }
        }

        // Enhanced form submission with AJAX
        document.getElementById('post-form').addEventListener('submit', function(e) {
            e.preventDefault();
            
            const formData = new FormData(this);
            const submitBtn = document.getElementById('submit-btn');
            const btnText = submitBtn.querySelector('.btn-text');
            const btnLoading = submitBtn.querySelector('.btn-loading');
            
            // Show loading state
            btnText.style.display = 'none';
            btnLoading.style.display = 'inline';
            submitBtn.disabled = true;
            
            // Send AJAX request
            fetch('create_post.php', {
                method: 'POST',
                body: formData,
                headers: {
                    'X-Requested-With': 'XMLHttpRequest'
                }
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    showAlert('success', data.message);
                    this.reset();
                    updateCharCounter('title', 255);
                    updateCharCounter('content', 10000);
                    
                    // Refresh the page after a short delay to show new post
                    setTimeout(() => {
                        window.location.reload();
                    }, 1500);
                } else {
                    showAlert('error', data.message);
                }
            })
            .catch(error => {
                console.error('Error:', error);
                showAlert('error', 'An unexpected error occurred. Please try again.');
            })
            .finally(() => {
                // Reset button state
                btnText.style.display = 'inline';
                btnLoading.style.display = 'none';
                submitBtn.disabled = false;
            });
        });

        // Clear form button
        document.getElementById('clear-btn').addEventListener('click', function() {
            if (confirm('Are you sure you want to clear the form?')) {
                document.getElementById('post-form').reset();
                updateCharCounter('title', 255);
                updateCharCounter('content', 10000);
            }
        });

        // Alert functions
        function showAlert(type, message) {
            const container = document.getElementById('message-container');
            const alertClass = type === 'success' ? 'alert-success' : 'alert-error';
            const icon = type === 'success' ? '✅' : '❌';
            
            const alertHTML = `
                <div class="alert ${alertClass}" id="dynamic-alert">
                    <span class="alert-icon">${icon}</span>
                    <span class="alert-text">${message}</span>
                    <button class="alert-close" onclick="closeAlert()">&times;</button>
                </div>
            `;
            
            container.innerHTML = alertHTML;
            
            // Auto-hide after 5 seconds
            setTimeout(() => {
                closeAlert();
            }, 5000);
        }

        function closeAlert() {
            const alerts = document.querySelectorAll('.alert');
            alerts.forEach(alert => {
                alert.style.opacity = '0';
                alert.style.transform = 'translateY(-10px)';
                setTimeout(() => {
                    if (alert.parentNode) {
                        alert.parentNode.removeChild(alert);
                    }
                }, 300);
            });
        }

        // Post sorting functionality
        let sortAscending = false;
        
        function toggleSort() {
            const container = document.getElementById('posts-container');
            const posts = Array.from(container.querySelectorAll('.post'));
            const sortText = document.getElementById('sort-text');
            
            posts.sort((a, b) => {
                const dateA = parseInt(a.dataset.date);
                const dateB = parseInt(b.dataset.date);
                return sortAscending ? dateA - dateB : dateB - dateA;
            });
            
            // Clear container and re-append sorted posts
            posts.forEach(post => container.appendChild(post));
            
            // Update button text
            sortAscending = !sortAscending;
            sortText.textContent = sortAscending ? '🔼 Oldest First' : '🔽 Newest First';
        }

        // Read more/less functionality for long posts
        function togglePost(button) {
            const post = button.closest('.post');
            const preview = post.querySelector('.post-preview');
            const full = post.querySelector('.post-full');
            
            if (full.style.display === 'none') {
                preview.style.display = 'none';
                full.style.display = 'block';
                button.textContent = 'Read Less';
            } else {
                preview.style.display = 'block';
                full.style.display = 'none';
                button.textContent = 'Read More';
            }
        }

        // Auto-hide alerts on page load
        setTimeout(() => {
            const alerts = document.querySelectorAll('.alert');
            alerts.forEach(alert => {
                if (!alert.querySelector('.alert-close').clicked) {
                    alert.style.opacity = '0.7';
                }
            });
        }, 3000);
    </script>
</body>
</html>