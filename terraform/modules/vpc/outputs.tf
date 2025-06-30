output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.lamp_vpc.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.lamp_public_subnet.id
}