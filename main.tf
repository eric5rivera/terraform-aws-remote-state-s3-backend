terraform {
  required_version = ">= 1.1.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.3"

    }
  }
}

# Create KMS Key to encrypt the bucket with
resource "aws_kms_key" "terraform-bucket-key" {
  description             = "This key is used to encrypt bucket objects for ${var.name}"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

# Give an alias name to the KMS key created above
resource "aws_kms_alias" "key-alias" {
  name          = "alias/terraform-bucket-key-${var.name}"
  target_key_id = aws_kms_key.terraform-bucket-key.key_id
}

## Create the S3 bucket
resource "aws_s3_bucket" "terraform-state" {
  bucket = "terraform-state-${var.name}"

}

# Configure the S3 bucket above to have private ACL... I think
resource "aws_s3_bucket_acl" "terraform_state_acl" {
  bucket     = aws_s3_bucket.terraform-state.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
}

# Configure the S3 bucket above to 
resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.terraform-state.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

# Turn on default server-side encryption for S3
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform-state.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform-bucket-key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Turn on versioning on the state bucket
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform-state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access to the state bucket
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.terraform-state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create KMS Key to encrypt the bucket with
resource "aws_kms_key" "terraform_dynamodb_key" {
  description             = "This key is used to encrypt the DynamoDB table for ${var.name}"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

# Give an alias name to the KMS key created above
resource "aws_kms_alias" "dynamodb_key" {
  name          = "alias/terraform-DynamoDB-key-${var.name}"
  target_key_id = aws_kms_key.terraform_dynamodb_key.id
}

# DynamoDB Table to be used for state locking
resource "aws_dynamodb_table" "terraform-state" {
  name           = "terraform-state-${var.name}"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID"

  server_side_encryption {
    enabled = true // enabled server side encryption
    kms_key_arn = aws_kms_key.terraform_dynamodb_key.arn # aws_kms_key.terraform_dynamodb_key.id
  }

  point_in_time_recovery {
        enabled = true
    }

  attribute {
    name = "LockID"
    type = "S"
  }
}
