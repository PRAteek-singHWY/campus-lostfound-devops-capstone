# Private, versioned, encrypted bucket for nightly pg_dump backups taken by the host.
resource "aws_s3_bucket" "backups" {
  count         = var.enable_backups_bucket ? 1 : 0
  bucket_prefix = "${local.name}-db-backups-"
  force_destroy = var.environment != "prod"
}

resource "aws_s3_bucket_versioning" "backups" {
  count  = var.enable_backups_bucket ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  count  = var.enable_backups_bucket ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  count                   = var.enable_backups_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.backups[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  count  = var.enable_backups_bucket ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id
  rule {
    id     = "expire-old-backups"
    status = "Enabled"
    filter {}
    expiration {
      days = 30
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
