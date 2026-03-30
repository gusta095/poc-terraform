# ECS Worker

Provisiona um serviço ECS Fargate sem load balancer, voltado para workers que consomem filas SQS ou executam processamento em background.

## Uso

```yaml
apiVersion: aws/v1
kind: ecs-worker
version: "26.03.23"

metadata:
  owner: my-team

spec:
  cluster_name: ecs-prod-cluster
  worker_name: payments-worker

  image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/payments-worker:v1.0.0
  cpu: 256
  memory: 512

  sqs_access_arns:
    - arn:aws:sqs:us-east-1:123456789012:payments-queue
```

## Notas

- Prefira sempre `cluster_arn` via `dependency` — o ARN é injetado automaticamente e garante a ordem de criação. Use `cluster_name`
apenas em casos atípicos onde o cluster não é gerenciado no mesmo stack.
- `environment`, `account_id` e `aws_region` são injetadas pelo Terragrunt via contexto de conta/região — omitir do `spec`.
- `autoscale_strategy: sqs_messages_scaling` requer ao menos um ARN em `sqs_access_arns`. Se houver múltiplas filas, use `sqs_specific_name` para indicar qual fila deve ser monitorada.
- `cpu` e `memory` devem seguir as combinações válidas do Fargate. Exemplos: 256 CPU / 512 MiB, 512 CPU / 1024 MiB, 1024 CPU / 2048 MiB. Valores fora das combinações suportadas resultam em erro na criação da task definition.

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
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ecs_service_worker"></a> [ecs\_service\_worker](#module\_ecs\_service\_worker) | terraform-aws-modules/ecs/aws//modules/service | 7.3.1 |
| <a name="module_ecs_worker_sg"></a> [ecs\_worker\_sg](#module\_ecs\_worker\_sg) | terraform-aws-modules/security-group/aws | 5.3.1 |
| <a name="module_tags"></a> [tags](#module\_tags) | git::https://github.com/gusta-lab/terraform-aws-module-tags.git | v2.1.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.ecs_task_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ecs_task_policy](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/resources/iam_policy) | resource |
| [aws_iam_role.ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task_role](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ecs_task_execution_attach](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_task_policy_attach](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/resources/iam_role_policy_attachment) | resource |
| [terraform_data.validate_autoscaling_range](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.validate_sqs_scaling](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_ecs_cluster.ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/data-sources/ecs_cluster) | data source |
| [aws_iam_policy_document.ecs_task_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_task_policy](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/data-sources/iam_policy_document) | data source |
| [aws_subnets.public_subnets](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/data-sources/subnets) | data source |
| [aws_vpc.vpc_infos](https://registry.terraform.io/providers/hashicorp/aws/6.30.0/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | Identifica o ambiente de execução (ex: prod, staging) e é usado na nomenclatura e nas tags dos recursos. | `string` | n/a | yes |
| <a name="input_image"></a> [image](#input\_image) | A imagem do container a ser utilizada no serviço ECS Worker | `string` | n/a | yes |
| <a name="input_vpc_primary_name"></a> [vpc\_primary\_name](#input\_vpc\_primary\_name) | Nome da VPC principal que será utilizada na região | `string` | n/a | yes |
| <a name="input_worker_name"></a> [worker\_name](#input\_worker\_name) | Nome do serviço ECS Worker | `string` | n/a | yes |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Define se um endereço IP público será atribuído à ENI (somente para o tipo de execução Fargate) | `bool` | `true` | no |
| <a name="input_autoscale_strategy"></a> [autoscale\_strategy](#input\_autoscale\_strategy) | Lista de estratégias de escalonamento ativas. | `list(string)` | <pre>[<br/>  "cpu",<br/>  "memory"<br/>]</pre> | no |
| <a name="input_autoscaling_max"></a> [autoscaling\_max](#input\_autoscaling\_max) | Número máximo de tarefas para o serviço ECS Worker | `number` | `2` | no |
| <a name="input_autoscaling_min"></a> [autoscaling\_min](#input\_autoscaling\_min) | Número mínimo de tarefas para o serviço ECS Worker | `number` | `1` | no |
| <a name="input_cluster_arn"></a> [cluster\_arn](#input\_cluster\_arn) | Arn do cluster que o worker vai se conectar | `string` | `""` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Nome do cluster ECS. Ignorado quando cluster\_arn é fornecido. | `string` | `""` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | CPU alocada para a task Fargate. Valores aceitos: 256, 512, 1024, 2048, 4096. Deve ser compatível com `memory`. | `number` | `256` | no |
| <a name="input_create_service"></a> [create\_service](#input\_create\_service) | Determina se o recurso do serviço será criado | `bool` | `true` | no |
| <a name="input_deployment_circuit_breaker"></a> [deployment\_circuit\_breaker](#input\_deployment\_circuit\_breaker) | Configuração do circuit breaker de deploy do ECS Service. | <pre>object({<br/>    enable   = bool<br/>    rollback = bool<br/>  })</pre> | <pre>{<br/>  "enable": true,<br/>  "rollback": true<br/>}</pre> | no |
| <a name="input_dynamodb_access"></a> [dynamodb\_access](#input\_dynamodb\_access) | Lista de ARNs de tabelas DynamoDB nas quais a tarefa pode realizar operações de leitura e escrita. | `list(string)` | `[]` | no |
| <a name="input_environments"></a> [environments](#input\_environments) | Variáveis de ambiente como pares chave-valor em texto simples, Para valores sensíveis, use `secrets`. | `map(string)` | `{}` | no |
| <a name="input_extra_iam_statements"></a> [extra\_iam\_statements](#input\_extra\_iam\_statements) | Declarações IAM adicionais para anexar à role da tarefa. Use apenas para casos avançados ou excepcionais. | <pre>list(object({<br/>    sid           = optional(string)<br/>    effect        = optional(string, "Allow")<br/>    actions       = optional(list(string))<br/>    not_actions   = optional(list(string))<br/>    resources     = optional(list(string))<br/>    not_resources = optional(list(string))<br/>    condition = optional(list(object({<br/>      test     = string<br/>      variable = string<br/>      values   = list(string)<br/>    })))<br/>  }))</pre> | `[]` | no |
| <a name="input_lambda_access"></a> [lambda\_access](#input\_lambda\_access) | Lista de ARNs de funções Lambda que a tarefa pode invocar. | `list(string)` | `[]` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Número de dias para reter os logs no CloudWatch Logs | `number` | `7` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Memória alocada para a task Fargate, em MiB. Deve ser compatível com o valor de `cpu`. | `number` | `512` | no |
| <a name="input_propagate_tags"></a> [propagate\_tags](#input\_propagate\_tags) | Define se as tags serão propagadas da task definition ou do serviço para as tasks. Valores aceitos: `SERVICE` e `TASK_DEFINITION`. | `string` | `"SERVICE"` | no |
| <a name="input_s3_access_names"></a> [s3\_access\_names](#input\_s3\_access\_names) | Lista de nomes de buckets S3 nos quais a tarefa pode realizar operações de leitura e escrita. | `list(string)` | `[]` | no |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Variáveis de ambiente sensiveis como pares chave-valor em texto simples. | `map(string)` | `{}` | no |
| <a name="input_sidecars"></a> [sidecars](#input\_sidecars) | Mapa de containers sidecar a serem adicionados à task definition. A chave é usada como nome do container. | <pre>map(object({<br/>    image              = string<br/>    essential          = optional(bool, false)<br/>    cpu                = optional(number)<br/>    memory             = optional(number)<br/>    environments       = optional(map(string), {})<br/>    secrets            = optional(map(string), {})<br/>    log_retention_days = optional(number)<br/>    health_check = optional(object({<br/>      command      = list(string)<br/>      interval     = optional(number, 20)<br/>      timeout      = optional(number, 5)<br/>      retries      = optional(number, 2)<br/>      start_period = optional(number, 15)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_sns_access"></a> [sns\_access](#input\_sns\_access) | Lista de ARNs de tópicos SNS onde a tarefa pode publicar mensagens. | `list(string)` | `[]` | no |
| <a name="input_sqs_access_arns"></a> [sqs\_access\_arns](#input\_sqs\_access\_arns) | Lista de ARNs de filas SQS das quais a tarefa pode enviar e receber mensagens. | `list(string)` | `[]` | no |
| <a name="input_sqs_specific_name"></a> [sqs\_specific\_name](#input\_sqs\_specific\_name) | Nome da fila SQS usada como métrica de escalonamento quando `sqs_messages_scaling` está em `autoscale_strategy`. Não concede acesso à fila — para isso use `sqs_access_arns`. | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Mapeamento de chave-valor para tags dos recursos | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_worker_autoscaling_max_capacity"></a> [worker\_autoscaling\_max\_capacity](#output\_worker\_autoscaling\_max\_capacity) | Maior número de tarefas que o autoscaling pode provisionar. |
| <a name="output_worker_autoscaling_min_capacity"></a> [worker\_autoscaling\_min\_capacity](#output\_worker\_autoscaling\_min\_capacity) | Menor número de tarefas que o autoscaling manterá em execução. |
| <a name="output_worker_autoscaling_target_arn"></a> [worker\_autoscaling\_target\_arn](#output\_worker\_autoscaling\_target\_arn) | ARN do autoscaling target |
| <a name="output_worker_cloudwatch_log_group_arn"></a> [worker\_cloudwatch\_log\_group\_arn](#output\_worker\_cloudwatch\_log\_group\_arn) | ARN do log group no CloudWatch |
| <a name="output_worker_cloudwatch_log_group_name"></a> [worker\_cloudwatch\_log\_group\_name](#output\_worker\_cloudwatch\_log\_group\_name) | Nome do log group no CloudWatch |
| <a name="output_worker_cluster_name"></a> [worker\_cluster\_name](#output\_worker\_cluster\_name) | Nome do cluster ECS |
| <a name="output_worker_security_group_arn"></a> [worker\_security\_group\_arn](#output\_worker\_security\_group\_arn) | ARN do security group do serviço worker |
| <a name="output_worker_security_group_id"></a> [worker\_security\_group\_id](#output\_worker\_security\_group\_id) | ID do security group do serviço worker |
| <a name="output_worker_service_id"></a> [worker\_service\_id](#output\_worker\_service\_id) | ID do serviço ECS worker |
| <a name="output_worker_service_name"></a> [worker\_service\_name](#output\_worker\_service\_name) | Nome do serviço ECS worker |
| <a name="output_worker_task_definition_arn"></a> [worker\_task\_definition\_arn](#output\_worker\_task\_definition\_arn) | ARN completo da definição de tarefa (inclui family e revision) |
| <a name="output_worker_task_exec_role_arn"></a> [worker\_task\_exec\_role\_arn](#output\_worker\_task\_exec\_role\_arn) | ARN da task execution role — usada pelo agente do ECS para puxar imagens e enviar logs. Distinta da task role, que controla permissões da aplicação. |
| <a name="output_worker_task_role_arn"></a> [worker\_task\_role\_arn](#output\_worker\_task\_role\_arn) | ARN da task role — assume as permissões da aplicação em runtime (acesso a SQS, S3, DynamoDB etc.). Distinta da execution role, usada pelo agente do ECS. |
<!-- END_TF_DOCS -->
