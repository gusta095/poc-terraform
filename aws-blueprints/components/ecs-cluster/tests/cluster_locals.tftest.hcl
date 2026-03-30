# ==============================================================================
# TESTES: Lógica dos locals do componente ECS cluster
#
# Verifica container_insights_value, cloudwatch_log_group_name e setting
# via fixture de locals (sem provider AWS, sem credenciais).
#
# Como rodar:
#   cd components/containers/ecs/cluster
#   terraform test -filter=tests/cluster_locals.tftest.hcl
# ==============================================================================

# ==============================================================================
# container_insights_value
# ==============================================================================

run "enhanced_observability_false_retorna_enabled" {
  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    enhanced_observability = false
  }

  assert {
    condition     = output.container_insights_value == "enabled"
    error_message = "Esperado 'enabled' quando enhanced_observability = false, obtido: ${output.container_insights_value}"
  }
}

run "enhanced_observability_true_retorna_enhanced" {
  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    enhanced_observability = true
  }

  assert {
    condition     = output.container_insights_value == "enhanced"
    error_message = "Esperado 'enhanced' quando enhanced_observability = true, obtido: ${output.container_insights_value}"
  }
}

# ==============================================================================
# cloudwatch_log_group_name
# ==============================================================================

run "log_group_name_formatado_corretamente" {
  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    cluster_name = "meu-cluster"
  }

  assert {
    condition     = output.cloudwatch_log_group_name == "/aws/ecs-cluster/meu-cluster"
    error_message = "Esperado '/aws/ecs-cluster/meu-cluster', obtido: ${output.cloudwatch_log_group_name}"
  }
}

run "log_group_name_reflete_nome_do_cluster" {
  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    cluster_name = "producao-api"
  }

  assert {
    condition     = output.cloudwatch_log_group_name == "/aws/ecs-cluster/producao-api"
    error_message = "Esperado '/aws/ecs-cluster/producao-api', obtido: ${output.cloudwatch_log_group_name}"
  }
}

# ==============================================================================
# setting (bloco enviado ao módulo ECS)
# ==============================================================================

run "setting_name_e_sempre_containerInsights" {
  module {
    source = "./tests/fixtures/locals"
  }

  assert {
    condition     = output.setting_name == "containerInsights"
    error_message = "Esperado setting.name = 'containerInsights', obtido: ${output.setting_name}"
  }
}

run "setting_value_padrao_e_enabled" {
  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    enhanced_observability = false
  }

  assert {
    condition     = output.setting_value == "enabled"
    error_message = "Esperado setting.value = 'enabled', obtido: ${output.setting_value}"
  }
}

run "setting_value_enhanced_quando_ativo" {
  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    enhanced_observability = true
  }

  assert {
    condition     = output.setting_value == "enhanced"
    error_message = "Esperado setting.value = 'enhanced', obtido: ${output.setting_value}"
  }
}
