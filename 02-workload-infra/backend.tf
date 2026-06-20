terraform {
  backend "s3" {
    bucket                      = "361611338159-tf-state-lab"
    key                         = "workload/ap-south-1/vpc/terraform.tfstate"
    region                      = "ap-south-1"
    encrypt                     = true
    kms_key_id                  = "arn:aws:kms:ap-south-1:361611338159:key/d518001f-b35d-4078-b541-91d1a78e8915"
    dynamodb_table              = "terraform-state-lock"
    profile                     = "workload"
    dynamodb_endpoint           = "https://dynamodb.ap-south-1.amazonaws.com"

    assume_role = {
      role_arn = "arn:aws:iam::361611338159:role/TerraformStateRole-workload"
    }
  }
}