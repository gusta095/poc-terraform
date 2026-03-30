# ==============================================================================
# TESTES: Regras de validação das variáveis do componente EKS
#
# Como rodar:
#   cd components/eks
#   terraform init -backend=false
#   terraform test -filter=tests/variable_validations.tftest.hcl
# ==============================================================================

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "AIDAXXXXXXXXXXXXXXXXX"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn   = "arn:aws:iam::123456789012:user/test"
      issuer_id    = "AIDAXXXXXXXXXXXXXXXXX"
      issuer_name  = "test"
      session_name = ""
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition          = "aws"
      dns_suffix         = "amazonaws.com"
      reverse_dns_prefix = "com.amazonaws"
    }
  }
}

# Variáveis base válidas usadas em todos os runs.
variables {
  environment = "sandbox"
  account_id  = "123456789012"
  name        = "eks-lab"
  vpc_id      = "vpc-12345678"
  subnet_ids  = ["subnet-12345678", "subnet-87654321"]
}

# ==============================================================================
# environment — não pode ser vazio
# ==============================================================================

run "environment_vazio_deve_falhar" {
  command = plan

  variables {
    environment = ""
  }

  expect_failures = [var.environment]
}

run "environment_valido_deve_passar" {
  command = plan

  variables {
    environment = "production"
  }
}

# ==============================================================================
# account_id — deve ter exatamente 12 dígitos
# ==============================================================================

run "account_id_com_letras_deve_falhar" {
  command = plan

  variables {
    account_id = "12345678901a"
  }

  expect_failures = [var.account_id]
}

run "account_id_com_menos_digitos_deve_falhar" {
  command = plan

  variables {
    account_id = "12345678"
  }

  expect_failures = [var.account_id]
}

run "account_id_valido_deve_passar" {
  command = plan

  variables {
    account_id = "999999999999"
  }
}

# ==============================================================================
# name — charset EKS: alfanumérico, hífens e underscores
# ==============================================================================

run "name_iniciando_com_hifen_deve_falhar" {
  command = plan

  variables {
    name = "-eks-lab"
  }

  expect_failures = [var.name]
}

run "name_com_caractere_especial_deve_falhar" {
  command = plan

  variables {
    name = "eks@lab"
  }

  expect_failures = [var.name]
}

run "name_valido_com_hifen_deve_passar" {
  command = plan

  variables {
    name = "eks-production"
  }
}

run "name_valido_com_underscore_deve_passar" {
  command = plan

  variables {
    name = "eks_lab"
  }
}

# ==============================================================================
# eks_version — formato major.minor
# ==============================================================================

run "eks_version_sem_ponto_deve_falhar" {
  command = plan

  variables {
    eks_version = "135"
  }

  expect_failures = [var.eks_version]
}

run "eks_version_com_patch_deve_falhar" {
  command = plan

  variables {
    eks_version = "1.35.0"
  }

  expect_failures = [var.eks_version]
}

run "eks_version_valida_deve_passar" {
  command = plan

  variables {
    eks_version = "1.35"
  }
}

run "eks_version_null_deve_passar" {
  command = plan

  variables {
    eks_version = null
  }
}

# ==============================================================================
# vpc_id — formato vpc-xxxxxxxx
# ==============================================================================

run "vpc_id_sem_prefixo_deve_falhar" {
  command = plan

  variables {
    vpc_id = "12345678"
  }

  expect_failures = [var.vpc_id]
}

run "vpc_id_com_maiusculas_deve_falhar" {
  command = plan

  variables {
    vpc_id = "vpc-1234ABCD"
  }

  expect_failures = [var.vpc_id]
}

run "vpc_id_valido_deve_passar" {
  command = plan

  variables {
    vpc_id = "vpc-0a1b2c3d"
  }
}

run "vpc_id_longo_valido_deve_passar" {
  command = plan

  variables {
    vpc_id = "vpc-0a1b2c3d4e5f67890"
  }
}

# ==============================================================================
# subnet_ids — mínimo 2 subnets + formato subnet-xxxxxxxx
# ==============================================================================

run "subnet_ids_com_apenas_uma_subnet_deve_falhar" {
  command = plan

  variables {
    subnet_ids = ["subnet-12345678"]
  }

  expect_failures = [var.subnet_ids]
}

run "subnet_ids_com_formato_invalido_deve_falhar" {
  command = plan

  variables {
    subnet_ids = ["sub-12345678", "sub-87654321"]
  }

  expect_failures = [var.subnet_ids]
}

run "subnet_ids_validos_deve_passar" {
  command = plan

  variables {
    subnet_ids = ["subnet-aabbccdd", "subnet-11223344", "subnet-99887766"]
  }
}

# ==============================================================================
# endpoint_public_access_cidrs — obrigatório quando endpoint_public_access = true
# ==============================================================================

run "public_access_sem_cidrs_deve_falhar" {
  command = plan

  variables {
    endpoint_public_access       = true
    endpoint_public_access_cidrs = []
  }

  expect_failures = [var.endpoint_public_access_cidrs]
}

run "public_access_com_cidrs_deve_passar" {
  command = plan

  variables {
    endpoint_public_access       = true
    endpoint_public_access_cidrs = ["189.50.0.0/16"]
  }
}

run "public_access_false_sem_cidrs_deve_passar" {
  command = plan

  variables {
    endpoint_public_access       = false
    endpoint_public_access_cidrs = []
  }
}

# ==============================================================================
# authentication_mode — API ou API_AND_CONFIG_MAP
# ==============================================================================

run "authentication_mode_invalido_deve_falhar" {
  command = plan

  variables {
    authentication_mode = "CONFIG_MAP"
  }

  expect_failures = [var.authentication_mode]
}

run "authentication_mode_api_deve_passar" {
  command = plan

  variables {
    authentication_mode = "API"
  }
}

run "authentication_mode_api_and_config_map_deve_passar" {
  command = plan

  variables {
    authentication_mode = "API_AND_CONFIG_MAP"
  }
}

# ==============================================================================
# managed_node_groups — capacity_type deve ser ON_DEMAND ou SPOT
# ==============================================================================

run "capacity_type_invalido_deve_falhar" {
  command = plan

  variables {
    managed_node_groups = {
      bootstrap = {
        capacity_type = "RESERVED"
      }
    }
  }

  expect_failures = [var.managed_node_groups]
}

run "capacity_type_on_demand_deve_passar" {
  command = plan

  variables {
    managed_node_groups = {
      bootstrap = {
        capacity_type      = "ON_DEMAND"
        kubernetes_version = "1.35"
      }
    }
  }
}

run "capacity_type_spot_deve_passar" {
  command = plan

  variables {
    managed_node_groups = {
      workers = {
        capacity_type      = "SPOT"
        kubernetes_version = "1.35"
      }
    }
  }
}

# ==============================================================================
# enabled_log_types — apenas valores aceitos pela AWS
# ==============================================================================

run "log_type_invalido_deve_falhar" {
  command = plan

  variables {
    enabled_log_types = ["api", "invalid-log"]
  }

  expect_failures = [var.enabled_log_types]
}

run "log_types_validos_deve_passar" {
  command = plan

  variables {
    enabled_log_types = ["api", "audit", "authenticator"]
  }
}

run "todos_log_types_validos_deve_passar" {
  command = plan

  variables {
    enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  }
}

# ==============================================================================
# log_retention_days — valores aceitos pelo CloudWatch
# ==============================================================================

run "log_retention_invalido_deve_falhar" {
  command = plan

  variables {
    log_retention_days = 45
  }

  expect_failures = [var.log_retention_days]
}

run "log_retention_valido_deve_passar" {
  command = plan

  variables {
    log_retention_days = 30
  }
}

run "log_retention_90_dias_deve_passar" {
  command = plan

  variables {
    log_retention_days = 90
  }
}
