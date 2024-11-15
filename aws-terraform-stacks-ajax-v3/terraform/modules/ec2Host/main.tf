locals {
  truncated_request_id = substr(var.requestId, 0, 8)
}

data "aws_iam_policy_document" "ec2_instance_assume_role" {
  statement {
    sid    = ""
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "ec2_audit_policy" {
  name = "onehouse-ec2-audit-policy-${local.truncated_request_id}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "s3:*"
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::onehouse-customer-bucket-${local.truncated_request_id}",
          "arn:aws:s3:::onehouse-customer-bucket-${local.truncated_request_id}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_role_policy" {
  name = "onehouse-ec2-role-policy-${local.truncated_request_id}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeRouteTables",
          "ec2:DescribeNatGateways",
          "ec2:DescribeRouteTables",
          "iam:GetRole",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

data "aws_ami" "ec2_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "ec2_instance_sg" {
  name   = "onehouse-ec2-instance-sg-${local.truncated_request_id}"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "instance_role" {
  for_each = { for key, value in var.instances : key => value if value.enabled }

  name               = "onehouse-${each.key}-instance-role-${local.truncated_request_id}"
  assume_role_policy = data.aws_iam_policy_document.ec2_instance_assume_role.json
}

resource "aws_iam_role_policy_attachment" "attach_policy_0" {
  for_each = { for key, value in var.instances : key => value if value.enabled }

  role       = aws_iam_role.instance_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "attach_policy_1" {
  for_each = { for key, value in var.instances : key => value if value.enabled }

  role       = aws_iam_role.instance_role[each.key].name
  policy_arn = aws_iam_policy.ec2_audit_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_policy_2" {
  for_each = { for key, value in var.instances : key => value if value.enabled }

  role       = aws_iam_role.instance_role[each.key].name
  policy_arn = aws_iam_policy.ec2_role_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  for_each = { for key, value in var.instances : key => value if value.enabled }

  name = "onehouse-${each.key}-instance-profile-${local.truncated_request_id}"
  role = aws_iam_role.instance_role[each.key].name
}

resource "aws_instance" "ec2_host" {
  for_each = { for key, value in var.instances : key => value if value.enabled }

  ami                         = data.aws_ami.ec2_ami.id
  instance_type               = each.value.instanceType
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile[each.key].name
  vpc_security_group_ids      = [aws_security_group.ec2_instance_sg.id]
  subnet_id                   = var.private_subnet_id
  associate_public_ip_address = "false"

  tags = {
    Name       = "onehouse-${each.key}-${local.truncated_request_id}"
    CostCenter = "onehouse"
  }

  user_data = file("${path.module}/bastion_init.sh")
}

resource "aws_ssm_document" "ssm_document" {
  name            = "onehouse-ssm-document-${local.truncated_request_id}"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Document to hold regional settings for Session Manager"
    sessionType   = "Standard_Stream"
    inputs = {
      s3BucketName        = "onehouse-customer-bucket-${local.truncated_request_id}"
      s3KeyPrefix         = "ssm-session-logs"
      s3EncryptionEnabled = true
      idleSessionTimeout  = 20
    }
  })
}
