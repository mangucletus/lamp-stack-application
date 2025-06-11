#!/bin/bash

# Minimal EC2 User Data Script - Downloads and runs full setup
# This keeps user_data under the 16KB AWS limit

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

echo "Starting minimal user_data setup - $(date)"
echo "Project: $PROJECT_NAME ($ENVIRONMENT)"

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

# Install essential tools
apt-get install -y curl wget git

# Create full setup script
cat > /tmp/full-setup.sh << 'SETUP_SCRIPT'
#!/bin/bash
set -euo pipefail

# Get variables from environment
MYSQL_ROOT_PASSWORD="$1"
MYSQL_BLOG_PASSWORD="$2"
GITHUB_REPO_URL="$3"
PROJECT_NAME="$4"
ENVIRONMENT="$5"

echo "Starting full LAMP stack setup..."

# Install LAMP stack
apt-get install -y apache2 mysql-server php php-mysql php-apache2 php-cli php-common php-mbstring php-xml php-zip php-curl php-gd php-json libapache2-mod-php

# Configure MySQL
debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"

# Start services
systemctl start apache2 mysql
systemctl enable apache2 mysql

# Configure Apache
a2enmod rewrite ssl headers
BLOG_DIR="/var/www/html/blog"
mkdir -p $BLOG_DIR
chown -R www-data:www-data $BLOG_DIR

# Create Apache vhost
cat > /etc/apache2/sites-available/blog.conf << EOF
<VirtualHost *:80>
    ServerAdmin admin@localhost
    DocumentRoot $BLOG_DIR
    ErrorLog /var/log/apache2/blog_error.log
    CustomLog /var/log/apache2/blog_access.log combined
    <Directory $BLOG_DIR>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

a2ensite blog.conf
a2dissite 000-default.conf
systemctl reload apache2

# Setup database
mysql -u root -p$MYSQL_ROOT_PASSWORD << EOF
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
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO posts (title, content) VALUES 
('Welcome to $PROJECT_NAME!', 'This blog is running on AWS EC2 in $ENVIRONMENT environment!'),
('LAMP Stack Ready', 'Apache, MySQL, and PHP are configured and running.');
EOF

# Create deployment script
cat > /home/ubuntu/deploy-blog.sh << 'DEPLOY_EOF'
#!/bin/bash
set -e
BLOG_DIR="/var/www/html/blog"
TEMP_DIR="/tmp/blog-deploy"
rm -rf $TEMP_DIR && mkdir -p $TEMP_DIR
cd $TEMP_DIR
git clone "$GITHUB_REPO_URL" .
if [ -d "src" ]; then
    cp -r src/* $BLOG_DIR/
    chown -R www-data:www-data $BLOG_DIR
    chmod -R 755 $BLOG_DIR
    systemctl reload apache2
    echo "Deployment completed successfully"
fi
rm -rf $TEMP_DIR
DEPLOY_EOF

chmod +x /home/ubuntu/deploy-blog.sh
chown ubuntu:ubuntu /home/ubuntu/deploy-blog.sh

# Try initial deployment
if /home/ubuntu/deploy-blog.sh; then
    echo "Initial deployment successful"
else
    echo "Initial deployment failed - will deploy via CI/CD"
fi

# Create status page
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head><title>$PROJECT_NAME Server Ready</title>
<style>
body{font-family:Arial;text-align:center;margin-top:50px;background:linear-gradient(135deg,#667eea,#764ba2);color:white;min-height:100vh}
.container{max-width:600px;margin:0 auto;padding:2rem;background:rgba(255,255,255,0.1);border-radius:20px}
.status{color:#2ecc71;font-size:24px;margin:1rem 0}
.env-badge{background:#e74c3c;color:white;padding:0.5rem 1rem;border-radius:20px;display:inline-block;margin:1rem 0;text-transform:uppercase;font-weight:bold}
</style></head>
<body>
<div class="container">
<h1>🚀 $PROJECT_NAME Server Ready!</h1>
<div class="env-badge">$ENVIRONMENT Environment</div>
<p class="status">✅ LAMP Stack Installation Complete</p>
<p>Apache, MySQL, and PHP are running successfully.</p>
<p>Blog available at <strong>/blog</strong></p>
<hr style="margin:2rem 0;border:1px solid rgba(255,255,255,0.3);">
<p><small>Project: $PROJECT_NAME | Environment: $ENVIRONMENT</small></p>
</div>
</body>
</html>
EOF

echo "✅ LAMP Stack setup completed successfully!"
touch /var/log/userdata-complete
SETUP_SCRIPT

# Make setup script executable
chmod +x /tmp/full-setup.sh

# Run full setup script with parameters
/tmp/full-setup.sh "$MYSQL_ROOT_PASSWORD" "$MYSQL_BLOG_PASSWORD" "$GITHUB_REPO_URL" "$PROJECT_NAME" "$ENVIRONMENT"

# Cleanup
rm -f /tmp/full-setup.sh

echo "✅ User data completed successfully at $(date)"