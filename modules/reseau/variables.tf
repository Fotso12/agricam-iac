variable "projet" {
  description = "Nom du projet (ex: AgriCam)"
  type        = string
}

variable "environnement" {
  description = "Environnement cible (ex: dev, prod)"
  type        = string
}

variable "region" {
  description = "Région AWS de déploiement"
  type        = string
}

variable "vpc_cidr" {
  description = "Plage d'adresses CIDR pour le VPC"
  type        = string
}

variable "subnet_cidr" {
  description = "Plage d'adresses CIDR pour le sous-réseau"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN de la clé KMS pour le chiffrement des logs (Correction CKV_AWS_158)"
  type        = string
}