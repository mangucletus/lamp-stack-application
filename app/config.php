<?php
// Database configuration
$servername = "localhost";
$username = "root";
$password = "SecurePass123!";
$dbname = "todoapp";

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Set charset to handle special characters
$conn->set_charset("utf8mb4");
?>