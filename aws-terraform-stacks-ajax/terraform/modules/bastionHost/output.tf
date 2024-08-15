output "bastion_host_arn" {
  value = aws_instance.bastion_host.arn
}

output "bastion_role_arn" {
  value = aws_iam_role.bastion_instance_role.arn
}

output "session_document_arn" {
  value = aws_ssm_document.ssm_document.arn
}
