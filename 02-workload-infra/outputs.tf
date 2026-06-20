output "vpc_id" {
  value = aws_vpc.lab.id
}

output "vpc_cidr" {
  value = aws_vpc.lab.cidr_block
}

output "subnet_id" {
  value = aws_subnet.private.id
}

output "state_location" {
  value = "s3://361611338159-tf-state-lab/workload/ap-south-1/vpc/terraform.tfstate"
  description = "Where this workload's state is stored"
}