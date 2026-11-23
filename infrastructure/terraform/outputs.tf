output "vpc_id" {
  description = "ID of nexora-vpc."
  value       = module.network.vpc_id
}

output "public_subnet_id" {
  description = "ID of nexora-public-subnet-a."
  value       = module.network.public_subnet_id
}

output "private_subnet_id" {
  description = "ID of nexora-private-subnet-a (null when not created)."
  value       = module.network.private_subnet_id
}

output "ec2_instance_profile_name" {
  description = "Instance profile to attach to NX-DC01 and NX-LNX01."
  value       = aws_iam_instance_profile.ec2_ssm.name
}

output "ec2_role_arn" {
  description = "ARN of the EC2 SSM role (needed for scoped iam:PassRole)."
  value       = aws_iam_role.ec2_ssm.arn
}

output "dc_security_group_id" {
  description = "ID of nexora-dc-sg."
  value       = aws_security_group.dc.id
}
