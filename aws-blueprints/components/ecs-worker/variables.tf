# ------------------------------------------------------------------------------
# CONFIGURAÇÕES GLOBAIS
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Identifica o ambiente de execução (ex: prod, staging) e é usado na nomenclatura e nas tags dos recursos."
  type        = string
}

variable "vpc_primary_name" {
  description = "Nome da VPC principal que será utilizada na região"
  type        = string
}

variable "tags" {
  description = "Mapeamento de chave-valor para tags dos recursos"
  type        = map(string)
  default     = {}
}

variable "cluster_arn" {
  description = "Arn do cluster que o worker vai se conectar"
  type        = string
  default     = ""

  validation {
    condition     = !(var.cluster_arn != "" && var.cluster_name != "")
    error_message = "Quando utilizar o dependency não use o cluster_name, nunca use os dois ao mesmo tempo."
  }

  validation {
    condition     = var.cluster_arn != "" || var.cluster_name != ""
    error_message = "É necessário usar o dependency ou cluster_name. Atualmente, ambos estão vazios."
  }
}

# ------------------------------------------------------------------------------
# CONFIGURAÇÕES DO SERVIÇO ECS
# ------------------------------------------------------------------------------

variable "cluster_name" {
  description = "Nome do cluster ECS. Ignorado quando cluster_arn é fornecido."
  type        = string
  default     = ""
}

variable "worker_name" {
  description = "Nome do serviço ECS Worker"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,255}$", var.worker_name))
    error_message = "worker_name deve conter apenas letras, números, hífens e underscores (máx. 255 caracteres)."
  }
}

variable "create_service" {
  description = "Determina se o recurso do serviço será criado"
  type        = bool
  default     = true
}

variable "assign_public_ip" {
  description = "Define se um endereço IP público será atribuído à ENI (somente para o tipo de execução Fargate)"
  type        = bool
  default     = true
}

variable "propagate_tags" {
  description = "Define se as tags serão propagadas da task definition ou do serviço para as tasks. Valores aceitos: `SERVICE` e `TASK_DEFINITION`."
  type        = string
  default     = "SERVICE"

  validation {
    condition     = contains(["SERVICE", "TASK_DEFINITION"], var.propagate_tags)
    error_message = "propagate_tags deve ser SERVICE ou TASK_DEFINITION."
  }
}

# ------------------------------------------------------------------------------
# CONFIGURAÇÕES DE RECURSOS COMPUTACIONAIS
# ------------------------------------------------------------------------------

variable "cpu" {
  description = "CPU alocada para a task Fargate. Valores aceitos: 256, 512, 1024, 2048, 4096. Deve ser compatível com `memory`."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "Valor inválido para `cpu`. Valores permitidos: 256, 512, 1024, 2048, 4096 (Fargate)."
  }
}

variable "memory" {
  description = "Memória alocada para a task Fargate, em MiB. Deve ser compatível com o valor de `cpu`."
  type        = number
  default     = 512

  validation {
    condition = (
      contains(keys(local.valid_memory_ranges), tostring(var.cpu)) &&
      contains(
        lookup(local.valid_memory_ranges, tostring(var.cpu), []),
        var.memory
      )
    )

    error_message = "Combinação inválida de CPU/Memory para Fargate."
  }
}

variable "image" {
  description = "A imagem do container a ser utilizada no serviço ECS Worker"
  type        = string
}

# ------------------------------------------------------------------------------
# CONFIGURAÇÕES DE AUTOSCALING
# ------------------------------------------------------------------------------

variable "autoscaling_min" {
  description = "Número mínimo de tarefas para o serviço ECS Worker"
  type        = number
  default     = 1

  validation {
    condition     = var.autoscaling_min >= 0
    error_message = "autoscaling_min não pode ser negativo."
  }
}

variable "autoscaling_max" {
  description = "Número máximo de tarefas para o serviço ECS Worker"
  type        = number
  default     = 2

  validation {
    condition     = var.autoscaling_max >= 1
    error_message = "autoscaling_max deve ser pelo menos 1."
  }
}

variable "autoscale_strategy" {
  description = "Lista de estratégias de escalonamento ativas."
  type        = list(string)
  default     = ["cpu", "memory"]

  validation {
    condition = alltrue([
      for s in var.autoscale_strategy :
      contains(["cpu", "memory", "sqs_messages_scaling"], s)
    ])
    error_message = "Estratégia inválida. Valores permitidos: cpu, memory, sqs_messages_scaling."
  }
}

variable "sqs_specific_name" {
  description = "Nome da fila SQS usada como métrica de escalonamento quando `sqs_messages_scaling` está em `autoscale_strategy`. Não concede acesso à fila — para isso use `sqs_access_arns`."
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# CONFIGURAÇÕES DE IAM E ACESSO A SERVIÇOS
# ------------------------------------------------------------------------------

variable "extra_iam_statements" {
  description = "Declarações IAM adicionais para anexar à role da tarefa. Use apenas para casos avançados ou excepcionais."
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

variable "sqs_access_arns" {
  description = "Lista de ARNs de filas SQS das quais a tarefa pode enviar e receber mensagens."
  type        = list(string)
  default     = []
}

variable "sns_access" {
  description = "Lista de ARNs de tópicos SNS onde a tarefa pode publicar mensagens."
  type        = list(string)
  default     = []
}

variable "dynamodb_access" {
  description = "Lista de ARNs de tabelas DynamoDB nas quais a tarefa pode realizar operações de leitura e escrita."
  type        = list(string)
  default     = []
}

variable "lambda_access" {
  description = "Lista de ARNs de funções Lambda que a tarefa pode invocar."
  type        = list(string)
  default     = []
}

variable "s3_access_names" {
  description = "Lista de nomes de buckets S3 nos quais a tarefa pode realizar operações de leitura e escrita."
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------------------
# CONFIGURAÇÕES DO CONTAINER
# ------------------------------------------------------------------------------

variable "environments" {
  description = "Variáveis de ambiente como pares chave-valor em texto simples, Para valores sensíveis, use `secrets`."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Variáveis de ambiente sensiveis como pares chave-valor em texto simples."
  type        = map(string)
  default     = {}
}

variable "sidecars" {
  description = "Mapa de containers sidecar a serem adicionados à task definition. A chave é usada como nome do container."
  type = map(object({
    image              = string
    essential          = optional(bool, false)
    cpu                = optional(number)
    memory             = optional(number)
    environments       = optional(map(string), {})
    secrets            = optional(map(string), {})
    log_retention_days = optional(number)
    health_check = optional(object({
      command      = list(string)
      interval     = optional(number, 20)
      timeout      = optional(number, 5)
      retries      = optional(number, 2)
      start_period = optional(number, 15)
    }))
  }))
  default = {}
}

# ------------------------------------------------------------------------------
# CONFIGURAÇÕES DE LOGS E MONITORAMENTO
# ------------------------------------------------------------------------------

variable "log_retention_days" {
  description = "Número de dias para reter os logs no CloudWatch Logs"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "log_retention_days deve ser um dos valores aceitos pelo CloudWatch Logs: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365."
  }
}

# ------------------------------------------------------------------------------
# CONFIGURAÇÕES DE DEPLOY
# ------------------------------------------------------------------------------

variable "deployment_circuit_breaker" {
  description = "Configuração do circuit breaker de deploy do ECS Service."
  type = object({
    enable   = bool
    rollback = bool
  })

  default = {
    enable   = true
    rollback = true
  }
}
