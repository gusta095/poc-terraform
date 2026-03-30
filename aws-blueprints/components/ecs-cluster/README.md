# ECS Cluster

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.30.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ecs_cluster"></a> [ecs\_cluster](#module\_ecs\_cluster) | terraform-aws-modules/ecs/aws//modules/cluster | 7.3.1 |
| <a name="module_tags"></a> [tags](#module\_tags) | git::https://github.com/gusta-lab/terraform-aws-module-tags.git | v2.1.0 |

## Resources

| Name | Type |
|------|------|
| [terraform_data.validate_capacity_provider_strategy](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Nome do cluster ECS | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | O nome do ambiente | `string` | n/a | yes |
| <a name="input_cloudwatch_log_group_retention_in_days"></a> [cloudwatch\_log\_group\_retention\_in\_days](#input\_cloudwatch\_log\_group\_retention\_in\_days) | Número de dias para retenção dos eventos de log. | `number` | `30` | no |
| <a name="input_cluster_capacity_providers"></a> [cluster\_capacity\_providers](#input\_cluster\_capacity\_providers) | Lista os capacity providers disponíveis no cluster. Cada provider usado em default\_capacity\_provider\_strategy deve estar listado aqui. | `list(string)` | <pre>[<br/>  "FARGATE",<br/>  "FARGATE_SPOT"<br/>]</pre> | no |
| <a name="input_default_capacity_provider_strategy"></a> [default\_capacity\_provider\_strategy](#input\_default\_capacity\_provider\_strategy) | Mapa com as definições da estratégia padrão de capacity providers do cluster ECS. | <pre>map(object({<br/>    base   = optional(number)<br/>    weight = optional(number)<br/>  }))</pre> | <pre>{<br/>  "FARGATE": {<br/>    "base": 0,<br/>    "weight": 1<br/>  }<br/>}</pre> | no |
| <a name="input_enhanced_observability"></a> [enhanced\_observability](#input\_enhanced\_observability) | Ativa observabilidade avançada no ECS (enhanced). Por padrão, container insights já está habilitado. | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Mapeamento de chave-valor para tags dos recursos | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudwatch_log_group_arn"></a> [cloudwatch\_log\_group\_arn](#output\_cloudwatch\_log\_group\_arn) | ARN do log group do CloudWatch associado ao cluster |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Nome do log group do CloudWatch associado ao cluster |
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | ARN que identifica o cluster ECS |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Nome que identifica o cluster ECS |
| <a name="output_container_insights_mode"></a> [container\_insights\_mode](#output\_container\_insights\_mode) | Modo de observabilidade ativo no cluster: 'enabled' (padrão) ou 'enhanced' |
<!-- END_TF_DOCS -->
