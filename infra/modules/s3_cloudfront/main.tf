terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # This line tells the module to expect an aliased provider
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# Create private S3 bucket for static website assets
resource "aws_s3_bucket" "site_bucket" {
  bucket = "${var.project_prefix}-frontend-${random_id.bucket_suffix.hex}"
  tags = merge(
    {
      Name = "${var.project_prefix}-frontend"
    },
    var.tags
  )
}

resource "aws_s3_bucket_versioning" "site_bucket_versioning" {
  bucket = aws_s3_bucket.site_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site_bucket_sse" {
  bucket = aws_s3_bucket.site_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# random suffix for bucket name uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Block public access (we will allow CloudFront via OAI only)
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.site_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Identity (OAI) — allows CloudFront to access the S3 bucket privately
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "${var.project_prefix} OAI"
}

# S3 bucket policy to allow CloudFront OAI to GetObject
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid = "AllowCloudFrontServicePrincipalReadOnly"
    principals {
      type        = "CanonicalUser"
      identifiers = [aws_cloudfront_origin_access_identity.oai.s3_canonical_user_id]
    }

    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.site_bucket.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "site_policy" {
  bucket = aws_s3_bucket.site_bucket.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# Optional ACM cert in us-east-1 for custom domain; only created if enable_acm == true and domain_name != ""
resource "aws_acm_certificate" "cert" {
  count             = var.enable_acm && length(var.domain_name) > 0 ? 1 : 0
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = var.tags
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.site_bucket.bucket_regional_domain_name
    origin_id   = "s3-${aws_s3_bucket.site_bucket.id}"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${aws_s3_bucket.site_bucket.id}"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # viewer certificate: use ACM cert if created, otherwise use default CloudFront certificate
  viewer_certificate {
    # Set the default certificate to true ONLY if enable_acm is false or domain_name is empty
    cloudfront_default_certificate = var.enable_acm && length(var.domain_name) > 0 ? false : true

    # Set the ACM certificate ARN ONLY if enable_acm is true AND domain_name is set
    acm_certificate_arn = var.enable_acm && length(var.domain_name) > 0 ? aws_acm_certificate.cert[0].arn : null

    # Set SSL support method only if using an ACM cert
    ssl_support_method = var.enable_acm && length(var.domain_name) > 0 ? "sni-only" : null

    # Set minimum protocol version only if using an ACM cert
    minimum_protocol_version = var.enable_acm && length(var.domain_name) > 0 ? "TLSv1.2_2021" : null
  }

  # If using a custom domain, add it as an alias
  aliases = var.enable_acm && length(var.domain_name) > 0 ? [var.domain_name] : []

  tags = var.tags
}
