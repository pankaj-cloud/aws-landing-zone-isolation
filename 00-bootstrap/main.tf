terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Intentionally NO backend block — bootstrap uses local state
}

provider "aws" {
  region  = "ap-south-1"
  profile = "management"
}

# KMS key for state encryption — one per environment
resource "aws_kms_key" "tf_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable management account full access"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::361611338159:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow workload account to use key for state read/write"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::553752958960:root"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "terraform-state-kms"
    Environment = "management"
    Lab         = "tf-state-isolation"
  }
}

resource "aws_kms_alias" "tf_state" {
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.tf_state.key_id
}

# S3 bucket for all state files
resource "aws_s3_bucket" "tf_state" {
  bucket = "361611338159-tf-state-lab"

  tags = {
    Name        = "terraform-state"
    Environment = "management"
    Lab         = "tf-state-isolation"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tf_state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyNonEncryptedUploads"
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::361611338159-tf-state-lab/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "AllowWorkloadAccountViaCrossAccountRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::553752958960:root"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::361611338159-tf-state-lab",
          "arn:aws:s3:::361611338159-tf-state-lab/*"
        ]
      }
    ]
  })
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "tf_state_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "terraform-state-lock"
    Environment = "management"
    Lab         = "tf-state-isolation"
  }
}