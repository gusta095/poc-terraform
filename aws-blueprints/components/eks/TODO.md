# Todo

  Sequência que eu seguiria:

  1. eks blueprint  →  cluster só control plane  (já feito)
  2. managed-node-group blueprint  →  1 on-demand pequeno (bootstrap)
  3. ArgoCD  →  via Helm no node de bootstrap
  4. App-of-apps no ArgoCD  →  declara Karpenter, KEDA, ExternalDNS
  5. Karpenter NodePool  →  on-demand p/ sistema, spot p/ workloads
  6. Remove o managed node group de bootstrap (opcional)
