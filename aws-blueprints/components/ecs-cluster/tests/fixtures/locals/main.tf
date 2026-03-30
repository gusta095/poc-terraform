# ------------------------------------------------------------------------------
# FIXTURE: Lógica dos locals do componente ECS cluster
#
# Replica container_insights_value, cloudwatch_log_group_name e setting
# para que os testes possam verificar a lógica pura sem provider AWS.
#
# ATENÇÃO: Quando locals.tf for atualizado, este arquivo deve ser
# atualizado também para manter os testes em sincronia.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Variáveis — espelham as variáveis relevantes do componente
# ------------------------------------------------------------------------------

variable "cluster_name" {
  type    = string
  default = "meu-cluster"
}

variable "enhanced_observability" {
  type    = bool
  default = false
}

# ------------------------------------------------------------------------------
# Réplica exata de locals.tf (apenas lógica pura, sem module.tags)
# ------------------------------------------------------------------------------

locals {
  cloudwatch_log_group_name = "/aws/ecs-cluster/${var.cluster_name}"

  container_insights_value = var.enhanced_observability ? "enhanced" : "enabled"

  setting = [
    {
      name  = "containerInsights"
      value = local.container_insights_value
    }
  ]
}

# ------------------------------------------------------------------------------
# Outputs usados pelas asserções dos testes
# ------------------------------------------------------------------------------

output "container_insights_value" {
  value = local.container_insights_value
}

output "cloudwatch_log_group_name" {
  value = local.cloudwatch_log_group_name
}

output "setting_name" {
  value = local.setting[0].name
}

output "setting_value" {
  value = local.setting[0].value
}
