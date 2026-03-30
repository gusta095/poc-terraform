# ------------------------------------------------------------------------------
# TAGS
# ------------------------------------------------------------------------------

module "tags" {
  source = "git::https://github.com/gusta-lab/terraform-aws-module-tags.git?ref=v2.1.0"

  environment = var.environment
  tags        = var.tags
}

# ------------------------------------------------------------------------------
# EBS CSI Driver — Pod Identity
# ------------------------------------------------------------------------------

resource "aws_iam_role" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name = "${var.name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ------------------------------------------------------------------------------
# Node Monitoring — Pod Identity
# ------------------------------------------------------------------------------

resource "aws_iam_role" "node_monitoring" {
  count = var.enable_node_monitoring ? 1 : 0

  name = "${var.name}-node-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "node_monitoring" {
  count = var.enable_node_monitoring ? 1 : 0

  role       = aws_iam_role.node_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ------------------------------------------------------------------------------
# EKS
# ------------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.15.1"

  name               = var.name
  kubernetes_version = var.eks_version

  addons     = local.addons
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  authentication_mode                      = var.authentication_mode
  enable_cluster_creator_admin_permissions = var.creator_admin
  access_entries                           = local.all_access_entries

  eks_managed_node_groups = var.managed_node_groups

  enable_irsa = false

  create_kms_key    = var.create_kms_key
  encryption_config = var.create_kms_key ? {} : null

  enabled_log_types                      = var.enabled_log_types
  cloudwatch_log_group_retention_in_days = var.log_retention_days

  tags = module.tags.tags
}
