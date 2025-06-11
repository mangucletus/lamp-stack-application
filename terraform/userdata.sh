#!/bin/bash

# EC2 User Data Script for LAMP Stack Blog Application
# This script automatically configures a fresh Ubuntu instance

set -euo pipefail

# Variables from Terraform
MYSQL_ROOT_PASSWORD="${mysql_root_password}"
MYSQL_BLOG_PASSWORD="${mysql_blog_password}"
GITHUB_REPO_URL="${github_repo_url}"
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"

# Create log file
LOG_FILE="/var/log/userdata-setup.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=================================================="
echo "Starting LAMP Stack Setup - $(date)"
echo "Project: $PROJECT_NAME ($ENVIRONMENT)"
echo "=================================================="

# Function to log with timestamp
log_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Update system
log_status "📦 Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# Install essential packages
log_status "🔧 Installing essential packages..."
apt-get install -y curl wget unzip git htop vim ufw software-properties-common

# Install Apache
log_status "📡 Installing Apache..."
apt-get install -y apache2
systemctl start apache2
systemctl enable apache2

# Install MySQL
log_status "🗄️ Installing MySQL..."
echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
apt-get install -y mysql-server
systemctl start mysql
systemctl enable mysql

# Install PHP
log_status "🐘 Installing PHP..."
apt-get install -y php php-mysql php-apache2 php-cli php-common php-mbstring php-xml php-zip php-curl php-gd libapache2-mod-php

# Configure Apache
log_status "⚙️ Configuring Apache..."
a2enmod rewrite
a2enmod ssl
a2enmod headers

# Create blog directory
log_status "📁 Setting up application directory..."
BLOG_DIR="/var/www/html/blog"
mkdir -p $BLOG_DIR
chown -R www-data:www-data $BLOG_DIR
chmod -R 755 $BLOG_DIR

# Create Apache virtual host - FIXED: Using direct paths instead of variables
log_status "🌐 Configuring Apache virtual host..."
cat > /etc/apache2/sites-available/blog.conf << EOF
<VirtualHost *:80>
    ServerAdmin admin@localhost
    DocumentRoot /var/www/html/blog
    ServerName localhost
    
    ErrorLog /var/log/apache2/blog_error.log
    CustomLog /var/log/apache2/blog_access.log combined
    
    <Directory /var/www/html/blog>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        Header always set X-Content-Type-Options nosniff
        Header always set X-Frame-Options DENY
        Header always set X-XSS-Protection "1; mode=block"
    </Directory>
    
    ServerTokens Prod
    ServerSignature Off
    
    <FilesMatch \.php\$>
        SetHandler application/x-httpd-php
    </FilesMatch>
    
    <Files ~ "^\.">
        Require all denied
    </Files>
    
    <Files ~ "\.sql\$">
        Require all denied
    </Files>
</VirtualHost>
EOF

# Enable site
log_status "🔄 Enabling blog site..."
a2ensite blog.conf
a2dissite 000-default.conf
systemctl reload apache2

# Setup MySQL database
log_status "🔒 Setting up MySQL database..."
mysql -u root -p$MYSQL_ROOT_PASSWORD << EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

CREATE DATABASE IF NOT EXISTS blog_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'blog_user'@'localhost' IDENTIFIED BY '$MYSQL_BLOG_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE ON blog_db.* TO 'blog_user'@'localhost';
FLUSH PRIVILEGES;

USE blog_db;
CREATE TABLE IF NOT EXISTS posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_created_at (created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO posts (title, content) VALUES 
('Welcome to $PROJECT_NAME!', 'This blog is running on AWS EC2 in $ENVIRONMENT environment with LAMP stack!'),
('Setup Complete', 'Apache, MySQL, and PHP are configured and running successfully.'),
('Ready for Development', 'Your blog platform is ready for customization and content creation.');
EOF

# Test database connection
log_status "🧪 Testing database connection..."
if mysql -u blog_user -p$MYSQL_BLOG_PASSWORD -e "SELECT COUNT(*) FROM blog_db.posts;" > /dev/null 2>&1; then
    log_status "✅ Database connection successful"
else
    log_status "❌ Database connection failed"
    exit 1
fi

# Configure firewall
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
set -e

BLOG_DIR="/var/www/html/blog"
TEMP_DIR="/tmp/blog-deploy"

echo "$(date): Starting deployment..."

# Ensure blog directory exists
sudo mkdir -p $BLOG_DIR
sudo chown -R www-data:www-data $BLOG_DIR

# Clone repository
rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR
cd $TEMP_DIR

if git clone GITHUB_REPO_URL_PLACEHOLDER .; then
    if [ -d "src" ]; then
        sudo cp -r src/* $BLOG_DIR/
        sudo chown -R www-data:www-data $BLOG_DIR
        sudo chmod -R 755 $BLOG_DIR
        
        # Setup database if SQL file exists
        if [ -f "$BLOG_DIR/database.sql" ]; then
            mysql -u root -pMYSQL_ROOT_PASSWORD_PLACEHOLDER < $BLOG_DIR/database.sql || true
        fi
        
        sudo systemctl reload apache2
        echo "$(date): Deployment successful"
    else
        echo "$(date): No src directory found"
        exit 1
    fi
else
    echo "$(date): Failed to clone repository"
    exit 1
fi

rm -rf $TEMP_DIR
EOF

# Replace placeholders in deployment script
sed -i "s|GITHUB_REPO_URL_PLACEHOLDER|$GITHUB_REPO_URL|g" /home/ubuntu/deploy-blog.sh
sed -i "s|MYSQL_ROOT_PASSWORD_PLACEHOLDER|$MYSQL_ROOT_PASSWORD|g" /home/ubuntu/deploy-blog.sh

chmod +x /home/ubuntu/deploy-blog.sh
chown ubuntu:ubuntu /home/ubuntu/deploy-blog.sh

# Create basic PHP files
log_status "📄 Creating initial PHP files..."

# Create config.php
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
} catch(PDOException \$e) {
    die("Database connection failed: " . \$e->getMessage());
}
?>
EOF

# Create index.php
cat > $BLOG_DIR/index.php << EOF
<?php
require_once 'config.php';

try {
    \$stmt = \$pdo->query("SELECT * FROM posts ORDER BY created_at DESC");
    \$posts = \$stmt->fetchAll();
} catch (PDOException \$e) {
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
        <div class="status">✅ LAMP Stack running in $ENVIRONMENT environment!</div>
        
        <h2>Recent Posts</h2>
        <?php if (empty(\$posts)): ?>
            <p>No posts available.</p>
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

# Set permissions
chown -R www-data:www-data $BLOG_DIR
chmod -R 755 $BLOG_DIR

# Create status page
log_status "📊 Creating status page..."
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$PROJECT_NAME Server Ready</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; 
               background: linear-gradient(135deg, #667eea, #764ba2); color: white; min-height: 100vh; }
        .container { max-width: 600px; margin: 0 auto; padding: 2rem; 
                    background: rgba(255,255,255,0.1); border-radius: 20px; }
        .status { color: #2ecc71; font-size: 24px; margin: 1rem 0; }
        .link { color: #3498db; text-decoration: none; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 $PROJECT_NAME Server Ready!</h1>
        <p class="status">✅ LAMP Stack Installation Complete</p>
        <p>Environment: $ENVIRONMENT</p>
        <p><a href="/blog" class="link">🌐 Visit Blog</a></p>
    </div>
</body>
</html>
EOF

# Create service check script
cat > /home/ubuntu/check-services.sh << 'EOF'
#!/bin/bash
echo "=== Service Status ==="
echo "Apache2: $(systemctl is-active apache2)"
echo "MySQL: $(systemctl is-active mysql)"
echo ""
echo "=== Blog Directory ==="
ls -la /var/www/html/blog/
echo ""
echo "=== Database Test ==="
mysql -u blog_user -pMYSQL_BLOG_PASSWORD_PLACEHOLDER -e "SELECT COUNT(*) as posts FROM blog_db.posts;" 2>/dev/null || echo "Database connection failed"
EOF

sed -i "s|MYSQL_BLOG_PASSWORD_PLACEHOLDER|$MYSQL_BLOG_PASSWORD|g" /home/ubuntu/check-services.sh
chmod +x /home/ubuntu/check-services.sh
chown ubuntu:ubuntu /home/ubuntu/check-services.sh

# Final testing
log_status "🧪 Testing setup..."

# Check services
if systemctl is-active --quiet apache2; then
    log_status "✅ Apache is running"
else
    log_status "❌ Apache failed"
    exit 1
fi

if systemctl is-active --quiet mysql; then
    log_status "✅ MySQL is running"
else
    log_status "❌ MySQL failed"  
    exit 1
fi

# Test website
if curl -f -s "http://localhost/blog" > /dev/null; then
    log_status "✅ Website accessible"
else
    log_status "❌ Website test failed"
fi

# Final restart
systemctl restart apache2
systemctl restart mysql

log_status "=================================================="
log_status "✅ LAMP Stack Setup Complete!"
log_status "Apache: $(systemctl is-active apache2)"
log_status "MySQL: $(systemctl is-active mysql)"
log_status "Blog Directory: $BLOG_DIR"
log_status "=================================================="

# Mark completion
touch /var/log/userdata-complete

# Create MOTD
cat > /etc/motd << EOF

🚀 Welcome to $PROJECT_NAME Server!

📊 Status: Apache ($(systemctl is-active apache2)) | MySQL ($(systemctl is-active mysql))
🔧 Commands: ~/check-services.sh | ~/deploy-blog.sh
🌐 Blog: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/blog

Environment: $ENVIRONMENT | Updated: $(date)

EOF

log_status "🎉 Setup completed successfully!"