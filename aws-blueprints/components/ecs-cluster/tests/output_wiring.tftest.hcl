# ==============================================================================
# TESTES: Wiring de outputs do componente
#
# Estes testes aplicam o módulo com mock_provider e verificam via assert que
# os outputs chegam com os valores corretos — não apenas que o plan não falha.
#
# Diferença dos testes de comportamento (module_behavior):
#   module_behavior → plan sem erros (smoke test)
#   output_wiring   → apply + assert (verifica o valor dos outputs)
#
# Como rodar:
#   cd components/containers/ecs/cluster
#   terraform test -filter=tests/output_wiring.tftest.hcl
# ==============================================================================

mock_provider "aws" {}

variables {
  environment  = "sandbox"
  cluster_name = "meu-cluster"
}

# ==============================================================================
# cloudwatch_log_group_name — wiring local → módulo upstream → output
# ==============================================================================

run "cloudwatch_log_group_name_chega_com_path_correto" {
  command = apply

  assert {
    condition     = output.cloudwatch_log_group_name == "/aws/ecs-cluster/meu-cluster"
    error_message = "Esperado '/aws/ecs-cluster/meu-cluster', obtido: ${output.cloudwatch_log_group_name}"
  }
}

run "cloudwatch_log_group_name_reflete_cluster_name_customizado" {
  command = apply

  variables {
    cluster_name = "producao-pagamentos"
  }

  assert {
    condition     = output.cloudwatch_log_group_name == "/aws/ecs-cluster/producao-pagamentos"
    error_message = "Esperado '/aws/ecs-cluster/producao-pagamentos', obtido: ${output.cloudwatch_log_group_name}"
  }
}

# ==============================================================================
# container_insights_mode — wiring local → output
# ==============================================================================

run "container_insights_mode_padrao_e_enabled" {
  command = apply

  variables {
    enhanced_observability = false
  }

  assert {
    condition     = output.container_insights_mode == "enabled"
    error_message = "Esperado 'enabled' com enhanced_observability = false, obtido: ${output.container_insights_mode}"
  }
}

run "container_insights_mode_enhanced_quando_ativo" {
  command = apply

  variables {
    enhanced_observability = true
  }

  assert {
    condition     = output.container_insights_mode == "enhanced"
    error_message = "Esperado 'enhanced' com enhanced_observability = true, obtido: ${output.container_insights_mode}"
  }
}
