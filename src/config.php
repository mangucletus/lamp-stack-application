<?php
/**
 * Database Configuration File
 * 
 * This file contains all database connection settings for the blog application.
 * It establishes a PDO connection to MySQL database with error handling.
 */

// Database connection parameters
$host = 'localhost';                    // MySQL server hostname (localhost for same server)
$dbname = 'blog_db';                   // Database name for the blog application
$username = 'blog_user';               // Database user with limited privileges
$password = 'SecurePassword123!';      // Strong password for database user

try {
    // Create PDO instance with MySQL connection
    // PDO provides a secure way to interact with databases
    $pdo = new PDO("mysql:host=$host;dbname=$dbname", $username, $password);
    
    // Set PDO attributes for better error handling and security
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);  // Throw exceptions on errors
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC); // Return associative arrays
    $pdo->setAttribute(PDO::ATTR_EMULATE_PREPARES, false);          // Use real prepared statements
    
} catch(PDOException $e) {
    // Log error and show user-friendly message
    error_log("Database connection error: " . $e->getMessage());
    die("Sorry, there was a problem connecting to the database. Please try again later.");
}
?>