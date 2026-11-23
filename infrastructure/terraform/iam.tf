# -----------------------------------------------------------------------------
# Day 01 - EC2 instance role for Systems Manager and CloudWatch.
# Design: docs/security/iam-policies.md
#
#   nexora-ec2-ssm-role     trusted ONLY by the EC2 service
#     + AmazonSSMManagedInstanceCore   (Session Manager, Run Command, Fleet Manager)
#     + CloudWatchAgentServerPolicy    (CloudWatch agent metrics and logs)
#   nexora-ec2-ssm-profile  instance profile attached to NX-DC01 / NX-LNX01
#
# No AdministratorAccess and no inline wildcards on the instance role.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "AllowEC2ToAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ssm" {
  name               = "${var.name_prefix}-ec2-ssm-role"
  description        = "EC2 instance role for SSM management and CloudWatch agent (ESAL lab)"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.name_prefix}-ec2-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_agent" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.name_prefix}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name

  tags = {
    Name = "${var.name_prefix}-ec2-ssm-profile"
  }
}
