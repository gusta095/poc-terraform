# ------------------------------------------------------------------------------
# Cluster
# ------------------------------------------------------------------------------

output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN do cluster EKS."
  value       = module.eks.cluster_arn
}

output "cluster_version" {
  description = "Versão do Kubernetes em uso no cluster."
  value       = module.eks.cluster_version
}

output "cluster_endpoint" {
  description = "Endpoint da API do Kubernetes."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificado CA do cluster em Base64. Necessário para autenticar via kubectl."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_primary_security_group_id" {
  description = "Security group criado pelo EKS para comunicação entre control plane e data plane."
  value       = module.eks.cluster_primary_security_group_id
}

# ------------------------------------------------------------------------------
# Segurança
# ------------------------------------------------------------------------------

output "cluster_security_group_id" {
  description = "Security group adicional do cluster criado pelo módulo."
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group compartilhado entre os nós do cluster."
  value       = module.eks.node_security_group_id
}

# ------------------------------------------------------------------------------
# IAM
# ------------------------------------------------------------------------------

output "cluster_iam_role_arn" {
  description = "ARN da IAM role usada pelo control plane do cluster."
  value       = module.eks.cluster_iam_role_arn
}

output "node_iam_role_arn" {
  description = "ARN da IAM role atribuída aos nós. Necessário para configurar o Karpenter e outros controllers que criam nós."
  value       = module.eks.node_iam_role_arn
}

output "node_iam_role_name" {
  description = "Nome da IAM role atribuída aos nós."
  value       = module.eks.node_iam_role_name
}

output "kms_key_arn" {
  description = "ARN da KMS key usada para encriptar os secrets do cluster. Vazio quando create_kms_key = false."
  value       = module.eks.kms_key_arn
}

# ------------------------------------------------------------------------------
# OIDC (disponível mesmo com enable_irsa = false — útil para uso pontual)
# ------------------------------------------------------------------------------

output "oidc_provider_arn" {
  description = "ARN do OIDC provider do cluster."
  value       = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  description = "URL do OIDC issuer do cluster."
  value       = module.eks.cluster_oidc_issuer_url
}

# ------------------------------------------------------------------------------
# CloudWatch
# ------------------------------------------------------------------------------

output "cloudwatch_log_group_name" {
  description = "Nome do log group no CloudWatch para os logs do control plane."
  value       = module.eks.cloudwatch_log_group_name
}
