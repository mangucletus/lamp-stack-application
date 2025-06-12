#-------------------------------
# Output: Public IP Address
#-------------------------------
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.lamp_eip.public_ip
  # Retrieves and displays the Elastic IP assigned to the EC2 instance
}

#-------------------------------
# Output: Public DNS Name
#-------------------------------
output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.lamp_server.public_dns
  # Displays the default DNS name that AWS assigns to the EC2 instance
}

#-------------------------------
# Output: Web Application URL
#-------------------------------
output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_eip.lamp_eip.public_ip}"
  # Constructs the HTTP URL using the public IP to access the LAMP app
}

#-------------------------------
# Output: SSH Connection Command
#-------------------------------
output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i your-private-key.pem ubuntu@${aws_eip.lamp_eip.public_ip}"
  # Provides the ready-to-use SSH command to connect to the instance
  # Replace `your-private-key.pem` with the actual private key file
}
