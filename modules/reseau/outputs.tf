# modules/reseau/outputs.tf
output "vpc_id" { value = aws_vpc.main.id }
output "subnet_public_id" { value = aws_subnet.public.id }
output "security_group_id" { value = aws_security_group.web.id }