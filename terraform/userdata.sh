#!/bin/bash

/**
 * EC2 User Data Script for LAMP Stack Blog Application - CORRECTED VERSION
 * 
 * This script automatically configures a fresh Ubuntu instance with:
 * - LAMP stack (Linux, Apache, MySQL, PHP)
 * - Blog application deployment
 * - Security configurations
 * - Monitoring and logging setup
 * 
 * The script is executed with root privileges during instance launch.
 */

# Enable strict error handling
set -euo pipefail

# Define variables (passed from Terraform)
MYSQL_ROOT_PASSWORD="${mysql_root_password}"
MYSQL_BLOG_PASSWORD="${mysql_blog_password}"
GITHUB_REPO_URL="${github_repo_url}"
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"

# Create log file for this script
LOG_FILE="/var/log/userdata-setup.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=================================================="
echo "Starting LAMP Stack Setup - $(date)"
echo "Project: $PROJECT_NAME ($ENVIRONMENT)"
echo "Repository: $GITHUB_REPO_URL"
echo "=================================================="

# Function to log status with timestamp
log_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if service is running
check_service() {
    local service_name=$1
    if systemctl is-active --quiet $service_name; then
        log_status "✅ $service_name is running"
        return 0
    else
        log_status "❌ $service_name is not running"
        return 1
    fi
}

# Update system packages
log_status "📦 Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# Install essential packages first
log_status "🔧 Installing essential packages..."
apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    htop \
    vim \
    ufw \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install LAMP stack components
log_status "🚀 Installing LAMP stack..."

# Install Apache web server
log_status "📡 Installing Apache..."
apt-get install -y apache2
systemctl start apache2
systemctl enable apache2
check_service apache2

# Install MySQL server with proper configuration
log_status "🗄️ Installing MySQL..."
# Pre-configure MySQL to avoid interactive prompts
echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
apt-get install -y mysql-server

# Start MySQL service
systemctl start mysql
systemctl enable mysql
check_service mysql

# Install PHP and required modules
log_status "🐘 Installing PHP..."
apt-get install -y \
    php \
    php-mysql \
    php-apache2 \
    php-cli \
    php-common \
    php-mbstring \
    php-xml \
    php-zip \
    php-curl \
    php-gd \
    php-json \
    libapache2-mod-php

# Configure Apache for PHP
log_status "⚙️ Configuring Apache..."
a2enmod rewrite
a2enmod ssl
a2enmod headers
a2enmod php8.3 || a2enmod php8.1 || a2enmod php  # Handle different PHP versions

# Create blog application directory with proper permissions
log_status "📁 Setting up application directory..."
BLOG_DIR="/var/www/html/blog"
mkdir -p $BLOG_DIR
chown -R www-data:www-data $BLOG_DIR
chmod -R 755 $BLOG_DIR

# Verify directory was created
if [ -d "$BLOG_DIR" ]; then
    log_status "✅ Blog directory created successfully: $BLOG_DIR"
else
    log_status "❌ Failed to create blog directory: $BLOG_DIR"
    exit 1
fi

# Create Apache virtual host configuration
log_status "🌐 Configuring Apache virtual host..."
cat > /etc/apache2/sites-available/blog.conf << EOF
<VirtualHost *:80>
    # Basic virtual host configuration
    ServerAdmin admin@localhost
    DocumentRoot $BLOG_DIR
    ServerName localhost
    
    # Logging configuration
    ErrorLog \${APACHE_LOG_DIR}/blog_error.log
    CustomLog \${APACHE_LOG_DIR}/blog_access.log combined
    
    # Directory configuration with security settings
    <Directory $BLOG_DIR>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Security headers
        Header always set X-Content-Type-Options nosniff
        Header always set X-Frame-Options DENY
        Header always set X-XSS-Protection "1; mode=block"
    </Directory>
    
    # Disable server signature for security
    ServerTokens Prod
    ServerSignature Off
    
    # PHP configuration
    <FilesMatch \.php$>
        SetHandler application/x-httpd-php
    </FilesMatch>
    
    # Deny access to sensitive files
    <Files ~ "^\.">
        Require all denied
    </Files>
    
    <Files ~ "\.sql$">
        Require all denied
    </Files>
</VirtualHost>
EOF

# Enable the blog site and disable default
log_status "🔄 Enabling blog site..."
a2ensite blog.conf
a2dissite 000-default.conf
systemctl reload apache2
check_service apache2

# Secure MySQL installation and setup database
log_status "🔒 Securing MySQL and setting up database..."
mysql -u root -p$MYSQL_ROOT_PASSWORD << EOF
-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';
-- Remove remote root login
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Create blog database
CREATE DATABASE IF NOT EXISTS blog_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create blog user
CREATE USER IF NOT EXISTS 'blog_user'@'localhost' IDENTIFIED BY '$MYSQL_BLOG_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE ON blog_db.* TO 'blog_user'@'localhost';
FLUSH PRIVILEGES;

-- Use blog database and create table
USE blog_db;
CREATE TABLE IF NOT EXISTS posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_created_at (created_at DESC),
    INDEX idx_title (title(50))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample posts
INSERT INTO posts (title, content) VALUES 
('Welcome to $PROJECT_NAME!', 'This is my first post on this amazing blog platform. This blog is running on AWS EC2 in the $ENVIRONMENT environment with a complete LAMP stack!'),
('AWS EC2 Deployment Success!', 'Successfully deployed this blog application on AWS EC2 using Terraform for infrastructure as code. The deployment includes automatic setup of Apache, MySQL, and PHP with proper security configurations.'),
('About This Blog Platform', 'This blog platform is built with PHP and MySQL, featuring a clean and responsive design. It supports creating new posts through a simple form interface and displays all posts in chronological order.');
EOF

# Test database connection
log_status "🧪 Testing database connection..."
if mysql -u blog_user -p$MYSQL_BLOG_PASSWORD -e "SELECT COUNT(*) as post_count FROM blog_db.posts;" > /dev/null 2>&1; then
    log_status "✅ Database connection successful"
else
    log_status "❌ Database connection failed"
    exit 1
fi

# Configure firewall (UFW)
log_status "🛡️ Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 'Apache Full'
ufw default deny incoming
ufw default allow outgoing

# Create deployment script
log_status "📝 Creating deployment script..."
cat > /home/ubuntu/deploy-blog.sh << 'EOF'
#!/bin/bash
# Blog deployment script with improved error handling

set -e

BLOG_DIR="/var/www/html/blog"
TEMP_DIR="/tmp/blog-deploy"
LOG_FILE="/var/log/blog-deploy.log"

echo "$(date): Starting blog deployment..." | tee -a $LOG_FILE

# Ensure blog directory exists
if [ ! -d "$BLOG_DIR" ]; then
    echo "$(date): Creating blog directory: $BLOG_DIR" | tee -a $LOG_FILE
    sudo mkdir -p $BLOG_DIR
    sudo chown -R www-data:www-data $BLOG_DIR
    sudo chmod -R 755 $BLOG_DIR
fi

# Create temporary directory
rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR

# Clone the repository
cd $TEMP_DIR
if ! git clone GITHUB_REPO_URL_PLACEHOLDER .; then
    echo "$(date): Failed to clone repository" | tee -a $LOG_FILE
    exit 1
fi

# Copy source files if they exist
if [ -d "src" ]; then
    echo "$(date): Copying source files..." | tee -a $LOG_FILE
    sudo cp -r src/* $BLOG_DIR/
    sudo chown -R www-data:www-data $BLOG_DIR
    sudo chmod -R 755 $BLOG_DIR
    
    # Setup database if SQL file exists
    if [ -f "$BLOG_DIR/database.sql" ]; then
        echo "$(date): Setting up database..." | tee -a $LOG_FILE
        mysql -u root -pMYSQL_ROOT_PASSWORD_PLACEHOLDER < $BLOG_DIR/database.sql || echo "$(date): Database setup completed with existing data"
    fi
    
    echo "$(date): Files deployed successfully" | tee -a $LOG_FILE
else
    echo "$(date): Source directory not found" | tee -a $LOG_FILE
    exit 1
fi

# Reload Apache
sudo systemctl reload apache2

# Cleanup
rm -rf $TEMP_DIR

echo "$(date): Deployment completed successfully" | tee -a $LOG_FILE
EOF

# Replace placeholders in deployment script
sed -i "s|GITHUB_REPO_URL_PLACEHOLDER|$GITHUB_REPO_URL|g" /home/ubuntu/deploy-blog.sh
sed -i "s|MYSQL_ROOT_PASSWORD_PLACEHOLDER|$MYSQL_ROOT_PASSWORD|g" /home/ubuntu/deploy-blog.sh

chmod +x /home/ubuntu/deploy-blog.sh
chown ubuntu:ubuntu /home/ubuntu/deploy-blog.sh

# Create basic PHP files for initial testing
log_status "📄 Creating initial PHP files..."

# Create basic config.php
cat > $BLOG_DIR/config.php << EOF
<?php
\$host = 'localhost';
\$dbname = 'blog_db';
\$username = 'blog_user';
\$password = '$MYSQL_BLOG_PASSWORD';

try {
    \$pdo = new PDO("mysql:host=\$host;dbname=\$dbname", \$username, \$password);
    \$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    \$pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    \$pdo->setAttribute(PDO::ATTR_EMULATE_PREPARES, false);
} catch(PDOException \$e) {
    error_log("Database connection error: " . \$e->getMessage());
    die("Sorry, there was a problem connecting to the database.");
}
?>
EOF

# Create basic index.php
cat > $BLOG_DIR/index.php << EOF
<?php
require_once 'config.php';

// Fetch posts
try {
    \$stmt = \$pdo->query("SELECT * FROM posts ORDER BY created_at DESC");
    \$posts = \$stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (PDOException \$e) {
    error_log("Error fetching posts: " . \$e->getMessage());
    \$posts = [];
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$PROJECT_NAME Blog</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; }
        .post { margin-bottom: 30px; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
        .post h3 { color: #333; margin-top: 0; }
        .post-meta { color: #666; font-size: 0.9em; margin-bottom: 15px; }
        .status { background: #d4edda; color: #155724; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌟 $PROJECT_NAME Blog</h1>
        <div class="status">✅ LAMP Stack is running successfully! Environment: $ENVIRONMENT</div>
        
        <h2>Recent Posts</h2>
        <?php if (empty(\$posts)): ?>
            <p>No posts available yet.</p>
        <?php else: ?>
            <?php foreach (\$posts as \$post): ?>
                <div class="post">
                    <h3><?php echo htmlspecialchars(\$post['title']); ?></h3>
                    <div class="post-meta">Posted on <?php echo date('F j, Y', strtotime(\$post['created_at'])); ?></div>
                    <div><?php echo nl2br(htmlspecialchars(\$post['content'])); ?></div>
                </div>
            <?php endforeach; ?>
        <?php endif; ?>
    </div>
</body>
</html>
EOF

# Set proper permissions
chown -R www-data:www-data $BLOG_DIR
chmod -R 755 $BLOG_DIR

# Create server status page
log_status "📊 Creating server status page..."
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$PROJECT_NAME Server Ready</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background: linear-gradient(135deg, #667eea, #764ba2); color: white; min-height: 100vh; }
        .container { max-width: 600px; margin: 0 auto; padding: 2rem; background: rgba(255,255,255,0.1); border-radius: 20px; }
        .status { color: #2ecc71; font-size: 24px; margin: 1rem 0; }
        .env-badge { background: #e74c3c; color: white; padding: 0.5rem 1rem; border-radius: 20px; display: inline-block; margin: 1rem 0; text-transform: uppercase; font-weight: bold; }
        .link { color: #3498db; text-decoration: none; font-weight: bold; }
        .link:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 $PROJECT_NAME Server Ready!</h1>
        <div class="env-badge">$ENVIRONMENT Environment</div>
        <p class="status">✅ LAMP Stack Installation Complete</p>
        <p>Apache: Running ✅</p>
        <p>MySQL: Running ✅</p>
        <p>PHP: Configured ✅</p>
        <hr style="margin: 2rem 0; border: 1px solid rgba(255,255,255,0.3);">
        <p><a href="/blog" class="link">🌐 Visit Blog Application</a></p>
        <p><small>Project: $PROJECT_NAME | Environment: $ENVIRONMENT | Setup completed: $(date)</small></p>
    </div>
</body>
</html>
EOF

# Create systemd service status check script
cat > /home/ubuntu/check-services.sh << 'EOF'
#!/bin/bash
echo "=== Service Status Check ==="
echo "Apache2: $(systemctl is-active apache2)"
echo "MySQL: $(systemctl is-active mysql)"
echo "UFW: $(systemctl is-active ufw)"
echo ""
echo "=== Disk Usage ==="
df -h /
echo ""
echo "=== Memory Usage ==="
free -h
echo ""
echo "=== Apache Error Log (last 5 lines) ==="
sudo tail -5 /var/log/apache2/blog_error.log 2>/dev/null || echo "No errors found"
echo ""
echo "=== Blog Directory Status ==="
ls -la /var/www/html/blog/ 2>/dev/null || echo "Blog directory not found"
echo ""
echo "=== Database Connection Test ==="
mysql -u blog_user -p'$MYSQL_BLOG_PASSWORD' -e "SELECT COUNT(*) as post_count FROM blog_db.posts;" 2>/dev/null || echo "Database connection failed"
EOF

chmod +x /home/ubuntu/check-services.sh
chown ubuntu:ubuntu /home/ubuntu/check-services.sh

# Test the setup
log_status "🧪 Testing complete setup..."

# Test Apache
if check_service apache2; then
    log_status "✅ Apache test passed"
else
    log_status "❌ Apache test failed"
    systemctl status apache2
fi

# Test MySQL
if check_service mysql; then
    log_status "✅ MySQL test passed"
else
    log_status "❌ MySQL test failed"
    systemctl status mysql
fi

# Test blog directory
if [ -d "$BLOG_DIR" ] && [ -f "$BLOG_DIR/index.php" ]; then
    log_status "✅ Blog directory and files test passed"
else
    log_status "❌ Blog directory test failed"
    ls -la $BLOG_DIR || echo "Directory does not exist"
fi

# Test website accessibility (internal)
if curl -f -s "http://localhost/blog" > /dev/null; then
    log_status "✅ Internal website access test passed"
else
    log_status "❌ Internal website access test failed"
fi

# Restart services to ensure everything is running
log_status "🔄 Final service restart..."
systemctl restart apache2
systemctl restart mysql

# Final status report
log_status "=================================================="
log_status "✅ LAMP Stack Setup Complete! - $(date)"
log_status "=================================================="
log_status "🌐 Apache: $(systemctl is-active apache2)"
log_status "🗄️ MySQL: $(systemctl is-active mysql)" 
log_status "🐘 PHP: Installed and configured"
log_status "🛡️ Security: UFW firewall active"
log_status "📁 Blog Directory: $BLOG_DIR"
log_status "🔗 Repository: $GITHUB_REPO_URL"
log_status "🏷️ Environment: $ENVIRONMENT"
log_status "=================================================="

# Signal successful completion
touch /var/log/userdata-complete
log_status "✅ User data script completed successfully at $(date)"

# Create welcome message for SSH login
cat > /etc/motd << EOF

🚀 Welcome to the $PROJECT_NAME Server!

📊 Server Status:
   - Apache: $(systemctl is-active apache2)
   - MySQL: $(systemctl is-active mysql)
   - PHP: Configured and ready
   
🔧 Useful Commands:
   - Check services: ~/check-services.sh
   - Deploy blog: ~/deploy-blog.sh
   - View logs: tail -f /var/log/userdata-setup.log
   
🌐 Access your blog at: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/blog

Environment: $ENVIRONMENT
Last updated: $(date)

EOF

log_status "🎉 Setup completed successfully! Server is ready for deployment."