output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.lamp_eip.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.lamp_server.public_dns
}

output "application_url" {
  description = "URL to access the application"
  value       = "http://${aws_eip.lamp_eip.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i your-private-key.pem ubuntu@${aws_eip.lamp_eip.public_ip}"
}