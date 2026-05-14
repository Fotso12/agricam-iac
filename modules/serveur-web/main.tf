# --- Instance EC2 ---
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.instance_profile

  # CKV_AWS_126 : Monitoring détaillé
  monitoring = true
  # CKV_AWS_135 : Optimisation EBS
  ebs_optimized = true

  # Modification ici pour injecter ton fichier index.html
  user_data = <<-EOT
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx amazon-ssm-agent
    systemctl enable nginx amazon-ssm-agent
    systemctl start nginx amazon-ssm-agent
    
    # On injecte le contenu du fichier index.html situé dans le même dossier
    cat <<EOF > /var/www/html/index.html
    ${file("${path.module}/index.html")}
    EOF
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

  tags = { Name = "${var.projet}-serveur-${var.environnement}" }
}