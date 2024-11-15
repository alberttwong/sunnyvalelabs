resource "aws_iam_policy" "onehouse_database_data_load_policy" {
  name = "onehouse-database-data-load-policy-${substr(var.requestId, 0, 8)}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Action" : "kafka:*",
        "Effect" : "Allow",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/CostCenter" : "OneHouse"
          }
        }
      },
      {
        "Sid" : "CloudWatchForMSKAutoScaling",
        "Effect" : "Allow",
        "Action" : [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms"
        ],
        "Resource" : "*"
      },
      {
        "Action" : [
          "kafka:DescribeCluster",
          "kafka:DescribeClusterV2",
          "kafka:CreateConfiguration",
          "kafka:DeleteConfiguration",
          "kafka:DescribeClusterOperation"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      },
      {
        "Action" : [
          "kafka:DescribeConfigurationRevision",
          "kafka:DescribeConfiguration"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:kafka:*:*:configuration/onehouse-database-cdc-${substr(var.requestId, 0, 8)}/*"
      },
      {
        "Action" : [
          "kms:TagResource",
          "kms:GetKeyRotationStatus",
          "kms:ScheduleKeyDeletion",
          "kms:GetKeyPolicy",
          "kms:DescribeKey",
          "kms:CreateKey",
          "kms:ListResourceTags",
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        "Effect" : "Allow",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/CostCenter" : "OneHouse"
          }
        }
      }
    ]
  })
}
