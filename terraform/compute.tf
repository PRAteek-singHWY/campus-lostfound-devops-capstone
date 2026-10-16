# One Ubuntu host that installs Docker and runs the published images with docker compose.
# user_data pulls ghcr.io/prateek-singhwy/lostfound-{backend,frontend}:<image_tag>.
data "aws_ami" "ubuntu" {
  count       = var.enable_app_host && !var.use_localstack ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "tls_private_key" "ssh" {
  count     = var.enable_app_host ? 1 : 0
  algorithm = "ED25519"
}

resource "aws_key_pair" "app" {
  count      = var.enable_app_host ? 1 : 0
  key_name   = "${local.name}-key"
  public_key = tls_private_key.ssh[0].public_key_openssh
}

resource "aws_instance" "app" {
  count                       = var.enable_app_host ? 1 : 0
  ami                         = var.use_localstack ? var.localstack_ami_id : data.aws_ami.ubuntu[0].id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.app.name
  key_name                    = aws_key_pair.app[0].key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    image_tag     = var.image_tag
    db_password   = var.db_password
    backup_bucket = aws_s3_bucket.backups.bucket
    aws_region    = var.aws_region
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  tags = { Name = "${local.name}-app" }
}
