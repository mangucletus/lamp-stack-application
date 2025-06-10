-- Create database
CREATE DATABASE IF NOT EXISTS blog_db;
USE blog_db;

-- Create user and grant privileges
CREATE USER IF NOT EXISTS 'blog_user'@'localhost' IDENTIFIED BY 'your_secure_password';
GRANT ALL PRIVILEGES ON blog_db.* TO 'blog_user'@'localhost';
FLUSH PRIVILEGES;

-- Create posts table
CREATE TABLE IF NOT EXISTS posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO posts (title, content) VALUES 
('Welcome to My Blog!', 'This is my first blog post created with a simple LAMP stack application. The application is deployed on AWS Lightsail with automated CI/CD pipeline!'),
('About This Application', 'This blog application demonstrates a complete LAMP stack setup with:\n- Linux (Ubuntu)\n- Apache Web Server\n- MySQL Database\n- PHP for backend logic\n\nEverything is automated with Terraform and GitHub Actions!');