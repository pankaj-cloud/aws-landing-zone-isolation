terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Role now lives in MANAGEMENT account — this is where S3 and DynamoDB are
provider "aws" {
  region  = "ap-south-1"
  profile = "management"
}

resource "aws_iam_role" "terraform_state_access" {
  name = "TerraformStateRole-workload"

  # Trust policy — allow workload account and CI role to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowWorkloadAccountToAssume"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::553752958960:root"
        }
        Action = "sts:AssumeRole"
      },
      {
        Sid    = "AllowCIRoleToAssume"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::361611338159:role/TerraformCIRole-github"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "TerraformStateRole-workload"
    Environment = "workload"
    Lab         = "tf-state-isolation"
  }
}

resource "aws_iam_role_policy" "terraform_state_access" {
  name = "TerraformStateAccess-workload"
  role = aws_iam_role.terraform_state_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::361611338159-tf-state-lab/workload/*"
      },
      {
        Sid      = "S3ListBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::361611338159-tf-state-lab"
        Condition = {
          StringLike = {
            "s3:prefix" = ["workload/*"]
          }
        }
      },
      {
        Sid    = "DynamoDBLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:ap-south-1:361611338159:table/terraform-state-lock"
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "arn:aws:kms:ap-south-1:361611338159:key/d518001f-b35d-4078-b541-91d1a78e8915"
      },
      {
        Sid    = "EC2VPCPermissions"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcAttribute",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:DescribeSubnets",
          "ec2:DescribeAvailabilityZones",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}