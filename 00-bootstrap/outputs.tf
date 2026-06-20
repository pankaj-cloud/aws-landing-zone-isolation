output "state_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}

output "state_bucket_arn" {
  value = aws_s3_bucket.tf_state.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.tf_state_lock.name
}

output "kms_key_arn" {
  value = aws_kms_key.tf_state.arn
}

output "kms_key_id" {
  value = aws_kms_key.tf_state.key_id
}