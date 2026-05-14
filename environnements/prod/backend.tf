terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
  }

  backend "s3" {
    bucket         = "agricam-terraform-state-484056255809"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Projet        = "AgriCam"
      Environnement = "prod"
      Proprietaire  = "tamofotso90@gmail.com"
      ManagedBy     = "Terraform"
    }
  }
}
