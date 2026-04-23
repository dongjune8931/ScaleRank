output "bastion_public_ip" {
  description = "Bastion host public IP address"
  value       = aws_eip.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Bastion host EC2 instance ID"
  value       = aws_instance.bastion.id
}
