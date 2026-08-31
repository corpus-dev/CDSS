# shellcheck shell=bash
set -uo pipefail

env_file="/etc/environment"

source "${SCRIPT_DIR}/utils/platform_matrix.sh"

read_env_value() {
  local key="$1"
  if [[ ! -f "$env_file" ]]; then
    echo ""
    return 1
  fi
  local value
  value=$(grep "^${key}=" "$env_file" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '"' | tr -d "'")
  echo "$value"
}

write_env_value() {
  local key="$1"
  local value="$2"
  local tmp_file
  tmp_file=$(mktemp)

  if [[ -f "$env_file" ]]; then
    grep -v "^${key}=" "$env_file" > "$tmp_file" 2>/dev/null || true
  else
    touch "$tmp_file"
  fi

  echo "${key}=\"${value}\"" >> "$tmp_file"
  sudo_or_root mv -f "$tmp_file" "$env_file"
  sudo_or_root chmod 644 "$env_file"
}

check_updates() {
  local deployment_version
  deployment_version=$(read_env_value "CDSS_DEPLOYMENT_VERSION")
  if [[ -z "$deployment_version" ]]; then
    prepare_for_update
  else
    local timestamp
    timestamp=$(date +%s)
    local diff=$((timestamp - deployment_version))
    local five_minutes=300
    if [[ $diff -gt $five_minutes ]]; then
      prepare_for_update
    fi
  fi
}

prepare_for_update() {
  echo -e "${GREEN}$(trans "Перевіряємо наявність оновлень")${NC}"
  ensure_canonical_update_sources || true
  local raw_base_url="${CDSS_RAW_BASE_URL:-https://raw.githubusercontent.com/corpus-dev/CDSS/main}"
  local remote_version
  remote_version=$(curl -s --fail --location --show-error --connect-timeout 10 --max-time 60 "${raw_base_url}/version.txt" 2>/dev/null)

  if [[ -z "$remote_version" ]]; then
    echo -e "${RED}$(trans "Не вдалося отримати версію з сервера. Перевірте мережу.")${NC}"
    write_version "$(date +%s)"
    sleep 2
    return 1
  fi

  echo -e "$(trans "Актуальна версія") = ${ORANGE}${remote_version}${NC}"

  local local_version=""
  if [[ -f "${SCRIPT_DIR}/version.txt" ]]; then
    local_version=$(cat "${SCRIPT_DIR}/version.txt")
  fi

  if [[ "$local_version" == "$remote_version" ]]; then
    echo -e "${GREEN}$(trans "Встановлена остання версія")${NC}"
    write_version "$(date +%s)"
    sleep 2
    return 0
  fi

  if ! backup_module_settings; then
    return 1
  fi

  local update_status=0
  if update_cdss; then
    merge_environment_file || true
    CDSS_UPDATED=1
    write_version "$(date +%s)"
  else
    update_status=1
  fi
  sleep 2
  return "$update_status"
}

write_version() {
  write_env_value "CDSS_DEPLOYMENT_VERSION" "$1"
}

get_cdss_upstream_url() {
  echo "${CDSS_GIT_URL:-https://github.com/corpus-dev/CDSS.git}"
}

is_local_git_url() {
  local url="${1:-}"
  [[ -n "$url" ]] || return 1
  case "$url" in
    /*) return 0 ;;
    file://*) return 0 ;;
    *localhost*) return 0 ;;
    *127.0.0.1*) return 0 ;;
    *"/var/lib/cdss-wsl-test"*) return 0 ;;
    *"/root/"*) return 0 ;;
    *"/tmp/"*) return 0 ;;
  esac
  return 1
}

ensure_git_safe_directory() {
  local target="${1:-${SCRIPT_DIR}}"
  [[ -n "$target" && -d "$target" ]] || return 0
  command -v git >/dev/null 2>&1 || return 0
  if ! sudo_or_root git config --global --get-all safe.directory 2>/dev/null | grep -qx -- "$target"; then
    sudo_or_root git config --global --add safe.directory "$target" 2>/dev/null || true
  fi
  return 0
}

log_update_sources_event() {
  local message="$1"
  if command -v log_cdss_event >/dev/null 2>&1; then
    log_cdss_event "$message"
  else
    logger "CDSS: $message" 2>/dev/null || true
  fi
}

ensure_canonical_update_sources() {
  local upstream_url
  upstream_url=$(get_cdss_upstream_url)
  [[ -n "$upstream_url" ]] || return 0
  command -v git >/dev/null 2>&1 || return 0
  [[ -d "${SCRIPT_DIR}/.git" ]] || return 0

  ensure_git_safe_directory "${SCRIPT_DIR}"

  local origin_url
  origin_url=$(cd "${SCRIPT_DIR}" && sudo_or_root git remote get-url origin 2>/dev/null) || true

  if [[ -z "$origin_url" ]]; then
    if (cd "${SCRIPT_DIR}" && sudo_or_root git remote add origin "$upstream_url" >/dev/null 2>&1); then
      log_update_sources_event "update sources: added origin ${upstream_url}"
    fi
  elif [[ "$origin_url" != "$upstream_url" ]] && is_local_git_url "$origin_url" && ! is_local_git_url "$upstream_url"; then
    if (cd "${SCRIPT_DIR}" && sudo_or_root git remote set-url origin "$upstream_url" >/dev/null 2>&1); then
      log_update_sources_event "update sources: replaced local origin ${origin_url} with ${upstream_url}"
    fi
  fi

  return 0
}

backup_module_settings() {
  local backup_dir="${CDSS_BACKUP_DIR:-/var/lib/cdss/last-update-backup}"
  local env_file="${SCRIPT_DIR}/services/EnvironmentFile"

  if ! sudo_or_root mkdir -p "$backup_dir"; then
    echo -e "${RED}$(trans "Не вдалося створити каталог backup. Оновлення скасовано.")${NC}"
    return 1
  fi
  sudo_or_root chown cdss:cdss "$backup_dir" 2>/dev/null || true
  sudo_or_root chmod 755 "$backup_dir" 2>/dev/null || true

  if [[ -f "$env_file" ]]; then
    if ! sudo_or_root cp "$env_file" "$backup_dir/EnvironmentFile"; then
      echo -e "${RED}$(trans "Не вдалося створити backup EnvironmentFile. Оновлення скасовано.")${NC}"
      return 1
    fi
    sudo_or_root chown cdss:cdss "$backup_dir/EnvironmentFile" 2>/dev/null || true
    sudo_or_root chmod 644 "$backup_dir/EnvironmentFile" 2>/dev/null || true
  fi
  return 0
}

merge_environment_file() {
  if [[ -f "${SCRIPT_DIR}/utils/definitions.sh" ]]; then
    source "${SCRIPT_DIR}/utils/definitions.sh"
  fi
  local env_file="${SCRIPT_DIR}/services/EnvironmentFile"
  local backup_file="${CDSS_BACKUP_DIR:-/var/lib/cdss/last-update-backup}/EnvironmentFile"
  local line name in_section="" key value

  if [[ ! -f "$backup_file" ]]; then
    return 0
  fi

  if [[ ! -f "$env_file" ]]; then
    if sudo_or_root cp "$backup_file" "$env_file"; then
      sudo_or_root chmod 644 "$env_file" 2>/dev/null || true
    fi
    return 0
  fi

  local -A old_values=()
  while IFS= read -r line; do
    if [[ "$line" == "["*"]" ]]; then
      name="${line#[}"
      name="${name%]}"
      if [[ "$name" == /* ]]; then
        in_section=""
      else
        in_section="$name"
      fi
      continue
    fi
    if [[ -n "$in_section" && "$line" == *"="* ]]; then
      key="${line%%=*}"
      value="${line#*=}"
      case "$in_section" in
        mhddos|distress|x100)
          old_values["${in_section}/${key}"]="$value"
          ;;
      esac
    fi
  done < "$backup_file"

  local section
  local sk
  for sk in "${!old_values[@]}"; do
    section="${sk%%/*}"
    key="${sk#*/}"
    set_config_value "$env_file" "$section" "$key" "${old_values[$sk]}" || true
  done
  return 0
}

force_sync_cdss() {
  local backup_dir="${CDSS_BACKUP_DIR:-/var/lib/cdss/last-update-backup}"
  local old_commit
  local upstream_url
  upstream_url=$(get_cdss_upstream_url)

  if ! assert_safe_script_dir "${SCRIPT_DIR}"; then
    echo -e "${RED}$(trans "SCRIPT_DIR не пройшов перевірку. Оновлення скасовано.")${NC}"
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo -e "${RED}$(trans "git не знайдено. Оновлення через git неможливе.")${NC}"
    return 1
  fi

  if [[ ! -d "${SCRIPT_DIR}/.git" ]]; then
    echo -e "${RED}$(transf "%s не є git-репозиторієм. Оновлення неможливе." "$SCRIPT_DIR")${NC}"
    return 1
  fi

  ensure_canonical_update_sources || true
  ensure_git_safe_directory "${SCRIPT_DIR}"

  old_commit=$(cd "${SCRIPT_DIR}" && sudo_or_root git rev-parse HEAD 2>/dev/null) || old_commit=""
  if [[ -z "$old_commit" ]]; then
    echo -e "${RED}$(trans "Не вдалося визначити поточний commit. Оновлення скасовано.")${NC}"
    return 1
  fi

  sudo_or_root mkdir -p "$backup_dir" 2>/dev/null || true
  (cd "${SCRIPT_DIR}" && sudo_or_root git diff 2>/dev/null) | sudo_or_root tee "$backup_dir/tracked.diff" >/dev/null 2>&1 || true
  (cd "${SCRIPT_DIR}" && sudo_or_root git ls-files --others --exclude-standard 2>/dev/null) | sudo_or_root tee "$backup_dir/untracked.txt" >/dev/null 2>&1 || true
  echo "$old_commit" | sudo_or_root tee "$backup_dir/commit" >/dev/null 2>&1 || true
  sudo_or_root chown cdss:cdss "$backup_dir" 2>/dev/null || true
  sudo_or_root chmod 755 "$backup_dir" 2>/dev/null || true
  sudo_or_root chown cdss:cdss "$backup_dir"/tracked.diff "$backup_dir"/untracked.txt "$backup_dir"/commit 2>/dev/null || true
  sudo_or_root chmod 644 "$backup_dir"/tracked.diff "$backup_dir"/untracked.txt "$backup_dir"/commit 2>/dev/null || true

  if ! (cd "${SCRIPT_DIR}" && sudo_or_root git ls-remote --exit-code "$upstream_url" main >/dev/null 2>&1); then
    echo -e "${RED}$(trans "Не вдалося перевірити origin/main. Оновлення скасовано.")${NC}"
    log_cdss_event "force-sync: upstream/main unavailable ($upstream_url)"
    return 1
  fi

  local git_output
  if ! git_output=$(cd "${SCRIPT_DIR}" && sudo_or_root git fetch "$upstream_url" main 2>&1); then
    [[ -n "$git_output" ]] && echo "$git_output"
    echo -e "${RED}$(trans "git fetch зазнав помилки. Поточна версія не змінена.")${NC}"
    log_cdss_event "force-sync: git fetch failed ($upstream_url)"
    return 1
  fi

  if ! git_output=$(cd "${SCRIPT_DIR}" && sudo_or_root git reset --hard FETCH_HEAD 2>&1); then
    [[ -n "$git_output" ]] && echo "$git_output"
    echo -e "${RED}$(trans "git reset зазнав помилки. Відновлюємо попередню версію.")${NC}"
    (cd "${SCRIPT_DIR}" && sudo_or_root git reset --hard "$old_commit" 2>/dev/null) || true
    sudo_or_root chown -R cdss:cdss "${SCRIPT_DIR}" 2>/dev/null || true
    log_cdss_event "force-sync: git reset failed, rolled back to $old_commit"
    return 1
  fi

  sudo_or_root chown -R cdss:cdss "${SCRIPT_DIR}" 2>/dev/null || true
  local new_commit
  new_commit=$(cd "${SCRIPT_DIR}" && sudo_or_root git rev-parse --short HEAD 2>/dev/null) || new_commit="unknown"
  log_cdss_event "force-sync: updated $old_commit -> $new_commit"
  return 0
}

update_cdss() {
  if [[ -f "${SCRIPT_DIR}/utils/definitions.sh" ]]; then
    source "${SCRIPT_DIR}/utils/definitions.sh"
  fi
  echo -e "${GREEN}$(trans "Оновлюємо CDSS")${NC}"

  if ! force_sync_cdss; then
    return 1
  fi

  if [[ -f "${SCRIPT_DIR}/bin/cdss" ]]; then
    sudo_or_root chmod +x "${SCRIPT_DIR}/bin/cdss" 2>/dev/null || true
  fi

  echo -e "${GREEN}$(trans "CDSS успішно оновлено")${NC}"
  return 0
}

reload_runtime_files() {
  local runtime_files=(
    "$SCRIPT_DIR/utils/platform_matrix.sh"
    "$SCRIPT_DIR/utils/definitions.sh"
    "$SCRIPT_DIR/utils/dialog.sh"
    "$SCRIPT_DIR/utils/datapatch.sh"
    "$SCRIPT_DIR/utils/updater.sh"
    "$SCRIPT_DIR/utils/runtime_environment.sh"
    "$SCRIPT_DIR/utils/scheduler.sh"
    "$SCRIPT_DIR/utils/port-extending.sh"
    "$SCRIPT_DIR/utils/fail2ban.sh"
    "$SCRIPT_DIR/utils/ufw.sh"
    "$SCRIPT_DIR/utils/mhddos.sh"
    "$SCRIPT_DIR/utils/distress.sh"
    "$SCRIPT_DIR/utils/x100.sh"
    "$SCRIPT_DIR/menu/menu_init.sh"
    "$SCRIPT_DIR/menu/ddos_tool_managment.sh"
    "$SCRIPT_DIR/menu/ddoss.sh"
    "$SCRIPT_DIR/menu/autoloading.sh"
    "$SCRIPT_DIR/menu/security_configuration.sh"
    "$SCRIPT_DIR/menu/security_settings.sh"
    "$SCRIPT_DIR/menu/main_menu.sh"
  )
  local file

  for file in "${runtime_files[@]}"; do
    if [[ -f "$file" ]]; then
      source "$file"
    else
      echo -e "${RED}$(transf "Не знайдено файл '%s'." "$file")${NC}"
    fi
  done
}
