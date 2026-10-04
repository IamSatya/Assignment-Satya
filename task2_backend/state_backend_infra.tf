# Provisions S3 bucket and DynamoDB table for remote Terraform state and locking

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "AWS region for backend infrastructure"
  default     = "us-east-1"
}

variable "state_bucket_name" {
  type        = string
  description = "Name of the S3 bucket to store Terraform remote state"
  default     = "my-company-terraform-state-us-east-1"
}

variable "dynamodb_table_name" {
  type        = string
  description = "Name of DynamoDB table for Terraform state locking"
  default     = "terraform-state-locks"
}

# State bucket with prevent_destroy to guard against accidental deletion
resource "aws_s3_bucket" "terraform_state" {
  bucket        = var.state_bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "terraform-state-bucket"
    Environment = "shared-services"
  }
}

# Enable versioning so previous state versions are preserved for rollbacks
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state file at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state_public_access_block" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
# Note: Hash key must be named 'LockID' with string type (S) for Terraform backend compatibility
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "terraform-state-locks"
    Environment = "shared-services"
  }
}

output "s3_bucket_arn" {
  description = "ARN of the S3 remote state bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB state locking table"
  value       = aws_dynamodb_table.terraform_locks.arn
}
