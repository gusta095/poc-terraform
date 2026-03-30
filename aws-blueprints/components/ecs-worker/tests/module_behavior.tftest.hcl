# ==============================================================================
# TESTES: Comportamento do módulo com diferentes configurações
#
# Estes testes exercitam o componente real com mock_provider, verificando que
# combinações de flags e configurações planejam sem erros.
#
# Como rodar:
#   cd components/containers/ecs/service-worker
#   terraform test -filter=tests/module_behavior.tftest.hcl
# ==============================================================================

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

# Variáveis base válidas para todos os runs.
variables {
  environment      = "sandbox"
  vpc_primary_name = "vpc-sandbox"
  cluster_name     = "cluster-sandbox"
  worker_name      = "worker-test"
  image            = "nginx:latest"
}

# ==============================================================================
# Configuração padrão
# ==============================================================================

run "configuracao_padrao_planeia_sem_erros" {
  command = plan
}

# ==============================================================================
# create_service = false
# ==============================================================================

run "create_service_false_planeia_sem_erros" {
  command = plan

  variables {
    create_service = false
  }
}

# ==============================================================================
# Sidecars
# ==============================================================================

run "sidecar_simples_planeia_sem_erros" {
  command = plan

  variables {
    sidecars = {
      datadog = {
        image = "datadog/agent:latest"
      }
    }
  }
}

run "sidecar_com_health_check_planeia_sem_erros" {
  command = plan

  variables {
    sidecars = {
      otel = {
        image     = "otel/opentelemetry-collector:latest"
        essential = true
        cpu       = 128
        memory    = 256
        health_check = {
          command = ["CMD-SHELL", "wget -q -O- http://localhost:13133/health/status || exit 1"]
        }
      }
    }
  }
}

run "multiplos_sidecars_planejam_sem_erros" {
  command = plan

  variables {
    sidecars = {
      datadog = {
        image = "datadog/agent:latest"
      }
      fluentbit = {
        image = "fluent/fluent-bit:latest"
        cpu   = 64
      }
    }
  }
}

# ==============================================================================
# Circuit breaker
# ==============================================================================

run "circuit_breaker_desabilitado_planeia_sem_erros" {
  command = plan

  variables {
    deployment_circuit_breaker = {
      enable   = false
      rollback = false
    }
  }
}

run "circuit_breaker_sem_rollback_planeia_sem_erros" {
  command = plan

  variables {
    deployment_circuit_breaker = {
      enable   = true
      rollback = false
    }
  }
}

# ==============================================================================
# CPU e Memória (combinações válidas Fargate)
# ==============================================================================

run "cpu_512_memory_1024_planeia_sem_erros" {
  command = plan

  variables {
    cpu    = 512
    memory = 1024
  }
}

run "cpu_1024_memory_4096_planeia_sem_erros" {
  command = plan

  variables {
    cpu    = 1024
    memory = 4096
  }
}

run "cpu_2048_memory_8192_planeia_sem_erros" {
  command = plan

  variables {
    cpu    = 2048
    memory = 8192
  }
}

run "cpu_4096_memory_16384_planeia_sem_erros" {
  command = plan

  variables {
    cpu    = 4096
    memory = 16384
  }
}

# ==============================================================================
# Autoscaling
# ==============================================================================

run "apenas_cpu_scaling_planeia_sem_erros" {
  command = plan

  variables {
    autoscale_strategy = ["cpu"]
  }
}

run "apenas_memory_scaling_planeia_sem_erros" {
  command = plan

  variables {
    autoscale_strategy = ["memory"]
  }
}

run "sqs_messages_scaling_com_arn_planeia_sem_erros" {
  command = plan

  variables {
    autoscale_strategy = ["cpu", "memory", "sqs_messages_scaling"]
    sqs_access_arns    = ["arn:aws:sqs:us-east-1:123456789012:minha-fila"]
  }
}

run "sqs_messages_scaling_com_nome_especifico_planeia_sem_erros" {
  command = plan

  variables {
    autoscale_strategy = ["sqs_messages_scaling"]
    sqs_specific_name  = "minha-fila-especifica"
  }
}

# ==============================================================================
# Acesso a serviços (task role)
# ==============================================================================

run "sqs_access_planeia_sem_erros" {
  command = plan

  variables {
    sqs_access_arns = ["arn:aws:sqs:us-east-1:123456789012:fila-entrada"]
  }
}

run "sns_access_planeia_sem_erros" {
  command = plan

  variables {
    sns_access = ["arn:aws:sns:us-east-1:123456789012:topico-eventos"]
  }
}

run "dynamodb_access_planeia_sem_erros" {
  command = plan

  variables {
    dynamodb_access = ["arn:aws:dynamodb:us-east-1:123456789012:table/pedidos"]
  }
}

run "lambda_access_planeia_sem_erros" {
  command = plan

  variables {
    lambda_access = ["arn:aws:lambda:us-east-1:123456789012:function:processa-pedido"]
  }
}

run "s3_access_planeia_sem_erros" {
  command = plan

  variables {
    s3_access_names = ["bucket-artifacts"]
  }
}

run "todos_servicos_juntos_planejam_sem_erros" {
  command = plan

  variables {
    sqs_access_arns = ["arn:aws:sqs:us-east-1:123456789012:fila-entrada"]
    sns_access      = ["arn:aws:sns:us-east-1:123456789012:topico-eventos"]
    dynamodb_access = ["arn:aws:dynamodb:us-east-1:123456789012:table/pedidos"]
    lambda_access   = ["arn:aws:lambda:us-east-1:123456789012:function:processa-pedido"]
    s3_access_names = ["bucket-artifacts"]
  }
}

# ==============================================================================
# Secrets
# ==============================================================================

run "secret_ssm_planeia_sem_erros" {
  command = plan

  variables {
    secrets = {
      DB_PASSWORD = "arn:aws:ssm:us-east-1:123456789012:parameter/prod/db/password"
    }
  }
}

run "secret_secrets_manager_planeia_sem_erros" {
  command = plan

  variables {
    secrets = {
      API_KEY = "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/api-key"
    }
  }
}

run "secrets_ssm_e_secrets_manager_juntos_planejam_sem_erros" {
  command = plan

  variables {
    secrets = {
      DB_PASSWORD = "arn:aws:ssm:us-east-1:123456789012:parameter/prod/db/password"
      API_KEY     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/api-key"
    }
  }
}

# ==============================================================================
# Log retention
# ==============================================================================

run "log_retention_30_dias_planeia_sem_erros" {
  command = plan

  variables {
    log_retention_days = 30
  }
}

run "log_retention_365_dias_planeia_sem_erros" {
  command = plan

  variables {
    log_retention_days = 365
  }
}

# ==============================================================================
# Configuração completa
# ==============================================================================

run "configuracao_completa_planeia_sem_erros" {
  command = plan

  variables {
    cpu    = 1024
    memory = 4096

    autoscale_strategy = ["cpu", "memory", "sqs_messages_scaling"]
    autoscaling_min    = 2
    autoscaling_max    = 10

    sqs_access_arns = ["arn:aws:sqs:us-east-1:123456789012:fila-entrada"]
    sns_access      = ["arn:aws:sns:us-east-1:123456789012:topico-saida"]
    dynamodb_access = ["arn:aws:dynamodb:us-east-1:123456789012:table/pedidos"]
    lambda_access   = ["arn:aws:lambda:us-east-1:123456789012:function:enricher"]
    s3_access_names = ["bucket-artifacts", "bucket-reports"]

    secrets = {
      DB_PASSWORD = "arn:aws:ssm:us-east-1:123456789012:parameter/prod/db/password"
      API_KEY     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/api-key"
    }

    environments = {
      APP_ENV   = "production"
      LOG_LEVEL = "info"
    }

    log_retention_days = 30

    deployment_circuit_breaker = {
      enable   = true
      rollback = true
    }

    sidecars = {
      datadog = {
        image = "datadog/agent:latest"
        cpu   = 128
      }
    }
  }
}
