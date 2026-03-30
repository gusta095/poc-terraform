# TODOs — ecs/cluster

Prioridades identificadas na análise de maturidade do componente.
Referência: componente SQS e service-worker como baseline de maturidade.

Nível atual estimado: **3/5** — código limpo e funcional, validações básicas presentes,
mas exemplos com bugs, outputs incompletos e zero cobertura de testes.

---

## P0 — Bugs

### 1. Exemplo `simples` usa input inexistente no componente
**Arquivo:** `examples/simples/terragrunt.hcl`

O exemplo usa `fargate_capacity_providers` que **não existe** como variável neste componente.
É um input do módulo upstream (`terraform-aws-modules/ecs`) que não foi exposto.
Um cliente que copiar este exemplo vai receber erro no apply.

Os inputs corretos do componente são `cluster_capacity_providers` e `default_capacity_provider_strategy`.

**Fix esperado:** Reescrever o exemplo usando os inputs corretos do componente.

---

## P1 — Qualidade / Validações

### 2. `cloudwatch_log_group_retention_in_days` sem validação
**Arquivo:** `variables.tf:35`

CloudWatch Logs aceita apenas valores específicos (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653).
Qualquer outro valor falha no apply com erro obscuro do provider.
O default atual é `30` (válido), mas nada impede um valor inválido.

**Fix esperado:** `validation` block com `contains([...], var.cloudwatch_log_group_retention_in_days)`.
Padrão já aplicado em `service-worker/variables.tf:log_retention_days`.

### 3. `default_capacity_provider_strategy` sem validação cruzada com `cluster_capacity_providers`
**Arquivo:** `variables.tf:76`

Se o usuário define uma strategy para `FARGATE_SPOT` mas não inclui `FARGATE_SPOT` em
`cluster_capacity_providers`, o apply falha com erro genérico do provider.

**Fix esperado:** `terraform_data` precondition verificando que todas as chaves de
`default_capacity_provider_strategy` estão presentes em `cluster_capacity_providers`:
```hcl
condition = alltrue([
  for cp in keys(var.default_capacity_provider_strategy) :
  contains(var.cluster_capacity_providers, cp)
])
error_message = "Todos os capacity providers em default_capacity_provider_strategy devem estar listados em cluster_capacity_providers."
```

### 4. `base` e `weight` em `default_capacity_provider_strategy` sem validação de range
**Arquivo:** `variables.tf:79`

Os campos `base` e `weight` aceitam qualquer número — incluindo negativos. A AWS rejeita
valores negativos no apply.

**Fix esperado:** Após resolver como fazer validação dentro de `object` com campos `optional`,
considerar `terraform_data` precondition verificando que todos os valores são `>= 0`.

---

## P2 — Outputs incompletos

### 5. CloudWatch Log Group não exportado
**Arquivo:** `outputs.tf`

O componente cria e gerencia o log group do cluster, mas não exporta nem o nome nem o ARN.
Outros componentes (ex: dashboards, alertas) que precisem referenciar o log group não
conseguem obtê-lo sem hardcode.

**Fix esperado:**
```hcl
output "cloudwatch_log_group_name" {
  value = module.ecs_cluster.cloudwatch_log_group_name
}

output "cloudwatch_log_group_arn" {
  value = module.ecs_cluster.cloudwatch_log_group_arn
}
```
---

## P3 — Consistência

### 6. Exemplos apontando para GitLab
**Arquivos:** `examples/config-insights/terragrunt.hcl`, `examples/simples/terragrunt.hcl`

Source ainda usa `gitlab.com`. Migrar para GitHub seguindo o padrão atual do repo.
O exemplo `fartage-providers` não tem bloco `terraform { source = ... }` — inconsistente.

**Fix esperado:** Padronizar todos os exemplos com:
```
source = "git::ssh://git@github.com/gusta095/terraform-aws-blueprints.git//components/containers/ecs/cluster?ref=vCHANGEME"
```

### 7. Typo no nome do exemplo `fartage-providers`
**Diretório:** `examples/fartage-providers/`

Nome deveria ser `fargate-providers`.

**Fix esperado:** Renomear o diretório.

### 8. Source do módulo de tags aponta para GitLab
**Arquivo:** `main.tf:6`

```hcl
# atual (inconsistente)
source = "git::ssh://git@gitlab.com/gusta-lab/terraform/aws/modules/tags.git?ref=v2.1.0"

# esperado
source = "git::ssh://git@github.com/gusta095/terraform-aws-module-tags.git?ref=v2.1.0"
```

---

## P4 — Testes nativos (após P0-P3 resolvidos)

### 9. Zero cobertura de testes `.tftest.hcl`

Componente simples, mas com lógica de observabilidade e capacity providers que merece cobertura.
Suite sugerida seguindo a estrutura do SQS e service-worker:

| Arquivo | O que cobre |
|---|---|
| `module_behavior.tftest.hcl` | container_insights, enhanced_observability, FARGATE_SPOT only, config completa |
| `variable_validations.tftest.hcl` | cluster_name inválido, ambos insights ligados, capacity provider inválido, log_retention inválido, strategy sem provider correspondente |
| `locals.tftest.hcl` (via fixture) | container_insights_value: disabled/enabled/enhanced |

**Nota:** Componente simples — fixture de locals reduzida, ~20-25 testes devem atingir cobertura alta.
