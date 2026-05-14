# --- VPC Principal ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.projet}-vpc-${var.environnement}" }
}

# Correction CKV2_AWS_12 : Restreindre le groupe de sécurité par défaut du VPC
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
}

# Correction CKV2_AWS_11 : Activer les Flow Logs du VPC
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc-flow-log/${var.projet}-${var.environnement}"
  # CKV_AWS_338 : Rétention d'un an minimum
  retention_in_days = 365
  # CKV_AWS_158 : Chiffrement KMS obligatoire
  kms_key_id        = var.kms_key_arn 
}

resource "aws_iam_role" "flow_log_role" {
  name = "${var.projet}-vpc-flow-log-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow_log_policy" {
  name = "${var.projet}-vpc-flow-log-policy"
  role = aws_iam_role.flow_log_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      # CKV_AWS_290 & CKV_AWS_355 : Restriction à la ressource spécifique
      Resource = "${aws_cloudwatch_log_group.flow_log.arn}:*"
    }]
  })
}

# --- Sous-réseau ---
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false 

  tags = { Name = "${var.projet}-subnet-public-${var.environnement}" }
}

# --- Passerelle Internet ---
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.projet}-igw-${var.environnement}" }
}

# --- Table de routage ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.projet}-rt-public-${var.environnement}" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Security Group ---
resource "aws_security_group" "web" {
  # checkov:skip=CKV2_AWS_5: Le groupe sera attaché à l'instance EC2 lors du déploiement
  name        = "${var.projet}-sg-web-${var.environnement}"
  description = "Security group pour le serveur web AgriCam"
  vpc_id      = aws_vpc.main.id

  # CKV_AWS_260 : Port 80 supprimé pour forcer le HTTPS (ou à restreindre si nécessaire)
  ingress {
    description = "HTTPS depuis Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # CKV_AWS_382 : Egress restreint (On ne laisse pas ouvert sur tous les ports/protocoles)
  egress {
    description = "Autoriser HTTPS sortant pour les mises a jour"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.projet}-sg-web-${var.environnement}" }
}