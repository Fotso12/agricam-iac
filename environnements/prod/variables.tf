variable "aws_region" {
  description = "Region AWS"
  type        = string
  default     = "us-east-1"
}

variable "environnement" {
  description = "Nom de l'environnement"
  type        = string
  default     = "prod"
}

variable "projet" {
  description = "Nom du projet"
  type        = string
  default     = "agricam"
}

variable "vpc_cidr" {
  description = "CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_public_cidr" {
  description = "CIDR du sous-reseau public"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI Ubuntu 22.04 LTS"
  type        = string
  default     = "ami-0b6c4abb27d7e40ba"
}

# tflint-ignore: terraform_unused_declarations
variable "db_password" {
  description = "Mot de passe BDD — injecté via variable d'environnement TF_VAR_db_password"
  type        = string
  sensitive   = true
}