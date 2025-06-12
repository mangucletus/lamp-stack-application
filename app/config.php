<?php
// ----------------------------------------
// Database Configuration and Connection
// ----------------------------------------

// Define the server name where the MySQL database is hosted.
// In most local development environments, this is "localhost".
$servername = "localhost";

// Define the MySQL username with access to the database.
// "root" is the default MySQL admin user (should be changed in production).
$username = "root";

// Define the password associated with the above user.
// Strong passwords should always be used in production.
$password = "SecurePass123!";

// Define the name of the MySQL database to connect to.
// This must already exist on the MySQL server.
$dbname = "todoapp";

// ----------------------------------------
// Create a connection to the MySQL database
// ----------------------------------------

// Create a new instance of the MySQLi class using the above credentials.
// This object-oriented method is preferred over the old mysql_* functions.
$conn = new mysqli($servername, $username, $password, $dbname);

// ----------------------------------------
// Check for a successful connection
// ----------------------------------------

// If the connection fails, $conn->connect_error will contain the error message.
// Use die() to immediately terminate the script and display the error.
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// ----------------------------------------
// Set Character Encoding for the Connection
// ----------------------------------------

// Set the connection charset to UTF-8 with full Unicode support (utf8mb4).
// This ensures that characters like emojis or other special characters
// are stored and retrieved correctly from the database.
$conn->set_charset("utf8mb4");
?>
