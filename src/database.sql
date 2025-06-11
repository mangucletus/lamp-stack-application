/*
 * Database Schema for Simple Blog Application
 * 
 * This script creates the necessary database, tables, and user for the blog application.
 * It includes proper indexing and constraints for optimal performance and data integrity.
 */

-- Create the blog database if it doesn't exist
CREATE DATABASE IF NOT EXISTS blog_db
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

-- Use the blog database
USE blog_db;

-- Create the posts table with proper constraints and indexing
CREATE TABLE IF NOT EXISTS posts (
    id INT AUTO_INCREMENT PRIMARY KEY,              -- Unique identifier for each post
    title VARCHAR(255) NOT NULL,                   -- Post title (required, max 255 chars)
    content TEXT NOT NULL,                         -- Post content (required, can be long)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Auto-set creation timestamp
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, -- Auto-update timestamp
    
    -- Add indexes for better query performance
    INDEX idx_created_at (created_at DESC),        -- Index for ordering posts by date
    INDEX idx_title (title(50))                    -- Partial index on title for searches
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create a dedicated database user with limited privileges for security
-- This follows the principle of least privilege
CREATE USER IF NOT EXISTS 'blog_user'@'localhost' IDENTIFIED BY 'SecurePassword123!';

-- Grant only necessary permissions to the blog_user
-- SELECT: Read posts
-- INSERT: Create new posts  
-- UPDATE: Modify existing posts (for future features)
-- DELETE: Remove posts (for future features)
GRANT SELECT, INSERT, UPDATE, DELETE ON blog_db.posts TO 'blog_user'@'localhost';

-- Apply the privilege changes
FLUSH PRIVILEGES;

-- Insert some sample data for testing (optional)
INSERT INTO posts (title, content) VALUES 
    ('Welcome to My Blog!', 'This is my first post on this amazing blog platform. I''m excited to share my thoughts and experiences with you all. Stay tuned for more interesting content!'),
    ('Getting Started with AWS EC2', 'Today I want to share my experience with deploying applications on AWS EC2. It''s been quite a journey learning about cloud infrastructure and automation with Terraform.'),
    ('The Power of CI/CD Pipelines', 'Continuous Integration and Continuous Deployment have revolutionized the way we develop and deploy applications. In this post, I''ll discuss the benefits and implementation strategies.');

-- Show table structure for verification
DESCRIBE posts;

-- Show current posts count
SELECT COUNT(*) as total_posts FROM posts;