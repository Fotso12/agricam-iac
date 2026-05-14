data "aws_caller_identity" "current" {}

# --- Clé KMS pour le chiffrement global ---
resource "aws_kms_key" "main" {
  description             = "Cle KMS pour AgriCam (S3, CloudTrail, Logs)"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
            data.aws_caller_identity.current.arn
          ]
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to use KMS for SNS"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to use the key"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- Bucket S3 Stockage ---
resource "aws_s3_bucket" "stockage" {
  bucket = "${var.projet}-stockage-${var.environnement}-${var.suffix}"
  tags   = { Name = "${var.projet}-stockage-${var.environnement}" }

  # checkov:skip=CKV_AWS_144:La réplication cross-region n'est pas requise pour AgriCam
  # checkov:skip=CKV2_AWS_62:Les notifications d'événements ne sont pas nécessaires pour ce cas d'usage
}

resource "aws_s3_bucket_server_side_encryption_configuration" "stockage" {
  bucket = aws_s3_bucket.stockage.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "stockage" {
  bucket = aws_s3_bucket.stockage.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "stockage" {
  bucket = aws_s3_bucket.stockage.id
  rule {
    id     = "archive-and-cleanup"
    status = "Enabled"
    filter {}
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_logging" "stockage" {
  bucket        = aws_s3_bucket.stockage.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "log/stockage/"
}

resource "aws_s3_bucket_public_access_block" "stockage" {
  bucket                  = aws_s3_bucket.stockage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Bucket S3 pour les logs ---
resource "aws_s3_bucket" "logs" {
  bucket = "${var.projet}-cloudtrail-logs-${var.environnement}-${var.suffix}"
  tags   = { Name = "${var.projet}-cloudtrail-logs-${var.environnement}", Type = "Logs" }

  # checkov:skip=CKV_AWS_144:Bucket de logs local uniquement pour archivage
  # checkov:skip=CKV2_AWS_62:Pas de traitement automatisé des logs S3 prévu
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "log-retention-policy"
    status = "Enabled"
    filter {}
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration {
      days = 365
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# --- CloudWatch Logs pour CloudTrail ---
resource "aws_cloudwatch_log_group" "trail" {
  name              = "/aws/cloudtrail/${var.projet}-audit"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.main.arn
}

# --- SNS pour CloudTrail ---
resource "aws_sns_topic" "trail_alerts" {
  name              = "${var.projet}-cloudtrail-alerts"
  kms_master_key_id = aws_kms_key.main.id
}

# --- Politique SNS pour CloudTrail ---
resource "aws_sns_topic_policy" "trail_sns_policy" {
  arn = aws_sns_topic.trail_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudTrailPublish"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.trail_alerts.arn
      }
    ]
  })
}

# --- AWS CloudTrail ---
resource "aws_cloudtrail" "audit" {
  name                          = "${var.projet}-trail-${var.environnement}"
  s3_bucket_name                = aws_s3_bucket.logs.id
  kms_key_id                    = aws_kms_key.main.arn
  sns_topic_name                = aws_sns_topic.trail_alerts.name
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.trail_to_cw.arn
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  include_global_service_events = true
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  depends_on = [aws_s3_bucket_policy.logs, aws_sns_topic_policy.trail_sns_policy]
  tags       = { Type = "Securite" }
}

# --- Roles IAM CloudTrail vers CloudWatch ---
resource "aws_iam_role" "trail_to_cw" {
  name = "${var.projet}-cloudtrail-to-cw-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "trail_to_cw_policy" {
  name = "${var.projet}-cloudtrail-to-cw-policy"
  role = aws_iam_role.trail_to_cw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.trail.arn}:*"
      }
    ]
  })
}

# --- Role IAM EC2 ---
resource "aws_iam_role" "ec2" {
  name = "${var.projet}-role-ec2-${var.environnement}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.projet}-profile-ec2-${var.environnement}"
  role = aws_iam_role.ec2.name
}