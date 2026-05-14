# environnements/prod/main.tf

module "securite" {
  source        = "../../modules/securite"
  projet        = var.projet
  environnement = var.environnement
  suffix        = "a1b2c3" # Assurez-vous que ce suffixe est unique globalement pour S3
}

module "reseau" {
  source = "../../modules/reseau"
  # Injection de la clé KMS provenant du module sécurité
  kms_key_arn   = module.securite.kms_key_arn
  projet        = var.projet
  environnement = var.environnement
  region        = var.aws_region
  vpc_cidr      = var.vpc_cidr
  subnet_cidr   = var.subnet_public_cidr
}

module "serveur_web" {
  source            = "../../modules/serveur-web"
  projet            = var.projet
  environnement     = var.environnement
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  subnet_id         = module.reseau.subnet_public_id
  security_group_id = module.reseau.security_group_id
  instance_profile  = module.securite.instance_profile_name
  # Ajout du KMS ARN pour le chiffrement des disques EBS
  kms_key_arn = module.securite.kms_key_arn

  depends_on = [module.reseau, module.securite]
}

# --- Outputs du déploiement ---
output "ip_serveur" { value = module.serveur_web.public_ip }
output "vpc_id" { value = module.reseau.vpc_id }
output "bucket_s3_id" { value = module.securite.bucket_stockage_id }