# Instance role: read-only on the backups bucket and SSM Session Manager (no SSH keys needed in prod).
data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.name}-app-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
}

data "aws_iam_policy_document" "backups" {
  count = var.enable_backups_bucket ? 1 : 0
  statement {
    sid       = "BackupBucketRW"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.backups[0].arn, "${aws_s3_bucket.backups[0].arn}/*"]
  }
}

resource "aws_iam_role_policy" "backups" {
  count  = var.enable_backups_bucket ? 1 : 0
  name   = "${local.name}-backups"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.backups[0].json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name}-app-profile"
  role = aws_iam_role.app.name
}
