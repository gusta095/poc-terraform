# ==============================================================================
# TESTES: Nomenclatura das filas FIFO
#
# Regra de negócio testada (locals.tf):
#   queue_name     = fifo_queue ? "${name}.fifo"     : name
#   dlq_queue_name = fifo_queue ? "${name}-dlq.fifo" : name
#
# Além do nome visível, essa lógica impacta os ARNs interpolados dentro das
# policies de acesso — por isso o terceiro teste verifica o ARN gerado.
#
# Como rodar:
#   cd components/application-integration/sqs
#   terraform init
#   terraform test -filter=tests/fifo_naming.tftest.hcl
# ==============================================================================

# ------------------------------------------------------------------------------
# Cenário 1: Fila padrão (não-FIFO) não deve ter nenhum sufixo
# ------------------------------------------------------------------------------
run "fila_padrao_nao_tem_sufixo" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name       = "minha-fila"
    fifo_queue = false
  }

  assert {
    condition     = output.queue_name == "minha-fila"
    error_message = "Fila padrão não deve ter sufixo. Esperado: 'minha-fila', obtido: '${output.queue_name}'"
  }

  assert {
    condition     = output.dlq_queue_name == "minha-fila"
    error_message = "DLQ padrão não deve ter sufixo. Esperado: 'minha-fila', obtido: '${output.dlq_queue_name}'"
  }
}

# ------------------------------------------------------------------------------
# Cenário 2: Fila FIFO deve receber os sufixos corretos
# ------------------------------------------------------------------------------
run "fila_fifo_recebe_sufixos_corretos" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name       = "minha-fila"
    fifo_queue = true
  }

  assert {
    condition     = output.queue_name == "minha-fila.fifo"
    error_message = "Fila FIFO deve ter sufixo '.fifo'. Esperado: 'minha-fila.fifo', obtido: '${output.queue_name}'"
  }

  assert {
    condition     = output.dlq_queue_name == "minha-fila-dlq.fifo"
    error_message = "DLQ FIFO deve ter sufixo '-dlq.fifo'. Esperado: 'minha-fila-dlq.fifo', obtido: '${output.dlq_queue_name}'"
  }
}

# ------------------------------------------------------------------------------
# Cenário 3: O ARN interpolado na policy deve usar o nome com sufixo .fifo
#
# Por que isso importa? A policy da fila referencia o ARN do recurso. Se a fila
# for FIFO e o ARN na policy não tiver '.fifo', a policy fica inválida na AWS.
# ------------------------------------------------------------------------------
run "policy_de_fila_fifo_usa_arn_com_sufixo" {
  command = plan

  module {
    source = "./tests/fixtures/locals"
  }

  variables {
    name       = "pedidos"
    aws_region = "us-east-1"
    account_id = "111122223333"
    fifo_queue = true
  }

  assert {
    condition     = output.default_policy_resource_arn == "arn:aws:sqs:us-east-1:111122223333:pedidos.fifo"
    error_message = "ARN na policy FIFO deve usar o nome com sufixo '.fifo'. Obtido: '${output.default_policy_resource_arn}'"
  }
}
