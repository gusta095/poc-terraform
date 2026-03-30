# AWS EKS Cluster

Provisiona um cluster EKS com control plane, managed node groups e addons essenciais via `terraform-aws-modules/eks`.

## Addons

### Sempre habilitados

| Addon | O que faz |
|-------|-----------|
| `vpc-cni` | Atribui IPs da VPC diretamente aos pods (modelo nativo AWS). Instalado antes dos nós (`before_compute = true`) para evitar race condition no bootstrap. |
| `coredns` | DNS interno do cluster. Resolve nomes de serviços (`my-service.namespace.svc.cluster.local`). |
| `kube-proxy` | Mantém as regras de rede nos nós para roteamento de tráfego entre pods e serviços. |
| `eks-pod-identity-agent` | Agente que permite pods assumirem IAM roles sem IRSA. Substitui o modelo de anotação de service account. |

### Opcionais

| Addon | Variável | O que faz |
|-------|----------|-----------|
| `aws-ebs-csi-driver` | `enable_ebs_csi_driver` | Driver para provisionar volumes EBS como PersistentVolumes. Necessário para qualquer workload com storage persistente. Usa Pod Identity. |
| `amazon-cloudwatch-observability` | `enable_node_monitoring` | Coleta métricas e logs dos nós e pods no CloudWatch. Usa Pod Identity. |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.30.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.30.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 21.15.1 |
| <a name="module_tags"></a> [tags](#module\_tags) | git::https://github.com/gusta-lab/terraform-aws-module-tags.git | v2.1.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/resources/iam_role) | resource |
| [aws_iam_role.node_monitoring](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.node_monitoring](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/resources/iam_role_policy_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS account ID | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Nome do ambiente (ex: production, staging) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Nome do cluster EKS. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Lista de subnet IDs onde os nós serão provisionados. O control plane (ENIs) também usará essas subnets se `control_plane_subnet_ids` não for informado. | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID da VPC onde o security group do cluster será provisionado. | `string` | n/a | yes |
| <a name="input_access_entries"></a> [access\_entries](#input\_access\_entries) | Controla o acesso ao cluster. Substitui o aws-auth ConfigMap quando authentication\_mode = API. | <pre>map(object({<br/>    principal_arn     = string<br/>    kubernetes_groups = optional(list(string))<br/>    type              = optional(string, "STANDARD")<br/>    user_name         = optional(string)<br/>    tags              = optional(map(string), {})<br/>    policy_associations = optional(map(object({<br/>      policy_arn = string<br/>      access_scope = object({<br/>        namespaces = optional(list(string))<br/>        type       = string<br/>      })<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_authentication_mode"></a> [authentication\_mode](#input\_authentication\_mode) | Modo de autenticação do cluster. | `string` | `"API"` | no |
| <a name="input_create_kms_key"></a> [create\_kms\_key](#input\_create\_kms\_key) | Cria uma KMS key dedicada para encriptar os secrets do cluster. | `bool` | `false` | no |
| <a name="input_creator_admin"></a> [creator\_admin](#input\_creator\_admin) | Adiciona o identity que executou o Terraform como admin do cluster via access entry. Útil no bootstrap inicial. | `bool` | `false` | no |
| <a name="input_eks_version"></a> [eks\_version](#input\_eks\_version) | Kubernetes `<major>.<minor>` version to use for the EKS cluster (i.e.: `1.33`) | `string` | `null` | no |
| <a name="input_enable_ebs_csi_driver"></a> [enable\_ebs\_csi\_driver](#input\_enable\_ebs\_csi\_driver) | Habilita o addon aws-ebs-csi-driver com Pod Identity | `bool` | `false` | no |
| <a name="input_enable_node_monitoring"></a> [enable\_node\_monitoring](#input\_enable\_node\_monitoring) | Habilita o addon amazon-cloudwatch-observability com Pod Identity (opcional) | `bool` | `false` | no |
| <a name="input_enabled_log_types"></a> [enabled\_log\_types](#input\_enabled\_log\_types) | Lista de logs do control plane. | `list(string)` | `[]` | no |
| <a name="input_endpoint_public_access"></a> [endpoint\_public\_access](#input\_endpoint\_public\_access) | Habilita o endpoint público da API do cluster. Necessário para acesso via kubectl fora da VPC (ex: lab sem VPN). | `bool` | `false` | no |
| <a name="input_endpoint_public_access_cidrs"></a> [endpoint\_public\_access\_cidrs](#input\_endpoint\_public\_access\_cidrs) | CIDRs com acesso ao endpoint público. Restrinja ao seu IP em ambientes expostos. | `list(string)` | `[]` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Dias de retenção dos logs do control plane no CloudWatch. | `number` | `90` | no |
| <a name="input_managed_node_groups"></a> [managed\_node\_groups](#input\_managed\_node\_groups) | Mapa de managed node groups a criar no cluster. | <pre>map(object({<br/>    min_size       = optional(number, 1)<br/>    max_size       = optional(number, 2)<br/>    desired_size   = optional(number, 1)<br/>    instance_types = optional(list(string), ["t3.medium"])<br/>    capacity_type  = optional(string, "ON_DEMAND")<br/>    ami_type       = optional(string)<br/>    disk_size      = optional(number, 30)<br/>    labels         = optional(map(string), {})<br/>    taints = optional(map(object({<br/>      key    = string<br/>      value  = optional(string)<br/>      effect = string<br/>    })), {})<br/>    kubernetes_version           = optional(string)<br/>    iam_role_additional_policies = optional(map(string), {})<br/>    subnet_ids                   = optional(list(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Mapeamento de chave-valor para tags dos recursos. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Nome do log group no CloudWatch para os logs do control plane. |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN do cluster EKS. |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Certificado CA do cluster em Base64. Necessário para autenticar via kubectl. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Endpoint da API do Kubernetes. |
| <a name="output_cluster_iam_role_arn"></a> [cluster\_iam\_role\_arn](#output\_cluster\_iam\_role\_arn) | ARN da IAM role usada pelo control plane do cluster. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Nome do cluster EKS. |
| <a name="output_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#output\_cluster\_oidc\_issuer\_url) | URL do OIDC issuer do cluster. |
| <a name="output_cluster_primary_security_group_id"></a> [cluster\_primary\_security\_group\_id](#output\_cluster\_primary\_security\_group\_id) | Security group criado pelo EKS para comunicação entre control plane e data plane. |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | Security group adicional do cluster criado pelo módulo. |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | Versão do Kubernetes em uso no cluster. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN da KMS key usada para encriptar os secrets do cluster. Vazio quando create\_kms\_key = false. |
| <a name="output_node_iam_role_arn"></a> [node\_iam\_role\_arn](#output\_node\_iam\_role\_arn) | ARN da IAM role atribuída aos nós. Necessário para configurar o Karpenter e outros controllers que criam nós. |
| <a name="output_node_iam_role_name"></a> [node\_iam\_role\_name](#output\_node\_iam\_role\_name) | Nome da IAM role atribuída aos nós. |
| <a name="output_node_security_group_id"></a> [node\_security\_group\_id](#output\_node\_security\_group\_id) | Security group compartilhado entre os nós do cluster. |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN do OIDC provider do cluster. |
<!-- END_TF_DOCS -->
