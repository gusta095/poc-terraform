# Changelog

## Unreleased

## v26.03.31 - 2026-03-29

- **Blueprint `components/eks` — testes e validações adicionais**
  - Suite de testes com 50 casos em 2 arquivos: `variable_validations.tftest.hcl` (35 runs) e `module_behavior.tftest.hcl` (15 runs) — 100% mock
  - `module_behavior.tftest.hcl`: assertions em criação condicional de roles IAM, nomes de recursos, policy ARNs e 5 cenários end-to-end (lab, produção, bootstrap, multi-node, stack completa)
  - Variável `kubernetes_version` adicionada a `managed_node_groups` (suporte a upgrades graduais de node group)
  - `make test-eks` adicionado; `make test-all` atualizado

## v26.03.30 - 2026-03-29

- **Blueprint `components/eks` — refatoração completa da interface**
  - Upstream atualizado: `terraform-aws-modules/eks/aws` `20.8.4` → `21.15.1`
  - Variáveis redesenhadas: `cluster_name` → `name`, `cluster_version` → `eks_version`, `private_subnets_ids` → `subnet_ids`, `cluster_endpoint_public_access` → `endpoint_public_access`
  - `authentication_mode` com padrão alterado para `API` (antes `API_AND_CONFIG_MAP`)
  - `create_kms_key` (bool) substitui `cluster_encryption_config: any`
  - `enabled_log_types` e `log_retention_days` substituem `cluster_enabled_log_types`
  - Nova variável `creator_admin` para bootstrap inicial via access entry
  - Addons core (`vpc-cni`, `coredns`, `kube-proxy`, `eks-pod-identity-agent`) sempre habilitados
  - `enable_ebs_csi_driver`: addon `aws-ebs-csi-driver` com role Pod Identity gerenciado pelo blueprint
  - `enable_node_monitoring`: addon `amazon-cloudwatch-observability` com role Pod Identity gerenciado pelo blueprint
  - `access_entries` tipado (`map(object(...))`) com entrada `root` sempre injetada via `locals.tf`
  - `enable_irsa = false` — Pod Identity é o modelo preferido
  - `managed_node_groups` tipado com campos essenciais: sizing, `capacity_type`, `ami_type`, `labels`, `taints`, `iam_role_additional_policies`
  - Validações: `account_id` (12 dígitos), `eks_version` (formato major.minor), `name` (charset EKS), `vpc_id` e `subnet_ids` (formato AWS + mínimo 2), `enabled_log_types` (valores válidos), `log_retention_days` (valores aceitos pelo CloudWatch)
  - Outputs adicionados: `node_iam_role_arn` e `node_iam_role_name` (necessários para Karpenter)
  - Exemplos: `cluster-lab`, `access-entries` e `bootstrap-node` (nó on-demand para ArgoCD)
  - Validado em sandbox: cluster `v1.34` com 1 nó `t3.medium`, todos addons `Running`

## v26.03.29 - 2026-03-28

- **Blueprint `components/acm`**
  - Ajuste no zone_id

## v26.03.28 - 2026-03-27

- **Blueprint `components/acm` — refatoração da interface e adição de testes**
  - Variável `name` removida (não existia no upstream e não era usada)
  - Adicionadas variáveis: `validation_method` (default `"DNS"`, aceita `EMAIL`), `wait_for_validation` (default `true`), `zones` (map de Zone IDs para SANs em hosted zones diferentes)
  - 5 novos blocos `validation`: `environment` (não vazio), `account_route53_zone_id` (formato Route53 `Z[A-Z0-9]+`), `domain_name` (domínio válido, suporta wildcard), `subject_alternative_names` (cada entrada validada), `zones` (valores seguem formato de Zone ID)
  - Novo output `acm_certificate_status` (`PENDING_VALIDATION`, `ISSUED`, etc.)
  - 3 exemplos YAML: `simples/` (atualizado com header), `com-sans/`, `multi-zona/`
  - Suite de testes com 24 casos em 2 arquivos: `variable_validations.tftest.hcl` (18 runs) e `module_behavior.tftest.hcl` (6 runs) — 100% mock
  - `make test-acm` adicionado; `make test-all` atualizado
  - README regenerado refletindo interface atual

## v26.03.27 - 2026-03-27

- **Blueprint `components/route53` — novo componente para hosted zones Route53**
  - Migrado do padrão legado `components/route53/zone` (multi-zona via `var.zones: any`) para blueprint único com interface tipada
  - Wraps `terraform-aws-modules/route53/aws` v6.4.0 (root module — `modules/zones` removido no upstream)
  - Suporta 3 casos de uso: zona pública, zona privada (via `var.vpc`) e lookup de zona existente (`create_zone: false`) para criação de records sem gerenciar a zona
  - Records DNS integrados via `var.records` — suporte a A, CNAME, MX, alias, failover, geolocalização, latência, weighted e CIDR routing
  - Variáveis tipadas: `name` (obrigatório), `comment`, `force_destroy`, `delegation_set_id`, `vpc`
  - 5 validações: `name` (formato de domínio), `comment` (não vazio, máx 256 chars), `force_destroy`/`vpc`/`delegation_set_id` só permitidos com `create_zone = true`; `delegation_set_id` conflita com `vpc`
  - 5 exemplos YAML: `public-zone`, `private-zone`, `public-zone-with-records`, `private-zone-with-records`, `records-only`
  - Suite de testes com 25 casos em `tests/variable_validations.tftest.hcl` — 100% mock, sem bater no provedor
  - `make test-route53-zone` adicionado; `make test-all` atualizado

## v26.03.26 - 2026-03-26

- **`ecs-worker`** — validação em `cluster_arn` impede uso simultâneo com `cluster_name`; 2 novos testes cobrem o caso de falha e o happy path
- Foi removido todos os `metadata`
- Foi Alterado o formato do apiversion de `apiVersion: v1` para `apiVersion: aws/v1` dando suporte ao provedor agora

## v26.03.25 - 2026-03-26

- fix

## v26.03.24 - 2026-03-26

- **Blueprint `components/ecs-worker` — suporte a `dependency` e melhorias de interface**
  - Nova variável `cluster_arn`: aceita ARN do cluster diretamente, tipicamente injetado via `dependency` no Terragrunt — elimina necessidade de buscar o cluster pelo nome
  - `cluster_name` agora opcional (`default = ""`): usado apenas como fallback quando `cluster_arn` não é fornecido
  - `data "aws_ecs_cluster"` passa a ter `count = 0` quando `cluster_arn` está preenchido
  - Nova variável `propagate_tags` (`SERVICE` | `TASK_DEFINITION`, default `SERVICE`)
  - Novas validações: `worker_name` (charset ECS), `autoscaling_min` (≥ 0), `autoscaling_max` (≥ 1), `propagate_tags`
  - Novo exemplo `dependency-cluster`: demonstra uso com cluster criado no mesmo stack
  - Exemplo `multi-acccess` renomeado para `multi-access` (typo corrigido) e cabeçalho adicionado
  - Cabeçalhos explicativos adicionados em todos os exemplos que estavam sem
  - Suite de testes expandida: novos casos para `propagate_tags`, `worker_name`, `autoscaling_min`, `autoscaling_max`

## v26.03.23 - 2026-03-24

- **Tooling interno — agentes Claude Code refatorados**
  - Agente `cida` reestruturado: knowledge-base modular em `.claude/agents/cida/knowledge-base/` com 17 arquivos temáticos (anti-patterns, boundary, state, IaC, testes, stack-patterns, etc.) — antes tudo inline no `cida.md`
  - Agente `juca` removido; fontes em `.claude/fontes/` removidas
  - `.claude/make.md` removido (conteúdo absorvido pela Cida)
  - Novo agente `jade` adicionado: especialista em design de interface YAML, READMEs e documentação técnica de módulos Terraform — com knowledge-base própria em `.claude/agents/jade/knowledge-base/`

## v26.03.22 - 2026-03-23

- Blueprint `components/iam-provider` — novo componente para criação de OIDC Identity Providers na AWS
  - Wraps `terraform-aws-modules/iam/aws//modules/iam-oidc-provider` v6.4.0
  - Thumbprint auto-gerenciado via `data "tls_certificate"` (provider `tls = 4.2.1`) — sem variável exposta
  - Interface mínima: `url` (default `https://token.actions.githubusercontent.com`) + `client_id_list` (default `[]`)
  - Validação: `url` deve incluir prefixo `https://`
  - Caso modal GitHub Actions funciona com zero `spec` — apenas `metadata` necessário
  - 2 exemplos YAML: `github-actions` (zero config) e `terraform-cloud` (com `client_id_list: ["aws.workload.identity"]`)
  - Suite de testes com 6 testes em 2 arquivos: `module_behavior`, `variable_validations`
  - Adição de `make test-iam-provider`; `make test-all` atualizado

## v26.03.21 - 2026-03-22

- Blueprint `components/iam-role` — melhorias de interface e validações
  - `extra_statements` renomeado para `extra_trust_statements` — elimina ambiguidade semântica com `inline_policy` (breaking rename, sem callers em prod)
  - `validate_inline_policy` migrado de `terraform_data` precondition para `validation` block em `var.inline_policy` — falha mais cedo, remove recurso do state, permite `expect_failures = [var.inline_policy]` nos testes
  - Nova `validation` block em `var.enable_oidc`: requer ao menos uma URL em `oidc_provider_urls` quando `enable_oidc = true` — previne misconfiguration silenciosa (upstream ignora `enable_oidc = true` com lista vazia sem emitir erro)
  - Descrição de `use_name_prefix` corrigida para português
  - Exemplo `cross-account`: adicionado comentário de segurança sobre uso de `root` com `Condition: aws:PrincipalArn` via `extra_trust_statements`
  - Teste documentando que `create_inline_policy = true` com `inline_policy = []` passa no plan mas falha no apply com `MalformedPolicyDocument`
  - Suite de testes atualizada: 62 testes (eram 59)

## v26.03.20 - 2026-03-22

- Blueprint `components/iam-role` — novo componente para criação de IAM roles
  - Wraps `terraform-aws-modules/iam/aws//modules/iam-role` v6.4.0 com interface simplificada
  - Trust policy construída modularmente em `trust-policy-permissions.tf` — cada tipo de principal (`Service`, `AWS`) gera statement isolado e são concatenados via `concat()`, convertidos para `map` com `coalesce(stmt.sid, tostring(idx))` como chave
  - Suporte a OIDC genérico (`enable_oidc`, `oidc_provider_urls`, `oidc_subjects`, `oidc_wildcard_subjects`, `oidc_audiences`)
  - Suporte a GitHub Actions OIDC (`enable_github_oidc`, `github_provider`) — sem criar OIDC provider (blueprint separada por design)
  - Suporte a managed policies (`policy_arns`), inline policy (`inline_policy` + `create_inline_policy`) e cross-account (`role_arns`)
  - Suporte a EC2 Instance Profile (`create_instance_profile`)
  - Suporte a permissions boundary (`permissions_boundary`) e session duration (`max_session_duration`)
  - **`create_inline_policy` tem `default = false`** — inline policy é opt-in explícito; AWS rejeita policy vazia com `MalformedPolicyDocument`
  - Preconditions: `validate_instance_profile` (EC2 requer `ec2.amazonaws.com`) e `validate_inline_policy` (`inline_policy` requer `create_inline_policy = true`)
  - Validações de variáveis em plan: `name` (64 chars, charset IAM), `description` (1000 chars), `max_session_duration` (3600–43200), `permissions_boundary` (ARN format), `policy_arns` (ARN format), `role_arns` (ARN format), `aws_service_name` (`*.amazonaws.com`), `github_provider` e `oidc_provider_urls` (sem prefixo `https://`)
  - Outputs: `role_arn`, `role_name`, `role_unique_id`, `instance_profile_arn`, `instance_profile_name`, `instance_profile_id`
  - 9 exemplos YAML: `simple`, `ec2-instance-profile`, `cross-account`, `github-actions`, `github-actions-scoped`, `with-managed-policies`, `with-inline-policy`, `with-permissions-boundary`, `oidc-generic`
  - Suite de testes nativos com 59 testes em 4 arquivos: `module_behavior`, `trust_policy_merge`, `locals_merge`, `variable_validations` + fixture `tests/fixtures/locals`
  - Adição de `make test-iam-role`; `make test-all` atualizado

## v26.03.19 - 2026-03-21

- Exemplos de todos os componentes convertidos de `terragrunt.hcl` para YAML (schema `kind` + `version` + `metadata` + `spec`)
  - Componentes cobertos: `sns` (14), `sqs-with-sns` (16), `ecs-cluster` (3), `ecs-worker` (10), `ecs-service` (3), `lambda` (4), `s3-bucket` (9), `vpc`, `instance`, `account-alias`, `kms`, `acm`, `secret-manager`, `route53-zone`, `route53-record`, `s3-global-resources`, `s3-replication-role`, `eks`, `alb`, `nlb`
  - Todos os `terragrunt.hcl` de exemplos removidos — stubs gerados em `aws-config-live` via `tg-init`
  - Ajuste estético: removida linha em branco entre `apiVersion: v1` e `kind:` em todos os YAMLs

## v26.03.18 - 2026-03-21

- Fix

## v26.03.17 - 2026-03-21

- **YAML schema — breaking change:** campos renomeados para alinhar com o padrão do `aws-config-live`
  - `type` → `kind` — nome curto do componente, corresponde diretamente ao diretório em `components/` (ex: `sqs`, `sns`, `sqs-with-sns`)
  - `component_version` → `version`
  - Sem mapeamento necessário: `kind` é o path literal usado no source Terraform (`components/${kind}`)
  - Decisão de design: variações (FIFO, DLQ, KMS) expressas via `spec`, não via kinds distintos; categoria/domínio vive em `metadata` e no IDP

- Blueprint `components/sqs` — exemplos convertidos de `terragrunt.hcl` para `sqs.yml` (schema acima)

## v26.03.16 - 2026-03-18

- Blueprint `components/integrations/sqs-with-sns` — novo blueprint composto
  - Cria SQS + SNS integrados em um único `terraform apply`, eliminando dependência circular entre units no live repo
  - Subscription SNS→SQS gerenciada via `aws_sns_topic_subscription` (fora dos módulos individuais para evitar circularidade)
  - Queue policy gerenciada pelo módulo SQS com acesso ao tópico interno via `sns_access_arns`
  - Suporte a tópicos SNS externos adicionais via `sqs_sns_access_arns`
  - Suporte a produtores S3 via `sqs_s3_access_names`
  - Suporte a statements IAM customizados na queue policy via `sqs_extra_iam_statements`
  - Suporte a statements IAM customizados na topic policy via `sns_extra_iam_statements` (list — alinhado com a interface do blueprint SNS)
  - Suporte a subscriptions adicionais (Lambda, HTTP, email, Firehose, SMS) via `sns_subscriptions`
  - 12 exemplos cobrindo todos os cenários: mínimo, DLQ, FIFO, KMS, tags, raw message, policy customizada, S3 producer, SNS externo, Lambda subscription, topic policy customizada, statements cross-account
  - `components/integrations/README.md` — documenta a categoria, quando usar vs blueprints individuais e decisão de não usar `dependency` blocks
  - **Correção:** removidas variáveis `sns_topic_policy_statements` (map — tipo incompatível com o blueprint SNS) e `default_policy_statements` (bool — input inexistente no blueprint SNS). Substituídas por `sns_extra_iam_statements` (list, alinhado com `extra_iam_statements` do SNS)

## v26.03.15 - 2026-03-18

- Blueprint `components/application-integration/sns`
  - Adição de suporte a tópicos FIFO via `fifo_topic` — sufixo `.fifo` adicionado automaticamente ao nome, seguindo o padrão do blueprint SQS
  - Adição de `content_based_deduplication` para deduplicação por hash de conteúdo em tópicos FIFO
  - Adição de `kms_master_key_id` para criptografia com chave KMS gerenciada pelo cliente
  - Precondition `validate_content_based_deduplication` — impede uso de `content_based_deduplication` sem `fifo_topic = true`
  - Novos exemplos: `fifo`, `fifo-with-deduplication`, `kms`, `fifo-with-kms`, `eventbridge-producer`, `cloudwatch-producer`, `s3-producer`, `budgets-producer`, `extra-iam-statements`, `topic`, `topic-with-policy`, `subscription-lambda`
  - Criação de suite de testes nativos `.tftest.hcl` com 5 arquivos e 66 testes cobrindo: nomenclatura FIFO, geração de policy statements (incluindo resource ARNs e sufixo .fifo), comportamento do módulo, validações de variáveis e resolução automática de endpoints (nome→ARN via mock_data)
  - Adição de target `make test-sns` no Makefile; `make test-all` agora inclui SNS
  - **Correção de bug crítico:** `policy-statements.tf` usava `var.name` nos ARNs dos statements — tópicos FIFO geravam policies com ARN incorreto (sem sufixo `.fifo`). Corrigido para `local.topic_name`
  - **Correção de bug crítico:** exemplos `topic-with-policy` e `subscription-lambda` referenciavam inputs removidos (`topic_policy_statements`, `default_policy_statements`). Reescritos para usar `extra_iam_statements`
  - **Correção de bug:** `extra_iam_statements` com `sid = null` causava chave nula no `topic_policy_statements` map. Corrigido com `coalesce(stmt.sid, tostring(idx))` no `for` expression — mesma correção aplicada ao SQS e às fixtures de teste de ambos
  - Remoção de `enable_default_topic_policy` da interface pública — o módulo upstream usa `true` como default, o que adicionaria um statement implícito fora do controle declarativo do blueprint. O blueprint agora passa `enable_default_topic_policy = false` fixo internamente
  - Correção das descriptions de `event_bridge_arns`, `cloudwatch_arns`, `budgets_arns`, `s3_access_names` e `extra_iam_statements` — descreviam "fila" em vez de "tópico SNS" (copy-paste do SQS)
  - Fixture `tests/fixtures/locals/main.tf` sincronizada com o fix do `coalesce`

- Blueprint `components/application-integration/sqs`
  - **Correção de bug:** `extra_iam_statements` com `sid = null` causava chave nula no `queue_policy_statements` map. Corrigido com `coalesce(stmt.sid, tostring(idx))` em `policy-statements.tf` e fixture de testes
  - Reorganização de `variables.tf`: `sqs_managed_sse_enabled` agrupada com `kms_master_key_id` (criptografia); `create_queue_policy` movida para a seção de permissões; `max_receive_count` reposicionada logo após `create_dlq`; criptografia da DLQ fechando a seção DLQ

## v26.03.14 - 2026-03-17

- Updates

## v26.03.13 - 2026-03-17

- Ajsute de Skill

## v26.03.12 - 2026-03-13

- Blueprint `components/use-case/event-driven-message`
  - Foi removida e talvez volte no futuro

- Blueprint `components/containers/ecs/cluster`
  - Removida variável `container_insights` — container insights agora ela é default `true`
  - Adição de output `container_insights_mode` expondo o modo ativo (`enabled` ou `enhanced`)
  - Remoção de `terraform_data.validate_capacity_provider_weights` — precondition redundante com validação nativa do AWS provider
  - Correção da description de `cluster_capacity_providers` — descrevia estratégia em vez de listar providers disponíveis
  - Uniformização do idioma nas descriptions dos outputs (português)
  - Melhoria dos exemplos: nomes genéricos, comentários inline, `cluster_capacity_providers` explícito no exemplo `fargate-providers`
  - Criação de suite de testes nativos `.tftest.hcl` com 47 testes

## v26.03.11 - 2026-03-12

- Blueprint `components/containers/ecs/service-worker`
  - Correção de bug: substituição de `coalesce` por condicional explícito em `autoscaling_policies.tf` para evitar crash no plan quando nenhuma fila SQS é configurada
  - Correção de bug: adição de suporte a Secrets Manager na execution role — ARNs `arn:aws:secretsmanager:*` passados em `secrets` agora recebem permissão `secretsmanager:GetSecretValue`
  - Adição de precondition para `sqs_messages_scaling` sem fila configurada
  - Adição de precondition para `autoscaling_min` maior que `autoscaling_max`
  - Adição de validação de `log_retention_days` com os valores aceitos pelo CloudWatch Logs
  - Criação de suite de testes nativos `.tftest.hcl` com 65 testes cobrindo comportamento do módulo, políticas IAM, lógica de autoscaling e validações de variáveis
  - Adição de target `make test-service-worker` no Makefile
  - Adição de exemplo `secrets-manager` demonstrando uso combinado de SSM e Secrets Manager
  - Correção dos exemplos existentes: migração do `source` de GitLab para GitHub, correção de `worker_name` no exemplo `s3-processor` e remoção de comentário incorreto no exemplo `cpu-memory-autoscaling`

## v26.03.10 - 2026-03-12

- Blueprint `components/application-integration/sqs`
  - Criação de testes unitários para o blueprint de SQS
  - Refatoração do modelo de políticas para melhor modularização e flexibilidade
  - Refatoração dos exemplos
  - Adicão de novos inputs
- Blueprint `components/containers/ecs/service-worker`
  - Mudança no source do módulo de tags

## v26.03.9 - 2026-03-10

- Blueprint `components/containers/ecs/service-worker`
  - suporte a limites de CPU e memória para sidecar

## v26.03.8 - 2026-03-10

- Blueprint `components/containers/ecs/service-worker`
  - Adição de suporte a sidecar para serviços ECS Worker
  - Ajuste automático do tamanho da task definition com base na quantidade de containers definidos
  - Adição de novos exemplos de configuração para o serviço worker
  - Ajustes no uso das políticas do SSM Parameter Store

## v26.03.7 - 2026-03-08

- Blueprint `components/containers/ecs/service-worker`
  - Adição de novos exemplos de configuração para o serviço worker
  - Separação dos statements de política em blocos distintos para melhor organização
  - Adição de data para assume role do serviço worker

## v26.03.6 - 2026-03-08

- Blueprint `components/containers/ecs/service-worker`
  - Adição de permissões do S3

## v26.03.5 - 2026-03-07

- Blueprint `components/containers/ecs/service-worker`
  - Está diponivel a versão estavel

## v26.03.4 - 2026-03-05

- Blueprint `components/containers/ecs/service-worker`
  - Adição de suporte a autoscaling por backlog de mensagens no SQS

## v26.03.3 - 2026-03-02

- Blueprint `components/containers/ecs/service-worker`
  - adição do modulo de security group para o serviço worker
  - suporte a envariment variables e secrets via SSM Parameter Store
  - novo exemplo de configuração do serviço worker utilizando environment variables e secrets
  - adição de health check simples

## v26.03.2 - 2026-03-01

- Blueprint `components/containers/ecs/service-worker`
  - Exporte do iam service role e task role
  - Exporte do security group do serviço worker
  - refatoração dos outputs
  - refatoração dos exemplos

## v26.03.1 - 2026-03-01

- Blueprint `components/containers/ecs/service-worker`
  - Adição de suporte a autoscaling para serviços ECS Worker
  - Configuração de regras de segurança para tráfego de saída
  - Refatoração da estrutura de inputs para maior flexibilidade
  - adição de perfis de acessos a recursos

## v26.03.0 - 2026-03-01

- Blueprint `components/containers/ecs/service-worker`
  - Update do módulo de ECS para versão `7.3.1`
  - refatoração completa da blueprint de ECS Service Worker
  - Adição de role e políticas para tarefas do ECS Service Worker
  - Configuração de regras de segurança para permitir tráfego de saída

## v26.02.4 - 2026-02-27

- Blueprint `components/containers/ecs/cluster`
  - Adição de suporte a `capacity_provider_strategy` para clusters ECS
  - Exemplo atualizado para demonstrar o uso de Fargate e Fargate Spot como provedores de capacidade
  - Atualização do módulo de ECS para versão `7.3.1`
  - Atualização do modulo de tags para versão `2.1.0`

## v26.02.3 - 2026-02-21

- update do módulo de tags para versão `2.1.0`

## v26.02.2 - 2026-02-16

## v26.02.1 - 2026-02-16

- Blueprint `components/application-integration/sns`
  - Refatoração do input `subscriptions` para aceitar uma lista de objetos com `protocol` e `endpoint`
  - Adição de validação para protocolos de assinatura
  - Atualização do módulo AWS SNS para versão `7.1.0`
  - Ajuste na lógica de políticas padrão para tópicos SNS
  - Adição de tags indicativas para uso de políticas padrão

## v26.02.0 - 2026-02-14

- Blueprint `components/application-integration/sqs`
  - Atualização para versão `5.2.1` do módulo de SQS
  - Refatoração do input `queue_policy_statements` para aceitar um mapa de políticas
  - Adição de suporte a tags para filas SQS e DLQ
  - Novos exemplos de configuração com tags e políticas personalizadas

## v25.04.2 - 2025-04-10

- Blueprint `components/security/secret-manager`
  - Versão inicial criada

## v25.04.1 - 2025-04-06

- Blueprint `components/security/iam/s3-replication-role`
  - Ajustar variaveis de origin e destination bucket
  - Adição de suporte a default tag policy

## v25.04.0 - 2025-04-01

- Blueprint `components/containers/ecs/service`
  - Add suporte as configs do autoscaling

## v25.03.22 - 2025-03-29

- Blueprint `components/security/iam/s3-replication-role`
  - Criação de blueprint para policy e role
  - Criação de assume role para s3 replication
- Blueprint `components/storage/s3/bucket`
  - Adição de suporte a s3 replication

## v25.03.21 - 2025-03-27

- Blueprint `components/containers/ecs/service`
  - Suporte a sidecar implementado
  - Ajuste automatico do tamanho da task definition

## v25.03.20 - 2025-03-26

- Blueprint `components/containers/ecs/service`
  - Removido o suporte a `service_connect_configuration`
  - Removido o suporte a criação de container via `container`
  - Adicionado suporte a criação de containers via `container_definitions`
  - Ajustes no output

## v25.03.19 - 2025-03-26

- Blueprint `components/containers/ecs/service`
  - Suporte a rodar sem um ALB ou NLB via flag

## v25.03.18 - 2025-03-23

- Blueprint `components/containers/ecs/service`
  - Separei o ECS Service do ALB
  - Ajustei os outputs
  - refatorei os datas

## v25.03.17 - 2025-03-22

- Blueprint `components/networking/load-balancer/alb`
  - Criação de blueprint para o alb
- Blueprint `components/networking/load-balancer/nlb`
  - Criação de blueprint para o nlb

## v25.03.16 - 2025-03-21

- Blueprint `components/containers/ecs/service`
  - refatoração da blueprint de ecs service
  - Criando o fluxo completo

## v25.03.15 - 2025-03-17

- Blueprint `components/containers/ecs/cluster`
  - refatoração da blueprint de ecs
  - criação da ecs cluster

## v25.03.14 - 2025-03-16

- Blueprint `components/storage/s3/bucket`
  - Simplificação do lambda subscription
  - Ajustes nas validações das subscriptions

## v25.03.13 - 2025-03-16

- Update do modulo de tags em todas as blueprints
  - Foi ajustado o problema do `created-time`

## v25.03.12 - 2025-03-16

- Blueprint `components/compute/lambda`
  - Adicionada validação em alguns outputs

## v25.03.11 - 2025-03-15

- Blueprint `components/storage/s3/bucket`
  - Adicionada validação em alguns outputs
- Blueprint `components/application-integration/sqs`
  - Adicionada validação nos inputs do SQS e DLQ
- Blueprint `components/application-integration/sns`
  - Adicionado o output para subscriptions
  - Adicionada validação em alguns outputs

## v25.03.10 - 2025-03-15

- Blueprint `components/compute/lambda`
  - Adicionado suporte à criação de aliases para versionamento de funções
  - Novo exemplo de integração com SNS Trigger para disparo de eventos

## v25.03.9 - 2025-03-12

- Blueprint `components/application-integration/sqs`
  - Adicionada flag `disable_default_policy` para controle de políticas padrão
- Blueprint `components/storage/s3/bucket`
  - Adicionada flag `disable_default_policy` para desativar políticas automáticas
- Blueprint `components/compute/lambda`
  - Nova flag `disable_default_policy` para personalização de permissões

## v25.03.8 - 2025-03-09

- Blueprint `components/application-integration/sqs`
  - Refatoração da lógica de políticas padrão para melhor modularização
- Blueprint `components/application-integration/sns`
  - Políticas padrão reestruturadas e flag `disable_default_policy` adicionada
- Blueprint `components/storage/s3/bucket`
  - Melhoria na estruturação das políticas padrão do bucket

## v25.03.7 - 2025-03-08

- Blueprint `components/compute/lambda`
  - Simplificação das políticas padrão para funções Lambda
  - Novo exemplo de configuração com trigger SQS

## v25.03.6 - 2025-03-05

- Blueprint `components/compute/lambda`
  - Suporte à criação automática de políticas padrão
  - Adição de tags específicas para rastreamento de políticas

## v25.03.5 - 2025-03-04

- Blueprint `components/compute/lambda`
  - Versão básica inicial do blueprint
  - Exemplo `simples` adicionado para implantação rápida
  - Controle aprimorado de roles assumidas e grupos de logs

## v25.03.4 - 2025-03-03

## v25.03.3 - 2025-03-03

- Blueprint `components/storage/s3/bucket`
  - Implementação de políticas padrão para buckets
  - Atualização do módulo de tags para compatibilidade com Terraform 1.11
  - Exemplos reformulados com interpolação dinâmica
  - Adição de flag `enable_public_access` para exposição pública
  - Suporte à hospedagem de sites estáticos
- Aprimoramento de documentação e exemplos em todos os blueprints

## v25.03.2 - 2025-03-02

- Blueprint `components/application-integration/sns`
  - Variável `topic_policy_statements` reformulada para maior flexibilidade
  - Políticas padrão para tópicos SNS implementadas
  - Tags indicativas para identificação de políticas padrão
  - Variável `subscriptions` convertida para lista de objetos
- Blueprint `components/security/kms`
  - Versão simplificada para criação de chaves KMS

## v25.03.1 - 2025-03-02

- Padronização do uso de `find_in_parent_folders("root.hcl")` em exemplos
- Atualização de versões:
  - Terragrunt para `0.73.16`
  - Terraform para `1.11.0`
  - Terraform-docs para `0.19.0`
  - Pre-commit hooks atualizados

## v25.03.0 - 2025-03-01

- Blueprint `components/application-integration/sqs`
  - Reversão para módulo de tags padrão do Terraform
  - Políticas padrão para filas SQS e DLQ (Dead Letter Queue)
  - Tags indicativas para uso de políticas padrão

## v25.02.12 - 2025-02-28

- Blueprint `components/application-integration/sqs`
  - Input `queue_policy_statements` ajustado para aceitar lista de políticas
- Blueprint `components/storage/s3/bucket`
  - Inputs `sqs_notifications` e `sns_notifications` agora aceitam nomes e ARNs

## v25.02.11 - 2025-02-25

- Blueprint `components/application-integration/sns`
  - Refatoração do input `topic_policy_statements` para suportar múltiplas assinaturas
  - Suporte a endpoints por nome ou ARN
  - Lógica ajustada: `enable_default_topic_policy` ativa apenas se `topic_policy_statements` estiver vazio
  - Atualização do módulo AWS SNS para versão `6.1.2`
- Blueprint `components/application-integration/sqs`
  - Removida necessidade de `create_queue_policy = true` para criação de políticas

## v25.02.10 - 2025-02-23

- Blueprint `components/storage/s3/bucket`
  - Novos exemplos adicionados:
    - `acl-private`: Configuração de ACL privada
    - `all-notification`: Notificações para SQS, SNS e Lambda
    - `object-ownership`: Controle de propriedade de objetos
    - `public-access`: Bucket com acesso público controlado
    - `with-policy`: Bucket com política personalizada

## v25.02.9 - 2025-02-22

- Correção de regras do Tflint em blueprints

## v25.02.8 - 2025-02-22

- Ajuste na geração de documentação via `terraform-docs`

## v25.02.7 - 2025-02-22

- Adição de documentação automatizada para:
  - Blueprint `components/application-integration/sns`
  - Use-case `components/use-case/event-driven-message`

## v25.02.6 - 2025-02-22

- Novo use-case `event-driven-message` para arquiteturas baseadas em eventos
- Refatoração do blueprint `components/application-integration/sns` para melhor escalabilidade

## v25.02.5 - 2025-02-21

- Criação do diretório `shared` para módulos reutilizáveis
- Tradução de descrições para português em `components/application-integration/sqs`
- Integração do blueprint SQS com módulos compartilhados

## v25.02.4 - 2025-02-21

- Atualização do `Makefile` para suportar novos comandos de automação

## v25.02.3 - 2025-02-21

## v25.02.2 - 2025-02-21

## v25.02.1 - 2025-02-21

- Testes iniciais de funcionalidades do `Makefile`

## v25.02.0 - 2025-02-20

- Blueprint `components/compute/instance`
  - Suporte a `data sources` para consulta de informações de infraestrutura

## v24.10.0 - 2024-10-05

## v24.04.0 - 2024-04-09

- Blueprint `components/containers/ecs`
  - Suporte a configuração HTTPS para serviços ECS

## v24.03.11 - 2024-03-28

- Blueprint `components/security/acm`
  - Criação automatizada de certificados ACM
- Blueprint `components/containers/eks`
  - Ajustes de configuração para clusters EKS

## v24.03.10 - 2024-03-27

- Blueprint `components/containers/eks`
  - Remoção de políticas redundantes no node group

## v24.03.9 - 2024-03-26

- Blueprint `components/networking/route53`
  - Criação de zonas DNS e registros
- Blueprint `components/containers/ecs`
  - Documentação detalhada de implantação
- Blueprint `components/containers/eck`
  - Atualização de parâmetros de configuração

## v24.03.8 - 2024-03-24

- Blueprint `components/containers/eks`
  - Configuração do Cluster Autoscaler para escalonamento automático

## v24.03.7 - 2024-03-22

- Blueprint `components/containers/eks`
  - Adição de Managed Node Groups para worker nodes
- Blueprint `components/containers/ecs`
  - Novos outputs para integração com outros serviços
- Blueprint `components/compute/instance`
  - Configuração de instâncias para Minikube

## v24.03.6 - 2024-03-21

- Blueprint `components/compute/user-data`
  - Scripts de user-data para inicialização de Minikube

## v24.03.5 - 2024-03-21

- Correção de remoção inadvertida de tags em volumes raiz (blueprints de compute)

## v24.03.4 - 2024-03-21

- Ajuste de tags para compliance com políticas de custos

## v24.03.3 - 2024-03-21

- Blueprint `components/compute`
  - Suporte a configuração de disco raiz personalizado
  - Atualização de versões de módulos Terraform

## v24.03.2 - 2024-03-21

- Blueprint `components/containers/ecs`
  - Primeira versão estável com suporte a serviços ECS
  - Exemplos de assinatura em `components/application-integration`

## v24.03.1 - 2024-03-10

- Blueprint `components/application-integration/sns`
  - Suporte a assinaturas SQS para tópicos SNS

## v24.03.0 - 2024-03-08

- Blueprint `components/application-integration/sns`
  - Implementação inicial de tópicos SNS
- Blueprint `components/application-integration/sqs`
  - Novos exemplos de configuração de filas

## v23.12.0 - 2023-12-06

- Apresentação interna da estrutura de blueprints para o time

## v23.11.9 - 2023-11-13

- Blueprint `components/compute/instance`
  - Nova variável `additional_ingress_with_cidr_blocks` para regras de segurança

## v23.11.8 - 2023-11-12

- Blueprint `components/compute/user-data`
  - Instalação automática do Docker via scripts de inicialização

## v23.11.7 - 2023-11-06

- Terceira iteração de testes de integração contínua com GitLab

## v23.11.6 - 2023-11-06

- Segunda fase de testes de CI/CD no GitLab

## v23.11.5 - 2023-11-06

- Integração inicial do pipeline com GitLab

## v23.11.4 - 2023-11-05

- Movimento de scripts para o diretório `_bin` para organização

## v23.11.3 - 2023-11-04

- Reformulação do pipeline de CI para estágios paralelos
- Adição de verificação de segredos com GitGuardian

## v23.11.2 - 2023-11-02

- Blueprint `components/application-integration/sns`
  - Versão inicial de tópicos SNS
- Blueprint `components/compute/instance`
  - Regra de segurança para acesso via IP do usuário

## v23.11.1 - 2023-11-01

- Breaking change: Reestruturação de diretórios para padronização

## v23.11.0 - 2023-11-01

- Blueprint `components/application-integration/sqs`
  - Implementação inicial de filas SQS
- Renomeação do exemplo `VPC Simple` para `Default` em `components/networking/vpc/examples`

## v23.10.8 - 2023-10-31

- Blueprint `components/compute/instance`
  - Suporte a scripts customizados via user-data

## v23.10.7 - 2023-10-29

- Blueprint `components/compute/instance`
  - Integração com outputs de VPC (subnets, security groups)
- Blueprint `components/networking/vpc`
  - Criação de VPCs com configuração básica

## v23.10.6 - 2023-10-28

- Blueprint `components/compute/instance`
  - Primeira versão para criação de instâncias EC2

## v23.10.5 - 2023-10-28

- Blueprint `components/storage/s3`
  - Implementação inicial de buckets S3

## v23.10.4 - 2023-10-27

- Blueprint `components/null`
  - Módulo placeholder para operações de depuração

## v23.10.3 - 2023-10-27

- Blueprint `components/organizations/account-alias`
  - Configuração inicial de alias para contas AWS

## v23.10.2 - 2023-10-27

- Finalização da configuração base do repositório

## v23.10.1 - 2023-10-27

- Inicialização do repositório com estrutura básica de blueprints
