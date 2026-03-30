# ------------------------------------------------------------------------------
# Tags
# ------------------------------------------------------------------------------

module "tags" {
  source = "git::https://github.com/gusta-lab/terraform-aws-module-tags.git?ref=v2.1.0"

  environment = var.environment
  tags        = var.tags
}

#------------------------------------------------------------------------------
# Cluster
#------------------------------------------------------------------------------

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.3.1"

  name = var.cluster_name

  cloudwatch_log_group_name              = local.cloudwatch_log_group_name
  cloudwatch_log_group_tags              = local.cloudwatch_log_group_tags
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days

  setting = local.setting

  cluster_capacity_providers         = var.cluster_capacity_providers
  default_capacity_provider_strategy = var.default_capacity_provider_strategy

  tags = module.tags.tags
}

#------------------------------------------------------------------------------
# Validações de precondição
#------------------------------------------------------------------------------

resource "terraform_data" "validate_capacity_provider_strategy" {
  lifecycle {
    precondition {
      condition = alltrue([
        for cp in keys(var.default_capacity_provider_strategy) :
        contains(var.cluster_capacity_providers, cp)
      ])
      error_message = "Todos os capacity providers em default_capacity_provider_strategy devem estar listados em cluster_capacity_providers."
    }
  }
}
