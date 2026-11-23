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

output "dc_instance_id" {
  description = "Instance ID of NX-DC01 (null when create_dc = false)."
  value       = one(aws_instance.dc[*].id)
}

output "dc_private_ip" {
  description = "Private IPv4 of NX-DC01."
  value       = one(aws_instance.dc[*].private_ip)
}

output "dc_ami_id" {
  description = "AMI used by NX-DC01 at creation time."
  value       = one(aws_instance.dc[*].ami)
}

output "dc_ssm_session_command" {
  description = "Command to open a Session Manager shell on NX-DC01."
  value       = var.create_dc ? "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.dc[0].id}" : null
}

output "dhcp_options_id" {
  description = "ID of nexora-dhcp-options (null until enable_ad_dhcp_options = true)."
  value       = one(aws_vpc_dhcp_options.nexora[*].id)
}
