#!/bin/bash
# EC2 User Data Script to set up a LAMP stack and deploy a basic To-Do app

#-------------------------------
# 1. Update and Upgrade Packages
#-------------------------------
apt-get update -y         # Fetches the list of available updates
apt-get upgrade -y        # Installs the latest versions of all packages

#-------------------------------
# 2. Install Apache Web Server
#-------------------------------
apt-get install -y apache2  # Installs the Apache2 HTTP server

#-------------------------------
# 3. Install MySQL Server
#-------------------------------
export DEBIAN_FRONTEND=noninteractive  # Prevent interactive prompts during installation
apt-get install -y mysql-server        # Installs MySQL server

#-------------------------------
# 4. Install PHP and Extensions
#-------------------------------
apt-get install -y php php-mysql libapache2-mod-php php-cli php-common php-mbstring php-xml
# Installs PHP, the MySQL driver, Apache PHP module, and common PHP extensions

#-------------------------------
# 5. Enable and Start Services
#-------------------------------
systemctl start apache2     # Starts Apache service
systemctl enable apache2    # Ensures Apache starts on boot
systemctl start mysql       # Starts MySQL service
systemctl enable mysql      # Ensures MySQL starts on boot

#-------------------------------
# 6. Secure and Configure MySQL
#-------------------------------
# Set MySQL root password using native password plugin
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'SecurePass123!';"

# Create a new database for the To-Do app
mysql -u root -pSecurePass123! -e "CREATE DATABASE todoapp;"

# Create a table named 'tasks' inside 'todoapp' DB
mysql -u root -pSecurePass123! -e \
"USE todoapp; CREATE TABLE tasks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    task VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

# Apply privilege changes
mysql -u root -pSecurePass123! -e "FLUSH PRIVILEGES;"

#-------------------------------
# 7. Configure Apache for PHP
#-------------------------------
a2enmod rewrite           # Enables mod_rewrite module for clean URLs
systemctl restart apache2 # Restarts Apache to apply changes

#-------------------------------
# 8. Set File Permissions
#-------------------------------
chown -R www-data:www-data /var/www/html  # Changes ownership to Apache user
chmod -R 755 /var/www/html                # Grants read & execute permissions

#-------------------------------
# 9. Clean Up Default Page
#-------------------------------
rm -f /var/www/html/index.html  # Removes Apache default welcome page

#-------------------------------
# 10. Prepare App Directory
#-------------------------------
mkdir -p /var/www/html/app             # Creates app folder
chown -R www-data:www-data /var/www/html/app  # Sets proper ownership

#-------------------------------
# 11. Optional: Install AWS CLI
#-------------------------------
apt-get install -y awscli   # Installs AWS CLI (used for S3 sync, logs, etc.)

#-------------------------------
# 12. Completion Message
#-------------------------------
echo "LAMP Stack installation completed!"  # Confirmation message
