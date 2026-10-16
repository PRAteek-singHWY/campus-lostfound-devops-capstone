output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "security_group_id" {
  value = aws_security_group.app.id
}

output "instance_id" {
  value = aws_instance.app.id
}

output "app_public_ip" {
  description = "Open http://<ip>/ once cloud-init has finished (2-3 minutes)"
  value       = aws_instance.app.public_ip
}

output "app_url" {
  value = "http://${aws_instance.app.public_ip}/"
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.bucket
}

output "ssh_private_key_pem" {
  description = "terraform output -raw ssh_private_key_pem > lostfound.pem && chmod 600 lostfound.pem"
  value       = tls_private_key.ssh.private_key_openssh
  sensitive   = true
}
