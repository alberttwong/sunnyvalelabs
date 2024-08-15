locals {
  truncated_request_id = substr(var.requestId, 0, 8)
}

data "aws_iam_policy_document" "bastion_instance_assume_role" {
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

resource "aws_iam_role" "bastion_instance_role" {
  name               = "onehouse-bastion-instance-role-${local.truncated_request_id}"
  assume_role_policy = data.aws_iam_policy_document.bastion_instance_assume_role.json
}

resource "aws_iam_role_policy_attachment" "attach_bastion_policy_0" {
  role       = aws_iam_role.bastion_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "bastion_audit_policy" {
  name = "onehouse-bastion-audit-policy-${local.truncated_request_id}"

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

resource "aws_iam_role_policy_attachment" "attach_bastion_policy_1" {
  role       = aws_iam_role.bastion_instance_role.name
  policy_arn = aws_iam_policy.bastion_audit_policy.arn
}

resource "aws_iam_instance_profile" "bastion_instance_profile" {
  name = "onehouse-bastion-instance-profile-${local.truncated_request_id}"
  role = aws_iam_role.bastion_instance_role.name
}

data "aws_ami" "bastion_ami" {
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

resource "aws_security_group" "bastion_instance_sg" {
  name   = "onehouse-bastion-instance-sg-${local.truncated_request_id}"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_instance" "bastion_host" {
  ami                         = data.aws_ami.bastion_ami.id
  instance_type               = var.ec2_instance_type
  iam_instance_profile        = aws_iam_instance_profile.bastion_instance_profile.name
  vpc_security_group_ids      = [aws_security_group.bastion_instance_sg.id]
  subnet_id                   = var.private_subnet_id
  associate_public_ip_address = "false"

  tags = {
    Name       = "onehouse-bastion-${local.truncated_request_id}"
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
