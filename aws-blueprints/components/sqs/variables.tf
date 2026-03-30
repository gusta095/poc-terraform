# ------------------------------------------------------------------------------
# GLOBAL
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Nome do ambiente (ex: prod, staging). Propagado para tags e identificadores de recursos."
  type        = string
}

variable "account_id" {
  description = "ID da conta AWS onde a fila será provisionada. Usado na construção de ARNs nas policies de acesso."
  type        = string
}

variable "aws_region" {
  description = "Região AWS onde a fila será provisionada. Usado na construção de ARNs nas policies de acesso."
  type        = string
}

variable "tags" {
  description = "Mapeamento de chave-valor para tags dos recursos."
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# SQS
# ------------------------------------------------------------------------------

variable "name" {
  description = "Nome da fila SQS. Em filas FIFO, o sufixo `.fifo` é adicionado automaticamente."
  type        = string
}

variable "fifo_queue" {
  description = "Cria a fila no modo FIFO (First In, First Out), que garante ordenação e suporte a deduplicação. O tópico SNS de origem também deve ser FIFO."
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Habilita deduplicação automática pelo hash SHA-256 do corpo da mensagem, eliminando a necessidade de gerar um `MessageDeduplicationId` no produtor. Aplicável apenas a filas FIFO."
  type        = bool
  default     = false
}

variable "fifo_throughput_limit" {
  description = "Escopo do limite de throughput para filas FIFO. Aceita `perQueue` ou `perMessageGroupId`. Se não informado, a AWS aplica `perQueue`. Aplicável apenas com `fifo_queue = true`."
  type        = string
  default     = null

  validation {
    condition     = var.fifo_throughput_limit == null || contains(["perQueue", "perMessageGroupId"], var.fifo_throughput_limit)
    error_message = "fifo_throughput_limit deve ser 'perQueue' ou 'perMessageGroupId'."
  }
}

variable "visibility_timeout_seconds" {
  description = "Janela de tempo em segundos durante a qual uma mensagem consumida fica invisível para outros consumidores. Deve ser maior que o tempo de processamento do worker."
  type        = number
  default     = 30

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "O valor de visibility_timeout_seconds deve estar entre 0 e 43200 segundos."
  }
}

variable "message_retention_seconds" {
  description = "Tempo em segundos que o SQS retém uma mensagem não consumida. Mensagens que excedem esse prazo são descartadas automaticamente. Default: 4 dias."
  type        = number
  default     = 345600

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "O valor de message_retention_seconds deve estar entre 60 e 1209600 segundos (14 dias)."
  }
}

variable "max_message_size" {
  description = "Tamanho máximo em bytes de uma mensagem antes de ser rejeitada pelo SQS. Default: 256 KB (máximo permitido)."
  type        = number
  default     = 262144

  validation {
    condition     = var.max_message_size >= 1024 && var.max_message_size <= 262144
    error_message = "O valor de max_message_size deve estar entre 1024 e 262144 bytes."
  }
}

variable "delay_seconds" {
  description = "Atraso em segundos antes que mensagens novas fiquem disponíveis para consumo. Use para desacoplar produtores de consumidores com ritmos diferentes."
  type        = number
  default     = 0

  validation {
    condition     = var.delay_seconds >= 0 && var.delay_seconds <= 900
    error_message = "O valor de delay_seconds deve estar entre 0 e 900 segundos (15 minutos)."
  }
}

variable "receive_wait_time_seconds" {
  description = "Tempo máximo em segundos que uma chamada ReceiveMessage aguarda por mensagem. Valores > 0 habilitam long polling, reduzindo chamadas vazias e custo."
  type        = number
  default     = 0

  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "O valor de receive_wait_time_seconds deve estar entre 0 e 20 segundos."
  }
}

variable "sqs_managed_sse_enabled" {
  description = "Habilita criptografia SSE com chaves gerenciadas pelo SQS. Ignorado automaticamente quando `kms_master_key_id` está definido — os dois mecanismos são mutuamente exclusivos."
  type        = bool
  default     = true
}

variable "kms_master_key_id" {
  description = "ID ou ARN de uma chave KMS gerenciada pelo cliente para criptografia da fila. Quando definido, `sqs_managed_sse_enabled` é ignorado automaticamente."
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# SQS DLQ
# ------------------------------------------------------------------------------

variable "create_dlq" {
  description = "Cria uma Dead Letter Queue vinculada à fila principal. Mensagens que excedem `max_receive_count` são movidas automaticamente para a DLQ."
  type        = bool
  default     = false
}

variable "max_receive_count" {
  description = "Número de vezes que uma mensagem pode ser recebida antes de ser movida para a DLQ. Requer `create_dlq = true`."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "O valor de max_receive_count deve estar entre 1 e 1000."
  }
}

variable "dlq_visibility_timeout_seconds" {
  description = "Janela de tempo em segundos durante a qual uma mensagem na DLQ fica invisível após ser lida. Deve ser maior que o tempo de inspeção."
  type        = number
  default     = 30

  validation {
    condition     = var.dlq_visibility_timeout_seconds >= 0 && var.dlq_visibility_timeout_seconds <= 43200
    error_message = "O valor de dlq_visibility_timeout_seconds deve estar entre 0 e 43200 segundos (12 horas)."
  }
}

variable "dlq_message_retention_seconds" {
  description = "Tempo em segundos que o SQS retém uma mensagem na DLQ antes de descartá-la. Default: 4 dias."
  type        = number
  default     = 345600

  validation {
    condition     = var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600
    error_message = "O valor de dlq_message_retention_seconds deve estar entre 60 e 1209600 segundos (14 dias)."
  }
}

variable "dlq_delay_seconds" {
  description = "Atraso em segundos antes que mensagens na DLQ fiquem disponíveis para leitura."
  type        = number
  default     = 0

  validation {
    condition     = var.dlq_delay_seconds >= 0 && var.dlq_delay_seconds <= 900
    error_message = "O valor de dlq_delay_seconds deve estar entre 0 e 900 segundos (15 minutos)."
  }
}

variable "dlq_receive_wait_time_seconds" {
  description = "Tempo máximo em segundos que uma chamada ReceiveMessage aguarda por mensagem na DLQ. Valores > 0 habilitam long polling."
  type        = number
  default     = 0

  validation {
    condition     = var.dlq_receive_wait_time_seconds >= 0 && var.dlq_receive_wait_time_seconds <= 20
    error_message = "O valor de dlq_receive_wait_time_seconds deve estar entre 0 e 20 segundos."
  }
}

variable "dlq_sqs_managed_sse_enabled" {
  description = "Habilita criptografia SSE com chaves gerenciadas pelo SQS na DLQ. Ignorado automaticamente quando `dlq_kms_master_key_id` ou `kms_master_key_id` estão definidos."
  type        = bool
  default     = true
}

variable "dlq_kms_master_key_id" {
  description = "Chave KMS para criptografia da DLQ. Se não informado e `kms_master_key_id` estiver definido, a DLQ herda a mesma chave da fila principal."
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# CONFIGURAÇÕES DE ACESSO E PERMISSÕES
# ------------------------------------------------------------------------------

variable "create_queue_policy" {
  description = "Cria uma policy de acesso para a fila. Requer ao menos uma entrada em `sns_access_arns`, `s3_access_names` ou `extra_iam_statements`. Use `false` para filas sem policy de acesso explícita."
  type        = bool
  default     = true
}

variable "sns_access_arns" {
  description = "Lista de ARNs de tópicos SNS autorizados a enviar mensagens para a fila."
  type        = list(string)
  default     = []
}

variable "s3_access_names" {
  description = "Lista de nomes de buckets S3 autorizados a enviar mensagens para a fila."
  type        = list(string)
  default     = []
}

variable "extra_iam_statements" {
  description = "Statements IAM adicionais para a policy da fila. Use apenas para casos que vão além de `sns_access_arns` e `s3_access_names`."
  type = list(object({
    sid           = optional(string)
    effect        = optional(string, "Allow")
    actions       = optional(list(string))
    not_actions   = optional(list(string))
    resources     = optional(list(string))
    not_resources = optional(list(string))
    condition = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })))
  }))
  default = []
}
