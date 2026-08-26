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
  local remote_version
  remote_version=$(curl -s --fail --location --show-error --connect-timeout 10 --max-time 60 'https://raw.githubusercontent.com/corpus-dev/CDSS/main/version.txt' 2>/dev/null)

  if [[ -z "$remote_version" ]]; then
    echo -e "${RED}$(trans "Не вдалося отримати версію з сервера. Перевірте мережу.")${NC}"
    write_version $(date +%s)
    sleep 2
    return 1
  fi

  echo -e "$(trans "Актуальна версія") = ${ORANGE}${remote_version}${NC}"

  local local_version
  if [[ -f "${SCRIPT_DIR}/version.txt" ]]; then
    local_version=$(cat "${SCRIPT_DIR}/version.txt")
  fi

  if [[ "$local_version" == "$remote_version" ]]; then
    echo -e "${GREEN}$(trans "Встановлена остання версія")${NC}"
    write_version $(date +%s)
    sleep 2
    return 0
  fi

  update_cdss
  if [[ $? -eq 0 ]]; then
    write_version $(date +%s)
  fi
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

  if ! { cd "${SCRIPT_DIR}" && git pull --all 2>&1; }; then
    local local_changed upstream_changed f resolved=0
    local_changed=$(git diff --name-only 2>/dev/null)
    upstream_changed=$(git diff --name-only HEAD origin/main 2>/dev/null)
    for f in $local_changed; do
      if printf '%s\n' "$upstream_changed" | grep -qx -- "$f"; then
        git checkout -- "$f" 2>/dev/null && resolved=1 || true
      fi
    done
    if [[ "$resolved" -eq 1 ]] && git pull --all 2>&1; then
      :
    else
      echo -e "${RED}$(trans "git pull зазнав помилки. Restore (поки) не запущено.")${NC}"
      echo -e "${RED}$(trans "Спробуйте оновити вручну: git pull")${NC}"
      return 1
    fi
  fi

  if [[ -f "${SCRIPT_DIR}/bin/cdss" ]]; then
    sudo_or_root chmod +x "${SCRIPT_DIR}/bin/cdss" 2>/dev/null || true
  fi

  if id cdss >/dev/null 2>&1; then
    sudo_or_root chown -R cdss:cdss "${SCRIPT_DIR}" 2>/dev/null || true
    if ! sudo_or_root git config --global --get-all safe.directory 2>/dev/null | grep -qx -- "${SCRIPT_DIR}"; then
      sudo_or_root git config --global --add safe.directory "${SCRIPT_DIR}" 2>/dev/null || true
    fi
  fi

  local svc_file
  for svc_file in "${SCRIPT_DIR}/services/mhddos.service" "${SCRIPT_DIR}/services/distress.service"; do
    [[ -f "$svc_file" ]] || continue
    if ! grep -q '^ReadWritePaths=' "$svc_file"; then
      sed -i "/^\[Install\]/i ReadWritePaths=${SCRIPT_DIR} /var/log /tmp" "$svc_file" 2>/dev/null || true
    elif ! grep -q "^ReadWritePaths=.*${SCRIPT_DIR}" "$svc_file"; then
      sed -i "s|^ReadWritePaths=|ReadWritePaths=${SCRIPT_DIR} |" "$svc_file" 2>/dev/null || true
    fi
    if ! grep -q '^WorkingDirectory=' "$svc_file"; then
      sed -i "/^\[Install\]/i WorkingDirectory=${SCRIPT_DIR}" "$svc_file" 2>/dev/null || true
    fi
  done

  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    service_daemon_reload
    local svc
    for svc in mhddos distress x100; do
      if service_is_active "$svc"; then
        service_restart "$svc"
      fi
    done
  fi

  echo -e "${GREEN}$(trans "CDSS успішно оновлено")${NC}"
}

reload_runtime_files() {
  local runtime_files=(
    "$SCRIPT_DIR/utils/definitions.sh"
    "$SCRIPT_DIR/utils/dialog.sh"
    "$SCRIPT_DIR/utils/datapatch.sh"
    "$SCRIPT_DIR/utils/updater.sh"
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
    fi
  done
}
