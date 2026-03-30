locals {
  # Prioriza cluster_arn injetado via dependency; fallback para data source pelo nome
  cluster_arn = var.cluster_arn != "" ? var.cluster_arn : data.aws_ecs_cluster.ecs_cluster[0].arn

  # Converte os maps expostos na interface (environment/secrets)
  # para o formato de lista de objetos exigido pelo ECS.
  # Mantém a API simples e encapsula o formato do provider.
  container_environment = [
    for k, v in var.environments : {
      name  = k
      value = v
    }
  ]

  container_secrets = [
    for k, v in var.secrets : {
      name      = k
      valueFrom = v
    }
  ]

  sidecar_definitions = {
    for name, sidecar in var.sidecars : name => {
      name      = name
      image     = sidecar.image
      essential = sidecar.essential

      cpu    = sidecar.cpu
      memory = sidecar.memory

      environment = [for k, v in sidecar.environments : { name = k, value = v }]
      secrets     = [for k, v in sidecar.secrets : { name = k, valueFrom = v }]

      enable_cloudwatch_logging              = true
      create_cloudwatch_log_group            = true
      cloudwatch_log_group_name              = "/ecs/${var.worker_name}/${name}"
      cloudwatch_log_group_retention_in_days = coalesce(sidecar.log_retention_days, var.log_retention_days)

      healthCheck = sidecar.health_check == null ? null : {
        command     = sidecar.health_check.command
        interval    = sidecar.health_check.interval
        timeout     = sidecar.health_check.timeout
        retries     = sidecar.health_check.retries
        startPeriod = sidecar.health_check.start_period
      }
    }
  }

  container_definitions = merge(
    {
      worker = {
        name  = var.worker_name
        image = var.image

        essential = true

        environment = local.container_environment
        secrets     = local.container_secrets

        enable_cloudwatch_logging              = true
        create_cloudwatch_log_group            = true
        cloudwatch_log_group_name              = "/ecs/${var.worker_name}"
        cloudwatch_log_group_retention_in_days = var.log_retention_days

        healthCheck = {
          command     = ["CMD-SHELL", "kill -0 1"]
          interval    = 20
          timeout     = 5
          retries     = 2
          startPeriod = 15
        }
      }
    },
    local.sidecar_definitions
  )

  # mapa de CPU/Memória permitido pelo Fargate, usado nas validações
  # de `var.cpu`/`var.memory`. memória mínima = 2×vCPU; demais valores seguem os
  # limites de valores da AWS.
  valid_memory_ranges = {
    256  = [512, 1024, 2048]
    512  = [1024, 2048, 3072, 4096]
    1024 = range(2048, 8193, 1024)
    2048 = range(4096, 16385, 1024)
    4096 = range(8192, 30721, 1024)
  }
}
