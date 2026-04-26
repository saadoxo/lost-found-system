resource "aws_s3_bucket" "images" {
  bucket = "${var.project}-images-${var.environment}-${var.aws_region}"
  tags   = merge(var.common_tags, { Name = "images-primary" })
}

resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── DR Bucket (us-west-2) ──────────────────────────────────────────────────
resource "aws_s3_bucket" "images_dr" {
  provider = aws.dr
  bucket   = "${var.project}-images-${var.environment}-us-west-2"
  tags     = merge(var.common_tags, { Name = "images-dr" })
}

resource "aws_s3_bucket_versioning" "images_dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.images_dr.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images_dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.images_dr.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "images_dr" {
  provider                = aws.dr
  bucket                  = aws_s3_bucket.images_dr.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── CRR IAM Role ──────────────────────────────────────────────────────────────
resource "aws_iam_role" "replication" {
  name = "${var.project}-s3-replication-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "replication" {
  name = "replication"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = aws_s3_bucket.images.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        Resource = "${aws_s3_bucket.images.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = "${aws_s3_bucket.images_dr.arn}/*"
      }
    ]
  })
}

# ── Cross-Region Replication Rule ─────────────────────────────────────────────
resource "aws_s3_bucket_replication_configuration" "images" {
  bucket = aws_s3_bucket.images.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.images_dr.arn
      storage_class = "STANDARD_IA"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.images,
    aws_s3_bucket_versioning.images_dr
  ]
}
