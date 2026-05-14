# --- Recherche dynamique de l'AMI la plus récente ---
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Instance EC2 ---
resource "aws_instance" "web" {
  # Utilisation de l'ID dynamique pour éviter l'erreur InvalidAMIID.Malformed
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.instance_profile

  # Force le remplacement de l'instance si le script user_data (ou le HTML) change
  user_data_replace_on_change = true

  # CKV_AWS_126 : Monitoring détaillé
  monitoring = true
  # CKV_AWS_135 : Optimisation EBS
  ebs_optimized = true

  # Script d'initialisation pour Nginx et le contenu HTML
  user_data = <<-EOT
    #!/bin/bash
    # Version Deploy: 2026-05-14_V1 (Ce commentaire force le refresh Terraform)
    yum update -y
    amazon-linux-extras install nginx1 -y
    systemctl enable nginx
    systemctl start nginx
    
    # On injecte le contenu du fichier index.html situé dans le même dossier
    cat <<EOF > /usr/share/nginx/html/index.html
    ${file("${path.module}/index.html")}
    EOF
    
    # On s'assure que les permissions sont correctes pour Nginx
    chmod 644 /usr/share/nginx/html/index.html
  EOT

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
    # CKV_AWS_3 & CKV_AWS_8 : Utilisation de la clé KMS pour le chiffrement du volume
    kms_key_id = var.kms_key_arn
  }

  metadata_options {
    # CKV_AWS_79 : IMDSv2 est requis
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Changement du tag pour forcer Terraform à recréer la ressource si nécessaire
  tags = { 
    Name        = "${var.projet}-serveur-${var.environnement}"
    Deployment  = "NewUI-v2"
  }
}