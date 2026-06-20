terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider — management account (for state access)
provider "aws" {
  region = "ap-south-1"
}

# Workload provider — assumes into workload account for actual infra
provider "aws" {
  alias  = "workload"
  region = "ap-south-1"

  assume_role {
    role_arn     = "arn:aws:iam::361611338159:role/TerraformStateRole-workload"
    session_name = "GitHubActions-Workload"
  }
}

resource "aws_vpc" "lab" {
  provider             = aws.workload
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "tf-state-lab-vpc"
    Environment = "workload"
    ManagedBy   = "terraform"
    StateKey    = "workload/ap-south-1/vpc/terraform.tfstate"
    Lab         = "tf-state-isolation"
  }
}

resource "aws_subnet" "private" {
  provider          = aws.workload
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "tf-state-lab-private-subnet"
    Lab  = "tf-state-isolation"
  }
}