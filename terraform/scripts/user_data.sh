#!/bin/bash
# terraform/scripts/user_data.sh

# Update system
apt-get update -y
apt-get upgrade -y

# Install LAMP stack
apt-get install -y apache2 mysql-server php libapache2-mod-php php-mysql php-cli php-curl php-gd php-mbstring php-xml php-zip

# Start and enable services
systemctl start apache2
systemctl enable apache2
systemctl start mysql
systemctl enable mysql

# Configure MySQL
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${db_password}';"
mysql -e "CREATE DATABASE IF NOT EXISTS blog_db;"
mysql -e "CREATE USER IF NOT EXISTS 'blog_user'@'localhost' IDENTIFIED BY '${db_password}';"
mysql -e "GRANT ALL PRIVILEGES ON blog_db.* TO 'blog_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Create the posts table
mysql -u root -p${db_password} blog_db << 'EOF'
CREATE TABLE IF NOT EXISTS posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO posts (title, content) VALUES 
('Welcome to My Blog!', 'This is my first blog post created with a simple LAMP stack application. The application is deployed on AWS Lightsail with automated CI/CD pipeline!'),
('About This Application', 'This blog application demonstrates a complete LAMP stack setup with:\n- Linux (Ubuntu)\n- Apache Web Server\n- MySQL Database\n- PHP for backend logic\n\nEverything is automated with Terraform and GitHub Actions!');
EOF

# Configure Apache
cat > /etc/apache2/sites-available/000-default.conf << 'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Enable Apache modules
a2enmod rewrite
systemctl restart apache2

# Set proper permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Install Git for deployment
apt-get install -y git

# Create deployment directory
mkdir -p /opt/deployment
chown ubuntu:ubuntu /opt/deployment

# Create deployment script
cat > /opt/deployment/deploy.sh << 'EOF'
#!/bin/bash
cd /opt/deployment

# Clone or pull latest code
if [ -d "simple-lamp-blog" ]; then
    cd simple-lamp-blog
    git pull origin main
else
    git clone https://github.com/YOUR_USERNAME/simple-lamp-blog.git
    cd simple-lamp-blog
fi

# Copy files to web directory
cp -r src/* /var/www/html/
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Update database password in PHP files
sed -i "s/your_secure_password/${db_password}/g" /var/www/html/index.php

echo "Deployment completed at $(date)"
EOF

chmod +x /opt/deployment/deploy.sh
chown ubuntu:ubuntu /opt/deployment/deploy.sh

# Create a simple health check page
cat > /var/www/html/health.php << 'EOF'
<?php
echo "Server Status: OK\n";
echo "Time: " . date('Y-m-d H:i:s') . "\n";
echo "PHP Version: " . phpversion() . "\n";

// Test database connection
try {
    $pdo = new PDO("mysql:host=localhost;dbname=blog_db", "blog_user", "${db_password}");
    echo "Database: Connected\n";
} catch(PDOException $e) {
    echo "Database: Error - " . $e->getMessage() . "\n";
}
?>
EOF

# Replace password placeholder in health check
sed -i "s/\${db_password}/${db_password}/g" /var/www/html/health.php

# Create initial index.php with placeholder
cat > /var/www/html/index.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Blog Setup</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .container { max-width: 600px; margin: 0 auto; }
        h1 { color: #333; }
        p { color: #666; line-height: 1.6; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Server is Ready!</h1>
        <p>Your LAMP stack is configured and running.</p>
        <p>The blog application will be deployed automatically when you push code to GitHub.</p>
        <p><strong>Next steps:</strong></p>
        <ol style="text-align: left;">
            <li>Push your code to GitHub repository</li>
            <li>The CI/CD pipeline will automatically deploy the application</li>
            <li>Your blog will be available at this URL</li>
        </ol>
    </div>
</body>
</html>
EOF

# Install AWS CLI for GitHub Actions
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
./aws/install

# Restart Apache
systemctl restart apache2

echo "LAMP stack installation completed!"