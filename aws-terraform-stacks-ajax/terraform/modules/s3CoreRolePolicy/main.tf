locals {
  finalS3BucketArns = concat(var.s3BucketArns, ["arn:aws:s3:::onehouse-customer-bucket-${substr(var.requestId, 0, 8)}"])
}

resource "aws_iam_policy" "onehouse_core_s3_access_policy" {
  name = "onehouse-core-s3-access-policy-${substr(var.requestId, 0, 8)}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "ListAccess",
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ]
        "Resource" : local.finalS3BucketArns
      },
      {
        "Sid" : "ReadAccess",
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
        "Sid" : "ReadWriteAccessToOnehouseBucket",
        "Effect" : "Allow",
        "Action" : "s3:*Object",
        "Resource" : ["arn:aws:s3:::onehouse-customer-bucket-${substr(var.requestId, 0, 8)}/*"]
      },
      {
        "Sid" : "LifecycleAccessToOnehouseBucket",
        "Effect" : "Allow",
        "Action" : "s3:*LifecycleConfiguration",
        "Resource" : "arn:aws:s3:::onehouse-customer-bucket-${substr(var.requestId, 0, 8)}"
      }
    ]
  })
}
