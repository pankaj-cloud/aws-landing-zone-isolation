terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "ap-south-1"
  #profile = "workload"
}

# Simple VPC — real infra in the workload account
# State for this will live in management account S3
resource "aws_vpc" "lab" {
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
  vpc_id            = aws_vpc.lab.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "tf-state-lab-private-subnet"
    Lab  = "tf-state-isolation"
  }
}