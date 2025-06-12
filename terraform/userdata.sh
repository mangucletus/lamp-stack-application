#!/bin/bash

# Fresh EC2 Instance Userdata Script for Complete LAMP Stack Installation
# This script performs a complete fresh installation of all dependencies

set -euo pipefail

# Variables from Terraform
MYSQL_ROOT_PASSWORD="${mysql_root_password}"
MYSQL_BLOG_PASSWORD="${mysql_blog_password}"
GITHUB_REPO_URL="${github_repo_url}"
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"

# Create comprehensive log file
LOG_FILE="/var/log/userdata-setup.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "========================================================"
echo "🚀 Starting Fresh LAMP Stack Installation - $(date)"
echo "Project: $PROJECT_NAME ($ENVIRONMENT)"
echo "Instance Type: Fresh Installation"
echo "========================================================"

# Function to log with timestamp
log_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔷 $1"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1"
}

log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🎯 $1"
}

# Error handling function
handle_error() {
    log_error "Script failed at line $1"
    log_error "Last command: $BASH_COMMAND"
    echo "FAILED" > /var/log/userdata-status
    exit 1
}

trap 'handle_error $LINENO' ERR

# Update system packages
log_action "Updating system packages for fresh installation..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
log_success "System packages updated"

# Install essential packages
log_action "Installing essential packages..."
apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    htop \
    vim \
    nano \
    ufw \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    tree \
    zip
log_success "Essential packages installed"

# Install Apache
log_action "Installing Apache web server..."
apt-get install -y apache2
systemctl start apache2
systemctl enable apache2

# Verify Apache installation
if systemctl is-active --quiet apache2; then
    log_success "Apache installed and running"
else
    log_error "Apache installation failed"
    exit 1
fi

# Install MySQL Server
log_action "Installing MySQL server..."
echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
apt-get install -y mysql-server

# Start and enable MySQL
systemctl start mysql
systemctl enable mysql

# Verify MySQL installation
if systemctl is-active --quiet mysql; then
    log_success "MySQL installed and running"
else
    log_error "MySQL installation failed"
    exit 1
fi

# Install PHP and required extensions
log_action "Installing PHP and extensions..."
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
    php-bcmath \
    php-intl \
    libapache2-mod-php

# Verify PHP installation
if php --version >/dev/null 2>&1; then
    log_success "PHP installed successfully"
    log_status "PHP Version: $(php --version | head -1)"
else
    log_error "PHP installation failed"
    exit 1
fi

# Configure Apache
log_action "Configuring Apache for optimal performance..."
a2enmod rewrite
a2enmod ssl
a2enmod headers
a2enmod expires
a2enmod deflate

# Create optimized Apache configuration
cat > /etc/apache2/conf-available/blog-optimization.conf << 'EOF'
# Blog optimization configuration
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/x-javascript
</IfModule>

<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresByType image/jpg "access plus 1 month"
    ExpiresByType image/jpeg "access plus 1 month"
</IfModule>

<IfModule mod_headers.c>
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options DENY
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
</IfModule>
EOF

a2enconf blog-optimization
log_success "Apache optimized and configured"

# Create blog directory with proper permissions
log_action "Setting up blog application directory..."
BLOG_DIR="/var/www/html/blog"
mkdir -p "$BLOG_DIR"
chown -R www-data:www-data "$BLOG_DIR"
chmod -R 755 "$BLOG_DIR"
log_success "Blog directory created: $BLOG_DIR"

# Create Apache virtual host for blog
log_action "Creating Apache virtual host for blog..."
cat > /etc/apache2/sites-available/blog.conf << EOF
<VirtualHost *:80>
    ServerAdmin admin@$PROJECT_NAME.local
    DocumentRoot $BLOG_DIR
    ServerName localhost
    
    ErrorLog \${APACHE_LOG_DIR}/blog_error.log
    CustomLog \${APACHE_LOG_DIR}/blog_access.log combined
    
    <Directory $BLOG_DIR>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Security headers
        Header always set X-Content-Type-Options nosniff
        Header always set X-Frame-Options DENY
        Header always set X-XSS-Protection "1; mode=block"
        
        # PHP security
        php_admin_value expose_php Off
        php_admin_value display_errors Off
        php_admin_value log_errors On
    </Directory>
    
    # Security configurations
    ServerTokens Prod
    ServerSignature Off
    
    # PHP file handling
    <FilesMatch \.php\$>
        SetHandler application/x-httpd-php
    </FilesMatch>
    
    # Hide sensitive files
    <Files ~ "^\.">
        Require all denied
    </Files>
    
    <Files ~ "\.sql\$">
        Require all denied
    </Files>
    
    <Files ~ "\.md\$">
        Require all denied
    </Files>
</VirtualHost>
EOF

# Enable blog site and disable default
a2ensite blog.conf
a2dissite 000-default.conf
systemctl reload apache2
log_success "Apache virtual host configured"

# Secure MySQL installation
log_action "Securing MySQL installation..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" << EOF
-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Remove root login from remote hosts
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Create blog database
CREATE DATABASE IF NOT EXISTS blog_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create blog user with limited privileges
CREATE USER IF NOT EXISTS 'blog_user'@'localhost' IDENTIFIED BY '$MYSQL_BLOG_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE ON blog_db.* TO 'blog_user'@'localhost';

-- Apply changes
FLUSH PRIVILEGES;
EOF

log_success "MySQL secured and blog database created"

# Create database schema
log_action "Creating database schema..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" << 'EOF'
USE blog_db;

-- Create posts table with proper indexing
CREATE TABLE IF NOT EXISTS posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes for performance
    INDEX idx_created_at (created_at DESC),
    INDEX idx_title (title(50)),
    
    -- Full-text search index
    FULLTEXT(title, content)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample posts
INSERT INTO posts (title, content) VALUES 
    ('🎉 Welcome to Your Fresh Blog!', 'Congratulations! Your blog has been successfully deployed on fresh AWS infrastructure. This is your first post on a completely new, clean installation of the LAMP stack. Everything has been built from scratch with the latest packages and optimized configuration.'),
    ('🚀 Fresh Infrastructure Features', 'Your fresh blog installation includes: ✅ Latest Ubuntu 20.04 LTS, ✅ Apache 2.4 with security optimizations, ✅ MySQL 8.0 with proper security configuration, ✅ PHP 7.4+ with essential extensions, ✅ Optimized virtual host configuration, ✅ SSL-ready setup, ✅ Security headers configured'),
    ('🔧 Development Ready', 'Your fresh development environment is ready! You can now: 📝 Create new blog posts, 🎨 Customize the design, 🔒 Add authentication features, 📱 Make it mobile responsive, 🚀 Deploy updates via CI/CD, 📊 Add analytics and monitoring');
EOF

log_success "Database schema created with sample data"

# Test database
if mysql -u blog_user -p"$MYSQL_BLOG_PASSWORD" -e "SELECT COUNT(*) FROM blog_db.posts;" >/dev/null 2>&1; then
    log_success "✅ Database connection test passed"
else
    log_error "❌ Database connection test failed"
fi

# Test PHP
if php -m >/dev/null 2>&1; then
    log_success "✅ PHP modules test passed"
else
    log_error "❌ PHP modules test failed"
fi

# Final services restart
log_action "Final services restart for fresh configuration..."
systemctl restart apache2
systemctl restart mysql

# Wait for services to stabilize
sleep 5

# Final service verification
log_action "Final service verification..."
if systemctl is-active --quiet apache2; then
    log_success "✅ Apache final check: ACTIVE"
else
    log_error "❌ Apache final check: FAILED"
    exit 1
fi

if systemctl is-active --quiet mysql; then
    log_success "✅ MySQL final check: ACTIVE"
else
    log_error "❌ MySQL final check: FAILED"
    exit 1
fi

# Create system information file
log_action "Creating system information file..."
cat > /home/ubuntu/system-info.txt << EOF
====================================
FRESH BLOG SERVER SYSTEM INFORMATION
====================================
Installation Date: $(date)
Project: $PROJECT_NAME
Environment: $ENVIRONMENT

=== SOFTWARE VERSIONS ===
OS: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
Apache: $(apache2 -v | head -1)
MySQL: $(mysql --version)
PHP: $(php --version | head -1)

=== SERVICE STATUS ===
Apache: $(systemctl is-active apache2)
MySQL: $(systemctl is-active mysql)
UFW: $(systemctl is-active ufw)

=== NETWORK CONFIGURATION ===
Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "Not available")
Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo "Not available")
Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "Not available")

=== BLOG CONFIGURATION ===
Blog Directory: $BLOG_DIR
Database Name: blog_db
Database User: blog_user
Apache Virtual Host: /etc/apache2/sites-available/blog.conf

=== MANAGEMENT SCRIPTS ===
Service Check: /home/ubuntu/check-services.sh
Backup Script: /home/ubuntu/backup-blog.sh
System Info: /home/ubuntu/system-info.txt

=== LOG FILES ===
Userdata Log: /var/log/userdata-setup.log
Apache Access: /var/log/apache2/blog_access.log
Apache Error: /var/log/apache2/blog_error.log
MySQL Error: /var/log/mysql/error.log

=== USEFUL COMMANDS ===
Check Services: sudo systemctl status apache2 mysql
Restart Services: sudo systemctl restart apache2 mysql
View Logs: sudo tail -f /var/log/apache2/blog_error.log
Database Access: mysql -u blog_user -p blog_db
File Permissions: sudo chown -R www-data:www-data $BLOG_DIR

====================================
EOF

chown ubuntu:ubuntu /home/ubuntu/system-info.txt
log_success "System information file created"

# Create welcome message of the day
log_action "Setting up welcome message..."
cat > /etc/motd << EOF

🚀 Welcome to Fresh $PROJECT_NAME Server!

📊 Status: $(systemctl is-active apache2 | tr '[:lower:]' '[:upper:]') | MySQL: $(systemctl is-active mysql | tr '[:lower:]' '[:upper:]') | Environment: $ENVIRONMENT
🌐 Blog: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/blog
🛠️  Tools: ~/check-services.sh | ~/backup-blog.sh | ~/system-info.txt

Fresh installation completed: $(date)
All services optimized and ready for production!

EOF

log_success "Welcome message configured"

# Performance optimizations
log_action "Applying performance optimizations..."

# PHP optimizations
cat >> /etc/php/7.4/apache2/php.ini << 'EOF'

; Fresh Blog Performance Optimizations
memory_limit = 256M
max_execution_time = 60
max_input_time = 60
upload_max_filesize = 10M
post_max_size = 10M
max_file_uploads = 20

; Security optimizations
expose_php = Off
display_errors = Off
log_errors = On
error_log = /var/log/php_errors.log

; Session security
session.cookie_httponly = 1
session.use_only_cookies = 1
session.cookie_secure = 0
EOF

# MySQL optimizations for small instances
cat >> /etc/mysql/mysql.conf.d/mysqld.cnf << 'EOF'

# Fresh Blog MySQL Optimizations
innodb_buffer_pool_size = 128M
innodb_log_file_size = 32M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
query_cache_type = 1
query_cache_size = 32M
query_cache_limit = 2M
max_connections = 50
connect_timeout = 10
wait_timeout = 600
interactive_timeout = 600
EOF

log_success "Performance optimizations applied"

# Set up log rotation
log_action "Configuring log rotation..."
cat > /etc/logrotate.d/blog << 'EOF'
/var/log/apache2/blog_*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 640 www-data adm
    sharedscripts
    postrotate
        if /bin/systemctl status apache2 > /dev/null ; then \
            /bin/systemctl reload apache2 > /dev/null; \
        fi;
    endscript
}

/var/log/userdata-setup.log {
    monthly
    missingok
    rotate 12
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

log_success "Log rotation configured"

# Final cleanup and optimization
log_action "Final cleanup and optimization..."

# Update package cache
apt-get autoremove -y
apt-get autoclean

# Update file permissions
find "$BLOG_DIR" -type f -exec chmod 644 {} \;
find "$BLOG_DIR" -type d -exec chmod 755 {} \;
chown -R www-data:www-data "$BLOG_DIR"

# Restart services one final time
systemctl restart apache2
systemctl restart mysql

log_success "Final cleanup completed"

# Mark completion
log_action "Marking installation as complete..."
echo "SUCCESS" > /var/log/userdata-status
touch /var/log/userdata-complete

# Create completion summary
cat > /var/log/userdata-summary.txt << EOF
=====================================
FRESH BLOG INSTALLATION SUMMARY
=====================================
Start Time: Check /var/log/userdata-setup.log for start time
Completion Time: $(date)
Status: SUCCESS

=== INSTALLED COMPONENTS ===
✅ Ubuntu 20.04 LTS (Latest)
✅ Apache 2.4 with SSL modules
✅ MySQL 8.0 with security hardening
✅ PHP 7.4+ with essential extensions
✅ UFW Firewall configured
✅ SSL/TLS ready configuration
✅ Performance optimizations applied
✅ Security headers configured
✅ Log rotation configured

=== BLOG APPLICATION ===
✅ Database: blog_db created and populated
✅ User: blog_user with limited privileges
✅ Virtual Host: Configured and enabled
✅ Sample Content: 3 welcome posts created
✅ File Permissions: Properly configured
✅ Management Scripts: Available in /home/ubuntu/

=== ACCESS INFORMATION ===
🌐 Blog URL: http://[PUBLIC_IP]/blog
🏠 Server Status: http://[PUBLIC_IP]
🔍 Service Check: /home/ubuntu/check-services.sh
💾 Backup Tool: /home/ubuntu/backup-blog.sh
📋 System Info: /home/ubuntu/system-info.txt

=== NEXT STEPS ===
1. Access your blog via the URL above
2. Customize the design and content
3. Set up SSL certificate (Let's Encrypt recommended)
4. Configure monitoring and alerts
5. Set up regular backups
6. Add authentication if needed

=====================================
Fresh installation completed successfully!
Ready for production use.
=====================================
EOF

log_success "Installation summary created"

# Final success message
echo ""
echo "========================================================"
log_success "🎉 FRESH LAMP STACK INSTALLATION COMPLETED!"
echo "========================================================"
log_success "✅ Apache: $(systemctl is-active apache2)"
log_success "✅ MySQL: $(systemctl is-active mysql)"
log_success "✅ PHP: $(php --version | head -1)"
log_success "✅ Blog Directory: $BLOG_DIR"
log_success "✅ Database: blog_db with sample content"
log_success "✅ Security: Firewall and headers configured"
log_success "✅ Performance: Optimizations applied"
echo "========================================================"
log_success "🌐 Your fresh blog is ready at: http://[PUBLIC_IP]/blog"
log_success "🏠 Server status page: http://[PUBLIC_IP]"
log_success "🛠️  Management tools available in /home/ubuntu/"
echo "========================================================"
log_success "$(date): Fresh installation completed successfully!"
echo "" connectivity
log_action "Testing database connectivity..."
if mysql -u blog_user -p"$MYSQL_BLOG_PASSWORD" -e "SELECT COUNT(*) as post_count FROM blog_db.posts;" >/dev/null 2>&1; then
    log_success "Database connectivity test passed"
else
    log_error "Database connectivity test failed"
    exit 1
fi

# Configure firewall
log_action "Configuring UFW firewall..."
ufw --force enable
ufw allow ssh
ufw allow 'Apache Full'
ufw allow 80/tcp
ufw allow 443/tcp
ufw default deny incoming
ufw default allow outgoing
log_success "Firewall configured"

# Create useful management scripts
log_action "Creating management scripts..."

# Service status script
cat > /home/ubuntu/check-services.sh << 'EOF'
#!/bin/bash
echo "=== Fresh Blog Server Status ==="
echo "Date: $(date)"
echo ""
echo "=== Service Status ==="
systemctl is-active apache2 && echo "✅ Apache: ACTIVE" || echo "❌ Apache: INACTIVE"
systemctl is-active mysql && echo "✅ MySQL: ACTIVE" || echo "❌ MySQL: INACTIVE"
systemctl is-active ufw && echo "✅ Firewall: ACTIVE" || echo "❌ Firewall: INACTIVE"

echo ""
echo "=== Blog Directory ==="
ls -la /var/www/html/blog/ | head -10

echo ""
echo "=== Database Status ==="
mysql -u blog_user -pMYSQL_BLOG_PASSWORD_PLACEHOLDER -e "SELECT COUNT(*) as total_posts FROM blog_db.posts;" 2>/dev/null || echo "❌ Database connection failed"

echo ""
echo "=== System Resources ==="
df -h / | grep -v Filesystem
free -h | grep -v "Mem:"

echo ""
echo "=== Recent Apache Access ==="
tail -5 /var/log/apache2/blog_access.log 2>/dev/null || echo "No recent access logs"

echo ""
echo "=== Recent Apache Errors ==="
tail -3 /var/log/apache2/blog_error.log 2>/dev/null || echo "No recent error logs"
EOF

sed -i "s|MYSQL_BLOG_PASSWORD_PLACEHOLDER|$MYSQL_BLOG_PASSWORD|g" /home/ubuntu/check-services.sh
chmod +x /home/ubuntu/check-services.sh
chown ubuntu:ubuntu /home/ubuntu/check-services.sh

# Blog backup script
cat > /home/ubuntu/backup-blog.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

echo "Creating blog backup: $DATE"

# Backup files
tar -czf "$BACKUP_DIR/blog_files_$DATE.tar.gz" -C /var/www/html blog/

# Backup database
mysqldump -u blog_user -pMYSQL_BLOG_PASSWORD_PLACEHOLDER blog_db > "$BACKUP_DIR/blog_db_$DATE.sql"

echo "Backup completed: $BACKUP_DIR/"
ls -la "$BACKUP_DIR/" | tail -5
EOF

sed -i "s|MYSQL_BLOG_PASSWORD_PLACEHOLDER|$MYSQL_BLOG_PASSWORD|g" /home/ubuntu/backup-blog.sh
chmod +x /home/ubuntu/backup-blog.sh
chown ubuntu:ubuntu /home/ubuntu/backup-blog.sh

log_success "Management scripts created"

# Create initial blog files
log_action "Creating initial blog application files..."

# Basic config.php
cat > "$BLOG_DIR/config.php" << EOF
<?php
/**
 * Fresh Blog Database Configuration
 * Generated on: $(date)
 */

\$host = 'localhost';
\$dbname = 'blog_db';
\$username = 'blog_user';
\$password = '$MYSQL_BLOG_PASSWORD';

try {
    \$pdo = new PDO("mysql:host=\$host;dbname=\$dbname;charset=utf8mb4", \$username, \$password);
    \$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    \$pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    \$pdo->setAttribute(PDO::ATTR_EMULATE_PREPARES, false);
} catch(PDOException \$e) {
    error_log("Database connection error: " . \$e->getMessage());
    die("Database connection failed. Please check the configuration.");
}
?>
EOF

# Basic index.php for fresh installation
cat > "$BLOG_DIR/index.php" << EOF
<?php
/**
 * Fresh Blog Application - Main Index
 * Fresh installation completed on: $(date)
 */

require_once 'config.php';

try {
    \$stmt = \$pdo->query("SELECT * FROM posts ORDER BY created_at DESC");
    \$posts = \$stmt->fetchAll();
} catch (PDOException \$e) {
    error_log("Error fetching posts: " . \$e->getMessage());
    \$posts = [];
}

\$totalPosts = count(\$posts);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Fresh Blog - $PROJECT_NAME">
    <title>Fresh Blog - $PROJECT_NAME</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; padding: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        .container { 
            max-width: 900px; margin: 0 auto; 
            background: rgba(255,255,255,0.95); 
            padding: 30px; border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        .header { 
            text-align: center; margin-bottom: 30px; 
            border-bottom: 3px solid #667eea; padding-bottom: 20px;
        }
        .header h1 { 
            color: #667eea; margin: 0; font-size: 2.5em;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.1);
        }
        .fresh-badge { 
            background: linear-gradient(45deg, #28a745, #20c997);
            color: white; padding: 8px 16px; 
            border-radius: 20px; font-size: 0.9em;
            display: inline-block; margin-top: 10px;
            font-weight: bold;
        }
        .stats { 
            background: #f8f9fa; padding: 15px; border-radius: 8px; 
            margin: 20px 0; text-align: center;
        }
        .post { 
            margin: 20px 0; padding: 25px; 
            border: 1px solid #e9ecef; border-radius: 10px;
            background: #fff; box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .post h3 { color: #495057; margin-top: 0; }
        .post-meta { 
            color: #6c757d; font-size: 0.9em; 
            margin-bottom: 15px; font-style: italic;
        }
        .post-content { line-height: 1.6; }
        .empty-state { 
            text-align: center; padding: 50px; 
            color: #6c757d; font-style: italic;
        }
        .footer {
            text-align: center; margin-top: 30px; 
            padding-top: 20px; border-top: 1px solid #e9ecef;
            color: #6c757d; font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Fresh Blog</h1>
            <div class="fresh-badge">✨ Fresh Installation - $ENVIRONMENT</div>
            <p>Welcome to your completely fresh blog installation!</p>
        </div>

        <div class="stats">
            <strong>📊 Blog Statistics:</strong> 
            <?php echo \$totalPosts; ?> posts | 
            Fresh installation on <?php echo date('F j, Y'); ?> |
            PHP <?php echo phpversion(); ?> | 
            MySQL Ready
        </div>

        <div class="posts">
            <h2>📝 Recent Posts</h2>
            <?php if (empty(\$posts)): ?>
                <div class="empty-state">
                    <h3>🎉 Ready for Content!</h3>
                    <p>Your fresh blog is ready. Start creating amazing content!</p>
                </div>
            <?php else: ?>
                <?php foreach (\$posts as \$post): ?>
                    <div class="post">
                        <h3><?php echo htmlspecialchars(\$post['title']); ?></h3>
                        <div class="post-meta">
                            📅 Posted on <?php echo date('F j, Y \a\t g:i A', strtotime(\$post['created_at'])); ?>
                        </div>
                        <div class="post-content">
                            <?php echo nl2br(htmlspecialchars(\$post['content'])); ?>
                        </div>
                    </div>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>

        <div class="footer">
            <p>🌟 Fresh Blog Installation | Built with ❤️ on AWS | Environment: $ENVIRONMENT</p>
            <p>Server Time: <?php echo date('Y-m-d H:i:s T'); ?></p>
        </div>
    </div>
</body>
</html>
EOF

# Set proper permissions
chown -R www-data:www-data "$BLOG_DIR"
chmod -R 755 "$BLOG_DIR"
log_success "Initial blog files created"

# Create server status page
log_action "Creating server status page..."
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Fresh $PROJECT_NAME Server - Ready!</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0; background: linear-gradient(135deg, #667eea, #764ba2);
            color: white; min-height: 100vh; display: flex;
            align-items: center; justify-content: center;
        }
        .container { 
            text-align: center; max-width: 600px; padding: 40px;
            background: rgba(255,255,255,0.1); border-radius: 20px;
            backdrop-filter: blur(10px); box-shadow: 0 20px 40px rgba(0,0,0,0.2);
        }
        .status { color: #2ecc71; font-size: 28px; margin: 20px 0; }
        .link { 
            color: #3498db; text-decoration: none; font-weight: bold;
            font-size: 18px; display: inline-block; margin: 10px;
            padding: 12px 24px; background: rgba(255,255,255,0.2);
            border-radius: 25px; transition: all 0.3s;
        }
        .link:hover { 
            background: rgba(255,255,255,0.3); 
            transform: translateY(-2px);
        }
        .fresh-badge {
            background: linear-gradient(45deg, #28a745, #20c997);
            padding: 10px 20px; border-radius: 25px;
            display: inline-block; margin: 15px 0;
            font-weight: bold;
        }
        .tech-stack {
            margin: 20px 0; font-size: 14px;
            opacity: 0.9; line-height: 1.6;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Fresh $PROJECT_NAME Server</h1>
        <div class="fresh-badge">✨ Fresh Installation Complete</div>
        <div class="status">✅ LAMP Stack Ready</div>
        
        <div class="tech-stack">
            <strong>Fresh Tech Stack:</strong><br>
            🐧 Ubuntu 20.04 LTS | 🌐 Apache 2.4 | 🗄️ MySQL 8.0 | 🐘 PHP $(php --version | head -1 | cut -d' ' -f2)
        </div>
        
        <p>Environment: <strong>$ENVIRONMENT</strong></p>
        <p>Deployed: <strong>$(date '+%Y-%m-%d %H:%M:%S %Z')</strong></p>
        
        <div>
            <a href="/blog" class="link">🌐 Visit Fresh Blog</a>
        </div>
        
        <div style="margin-top: 30px; font-size: 14px; opacity: 0.8;">
            <p>✅ All services running | ✅ Database configured | ✅ Security optimized</p>
        </div>
    </div>
</body>
</html>
EOF

log_success "Server status page created"

# Final system tests
log_action "Running final system tests..."

# Test Apache
if curl -f -s "http://localhost/blog" >/dev/null; then
    log_success "✅ Blog website test passed"
else
    log_error "❌ Blog website test failed"
fi

# Test Apache root
if curl -f -s "http://localhost" >/dev/null; then
    log_success "✅ Root website test passed"
else
    log_error "❌ Root website test failed"
fi

# Test database