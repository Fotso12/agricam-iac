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
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.instance_profile

  # Indispensable pour que Terraform remplace l'instance quand le HTML ou l'image change
  user_data_replace_on_change = true

  monitoring    = true
  ebs_optimized = true

  user_data = <<-EOT
    #!/bin/bash
    # Version Deploy: Portfolio-v4-Fixed
    yum update -y
    amazon-linux-extras install nginx1 -y
    systemctl enable nginx
    systemctl start nginx
    
    # Injection du HTML (Fichier texte)
    cat <<EOF > /usr/share/nginx/html/index.html
    ${file("${path.module}/index.html")}
    EOF

    # Injection de la photo (Fichier binaire corrigé avec filebase64)
    echo "${filebase64("${path.module}/darryl.jpg")}" | base64 -d > /usr/share/nginx/html/darryl.jpg
    
    # Fix des permissions pour Nginx
    chmod 644 /usr/share/nginx/html/index.html
    chmod 644 /usr/share/nginx/html/darryl.jpg
  EOT

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.kms_key_arn
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = { 
    Name       = "${var.projet}-serveur-${var.environnement}" 
    Deployment = "Portfolio-Final"
  }
}