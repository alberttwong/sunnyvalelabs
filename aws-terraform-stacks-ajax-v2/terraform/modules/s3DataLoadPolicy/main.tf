resource "aws_iam_policy" "onehouse_s3_data_load_policy" {
  name = "onehouse-s3-data-load-policy-${substr(var.requestId, 0, 8)}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadWriteAcessToOnehouseS3MetadataBucket"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::s3-datasource-metadata-${var.requestId}"
        Action = [
          "s3:*Bucket*",
          "s3:Get*"
        ]
      },
      {
        Sid      = "ReadWriteAcessToOnehouseS3MetadataBucketFiles"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::s3-datasource-metadata-${var.requestId}/*"
        Action = [
          "s3:*Object*"
        ]
      },
      {
        Sid      = "AccessToDataSourceBucket"
        Effect   = "Allow"
        Resource = var.s3DataSourceBucketArns
        Action = [
          "s3:GetBucketNotification",
          "s3:PutBucketNotification",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketVersioning"
        ]
      },
      {
        Sid      = "ReadAccessToDataSourceBucketFiles"
        Effect   = "Allow"
        Resource = [for s in var.s3DataSourceBucketArns : "${s}/*"]
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersionAttributes",
          "s3:GetObjectRetention",
          "s3:GetObjectAttributes",
          "s3:GetObjectTagging"
        ]
      },
      {
        Action = [
          "sqs:DeleteMessage"
          , "sqs:GetQueueUrl"
          , "sqs:ListQueues"
          , "sqs:ChangeMessageVisibility"
          , "sqs:UntagQueue"
          , "sqs:ReceiveMessage"
          , "sqs:SendMessage"
          , "sqs:ListQueueTags"
          , "sqs:TagQueue"
          , "sqs:ListDeadLetterSourceQueues"
          , "sqs:PurgeQueue"
          , "sqs:CreateQueue"
          , "sqs:SetQueueAttributes"
          , "sns:TagResource"
          , "sns:CreatePlatformEndpoint"
          , "sns:UntagResource"
          , "sns:ListEndpointsByPlatformApplication"
          , "sns:SetEndpointAttributes"
          , "sns:Publish"
          , "sns:SetPlatformApplicationAttributes"
          , "sns:Subscribe"
          , "sns:ConfirmSubscription"
          , "sns:ListSubscriptionsByTopic"
          , "sns:CreatePlatformApplication"
          , "sns:CreateTopic"
          , "sns:GetPlatformApplicationAttributes"
          , "sns:ListSubscriptions"
          , "sns:GetEndpointAttributes"
          , "sns:SetSubscriptionAttributes"
          , "sns:ListPlatformApplications"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/accessibleTo" : "onehouse"
          }
        }
      },
      {
        "Action" : [
          "sqs:GetQueueAttributes"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:sqs:*:*:onehouse-*"
      },
      {
        "Action" : [
          "sns:SetTopicAttributes",
          "sns:GetTopicAttributes",
          "sns:ListTagsForResource",
          "sns:GetSubscriptionAttributes",
          "sns:Unsubscribe"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:sns:*:*:onehouse-*"
      }
    ]
  })
}
