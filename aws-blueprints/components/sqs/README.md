# SQS

Provisiona uma fila SQS padrão ou FIFO com DLQ opcional, criptografia configurável e policy de acesso para SNS e S3.

## Uso

```yaml
apiVersion: aws/v1
kind: sqs
version: "CHANGEME"

metadata:
  owner: payments-team

spec:
  name: payments-events
  sns_access_arns:
    - arn:aws:sns:us-east-1:123456789012:payments-topic
```

## Exemplos

Casos de uso adicionais em [`examples/`](examples/):

- [`simple/`](examples/simple/) — fila padrão com acesso SNS
- [`fifo/`](examples/fifo/) — fila FIFO para processamento ordenado
- [`fifo-high-throughput/`](examples/fifo-high-throughput/) — FIFO com throughput por message group e deduplicação automática
- [`dlq/`](examples/dlq/) — fila com Dead Letter Queue
- [`kms/`](examples/kms/) — criptografia via chave KMS gerenciada pelo cliente
- [`s3-access/`](examples/s3-access/) — acesso direto de bucket S3
- [`extra-iam-statements/`](examples/extra-iam-statements/) — statements IAM adicionais para casos avançados
- [`simple-no-policy/`](examples/simple-no-policy/) — fila sem policy de acesso

## Notas

- **Filas FIFO:** o sufixo `.fifo` é adicionado automaticamente ao nome. O tópico SNS de origem também deve ser FIFO.
- **KMS e SSE são mutuamente exclusivos:** ao definir `kms_master_key_id`, `enable_sqs_managed_sse` é ignorado. Não é necessário desabilitá-lo manualmente.
- **`create_queue_policy = true` requer ao menos um statement:** ao menos uma entrada em `sns_access_arns`, `s3_access_names` ou `extra_iam_statements` deve estar presente. O módulo falha no plan caso contrário. Para filas sem policy, use `create_queue_policy: false`.
- **DLQ herda KMS da fila principal:** se `dlq_kms_master_key_id` não for informado e `kms_master_key_id` estiver definido, a DLQ usa a mesma chave.
- **`enable_content_based_deduplication` e `fifo_throughput_limit`** só têm efeito com `fifo_queue = true`. O módulo bloqueia o apply caso contrário.

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
| <a name="module_sqs"></a> [sqs](#module\_sqs) | terraform-aws-modules/sqs/aws | 5.2.1 |
| <a name="module_tags"></a> [tags](#module\_tags) | git::https://github.com/gusta-lab/terraform-aws-module-tags.git | v2.1.0 |

## Resources

| Name | Type |
|------|------|
| [terraform_data.validate_fifo_options](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.validate_iam_statements](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | ID da conta AWS onde a fila será provisionada. Usado na construção de ARNs nas policies de acesso. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | Região AWS onde a fila será provisionada. Usado na construção de ARNs nas policies de acesso. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Nome do ambiente (ex: prod, staging). Propagado para tags e identificadores de recursos. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Nome da fila SQS. Em filas FIFO, o sufixo `.fifo` é adicionado automaticamente. | `string` | n/a | yes |
| <a name="input_content_based_deduplication"></a> [content\_based\_deduplication](#input\_content\_based\_deduplication) | Habilita deduplicação automática pelo hash SHA-256 do corpo da mensagem, eliminando a necessidade de gerar um `MessageDeduplicationId` no produtor. Aplicável apenas a filas FIFO. | `bool` | `false` | no |
| <a name="input_create_dlq"></a> [create\_dlq](#input\_create\_dlq) | Cria uma Dead Letter Queue vinculada à fila principal. Mensagens que excedem `max_receive_count` são movidas automaticamente para a DLQ. | `bool` | `false` | no |
| <a name="input_create_queue_policy"></a> [create\_queue\_policy](#input\_create\_queue\_policy) | Cria uma policy de acesso para a fila. Requer ao menos uma entrada em `sns_access_arns`, `s3_access_names` ou `extra_iam_statements`. Use `false` para filas sem policy de acesso explícita. | `bool` | `true` | no |
| <a name="input_delay_seconds"></a> [delay\_seconds](#input\_delay\_seconds) | Atraso em segundos antes que mensagens novas fiquem disponíveis para consumo. Use para desacoplar produtores de consumidores com ritmos diferentes. | `number` | `0` | no |
| <a name="input_dlq_delay_seconds"></a> [dlq\_delay\_seconds](#input\_dlq\_delay\_seconds) | Atraso em segundos antes que mensagens na DLQ fiquem disponíveis para leitura. | `number` | `0` | no |
| <a name="input_dlq_kms_master_key_id"></a> [dlq\_kms\_master\_key\_id](#input\_dlq\_kms\_master\_key\_id) | Chave KMS para criptografia da DLQ. Se não informado e `kms_master_key_id` estiver definido, a DLQ herda a mesma chave da fila principal. | `string` | `null` | no |
| <a name="input_dlq_message_retention_seconds"></a> [dlq\_message\_retention\_seconds](#input\_dlq\_message\_retention\_seconds) | Tempo em segundos que o SQS retém uma mensagem na DLQ antes de descartá-la. Default: 4 dias. | `number` | `345600` | no |
| <a name="input_dlq_receive_wait_time_seconds"></a> [dlq\_receive\_wait\_time\_seconds](#input\_dlq\_receive\_wait\_time\_seconds) | Tempo máximo em segundos que uma chamada ReceiveMessage aguarda por mensagem na DLQ. Valores > 0 habilitam long polling. | `number` | `0` | no |
| <a name="input_dlq_sqs_managed_sse_enabled"></a> [dlq\_sqs\_managed\_sse\_enabled](#input\_dlq\_sqs\_managed\_sse\_enabled) | Habilita criptografia SSE com chaves gerenciadas pelo SQS na DLQ. Ignorado automaticamente quando `dlq_kms_master_key_id` ou `kms_master_key_id` estão definidos. | `bool` | `true` | no |
| <a name="input_dlq_visibility_timeout_seconds"></a> [dlq\_visibility\_timeout\_seconds](#input\_dlq\_visibility\_timeout\_seconds) | Janela de tempo em segundos durante a qual uma mensagem na DLQ fica invisível após ser lida. Deve ser maior que o tempo de inspeção. | `number` | `30` | no |
| <a name="input_extra_iam_statements"></a> [extra\_iam\_statements](#input\_extra\_iam\_statements) | Statements IAM adicionais para a policy da fila. Use apenas para casos que vão além de `sns_access_arns` e `s3_access_names`. | <pre>list(object({<br/>    sid           = optional(string)<br/>    effect        = optional(string, "Allow")<br/>    actions       = optional(list(string))<br/>    not_actions   = optional(list(string))<br/>    resources     = optional(list(string))<br/>    not_resources = optional(list(string))<br/>    condition = optional(list(object({<br/>      test     = string<br/>      variable = string<br/>      values   = list(string)<br/>    })))<br/>  }))</pre> | `[]` | no |
| <a name="input_fifo_queue"></a> [fifo\_queue](#input\_fifo\_queue) | Cria a fila no modo FIFO (First In, First Out), que garante ordenação e suporte a deduplicação. O tópico SNS de origem também deve ser FIFO. | `bool` | `false` | no |
| <a name="input_fifo_throughput_limit"></a> [fifo\_throughput\_limit](#input\_fifo\_throughput\_limit) | Escopo do limite de throughput para filas FIFO. Aceita `perQueue` ou `perMessageGroupId`. Se não informado, a AWS aplica `perQueue`. Aplicável apenas com `fifo_queue = true`. | `string` | `null` | no |
| <a name="input_kms_master_key_id"></a> [kms\_master\_key\_id](#input\_kms\_master\_key\_id) | ID ou ARN de uma chave KMS gerenciada pelo cliente para criptografia da fila. Quando definido, `sqs_managed_sse_enabled` é ignorado automaticamente. | `string` | `null` | no |
| <a name="input_max_message_size"></a> [max\_message\_size](#input\_max\_message\_size) | Tamanho máximo em bytes de uma mensagem antes de ser rejeitada pelo SQS. Default: 256 KB (máximo permitido). | `number` | `262144` | no |
| <a name="input_max_receive_count"></a> [max\_receive\_count](#input\_max\_receive\_count) | Número de vezes que uma mensagem pode ser recebida antes de ser movida para a DLQ. Requer `create_dlq = true`. | `number` | `5` | no |
| <a name="input_message_retention_seconds"></a> [message\_retention\_seconds](#input\_message\_retention\_seconds) | Tempo em segundos que o SQS retém uma mensagem não consumida. Mensagens que excedem esse prazo são descartadas automaticamente. Default: 4 dias. | `number` | `345600` | no |
| <a name="input_receive_wait_time_seconds"></a> [receive\_wait\_time\_seconds](#input\_receive\_wait\_time\_seconds) | Tempo máximo em segundos que uma chamada ReceiveMessage aguarda por mensagem. Valores > 0 habilitam long polling, reduzindo chamadas vazias e custo. | `number` | `0` | no |
| <a name="input_s3_access_names"></a> [s3\_access\_names](#input\_s3\_access\_names) | Lista de nomes de buckets S3 autorizados a enviar mensagens para a fila. | `list(string)` | `[]` | no |
| <a name="input_sns_access_arns"></a> [sns\_access\_arns](#input\_sns\_access\_arns) | Lista de ARNs de tópicos SNS autorizados a enviar mensagens para a fila. | `list(string)` | `[]` | no |
| <a name="input_sqs_managed_sse_enabled"></a> [sqs\_managed\_sse\_enabled](#input\_sqs\_managed\_sse\_enabled) | Habilita criptografia SSE com chaves gerenciadas pelo SQS. Ignorado automaticamente quando `kms_master_key_id` está definido — os dois mecanismos são mutuamente exclusivos. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Mapeamento de chave-valor para tags dos recursos. | `map(string)` | `{}` | no |
| <a name="input_visibility_timeout_seconds"></a> [visibility\_timeout\_seconds](#input\_visibility\_timeout\_seconds) | Janela de tempo em segundos durante a qual uma mensagem consumida fica invisível para outros consumidores. Deve ser maior que o tempo de processamento do worker. | `number` | `30` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dlq_arn"></a> [dlq\_arn](#output\_dlq\_arn) | O ARN da fila DLQ. Null quando create\_dlq = false. |
| <a name="output_dlq_name"></a> [dlq\_name](#output\_dlq\_name) | O nome da fila DLQ. Null quando create\_dlq = false. |
| <a name="output_dlq_url"></a> [dlq\_url](#output\_dlq\_url) | A URL da fila DLQ. Null quando create\_dlq = false. |
| <a name="output_queue_arn"></a> [queue\_arn](#output\_queue\_arn) | O ARN da fila SQS |
| <a name="output_queue_name"></a> [queue\_name](#output\_queue\_name) | O nome da fila SQS |
| <a name="output_queue_url"></a> [queue\_url](#output\_queue\_url) | A URL da fila SQS criada |
<!-- END_TF_DOCS -->
