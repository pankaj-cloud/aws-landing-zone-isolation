terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Local state — this is a one-time setup module
}

provider "aws" {
  region  = "ap-south-1"
  profile = "management"
}

# GitHub Actions OIDC Identity Provider in AWS
# This tells AWS to trust JWT tokens issued by GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint — stable value, no need to rotate
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "github-actions-oidc"
    Lab  = "tf-state-isolation"
  }
}

# IAM Role assumed by GitHub Actions via OIDC
# Trust policy scoped to your specific repo and main branch only
resource "aws_iam_role" "github_actions_terraform" {
  name = "TerraformCIRole-github"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubActionsOIDC"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Scoped to your repo — any branch (plan runs on all branches)
            # For apply/destroy we add branch check in the workflow itself
            "token.actions.githubusercontent.com:sub" = "repo:pankaj-cloud/aws-landing-zone-isolation:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "TerraformCIRole-github"
    Lab  = "tf-state-isolation"
  }
}

# Policy — same permissions as TerraformStateRole-workload
# plus workload account VPC/subnet permissions
resource "aws_iam_role_policy" "github_actions_terraform" {
  name = "TerraformCIPolicy"
  role = aws_iam_role.github_actions_terraform.id

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
        Sid    = "WorkloadVPCPermissions"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:DescribeVpcs",
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