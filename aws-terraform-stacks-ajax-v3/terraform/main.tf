variable "config_path" {
  type        = string
  description = "optional: config file path"
  default     = ""
}

data "aws_secretsmanager_secret_version" "request_id" {
  count     = local.config.requestIdSecretManager.enabled ? 1 : 0
  secret_id = local.config.requestIdSecretManager.secretArn
}

locals {
  core_roles        = ["core", "support"]
  final_config_path = var.config_path == "" ? "./config.yaml" : var.config_path
  config            = yamldecode(file(local.final_config_path))
  onehouse_roles = [
    aws_iam_role.core_role[0].arn,
    aws_iam_role.core_role[1].arn,
    aws_iam_role.eks_cluster_role.arn,
    aws_iam_role.eks_node_role.arn,
    aws_iam_role.csi_driver_role.arn,
    "arn:aws:iam::*:role/aws-service-role/kafka.amazonaws.com/AWSServiceRoleForKafka",
    "arn:aws:iam::*:role/aws-service-role/kafka.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_KafkaCluster"
  ]

  requestId              = local.config.requestIdSecretManager.enabled ? data.aws_secretsmanager_secret_version.request_id[0].secret_string : local.config.requestId
  truncated_request_id   = substr(local.requestId, 0, 8)
  add_aggregate_policies = local.config.mskDataLoad.enabled || local.config.glueSync.enabled || local.config.ascp.enabled || local.config.secretsManagerConfig.credentialsManagementType == "BYOS" || local.config.lockProviderConfig.enableDynamoDB

  isS3DataLoadEnabled = local.config.s3DataLoad.enabled

  enabled_instances = {
    for name, config in {
      "bastion-host"  = local.config.ec2Config.bastionHostConfig
      "diagnose-host" = local.config.ec2Config.diagnoseHostConfig
    } :
    name => config if config.enabled
  }
}

module "s3_core_role_access_policy" {
  source       = "./modules/s3CoreRolePolicy"
  productFlow  = local.config.productFlow
  requestId    = local.requestId
  s3BucketArns = local.config.s3BucketArns
}

module "s3_node_role_access_policy" {
  source              = "./modules/s3NodeRolePolicy"
  productFlow         = local.config.productFlow
  requestId           = local.requestId
  s3BucketArns        = local.config.s3BucketArns
  isS3DataLoadEnabled = local.isS3DataLoadEnabled
  isAscpEnabled       = local.config.ascp.enabled
}

module "s3_data_load_access_policy" {
  count                  = local.isS3DataLoadEnabled ? 1 : 0
  source                 = "./modules/s3DataLoadPolicy"
  requestId              = local.requestId
  s3DataSourceBucketArns = local.config.s3DataLoad.s3DataSourceBucketArns
}

module "database_data_load_access_policy" {
  count     = local.config.databaseDataLoad.enabled ? 1 : 0
  source    = "./modules/databaseDataLoadPolicy"
  requestId = local.requestId
}

module "aggregate_node_role_policies" {
  count = local.add_aggregate_policies ? 1 : 0

  source    = "./modules/aggregateNodeRolePolicy"
  requestId = local.requestId
  featureFlags = {
    mskDataLoad              = local.config.mskDataLoad.enabled
    secretsManagerConfig     = local.config.secretsManagerConfig.credentialsManagementType == "BYOS"
    glueSync                 = local.config.glueSync.enabled
    secretsManagerAscpConfig = local.config.ascp.enabled
    lockProviderConfig       = local.config.lockProviderConfig.enableDynamoDB
  }
}

module "add_ec2_hosts" {
  count = length(local.enabled_instances) > 0 ? 1 : 0

  source            = "./modules/ec2Host"
  requestId         = local.requestId
  vpc_id            = local.config.ec2Config.vpcID
  private_subnet_id = local.config.ec2Config.privateSubnetID

  instances = local.enabled_instances
}

# For CSI driver Role
resource "aws_iam_role" "csi_driver_role" {
  name               = "onehouse-customer-csi-driver-role-${local.truncated_request_id}"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.node_role_assume_policy.json
  lifecycle {
    ignore_changes = [
      assume_role_policy
    ]
  }
}

data "aws_iam_policy_document" "csi_driver_secret_access" {
  count = local.config.ascp.enabled ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/accessibleTo"
      values   = ["onehouse"]
    }
  }
}

resource "aws_iam_policy" "csi_driver_secret_access" {
  count  = local.config.ascp.enabled ? 1 : 0
  name   = "onehouse-csi-secret-access-policy-${local.truncated_request_id}"
  policy = data.aws_iam_policy_document.csi_driver_secret_access[0].json
}

resource "aws_iam_role_policy_attachment" "csi_driver_secret_access" {
  count      = local.config.ascp.enabled ? 1 : 0
  role       = aws_iam_role.csi_driver_role.name
  policy_arn = aws_iam_policy.csi_driver_secret_access[0].arn
}

resource "aws_iam_role_policy_attachment" "attach_csi_driver_policy" {
  role       = aws_iam_role.csi_driver_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# For Core and support Role
resource "aws_iam_role" "core_role" {
  count = length(local.core_roles)

  name               = "onehouse-customer-${local.core_roles[count.index]}-role-${local.truncated_request_id}"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.core_role_assume_policy.json
}

data "aws_iam_policy_document" "core_role_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = local.config.environment == "production" ? ["arn:aws:iam::194159489498:role/onehouse-prod-eks-node-group-role", aws_iam_role.eks_cluster_role.arn, aws_iam_role.eks_node_role.arn] : [aws_iam_role.eks_cluster_role.arn, aws_iam_role.eks_node_role.arn, "arn:aws:iam::395578527081:role/onehouse-staging-eks-node-group-role", "arn:aws:iam::582558643208:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_aws-onehouse_team-dev_ccd12e2e98be0a91"]
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [local.requestId]
    }
  }

  dynamic "statement" {
    for_each = can(values(module.add_ec2_hosts[0].instance_role_arns)) ? [1] : []
    content {
      actions = ["sts:AssumeRole"]
      principals {
        type        = "AWS"
        identifiers = values(module.add_ec2_hosts[0].instance_role_arns)
      }
    }
  }
}

resource "aws_iam_role_policy_attachment" "attach_common_policy_0" {
  count = length(local.core_roles)

  role       = aws_iam_role.core_role[count.index].name
  policy_arn = aws_iam_policy.onehouse_core_role_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_ascp_policy" {
  count = local.config.ascp.enabled ? length(local.core_roles) : 0

  role       = aws_iam_role.core_role[count.index].name
  policy_arn = aws_iam_policy.onehouse_core_role_ascp_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "attach_common_policy_1" {
  count = length(local.core_roles)

  role       = aws_iam_role.core_role[count.index].name
  policy_arn = aws_iam_policy.onehouse_core_role_iam_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy_0" {
  count = length(local.core_roles)

  role       = aws_iam_role.core_role[count.index].name
  policy_arn = module.s3_core_role_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_s3_data_load_policy_0" {
  count = local.isS3DataLoadEnabled ? length(local.core_roles) : 0

  role       = aws_iam_role.core_role[count.index].name
  policy_arn = module.s3_data_load_access_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "attach_database_data_load_policy_0" {
  count = local.config.databaseDataLoad.enabled ? length(local.core_roles) : 0

  role       = aws_iam_role.core_role[count.index].name
  policy_arn = module.database_data_load_access_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "attach_core_role_guardduty_iam_policy" {
  count = local.config.guardDuty.enabled ? length(local.core_roles) : 0

  role       = aws_iam_role.core_role[count.index].name
  policy_arn = aws_iam_policy.onehouse_core_role_guardduty_iam_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "attach_ec2_policy_0" {
  count = length(local.enabled_instances) > 0 ? length(local.core_roles) : 0

  role       = aws_iam_role.core_role[count.index].name
  policy_arn = aws_iam_policy.onehouse_core_role_ec2_policy[0].arn
}

# For EKS Cluster Role
resource "aws_iam_role" "eks_cluster_role" {
  name               = "onehouse-customer-eks-role-${local.truncated_request_id}"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.cluster_role_assume_policy.json
}

data "aws_iam_policy_document" "cluster_role_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# AmazonEKSClusterPolicy
resource "aws_iam_role_policy_attachment" "attach_eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# AmazonEKSVPCResourceController
resource "aws_iam_role_policy_attachment" "attach_eks_vpc_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# AmazonEKSServicePolicy
resource "aws_iam_role_policy_attachment" "attach_eks_service_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# For EKS Node Role
resource "aws_iam_role" "eks_node_role" {
  name               = "onehouse-customer-eks-node-role-${local.truncated_request_id}"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.node_role_assume_policy.json
}

data "aws_iam_policy_document" "node_role_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy_1" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = module.s3_node_role_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy_2" {
  count      = local.config.ascp.enabled ? 1 : 0
  role       = aws_iam_role.csi_driver_role.name
  policy_arn = module.s3_node_role_access_policy.csi_policy_arn
}

# AmazonEKSWorkerNodePolicy
resource "aws_iam_role_policy_attachment" "attach_eks_worker_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# AmazonEC2ContainerRegistryReadOnly
resource "aws_iam_role_policy_attachment" "attach_ecr_readonly_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# AmazonEKS_CNI_Policy
resource "aws_iam_role_policy_attachment" "attach_eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "attach_glue_schema_registry_policy" {
  count      = local.config.glueSync.enabled ? 1 : 0
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSGlueSchemaRegistryFullAccess"
}

resource "aws_iam_role_policy_attachment" "attach_eks_node_policy_0" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = aws_iam_policy.eks_node_access_policy.arn
}


resource "aws_iam_role_policy_attachment" "attach_s3_data_load_policy_1" {
  count      = local.isS3DataLoadEnabled ? 1 : 0
  role       = aws_iam_role.eks_node_role.name
  policy_arn = module.s3_data_load_access_policy[0].arn
}

# For GlueSync, MSK DataLoad and Secrets Manager Policy
resource "aws_iam_role_policy_attachment" "attach_aggregate_node_policy" {
  count = local.add_aggregate_policies ? 1 : 0

  role       = aws_iam_role.eks_node_role.name
  policy_arn = module.aggregate_node_role_policies[0].arn
}

# permission Set for all roles
resource "aws_iam_policy" "onehouse_core_role_access_policy" {
  name = "onehouse-core-role-access-policy-${local.truncated_request_id}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeSpotInstanceRequests"
          , "ec2:DescribeAddresses"
          , "ec2:DescribeInstances"
          , "ec2:DescribeSecurityGroups"
          , "ec2:DescribeInstanceStatus"
          , "ec2:DescribeTags"
          , "ec2:DescribeImages"
          , "ec2:DescribeImageAttribute"
          , "ec2:DescribeSpotPriceHistory"
          , "ec2:DescribeRouteTables"
          , "ec2:DescribeSubnets"
          , "ec2:DescribeNatGateways"
          , "ec2:DescribeVpcs"
          , "eks:CreateCluster"
          , "eks:TagResource"
          , "eks:DescribeNodegroup"
          , "eks:DescribeCluster"
          , "autoscaling:*"
          , "application-autoscaling:*"
          , "sts:DecodeAuthorizationMessage"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        "Action" : [
          "eks:*"
        ],
        "Effect" : "Allow",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/CostCenter" : "OneHouse"
          }
        }
      },
      {
        Sid    = "CreatePersistenVolumeSnapshot",
        Effect = "Allow",
        Action = [
          "ec2:CreateSnapshot",
          "ec2:DescribeSnapshots",
          "ec2:CreateVolume",
          "ec2:DescribeVolumes"
        ],
        Resource = "*"
      },
      {
        "Sid" : "PermissionsToCreateLaunchTemplates",
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateLaunchTemplate"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringLike" : {
            "aws:RequestTag/eks:cluster-name" : "onehouse-customer-cluster-*"
          }
        }
      },
      {
        "Sid" : "LaunchTemplateAndInstancesRelatedPermissions",
        "Effect" : "Allow",
        "Action" : [
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringLike" : {
            "ec2:ResourceTag/eks:cluster-name" : "onehouse-customer-cluster-*"
          }
        }
      },
      {
        "Sid" : "PermissionsToManageEKSAndKubernetesTagsAndResourcesForNodegroups",
        "Effect" : "Allow",
        "Action" : [
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "onehouse_core_role_ascp_policy" {
  count = local.config.ascp.enabled ? 1 : 0
  name  = "onehouse-core-role-ascp-policy-${local.truncated_request_id}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:ListSecretVersionIds",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:DeleteSecret",
          "secretsmanager:TagResource"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/accessibleTo" : "onehouse",
            "aws:ResourceTag/createdBy" : "onehouse-control-plane"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "onehouse_core_role_ec2_policy" {
  count = length(local.enabled_instances) > 0 ? 1 : 0
  name  = "onehouse-core-role-ec2-policy-${local.truncated_request_id}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:TerminateSession",
          "ssm:StartSession",
          "ssm:ResumeSession"
        ]
        Effect = "Allow"
        Resource = concat(
          [module.add_ec2_hosts[0].session_document_arn],
          values(module.add_ec2_hosts[0].instance_arns)
        )
        Condition = {
          BoolIfExists = {
            "ssm:SessionDocumentAccessCheck" : "true"
          }
        }
      },
      {
        Action = [
          "ec2:RebootInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:TerminateInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/CostCenter" : "onehouse"
          }
        }
      },
      {
        Action = [
          "ssm:UpdateDocument",
          "ssm:CreateDocument",
          "ssm:DescribeDocument"
        ]
        Effect   = "Allow"
        Resource = module.add_ec2_hosts[0].session_document_arn
      }
    ]
  })
}

resource "aws_iam_policy" "onehouse_core_role_guardduty_iam_policy" {
  count = local.config.guardDuty.enabled ? 1 : 0

  name = "onehouse-core-role-guardduty-iam-policy-${local.truncated_request_id}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:CreateVpcEndpoint",
          "eks:DeleteAddon",
          "eks:CreateAddon",
          "eks:DescribeAddon",
          "eks:UpdateAddon",
          "eks:DescribeAddonVersions",
          "eks:DescribeAddonConfiguration",
          "eks:ListAddons",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribePrefixLists",
          "ec2:DescribeNetworkInterfaces"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "ec2:RevokeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress"
        ],
        Effect   = "Allow",
        Resource = "*",
        Condition = {
          "StringEquals" : {
            "aws:ResourceTag/accessibleTo" : "onehouse"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "onehouse_core_role_iam_policy" {
  name = "onehouse-core-role-iam-policy-${local.truncated_request_id}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Resource = "arn:aws:iam::*:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup"
        Action = [
          "iam:GetRole" // Needed by EKS to create cluster
        ]
      },
      {
        Effect   = "Allow"
        Resource = local.onehouse_roles
        Action = [
          "iam:GetRole" // Needed by EKS to create cluster
          , "iam:ListRolePolicies"
          , "iam:ListAttachedRolePolicies"
          , "iam:ListInstanceProfilesForRole"
          , "iam:CreateServiceLinkedRole"
          , "iam:AttachRolePolicy"
          , "iam:DeleteRole"
          , "iam:DetachRolePolicy"
        ]
      },
      {
        Effect   = "Allow"
        Resource = aws_iam_role.csi_driver_role.arn
        Action = [
          "iam:UpdateAssumeRolePolicy"
        ]
      },
      {
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "iam:CreateOpenIDConnectProvider"
          , "iam:TagOpenIDConnectProvider"
        ]
      },
      {
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "iam:GetOpenIDConnectProvider"
          , "iam:DeleteOpenIDConnectProvider"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/accessibleTo" : "onehouse"
          }
        }
      },
      {
        Effect   = "Allow"
        Resource = local.onehouse_roles
        Action = [
          "iam:PassRole" // Needed by EKS to create cluster
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" : "eks.amazonaws.com"
          },
          StringLike = {
            "iam:AssociatedResourceARN" : "arn:aws:eks:*:*:*/onehouse-customer-cluster-*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "eks_node_access_policy" {
  name = "eks-node-access-policy-${local.truncated_request_id}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        // Needed by EKS cluster-autoscaler to get the tags added to ec2 instances in the cluster.
        "Sid" : "DescribeAutoScalingGroups",
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeAutoScalingGroups",
          "ec2:DescribeLaunchTemplateVersions",
          "autoscaling:DescribeTags",
          "autoscaling:DescribeLaunchConfigurations"
        ],
        "Resource" : "*"
      },
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
        "Action" : [
          "kafka:DescribeCluster",
          "kafka:DescribeClusterV2",
          "kafka:DescribeClusterOperation",
          "kafka:ListClusters",
          "kafka:GetCompatibleKafkaVersions",
          "eks:DescribeNodegroup"
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
        "Resource" : "arn:aws:kafka:*:*:configuration/onehouse-database-cdc-${local.truncated_request_id}/*"
      },
      {
        "Sid" : "SetCapacityForAutoScalingGroups",
        "Effect" : "Allow",
        "Action" : [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/onehouse-customer-cluster-${local.truncated_request_id}" : "owned"
          }
        }
      },
      {
        "Sid" : "CloudwatchContainerMetrics",
        "Effect" : "Allow",
        "Action" : [
          "cloudwatch:GetMetricData"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "CloudwatchPutMetrics",
        "Effect" : "Allow",
        "Action" : [
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ],
        "Resource" : "arn:aws:logs:*:*:log-group:/aws/containerinsights/onehouse-customer-cluster-${local.truncated_request_id}/performance:*:*"
      },
      {
        "Sid" : "PersistentVolume",
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateVolume",
          "ec2:CreateTags",
          "ec2:AttachVolume"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_kms_key" "msk_key" {
  count       = local.config.mskDataLoad.enabled ? 1 : 0
  description = "Key for encrypting sasl secret, used by secrets manager"
  tags = {
    CostCenter = "OneHouse"
  }
}

resource "aws_secretsmanager_secret" "msk_secret" {
  count       = local.config.mskDataLoad.enabled ? 1 : 0
  description = "SASL username and password for onehouse-database-cdc MSK cluster"
  name        = "AmazonMSK_onehouse_database_cdc_${local.truncated_request_id}"
  kms_key_id  = aws_kms_key.msk_key[0].arn
  tags = {
    CostCenter = "OneHouse"
  }
}

resource "random_uuid" "msk_password" {
  count = local.config.mskDataLoad.enabled ? 1 : 0
}

resource "aws_secretsmanager_secret_version" "msk_secret_version" {
  count     = local.config.mskDataLoad.enabled ? 1 : 0
  secret_id = aws_secretsmanager_secret.msk_secret[0].id
  secret_string = jsonencode({
    username = "onehouse_msk_user"
    password = random_uuid.msk_password[0].result
  })
}

output "core_role_arn" {
  value = aws_iam_role.core_role[0].arn
}

# Upload the yaml config file
resource "aws_s3_object" "latest_config_yaml" {
  bucket = "onehouse-customer-bucket-${local.truncated_request_id}"
  key    = "onboarding/terraform/preboarding/config.yaml"
  source = local.final_config_path
  etag   = filemd5(local.final_config_path)

  depends_on = [
    aws_iam_policy.eks_node_access_policy,
    aws_iam_policy.onehouse_core_role_access_policy,
    aws_iam_policy.onehouse_core_role_iam_policy,
    aws_iam_policy.csi_driver_secret_access,
    aws_iam_policy.onehouse_core_role_ascp_policy,
    aws_iam_policy.onehouse_core_role_guardduty_iam_policy,
    aws_iam_policy.onehouse_core_role_ec2_policy,
    module.s3_core_role_access_policy,
    module.s3_node_role_access_policy,
    module.s3_data_load_access_policy,
    module.aggregate_node_role_policies,
    module.aggregate_node_role_policies,
    module.database_data_load_access_policy,
    module.s3_data_load_access_policy,
    module.add_ec2_hosts,
    aws_iam_role.core_role,
    aws_iam_role.csi_driver_role,
    aws_iam_role.eks_cluster_role,
    aws_iam_role.eks_node_role,
    aws_iam_role_policy_attachment.attach_common_policy_0,
    aws_iam_role_policy_attachment.attach_common_policy_1,
    aws_iam_role_policy_attachment.attach_csi_driver_policy,
    aws_iam_role_policy_attachment.attach_ecr_readonly_policy,
    aws_iam_role_policy_attachment.attach_eks_cluster_policy,
    aws_iam_role_policy_attachment.attach_eks_cni_policy,
    aws_iam_role_policy_attachment.attach_eks_node_policy_0,
    aws_iam_role_policy_attachment.attach_eks_service_policy,
    aws_iam_role_policy_attachment.attach_eks_vpc_policy,
    aws_iam_role_policy_attachment.attach_eks_worker_policy,
    aws_iam_role_policy_attachment.attach_s3_policy_0,
    aws_iam_role_policy_attachment.attach_s3_policy_1,
    aws_iam_role_policy_attachment.attach_s3_policy_2,
    aws_iam_role_policy_attachment.attach_aggregate_node_policy,
    aws_iam_role_policy_attachment.attach_ascp_policy,
    aws_iam_role_policy_attachment.attach_core_role_guardduty_iam_policy,
    aws_iam_role_policy_attachment.attach_database_data_load_policy_0,
    aws_iam_role_policy_attachment.attach_glue_schema_registry_policy,
    aws_iam_role_policy_attachment.attach_s3_data_load_policy_0,
    aws_iam_role_policy_attachment.attach_s3_data_load_policy_1,
    aws_iam_role_policy_attachment.csi_driver_secret_access,
    aws_kms_key.msk_key,
    aws_secretsmanager_secret.msk_secret,
    aws_secretsmanager_secret_version.msk_secret_version,
    random_uuid.msk_password
  ]
}
