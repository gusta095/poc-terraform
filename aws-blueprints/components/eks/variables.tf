# ------------------------------------------------------------------------------
# GLOBAL
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Nome do ambiente (ex: production, staging)"
  type        = string

  validation {
    condition     = length(var.environment) > 0
    error_message = "environment não pode ser vazio."
  }
}

variable "account_id" {
  description = "AWS account ID"
  type        = string

  validation {
    condition     = can(regex("^\\d{12}$", var.account_id))
    error_message = "account_id deve ter exatamente 12 dígitos numéricos."
  }
}

variable "tags" {
  description = "Mapeamento de chave-valor para tags dos recursos."
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# EKS
# ------------------------------------------------------------------------------

variable "name" {
  description = "Nome do cluster EKS."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9\\-_]{0,98}[a-zA-Z0-9]$", var.name))
    error_message = "name deve ter entre 2 e 100 caracteres, iniciar e terminar com alfanumérico, e conter apenas letras, números, hífens e underscores."
  }
}

variable "eks_version" {
  description = "Kubernetes `<major>.<minor>` version to use for the EKS cluster (i.e.: `1.33`)"
  type        = string
  default     = null

  validation {
    condition     = var.eks_version == null || can(regex("^\\d+\\.\\d+$", var.eks_version))
    error_message = "eks_version deve seguir o formato major.minor (ex: 1.33)."
  }
}

variable "vpc_id" {
  description = "ID da VPC onde o security group do cluster será provisionado."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8}([0-9a-f]{9})?$", var.vpc_id))
    error_message = "vpc_id deve seguir o formato vpc-xxxxxxxx."
  }
}

variable "subnet_ids" {
  description = "Lista de subnet IDs onde os nós serão provisionados. O control plane (ENIs) também usará essas subnets se `control_plane_subnet_ids` não for informado."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids deve conter ao menos 2 subnets para alta disponibilidade."
  }

  validation {
    condition = alltrue([
      for s in var.subnet_ids : can(regex("^subnet-[0-9a-f]{8}([0-9a-f]{9})?$", s))
    ])
    error_message = "Cada subnet_id deve seguir o formato subnet-xxxxxxxx."
  }
}

variable "endpoint_public_access" {
  description = "Habilita o endpoint público da API do cluster. Necessário para acesso via kubectl fora da VPC (ex: lab sem VPN)."
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs com acesso ao endpoint público. Restrinja ao seu IP em ambientes expostos."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.endpoint_public_access || length(var.endpoint_public_access_cidrs) > 0
    error_message = "endpoint_public_access_cidrs deve ter ao menos um CIDR quando endpoint_public_access = true."
  }
}

variable "authentication_mode" {
  description = "Modo de autenticação do cluster."
  type        = string
  default     = "API"

  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode deve ser API ou API_AND_CONFIG_MAP."
  }
}

variable "creator_admin" {
  description = "Adiciona o identity que executou o Terraform como admin do cluster via access entry. Útil no bootstrap inicial."
  type        = bool
  default     = false
}

variable "access_entries" {
  description = "Controla o acesso ao cluster. Substitui o aws-auth ConfigMap quando authentication_mode = API."
  type = map(object({
    principal_arn     = string
    kubernetes_groups = optional(list(string))
    type              = optional(string, "STANDARD")
    user_name         = optional(string)
    tags              = optional(map(string), {})
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        namespaces = optional(list(string))
        type       = string
      })
    })), {})
  }))
  default = {}
}

variable "managed_node_groups" {
  description = "Mapa de managed node groups a criar no cluster."
  type = map(object({
    min_size       = optional(number, 1)
    max_size       = optional(number, 2)
    desired_size   = optional(number, 1)
    instance_types = optional(list(string), ["t3.medium"])
    capacity_type  = optional(string, "ON_DEMAND")
    ami_type       = optional(string)
    disk_size      = optional(number, 30)
    labels         = optional(map(string), {})
    taints = optional(map(object({
      key    = string
      value  = optional(string)
      effect = string
    })), {})
    kubernetes_version           = optional(string)
    iam_role_additional_policies = optional(map(string), {})
    subnet_ids                   = optional(list(string))
  }))
  default = {}

  validation {
    condition = alltrue([
      for ng in values(var.managed_node_groups) :
      contains(["ON_DEMAND", "SPOT"], ng.capacity_type)
    ])
    error_message = "capacity_type deve ser ON_DEMAND ou SPOT."
  }
}

variable "enable_node_monitoring" {
  description = "Habilita o addon amazon-cloudwatch-observability com Pod Identity (opcional)"
  type        = bool
  default     = false
}

variable "enable_ebs_csi_driver" {
  description = "Habilita o addon aws-ebs-csi-driver com Pod Identity"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# KMS
# ------------------------------------------------------------------------------

variable "create_kms_key" {
  description = "Cria uma KMS key dedicada para encriptar os secrets do cluster."
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# LOGS
# ------------------------------------------------------------------------------

variable "enabled_log_types" {
  description = "Lista de logs do control plane."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for t in var.enabled_log_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], t)
    ])
    error_message = "enabled_log_types aceita apenas: api, audit, authenticator, controllerManager, scheduler."
  }
}

variable "log_retention_days" {
  description = "Dias de retenção dos logs do control plane no CloudWatch."
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180], var.log_retention_days)
    error_message = "log_retention_days deve ser um valor aceito pelo CloudWatch: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180."
  }
}
