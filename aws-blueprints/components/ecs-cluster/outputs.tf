#------------------------------------------------------------------------------
# ECS Cluster
#------------------------------------------------------------------------------

output "cluster_name" {
  description = "Nome que identifica o cluster ECS"
  value       = module.ecs_cluster.name
}

output "cluster_arn" {
  description = "ARN que identifica o cluster ECS"
  value       = module.ecs_cluster.arn
}

output "container_insights_mode" {
  description = "Modo de observabilidade ativo no cluster: 'enabled' (padrão) ou 'enhanced'"
  value       = local.container_insights_value
}

#------------------------------------------------------------------------------
# CloudWatch
#------------------------------------------------------------------------------

output "cloudwatch_log_group_name" {
  description = "Nome do log group do CloudWatch associado ao cluster"
  value       = module.ecs_cluster.cloudwatch_log_group_name
}

output "cloudwatch_log_group_arn" {
  description = "ARN do log group do CloudWatch associado ao cluster"
  value       = module.ecs_cluster.cloudwatch_log_group_arn
}
