<?php
/**
 * Post Creation Handler
 * 
 * This file handles the creation of new blog posts.
 * It processes form submissions and returns JSON responses for AJAX calls
 * or redirects for regular form submissions.
 */

// Include database configuration
require_once 'config.php';

// Set content type for JSON responses (when requested via AJAX)
if (isset($_SERVER['HTTP_X_REQUESTED_WITH']) && $_SERVER['HTTP_X_REQUESTED_WITH'] === 'XMLHttpRequest') {
    header('Content-Type: application/json');
}

/**
 * Validate post input data
 * 
 * @param string $title Post title
 * @param string $content Post content
 * @return array Validation result with success status and errors
 */
function validatePostData($title, $content) {
    $errors = [];
    
    // Validate title
    if (empty(trim($title))) {
        $errors[] = "Post title is required.";
    } elseif (strlen(trim($title)) > 255) {
        $errors[] = "Post title must be less than 255 characters.";
    }
    
    // Validate content
    if (empty(trim($content))) {
        $errors[] = "Post content is required.";
    } elseif (strlen(trim($content)) > 10000) {
        $errors[] = "Post content must be less than 10,000 characters.";
    }
    
    // Check for potential spam (simple checks)
    $suspiciousPatterns = ['http://', 'https://', 'www.', '.com', '.net', '.org'];
    $suspiciousCount = 0;
    foreach ($suspiciousPatterns as $pattern) {
        if (stripos($content, $pattern) !== false) {
            $suspiciousCount++;
        }
    }
    
    if ($suspiciousCount > 3) {
        $errors[] = "Post content appears to contain spam. Please review and try again.";
    }
    
    return [
        'success' => empty($errors),
        'errors' => $errors
    ];
}

/**
 * Create a new blog post
 * 
 * @param PDO $pdo Database connection
 * @param string $title Post title
 * @param string $content Post content
 * @return array Result with success status and message
 */
function createBlogPost($pdo, $title, $content) {
    try {
        // Prepare and execute insert statement
        $stmt = $pdo->prepare("INSERT INTO posts (title, content, created_at) VALUES (?, ?, NOW())");
        $result = $stmt->execute([trim($title), trim($content)]);
        
        if ($result) {
            // Get the ID of the newly created post
            $postId = $pdo->lastInsertId();
            
            return [
                'success' => true,
                'message' => 'Post created successfully!',
                'post_id' => $postId
            ];
        } else {
            return [
                'success' => false,
                'message' => 'Failed to create post. Please try again.'
            ];
        }
    } catch (PDOException $e) {
        // Log the actual error for debugging
        error_log("Database error in createBlogPost: " . $e->getMessage());
        
        return [
            'success' => false,
            'message' => 'Database error occurred. Please try again later.'
        ];
    }
}

// Main processing logic
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Get form data
    $title = $_POST['title'] ?? '';
    $content = $_POST['content'] ?? '';
    
    // Validate input
    $validation = validatePostData($title, $content);
    
    if ($validation['success']) {
        // Create the post
        $result = createBlogPost($pdo, $title, $content);
        
        // Handle AJAX requests
        if (isset($_SERVER['HTTP_X_REQUESTED_WITH']) && $_SERVER['HTTP_X_REQUESTED_WITH'] === 'XMLHttpRequest') {
            echo json_encode($result);
            exit;
        }
        
        // Handle regular form submission
        if ($result['success']) {
            // Redirect to main page with success message
            header('Location: index.php?success=1&message=' . urlencode($result['message']));
            exit;
        } else {
            // Redirect back with error
            header('Location: index.php?error=1&message=' . urlencode($result['message']));
            exit;
        }
    } else {
        // Validation failed
        $errorMessage = implode(' ', $validation['errors']);
        
        // Handle AJAX requests
        if (isset($_SERVER['HTTP_X_REQUESTED_WITH']) && $_SERVER['HTTP_X_REQUESTED_WITH'] === 'XMLHttpRequest') {
            echo json_encode([
                'success' => false,
                'message' => $errorMessage,
                'errors' => $validation['errors']
            ]);
            exit;
        }
        
        // Handle regular form submission
        header('Location: index.php?error=1&message=' . urlencode($errorMessage));
        exit;
    }
} else {
    // Not a POST request - redirect to main page
    header('Location: index.php');
    exit;
}
?>