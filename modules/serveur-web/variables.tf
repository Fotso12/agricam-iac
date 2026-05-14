variable "projet"           { type = string }
variable "environnement"     { type = string }
variable "ami_id"            { type = string }
variable "instance_type"     { type = string }
variable "subnet_id"         { type = string }
variable "security_group_id" { type = string }
variable "instance_profile"  { type = string }

variable "kms_key_arn" {
  description = "ARN de la clé KMS pour le chiffrement des volumes EBS"
  type        = string
}