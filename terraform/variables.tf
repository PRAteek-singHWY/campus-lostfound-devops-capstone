variable "aws_region" {
  description = "Region for every resource"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use for real AWS (ignored for LocalStack)"
  type        = string
  default     = null
}

variable "project" {
  description = "Name prefix for all resources"
  type        = string
  default     = "lostfound"
}

variable "environment" {
  description = "dev, staging or prod"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "vpc_cidr" {
  description = "Address range of the VPC"
  type        = string
  default     = "10.50.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_count" {
  description = "Public subnets spread across availability zones"
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "EC2 size for the application host"
  type        = string
  default     = "t3.small"
}

variable "admin_cidr" {
  description = "The only address range allowed to SSH in"
  type        = string
  default     = "0.0.0.0/0"
}

variable "image_tag" {
  description = "Tag of the ghcr.io images the host runs (set by CI to the commit SHA)"
  type        = string
  default     = "latest"
}

variable "db_password" {
  description = "PostgreSQL password injected into the host's .env (use TF_VAR_db_password)"
  type        = string
  sensitive   = true
  default     = "change-me-in-tfvars"
}

variable "use_localstack" {
  description = "true sends every call to LocalStack, false to real AWS"
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  description = "LocalStack edge URL"
  type        = string
  default     = "http://localhost:4566"
}

variable "localstack_ami_id" {
  description = "AMI used when running on LocalStack (real AWS looks up Ubuntu 24.04 instead)"
  type        = string
  default     = "ami-1e749f67"
}

variable "enable_eks" {
  description = "Create the EKS cluster and node group (false = EC2/compose host only)"
  type        = bool
  default     = true
}

variable "eks_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.31"
}

variable "eks_node_instance_type" {
  description = "Instance type for the managed node group"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_count" {
  description = "Desired worker nodes"
  type        = number
  default     = 2
}

variable "enable_app_host" {
  description = "Create the standalone EC2 host that runs the stack with docker compose"
  type        = bool
  default     = false
}
