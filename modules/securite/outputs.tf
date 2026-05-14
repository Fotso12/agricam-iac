# modules/securite/outputs.tf
output "bucket_stockage_id" { value = aws_s3_bucket.stockage.id }
output "bucket_stockage_arn" { value = aws_s3_bucket.stockage.arn }
output "instance_profile_name" { value = aws_iam_instance_profile.ec2.name }
output "kms_key_arn" {
  description = "L'ARN de la clé KMS créée"
  value       = aws_kms_key.main.arn
}