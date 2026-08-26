output "bucket_name" {
  description = "Name of the S3 bucket used by the Ansible SSM connection plugin"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket used by the Ansible SSM connection plugin"
  value       = aws_s3_bucket.this.arn
}
