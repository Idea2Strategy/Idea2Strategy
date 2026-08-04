resource "aws_s3_bucket" "market_data" {
  bucket        = local.market_data_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket" "results" {
  count = local.enable_service_stack ? 1 : 0

  bucket        = local.result_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "workload" {
  for_each = merge({
    market_data = aws_s3_bucket.market_data.id
    }, local.enable_service_stack ? {
    results = aws_s3_bucket.results[0].id
  } : {})

  bucket                  = each.value
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "workload" {
  for_each = merge({
    market_data = aws_s3_bucket.market_data.id
    }, local.enable_service_stack ? {
    results = aws_s3_bucket.results[0].id
  } : {})

  bucket = each.value

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "workload" {
  for_each = merge({
    market_data = aws_s3_bucket.market_data.id
    }, local.enable_service_stack ? {
    results = aws_s3_bucket.results[0].id
  } : {})

  bucket = each.value

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "workload" {
  for_each = merge({
    market_data = aws_s3_bucket.market_data.id
    }, local.enable_service_stack ? {
    results = aws_s3_bucket.results[0].id
  } : {})

  bucket = each.value

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "workload_tls" {
  for_each = merge({
    market_data = aws_s3_bucket.market_data.id
    }, local.enable_service_stack ? {
    results = aws_s3_bucket.results[0].id
  } : {})

  bucket = each.value
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::${each.value}",
          "arn:aws:s3:::${each.value}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.workload]
}

data "aws_ecr_repository" "this" {
  for_each = local.ecr_repositories
  name     = "${local.name_prefix}/${each.value}"
}
