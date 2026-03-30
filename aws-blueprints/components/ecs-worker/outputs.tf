# ------------------------------------------------------------------------------
# ECS Service Outputs
# ------------------------------------------------------------------------------

output "worker_service_name" {
  description = "Nome do serviço ECS worker"
  value       = try(module.ecs_service_worker.name, null)
}

output "worker_service_id" {
  description = "ID do serviço ECS worker"
  value       = try(module.ecs_service_worker.service_id, null)
}

output "worker_cluster_name" {
  description = "Nome do cluster ECS"
  value       = var.cluster_name
}

# ------------------------------------------------------------------------------
# Task Definition Outputs
# ------------------------------------------------------------------------------

output "worker_task_definition_arn" {
  description = "ARN completo da definição de tarefa (inclui family e revision)"
  value       = module.ecs_service_worker.task_definition_arn
}

# ------------------------------------------------------------------------------
# IAM Role Outputs
# ------------------------------------------------------------------------------

output "worker_task_exec_role_arn" {
  description = "ARN da task execution role — usada pelo agente do ECS para puxar imagens e enviar logs. Distinta da task role, que controla permissões da aplicação."
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "worker_task_role_arn" {
  description = "ARN da task role — assume as permissões da aplicação em runtime (acesso a SQS, S3, DynamoDB etc.). Distinta da execution role, usada pelo agente do ECS."
  value       = try(aws_iam_role.ecs_task_role[0].arn, null)
}

# ------------------------------------------------------------------------------
# Security Group Outputs
# ------------------------------------------------------------------------------

output "worker_security_group_id" {
  description = "ID do security group do serviço worker"
  value       = module.ecs_worker_sg.security_group_id
}

output "worker_security_group_arn" {
  description = "ARN do security group do serviço worker"
  value       = module.ecs_worker_sg.security_group_arn
}

# ------------------------------------------------------------------------------
# CloudWatch Logs Outputs
# ------------------------------------------------------------------------------

output "worker_cloudwatch_log_group_name" {
  description = "Nome do log group no CloudWatch"
  value       = try(module.ecs_service_worker.cloudwatch_log_group_name, "/ecs/${var.worker_name}")
}

output "worker_cloudwatch_log_group_arn" {
  description = "ARN do log group no CloudWatch"
  value       = try(module.ecs_service_worker.cloudwatch_log_group_arn, null)
}

# ------------------------------------------------------------------------------
# Autoscaling Outputs
# ------------------------------------------------------------------------------

output "worker_autoscaling_target_arn" {
  description = "ARN do autoscaling target"
  value       = try(module.ecs_service_worker.autoscaling_target_arn, null)
}

output "worker_autoscaling_min_capacity" {
  description = "Menor número de tarefas que o autoscaling manterá em execução."
  value       = var.autoscaling_min
}

output "worker_autoscaling_max_capacity" {
  description = "Maior número de tarefas que o autoscaling pode provisionar."
  value       = var.autoscaling_max
}
