# AWS Config Live

Repositório de infraestrutura AWS gerenciado com [Terragrunt](https://terragrunt.gruntwork.io/). Segue o padrão [gruntwork-io/terragrunt-infrastructure-live-stacks-example](https://github.com/gruntwork-io/terragrunt-infrastructure-live-stacks-example) e consome componentes do repositório [terraform-aws-blueprints](https://github.com/gusta-lab/terraform-aws-blueprints).

## Estrutura

```
root.hcl                          # Config global: provider, backend S3, retry logic
_templates/
  aws-provider.tpl                # Template do provider AWS
accounts/
  gusta-labs/
    sandbox/
      account.hcl                 # Vars de conta: account_id, environment, vpc_name, Route53
      _global/                    # Recursos não-regionais
        account-alias/
        route53/zone/
        route53/record/
        service.hcl
      us-east-1/
        region.hcl                # Vars de região: aws_region
        shared/                   # Infraestrutura compartilhada: VPC, ACM
          vpc/
          acm-certificate/
          service.hcl
        services/                 # Serviços — um subdiretório por workload
          <service>/
            service.hcl           # Tags do serviço
            <component>/
              terragrunt.hcl
```

## Hierarquia de configuração

O Terragrunt herda variáveis de baixo para cima via `find_in_parent_folders()`:

```
root.hcl → account.hcl → region.hcl → service.hcl → terragrunt.hcl
```

Cada `terragrunt.hcl` declara qual componente usa e em qual versão:

```hcl
locals {
  component_name    = "components/networking/vpc"
  component_version = "23.10.7"
}

terraform {
  source = "git::https://github.com/gusta-lab/terraform-aws-blueprints.git//components/networking/vpc?ref=v23.10.7"
}
```

## Decisões arquiteturais

### Uso restrito de `dependency` blocks

`dependency` blocks do Terragrunt são usados apenas para acoplamentos **estruturais** — onde um recurso literalmente não existe sem o outro:

- ✅ ECS → VPC (serviço precisa de subnets para existir)
- ✅ EKS → VPC (cluster precisa de subnets para existir)
- ❌ SNS → SQS (integração de aplicação, não dependência estrutural)

**Por quê:** `dependency` blocks entre recursos de integração (ex: SNS + SQS) criam dependência circular, exigem `mock_outputs`, poluem o código e acoplam unidades que deveriam ser independentes. Esse tipo de integração pertence ao blueprint, não à camada de orquestração.

### Complexidade fica nos blueprints, não nas units

Toda lógica de negócio, validação, segurança e integração entre recursos fica encapsulada nos blueprints do repositório `terraform-aws-blueprints`. As units do `aws-config-live` são declarativas e simples — apenas declaram o que querem, não como fazer.

**Por quê:** Mantém o live repo legível e auditável. Quem olha uma unit deve entender o que está sendo criado sem precisar entender a implementação.

### Recursos integrados por natureza usam blueprints compostos

Quando dois recursos são sempre usados juntos (ex: SNS + SQS para event-driven), a solução é um blueprint composto (`event-driven`) que chama os blueprints individuais como módulos Terraform — sem duplicar código, sem circular dependency.

**Por quê:** Evita a complexidade de orquestrar múltiplas units com dependências entre si. O blueprint composto resolve o acoplamento internamente.

### Terragrunt Stacks — avaliado e descartado para o padrão geral

Stacks foram avaliadas como mecanismo de orquestração para grupos de units relacionadas. A conclusão foi que transferem a complexidade de coordenação para o usuário do live repo, exigem conhecimento do grafo de dependências e tornam o código menos legível.

**Exceção:** Stacks podem fazer sentido para deploys de ambientes completos (bootstrap de conta) onde a ordem de centenas de resources precisa ser gerenciada.

## Comandos

```bash
make lint        # Roda todos os pre-commit hooks
make fmt         # Formata todos os arquivos HCL
make fmt-check   # Verifica formatação HCL (sem aplicar)
make clean-cache # Remove .terraform e .terragrunt-cache
```
