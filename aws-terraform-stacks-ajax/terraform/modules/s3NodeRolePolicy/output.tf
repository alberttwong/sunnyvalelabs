output "arn" {
  value = aws_iam_policy.onehouse_node_s3_access_policy.arn
}

output "csi_policy_arn" {
  value = var.isAscpEnabled ? aws_iam_policy.onehouse_csi_s3_read_access_policy[0].arn : ""
}
