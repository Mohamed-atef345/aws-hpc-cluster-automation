data "aws_caller_identity" "current" {}

locals {
  bucket_name = lower("${replace(var.project_name, "_", "-")}-ansible-transfer-${data.aws_caller_identity.current.account_id}-${var.aws_region}")
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = true

  tags = {
    Name = local.bucket_name
    Role = "ansible-transfer"
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-ansible-transfer-objects"
    status = "Enabled"

    filter {}

    expiration {
      days = var.object_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
