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
  value = var.enable_app_host ? aws_instance.app[0].id : null
}

output "app_public_ip" {
  description = "Open http://<ip>/ once cloud-init has finished (2-3 minutes)"
  value       = var.enable_app_host ? aws_instance.app[0].public_ip : null
}

output "app_url" {
  value = var.enable_app_host ? "http://${aws_instance.app[0].public_ip}/" : null
}

output "backup_bucket" {
  value = var.enable_backups_bucket ? aws_s3_bucket.backups[0].bucket : null
}

output "ssh_private_key_pem" {
  description = "terraform output -raw ssh_private_key_pem > lostfound.pem && chmod 600 lostfound.pem"
  value       = var.enable_app_host ? tls_private_key.ssh[0].private_key_openssh : null
  sensitive   = true
}

output "eks_cluster_name" {
  value = var.enable_eks ? aws_eks_cluster.main[0].name : null
}

output "eks_cluster_endpoint" {
  value = var.enable_eks ? aws_eks_cluster.main[0].endpoint : null
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the new cluster"
  value       = var.enable_eks ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main[0].name}${var.aws_profile != null ? " --profile ${var.aws_profile}" : ""}" : null
}
