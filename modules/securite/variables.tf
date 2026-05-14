# modules/securite/variables.tf
variable "projet"       { type = string }
variable "environnement" { type = string }
variable "suffix" {
  description = "Suffixe unique pour les noms de buckets S3"
  type        = string
}
