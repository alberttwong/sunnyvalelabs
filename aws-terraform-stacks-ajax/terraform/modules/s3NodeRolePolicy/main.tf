locals {
  finalS3BucketArns = concat(var.s3BucketArns, ["arn:aws:s3:::onehouse-customer-bucket-${substr(var.requestId, 0, 8)}"])
  s3DataSourceMetadataBucket = var.isS3DataLoadEnabled ? ["arn:aws:s3:::s3-datasource-metadata-${var.requestId}"] : []
}

resource "aws_iam_policy" "onehouse_node_s3_access_policy" {
  name = "onehouse-node-s3-access-policy-${substr(var.requestId, 0, 8)}"

  policy = var.productFlow == "core" ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "ReadOnlyAccess",
        "Effect" : "Allow",
        "Action" : [
          "s3:Get*",
          "s3:List*",
        ]
        "Resource" : local.finalS3BucketArns
      },
      {
        "Sid" : "AllObjectActions",
        "Effect" : "Allow",
        "Action" : "s3:*Object",
        "Resource" : [for s in local.finalS3BucketArns : "${s}/*"]
      },
    ]
    }) : var.productFlow == "lite" ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "ReadOnlyAccess",
        "Effect" : "Allow",
        "Action" : [
          "s3:Get*",
          "s3:List*",
        ]
        "Resource" : local.finalS3BucketArns
      },
      {
        "Sid" : "ReadObjectActions",
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:GetObjectVersionAttributes",
          "s3:GetObjectRetention",
          "s3:GetObjectAttributes",
          "s3:GetObjectTagging"
        ]
        "Resource" : [for s in var.s3BucketArns : endswith(s, "/") ? "${s}*/*/.hoodie/*" : "${s}/*/*/.hoodie/*"]
      },
      {
        "Sid" : "WriteAccessToOnehouseBucket",
        "Effect" : "Allow",
        "Action" : "s3:*Object",
        "Resource" : ["arn:aws:s3:::onehouse-customer-bucket-${substr(var.requestId, 0, 8)}/*"]
      }
    ]
    }) : jsonencode({
    Version   = "2012-10-17"
    Statement = []
  })
}

resource "aws_iam_policy" "onehouse_csi_s3_read_access_policy" {
  name = "onehouse-csi-s3-read-access-policy-${substr(var.requestId, 0, 8)}"
  count = var.isAscpEnabled ? 1 : 0

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "ReadOnlyAccess",
        "Effect" : "Allow",
        "Action" : [
          "s3:Get*",
          "s3:List*"
        ]
        "Resource" : concat(local.finalS3BucketArns, local.s3DataSourceMetadataBucket)
      },
      {
        "Sid" : "ReadObjectActions",
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:GetObjectVersionAttributes",
          "s3:GetObjectRetention",
          "s3:GetObjectAttributes",
          "s3:GetObjectTagging",
          "s3:HeadObject"
        ]
        "Resource" : concat(
          [for s in var.s3BucketArns : endswith(s, "/") ? "${s}*/*/.hoodie/*" : "${s}/*/*/.hoodie/*"],
          ["arn:aws:s3:::onehouse-customer-bucket-${substr(var.requestId, 0, 8)}/*"],
          [for s in local.s3DataSourceMetadataBucket : "${s}/*"]
        )
      }
    ]
  })
}
