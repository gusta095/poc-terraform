#!/usr/bin/env bash
# tg-run.sh — Roda um comando terragrunt em todos os subdiretórios com terragrunt.hcl

set -euo pipefail

# ── constantes ────────────────────────────────────────────────────────────────
readonly VERSION="1.0.0"

readonly BOLD='\033[1m'
readonly CYAN='\033[1;36m'
readonly GREEN='\033[1;32m'
readonly RED='\033[1;31m'
readonly YELLOW='\033[1;33m'
readonly RESET='\033[0m'

# ── estado global ─────────────────────────────────────────────────────────────
TG_CMD=""
TARGET_DIR=""
LOG_FILE=""
PARALLEL_LIMIT=0  # 0 = sequencial; -1 = ilimitado; >0 = máximo de jobs em paralelo
STATUS_DIR=""     # diretório temporário do modo paralelo, limpo no EXIT
PAT_ADD="" PAT_CHANGE="" PAT_DESTROY=""
LBL_ADD="" LBL_CHANGE="" LBL_DESTROY=""

DIRS=()
SUCCEEDED=()
FAILED=()
TOTAL_ADD=0
TOTAL_CHANGE=0
TOTAL_DESTROY=0
declare -A DIR_ADD DIR_CHANGE DIR_DESTROY

# Usados pelo modo paralelo (globais para permitir launch_job como função top-level)
declare -A PID_TO_REL PID_TO_SAFE PID_TO_LOG
RUNNING_PIDS=()

# ─────────────────────────────────────────────────────────────────────────────

# Escreve no log sem códigos ANSI — chamado sempre após o echo correspondente
log() {
  [[ -z "$LOG_FILE" ]] && return
  echo -e "$*" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        echo -e "Uso: tg-run [opções] <comando> <diretório>"
        echo ""
        echo -e "Comandos:  plan | apply | destroy | output | ..."
        echo -e "Diretório: caminho relativo ou absoluto contendo subdiretórios com terragrunt.hcl"
        echo ""
        echo -e "Opções:"
        echo -e "  -h, --help     Exibe esta mensagem"
        echo -e "  -v, --version  Exibe a versão"
        echo -e "  -l, --logs     Gera arquivo de log em \$PWD (ex: tg-run-plan-20260319-143022.log)"
        echo -e "  -p [n]         Executa em paralelo: sem número = ilimitado; com número = máximo de jobs (ex: -p 4)"
        echo ""
        echo -e "Exemplos:"
        echo -e "  tg-run plan      accounts/gusta-labs/sandbox/us-east-1/services/next-step"
        echo -e "  tg-run -l apply  accounts/gusta-labs/sandbox/us-east-1/services/next-step"
        echo -e "  tg-run -p plan   accounts/gusta-labs/sandbox/us-east-1/services/next-step"
        echo -e "  tg-run destroy   ."
        exit 0
        ;;
      -v|--version)
        echo "tg-run v${VERSION}"
        exit 0
        ;;
      -l|--logs)
        # Arquivo criado no diretório onde o comando foi executado, não em TARGET_DIR,
        # para que os logs fiquem acessíveis independente do escopo do plan/apply
        LOG_FILE="${PWD}/tg-run-$(date +%Y%m%d-%H%M%S).log"
        ;;
      -p|--parallel)
        # Aceita número opcional: -p (ilimitado) ou -p 4 (máximo 4)
        if [[ -n "${2:-}" && "${2:-}" =~ ^[1-9][0-9]*$ ]]; then
          PARALLEL_LIMIT=$2
          shift
        else
          PARALLEL_LIMIT=-1
        fi
        ;;
      -*)
        echo -e "${RED}❌ Opção desconhecida: $1${RESET}" >&2
        echo -e "   Use -h para ver as opções disponíveis." >&2
        exit 1
        ;;
      *)
        if [[ -z "$TG_CMD" ]]; then
          TG_CMD=$1
        elif [[ -z "$TARGET_DIR" ]]; then
          TARGET_DIR=$1
        fi
        ;;
    esac
    shift
  done
}

validate_inputs() {
  if [[ $PARALLEL_LIMIT -ne 0 && "${BASH_VERSINFO[0]}" -lt 5 ]]; then
    echo -e "${RED}❌ modo paralelo requer bash 5+ (atual: ${BASH_VERSION})${RESET}" >&2
    exit 1
  fi

  if [[ -z "$TG_CMD" || -z "$TARGET_DIR" ]]; then
    echo -e "${YELLOW}Uso: tg-run [opções] <comando> <diretório>${RESET}" >&2
    echo -e "  Use -h para ver as opções disponíveis." >&2
    exit 1
  fi

  if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${RED}❌ Diretório não encontrado: $TARGET_DIR${RESET}" >&2
    exit 1
  fi

  case "$TG_CMD" in
    plan)
      PAT_ADD="to add";  PAT_CHANGE="to change";  PAT_DESTROY="to destroy"
      LBL_ADD="add";     LBL_CHANGE="change";      LBL_DESTROY="destroy"
      ;;
    apply|destroy)
      PAT_ADD="added";   PAT_CHANGE="changed";     PAT_DESTROY="destroyed"
      LBL_ADD="added";   LBL_CHANGE="changed";     LBL_DESTROY="destroyed"
      ;;
    *)
      PAT_ADD="";        PAT_CHANGE="";            PAT_DESTROY=""
      LBL_ADD="added";   LBL_CHANGE="changed";     LBL_DESTROY="destroyed"
      ;;
  esac

  if [[ -n "$LOG_FILE" ]]; then
    local account="${AWS_PROFILE:-}"
    local region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
    {
      echo "tg-run v${VERSION}"
      echo "date:      $(date '+%Y-%m-%d %H:%M:%S')"
      echo "command:   terragrunt ${TG_CMD}"
      echo "directory: ${TARGET_DIR}"
      echo "account:   ${account}"
      echo "region:    ${region}"
      echo "──────────────────────────────────────────────────────────────"
    } >> "$LOG_FILE"
    echo -e "${CYAN}📄 log: ${LOG_FILE}${RESET}"
  fi
}

discover_dirs() {
  mapfile -t DIRS < <(
    find "$TARGET_DIR" -name "terragrunt.hcl" -not -path "*/.terragrunt-cache/*" -print0 \
      | xargs -0 -I{} dirname {} | sort -u
  )

  if [[ ${#DIRS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  Nenhum terragrunt.hcl encontrado em: $TARGET_DIR${RESET}"
    exit 0
  fi
}

confirm_destructive() {
  echo -e "${YELLOW}⚠️  Você está prestes a executar: ${BOLD}terragrunt ${TG_CMD}${RESET}${YELLOW} em ${#DIRS[@]} diretório(s):${RESET}"
  for dir in "${DIRS[@]}"; do
    local rel="${dir#"$TARGET_DIR"/}"
    [[ -z "$rel" ]] && rel="."
    echo -e "  ${CYAN}• ${rel}${RESET}"
  done
  echo ""
  local answer
  printf "${BOLD}Confirmar? [y/N]${RESET} "
  read -r answer
  case "$answer" in
    [yY][eE][sS]|[yY]) ;;
    *)
      echo -e "${YELLOW}Cancelado.${RESET}"
      exit 0
      ;;
  esac
  echo ""
}

parse_output() {
  local pattern=$1 file=$2
  # grep pode retornar exit 1 quando não há matches (ex: "No changes") —
  # || true garante que o pipeline não quebre o script via set -euo pipefail
  { grep -oE "[0-9]+ ${pattern}" "$file" || true; } | awk '{sum += $1} END {print sum+0}'
}

print_header() {
  local mode=""
  if [[ $PARALLEL_LIMIT -eq -1 ]]; then
    mode=" — ${YELLOW}paralelo (ilimitado)${RESET}"
  elif [[ $PARALLEL_LIMIT -gt 0 ]]; then
    mode=" — ${YELLOW}paralelo (limit: ${PARALLEL_LIMIT})${RESET}"
  fi

  local msg="\n${BOLD}🚀 terragrunt ${TG_CMD}${RESET} — ${CYAN}${TARGET_DIR}${RESET}${mode}"
  local count="${BOLD}   ${#DIRS[@]} diretório(s) encontrado(s)${RESET}\n"
  echo -e "$msg"
  echo -e "$count"
  log "$msg"
  log "$count"
}

run_dir() {
  local dir=$1 rel=$2 current=$3 total=$4

  local header="──────────────────────────────────────────────────────────────"
  local label="${CYAN}▶ ${rel}${RESET} ${BOLD}(${current}/${total})${RESET}"
  echo -e "$header"
  echo -e "$label"
  echo -e "$header"
  log "$header"
  log "▶ ${rel} (${current}/${total})"
  log "$header"

  local tmpfile
  tmpfile=$(mktemp)

  # set -e desabilitado aqui porque terragrunt pode falhar intencionalmente (ex: plan com diff);
  # PIPESTATUS captura o exit code do subshell antes do tee, que sempre retorna 0
  set +e
  (cd "$dir" && terragrunt "$TG_CMD") 2>&1 | tee "$tmpfile"
  local tg_exit
  tg_exit=${PIPESTATUS[0]}
  set -e

  # Strip ANSI antes de escrever no log para garantir legibilidade
  [[ -n "$LOG_FILE" ]] && sed 's/\x1b\[[0-9;]*m//g' "$tmpfile" >> "$LOG_FILE"

  if [[ $tg_exit -eq 0 ]]; then
    SUCCEEDED+=("$rel")

    if [[ -n "$PAT_ADD" ]]; then
      DIR_ADD[$rel]=$(parse_output    "$PAT_ADD"     "$tmpfile")
      DIR_CHANGE[$rel]=$(parse_output "$PAT_CHANGE"  "$tmpfile")
      DIR_DESTROY[$rel]=$(parse_output "$PAT_DESTROY" "$tmpfile")
      TOTAL_ADD=$((TOTAL_ADD         + DIR_ADD[$rel]))
      TOTAL_CHANGE=$((TOTAL_CHANGE   + DIR_CHANGE[$rel]))
      TOTAL_DESTROY=$((TOTAL_DESTROY + DIR_DESTROY[$rel]))
    fi

    echo -e "\n${GREEN}✅ $rel${RESET}\n"
    log "\n✅ $rel\n"
  else
    FAILED+=("$rel")
    echo -e "\n${RED}❌ $rel${RESET}\n"
    log "\n❌ $rel\n"
  fi

  rm -f "$tmpfile"
}

# Lança um job em background para o modo paralelo.
# Armazena o PID e metadados nos mapas globais PID_TO_*.
launch_job() {
  local dir=$1 rel=$2 safe=$3 job_log=$4 result_file=$5
  (
    set +e
    (cd "$dir" && terragrunt "$TG_CMD") 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$job_log"
    local tg_exit
    tg_exit=${PIPESTATUS[0]}
    set -e

    local add=0 change=0 destroy=0
    if [[ -n "$PAT_ADD" ]]; then
      add=$(parse_output     "$PAT_ADD"     "$job_log")
      change=$(parse_output  "$PAT_CHANGE"  "$job_log")
      destroy=$(parse_output "$PAT_DESTROY" "$job_log")
    fi

    # Result file é escrito por último — parent usa sua existência para detectar conclusão
    echo "$tg_exit $add $change $destroy" > "$result_file"
  ) &

  local pid=$!
  PID_TO_REL[$pid]="$rel"
  PID_TO_SAFE[$pid]="$safe"
  PID_TO_LOG[$pid]="$job_log"
  RUNNING_PIDS+=("$pid")
}

run_all_parallel() {
  local total=${#DIRS[@]}
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)

  STATUS_DIR=$(mktemp -d)
  trap '[[ -n "$STATUS_DIR" ]] && rm -rf "$STATUS_DIR"' EXIT

  # Fila de pendentes — usada pelo produtor-consumidor quando há limite
  local pending=("${DIRS[@]}")
  local remaining=$total

  # ── lançar jobs: todos de uma vez (-1) ou respeitando o limite (>0) ─────────
  if [[ $PARALLEL_LIMIT -eq -1 ]]; then
    for dir in "${DIRS[@]}"; do
      local rel="${dir#"$TARGET_DIR"/}"
      [[ -z "$rel" ]] && rel="."
      local safe="${rel//\//-}"
      local job_log="${PWD}/tg-run-${TG_CMD}-${safe}-${timestamp}.log"
      launch_job "$dir" "$rel" "$safe" "$job_log" "${STATUS_DIR}/${safe}.result"
      echo -e "  ${CYAN}▶ ${rel}${RESET} iniciado"
    done
    pending=()  # todos lançados — esvazia fila para o loop produtor-consumidor encerrar corretamente
    echo ""
  fi

  # ── loop produtor-consumidor (polling + lançamento sob demanda) ──────────────
  # Usado sempre: quando ilimitado, pending estará vazio desde o início;
  # quando com limite, lança novos jobs conforme slots ficam livres
  while [[ ${#pending[@]} -gt 0 || ${#RUNNING_PIDS[@]} -gt 0 ]]; do

    # Preencher slots disponíveis (só entra aqui quando PARALLEL_LIMIT > 0)
    while [[ ${#pending[@]} -gt 0 && $PARALLEL_LIMIT -gt 0 && ${#RUNNING_PIDS[@]} -lt $PARALLEL_LIMIT ]]; do
      local dir="${pending[0]}"
      pending=("${pending[@]:1}")
      local rel="${dir#"$TARGET_DIR"/}"
      [[ -z "$rel" ]] && rel="."
      local safe="${rel//\//-}"
      local job_log="${PWD}/tg-run-${TG_CMD}-${safe}-${timestamp}.log"
      launch_job "$dir" "$rel" "$safe" "$job_log" "${STATUS_DIR}/${safe}.result"
      echo -e "  ${CYAN}▶ ${rel}${RESET} iniciado  (${#RUNNING_PIDS[@]}/${PARALLEL_LIMIT} slots)"
    done

    # Bloqueia até qualquer job terminar — elimina polling ativo com sleep
    wait -n

    local completed=()
    local still_running=()

    for pid in "${RUNNING_PIDS[@]}"; do
      local safe="${PID_TO_SAFE[$pid]}"
      if [[ -f "${STATUS_DIR}/${safe}.result" ]]; then
        completed+=("$pid")
      else
        still_running+=("$pid")
      fi
    done

    local still_names=()
    for p in "${still_running[@]+"${still_running[@]}"}"; do
      still_names+=("${PID_TO_REL[$p]}")
    done

    for pid in "${completed[@]}"; do
      wait "$pid" 2>/dev/null || true

      local rel="${PID_TO_REL[$pid]}"
      local job_log="${PID_TO_LOG[$pid]}"
      local safe="${PID_TO_SAFE[$pid]}"

      local tg_exit add change destroy
      read -r tg_exit add change destroy < "${STATUS_DIR}/${safe}.result"

      remaining=$((remaining - 1))

      local rodando=""
      if [[ ${#still_names[@]} -gt 0 ]]; then
        local running_str
        running_str=$(IFS=', '; echo "${still_names[*]}")
        rodando="  ⏳ rodando: [${running_str}]"
      fi

      if [[ $tg_exit -eq 0 ]]; then
        SUCCEEDED+=("$rel")
        DIR_ADD[$rel]=$add
        DIR_CHANGE[$rel]=$change
        DIR_DESTROY[$rel]=$destroy
        TOTAL_ADD=$((TOTAL_ADD       + add))
        TOTAL_CHANGE=$((TOTAL_CHANGE + change))
        TOTAL_DESTROY=$((TOTAL_DESTROY + destroy))

        if [[ -n "$PAT_ADD" ]]; then
          echo -e "  ${GREEN}✅ ${rel}${RESET} — ${LBL_ADD}: ${GREEN}${add}${RESET}  ${LBL_CHANGE}: ${YELLOW}${change}${RESET}  ${LBL_DESTROY}: ${RED}${destroy}${RESET}  (${remaining} restando)${rodando}"
        else
          echo -e "  ${GREEN}✅ ${rel}${RESET}  (${remaining} restando)${rodando}"
        fi
        log "  ✅ ${rel} — ${LBL_ADD}: ${add}  ${LBL_CHANGE}: ${change}  ${LBL_DESTROY}: ${destroy}"
      else
        FAILED+=("$rel")
        echo -e "  ${RED}❌ ${rel} — falhou${RESET}  (${remaining} restando)${rodando}"
        log "  ❌ ${rel} — falhou"
      fi

      echo -e "     ${CYAN}📄 ${job_log}${RESET}"
      log "     📄 ${job_log}"
    done

    RUNNING_PIDS=("${still_running[@]+"${still_running[@]}"}")
  done

  echo ""
}

print_summary() {
  local account="${AWS_PROFILE:-}"
  local region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"

  local separator="══════════════════════════════════════════════════════════════"
  local title="Summary — terragrunt ${TG_CMD} — ${account} — ${region}"

  echo -e "$separator"
  echo -e "${BOLD}${title}${RESET}"
  echo -e "$separator"
  log "$separator"
  log "$title"
  log "$separator"

  for d in "${SUCCEEDED[@]}"; do
    if [[ -n "$PAT_ADD" ]]; then
      echo -e "  ${GREEN}✅ $d${RESET} — ${LBL_ADD}: ${GREEN}${DIR_ADD[$d]}${RESET}  ${LBL_CHANGE}: ${YELLOW}${DIR_CHANGE[$d]}${RESET}  ${LBL_DESTROY}: ${RED}${DIR_DESTROY[$d]}${RESET}"
      log "  ✅ $d — ${LBL_ADD}: ${DIR_ADD[$d]}  ${LBL_CHANGE}: ${DIR_CHANGE[$d]}  ${LBL_DESTROY}: ${DIR_DESTROY[$d]}"
    else
      echo -e "  ${GREEN}✅ $d${RESET}"
      log "  ✅ $d"
    fi
  done

  for d in "${FAILED[@]}"; do
    echo -e "  ${RED}❌ $d${RESET}"
    log "  ❌ $d"
  done

  if [[ -n "$PAT_ADD" ]]; then
    echo ""
    echo -e "  Resource status   — ${LBL_ADD}: ${GREEN}${TOTAL_ADD}${RESET}  ${LBL_CHANGE}: ${YELLOW}${TOTAL_CHANGE}${RESET}  ${LBL_DESTROY}: ${RED}${TOTAL_DESTROY}${RESET}"
    log ""
    log "  Resource status   — ${LBL_ADD}: ${TOTAL_ADD}  ${LBL_CHANGE}: ${TOTAL_CHANGE}  ${LBL_DESTROY}: ${TOTAL_DESTROY}"
  fi

  echo ""
  echo -e "  Components status — Sucesso: ${GREEN}${#SUCCEEDED[@]}${RESET}   Failure: ${RED}${#FAILED[@]}${RESET}"
  echo ""
  log ""
  log "  Components status — Sucesso: ${#SUCCEEDED[@]}   Failure: ${#FAILED[@]}"
  log ""
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  validate_inputs
  discover_dirs

  [[ "$TG_CMD" == "apply" || "$TG_CMD" == "destroy" ]] && confirm_destructive

  print_header

  if [[ $PARALLEL_LIMIT -ne 0 ]]; then
    run_all_parallel
  else
    local total=${#DIRS[@]}
    local current=0

    for dir in "${DIRS[@]}"; do
      local rel="${dir#"$TARGET_DIR"/}"
      [[ -z "$rel" ]] && rel="."
      current=$((current + 1))
      run_dir "$dir" "$rel" "$current" "$total"
    done
  fi

  print_summary

  [[ ${#FAILED[@]} -gt 0 ]] && exit 1
  exit 0
}

main "$@"
