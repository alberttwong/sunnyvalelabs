locals {
  policy_statements = {
    mskDataLoad = [
      {
        "Sid" : "DiscoverKafka",
        "Effect" : "Allow",
        "Action" : [
          "kafka:DescribeClusterOperation",
          "kafka:DescribeConfigurationRevision",
          "kafka:DescribeConfiguration",
          "kafka:DescribeCluster",
          "kafka:GetBootstrapBrokers"
        ],
        "Resource" : "*"
      },
      {
        "Action" : [
          "secretsmanager:ListSecrets",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds",
          "kms:Decrypt",
          "kms:GetKeyRotationStatus",
          "kms:GetKeyPolicy",
          "kms:DescribeKey",
          "kms:ListResourceTags",
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/CostCenter" : "OneHouse"
          }
        },
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]

    secretsManagerConfig = [
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:ListSecretVersionIds"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/accessibleTo" : "onehouse"
          }
        }
      }
    ]

    secretsManagerAscpConfig = [
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:ListSecretVersionIds",
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:TagResource"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/accessibleTo" : "onehouse"
          }
        }
      }
    ]

    glueSync = [
      {
        Sid      = "AccessToGlue"
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateDatabase",
          "glue:DeleteDatabase",
          "glue:GetTable",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchCreatePartition",
          "glue:BatchUpdatePartition",
          "glue:BatchDeletePartition"
        ]
      }
    ]

    lockProviderConfig = [
      {
        Sid      = "DynamoDBLocksTable"
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
      }
    ]
  }

  enabled_feature_flags = [for key, value in var.featureFlags : key if value]

  merged_policy_statements = length(local.enabled_feature_flags) > 0 ? flatten([
    for feature_flag in local.enabled_feature_flags : local.policy_statements[feature_flag]
  ]) : null
}

resource "aws_iam_policy" "onehouse_node_aggregate_access_policy" {
  name = "onehouse-node-aggregate-access-policy-${substr(var.requestId, 0, 8)}"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.merged_policy_statements
  })
}
