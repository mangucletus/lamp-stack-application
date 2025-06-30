output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.lamp_server.id
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.lamp_server.public_dns
}

output "eip_public_ip" {
  description = "Public IP address of the Elastic IP"
  value       = aws_eip.lamp_eip.public_ip
}