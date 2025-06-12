#!/bin/bash

# Update system
apt-get update -y
apt-get upgrade -y

# Install Apache
apt-get install -y apache2

# Install MySQL
export DEBIAN_FRONTEND=noninteractive
apt-get install -y mysql-server

# Install PHP and required modules
apt-get install -y php php-mysql libapache2-mod-php php-cli php-common php-mbstring php-xml

# Start and enable services
systemctl start apache2
systemctl enable apache2
systemctl start mysql
systemctl enable mysql

# Configure MySQL
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'SecurePass123!';"
mysql -u root -pSecurePass123! -e "CREATE DATABASE todoapp;"
mysql -u root -pSecurePass123! -e "USE todoapp; CREATE TABLE tasks (id INT AUTO_INCREMENT PRIMARY KEY, task VARCHAR(255) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
mysql -u root -pSecurePass123! -e "FLUSH PRIVILEGES;"

# Configure Apache
a2enmod rewrite
systemctl restart apache2

# Set proper permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Remove default Apache page
rm -f /var/www/html/index.html

# Create application directory
mkdir -p /var/www/html/app
chown -R www-data:www-data /var/www/html/app

# Install AWS CLI for deployment
apt-get install -y awscli

echo "LAMP Stack installation completed!"