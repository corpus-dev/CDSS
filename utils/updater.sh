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
  local remote_version
  remote_version=$(curl -s --fail --location --show-error --connect-timeout 10 --max-time 60 'https://raw.githubusercontent.com/corpus-dev/CDSS/main/version.txt' 2>/dev/null)

  echo -e "$(trans "Актуальна версія") = ${ORANGE}${remote_version}${NC}"

  if [[ -n "$remote_version" ]]; then
    update_cdss
  fi
  write_version $(date +%s)
  sleep 2
}

write_version() {
  write_env_value "CDSS_DEPLOYMENT_VERSION" "$1"
}

update_cdss() {
  source "${SCRIPT_DIR}/utils/definitions.sh"
  echo -e "${GREEN}$(trans "Оновляємо CDSS")${NC}"

  if ! assert_safe_script_dir "${SCRIPT_DIR}"; then
    echo -e "${RED}$(trans "SCRIPT_DIR не пройшов перевірку. Оновлення скасовано.")${NC}"
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo -e "${RED}$(trans "git не знайдено. Оновлення через git неможливе.")${NC}"
    return 1
  fi

  if [[ ! -d "${SCRIPT_DIR}/.git" ]]; then
    echo -e "${RED}$(trans "${SCRIPT_DIR} не є git-репозиторієм. Оновлення неможливе.")${NC}"
    return 1
  fi

  if ! cd "${SCRIPT_DIR}" && git pull --all 2>&1; then
    echo -e "${RED}$(trans "git pull зазнав помилки. Restore (поки) не запущено.")${NC}"
    echo -e "${RED}$(trans "Спробуйте оновити вручну: git pull")${NC}"
    return 1
  fi

  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    local SERVICES=('mhddos' 'distress')
    local svc
    for svc in "${SERVICES[@]}"; do
      local service_file="${SCRIPT_DIR}/services/${svc}.service"
      if [[ -f "$service_file" ]]; then
        source "${SCRIPT_DIR}/utils/${svc}.sh"
        regenerate_"${svc}"_service_file
      fi
    done
  fi

  echo -e "${GREEN}$(trans "CDSS успішно оновлено")${NC}"
}
