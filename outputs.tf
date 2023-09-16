output "bucket" {
  value = aws_s3_bucket.terraform-state.id
}

output "key" {
  value = aws_s3_bucket.terraform-state.bucket
}

output "dyanmo_db_table" {
  value = aws_dynamodb_table.terraform-state.name
}