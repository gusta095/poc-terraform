# ------------------------------------------------------------------------------
# GLOBAL
# ------------------------------------------------------------------------------

variable "environment" {
  description = "O nome do ambiente"
  type        = string
}

variable "tags" {
  description = "Mapeamento de chave-valor para tags dos recursos"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# ECS Cluster
# ------------------------------------------------------------------------------

variable "cluster_name" {
  description = "Nome do cluster ECS"
  type        = string

  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 255
    error_message = "O nome do cluster ECS deve ter entre 1 e 255 caracteres."
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_-]*$", var.cluster_name))
    error_message = "O nome do cluster ECS deve começar com uma letra e conter apenas letras, números, hífens (-) e underlines (_)."
  }
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Número de dias para retenção dos eventos de log."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.cloudwatch_log_group_retention_in_days)
    error_message = "Valor inválido para retenção de logs. Valores aceitos pelo CloudWatch: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365."
  }
}

variable "enhanced_observability" {
  description = "Ativa observabilidade avançada no ECS (enhanced). Por padrão, container insights já está habilitado."
  type        = bool
  default     = false
}

variable "cluster_capacity_providers" {
  description = "Lista os capacity providers disponíveis no cluster. Cada provider usado em default_capacity_provider_strategy deve estar listado aqui."
  type        = list(string)
  default     = ["FARGATE", "FARGATE_SPOT"]

  validation {
    condition = (
      length(var.cluster_capacity_providers) == length(distinct(var.cluster_capacity_providers))
      &&
      alltrue([
        for cp in var.cluster_capacity_providers :
        contains(["FARGATE", "FARGATE_SPOT"], cp)
      ])
    )
    error_message = "Valores permitidos: 'FARGATE' e/ou 'FARGATE_SPOT', sem duplicações."
  }
}

variable "default_capacity_provider_strategy" {
  description = "Mapa com as definições da estratégia padrão de capacity providers do cluster ECS."

  type = map(object({
    base   = optional(number)
    weight = optional(number)
  }))

  default = {
    FARGATE = {
      base   = 0
      weight = 1
    }
  }
}
