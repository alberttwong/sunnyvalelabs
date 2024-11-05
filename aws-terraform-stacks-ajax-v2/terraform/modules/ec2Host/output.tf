# Output the ARNs for all instances
output "instance_arns" {
  value = { for key, instance in aws_instance.ec2_host : key => instance.arn }
}

# Output the ARNs for all IAM roles
output "instance_role_arns" {
  value = { for key, role in aws_iam_role.instance_role : key => role.arn }
}

output "session_document_arn" {
  value = aws_ssm_document.ssm_document.arn
}
