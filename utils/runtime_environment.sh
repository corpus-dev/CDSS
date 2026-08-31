# shellcheck shell=bash
set -uo pipefail

CDSS_SERVICE_MODULES=("mhddos" "distress" "x100")

get_module_readwrite_paths() {
  local module="$1"
  case "$module" in
    mhddos|distress)
      echo "${SCRIPT_DIR} ${SCRIPT_DIR}/bin /var/log /tmp"
      ;;
    x100)
      echo "${SCRIPT_DIR}/x100-for-docker /var/log /tmp"
      ;;
  esac
}

service_file_set_directive() {
  local svc_file="$1"
  local directive="$2"
  local value="$3"

  if [[ ! -f "$svc_file" ]]; then
    return 1
  fi

  local tmp_file
  tmp_file=$(mktemp)
  local found=0
  local line

  while IFS= read -r line; do
    if [[ "$line" == "$directive="* ]]; then
      echo "${directive}=${value}" >> "$tmp_file"
      found=1
    else
      echo "$line" >> "$tmp_file"
    fi
  done < "$svc_file"

  if [[ "$found" == 0 ]]; then
    local tmp_file2
    tmp_file2=$(mktemp)
    local inserted=0
    while IFS= read -r line; do
      if [[ "$line" == "[Install]" && "$inserted" == 0 ]]; then
        echo "${directive}=${value}" >> "$tmp_file2"
        inserted=1
      fi
      echo "$line" >> "$tmp_file2"
    done < "$tmp_file"
    if [[ "$inserted" == 0 ]]; then
      echo "${directive}=${value}" >> "$tmp_file2"
    fi
    mv -f "$tmp_file2" "$tmp_file"
  fi

  if cmp -s "$svc_file" "$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  local allow_placeholder=0
  if grep -q '^ExecStart=placeholder$' "$svc_file" 2>/dev/null; then
    allow_placeholder=1
  fi

  if ! validate_service_file "$tmp_file" "$(basename "$svc_file" .service)" "$allow_placeholder"; then
    rm -f "$tmp_file"
    log_cdss_event "service policy: validation failed for $svc_file, keeping previous version"
    return 1
  fi

  local backup_dir="${CDSS_SERVICE_BACKUP_DIR:-/var/lib/cdss/service-backups}"
  local backup_file
  sudo_or_root mkdir -p "$backup_dir" 2>/dev/null || true
  backup_file="${backup_dir}/$(basename "$svc_file").$(date +%s)"
  sudo_or_root cp "$svc_file" "$backup_file" 2>/dev/null || true
  sudo_or_root chown cdss:cdss "$backup_dir" 2>/dev/null || true
  sudo_or_root chmod 755 "$backup_dir" 2>/dev/null || true

  if ! sudo_or_root mv -f "$tmp_file" "$svc_file"; then
    rm -f "$tmp_file"
    return 1
  fi
  sudo_or_root chown cdss:cdss "$svc_file" 2>/dev/null || true
  return 0
}

validate_service_file() {
  local svc_file="$1"
  local module="$2"
  local allow_placeholder="${3:-0}"
  local expected_rw

  if [[ ! -f "$svc_file" ]]; then
    return 1
  fi

  expected_rw=$(get_module_readwrite_paths "$module")

  grep -q '^\[Unit\]$' "$svc_file" || return 1
  grep -q '^\[Service\]$' "$svc_file" || return 1
  grep -q '^ExecStart=' "$svc_file" || return 1
  if [[ "$allow_placeholder" != "1" ]] && grep -q '^ExecStart=placeholder$' "$svc_file"; then
    return 1
  fi
  grep -q '^User=cdss$' "$svc_file" || return 1
  grep -q '^NoNewPrivileges=true$' "$svc_file" || return 1
  grep -q '^ProtectSystem=strict$' "$svc_file" || return 1
  grep -q "^ReadWritePaths=${expected_rw}$" "$svc_file" || return 1
  return 0
}

ensure_module_runtime_permissions() {
  local runtime_file

  for runtime_file in "${SCRIPT_DIR}/bin/mhddos_proxy_linux" "${SCRIPT_DIR}/bin/distress"; do
    if [[ -f "$runtime_file" ]]; then
      sudo_or_root chown cdss:cdss "$runtime_file" 2>/dev/null || true
      sudo_or_root chmod 755 "$runtime_file" 2>/dev/null || true
    fi
  done

  for runtime_file in "${SCRIPT_DIR}/mhddos.ini" "${SCRIPT_DIR}/bin/mhddos.ini"; do
    if [[ -f "$runtime_file" ]]; then
      sudo_or_root chown cdss:cdss "$runtime_file" 2>/dev/null || true
      sudo_or_root chmod 644 "$runtime_file" 2>/dev/null || true
    fi
  done

  if [[ -d "${SCRIPT_DIR}/x100-for-docker" ]]; then
    sudo_or_root chown -R cdss:cdss "${SCRIPT_DIR}/x100-for-docker" 2>/dev/null || true
    sudo_or_root find "${SCRIPT_DIR}/x100-for-docker" -type d -exec chmod 755 {} + 2>/dev/null || true
    sudo_or_root find "${SCRIPT_DIR}/x100-for-docker" -type f -exec chmod 644 {} + 2>/dev/null || true
    sudo_or_root find "${SCRIPT_DIR}/x100-for-docker" -type f -name "*.bash" -exec chmod 755 {} + 2>/dev/null || true
  fi
  return 0
}

ensure_module_service_policy() {
  local needs_reload=0
  local failed=0
  local module
  local svc_file
  local expected_rw
  local current_rw

  for module in "${CDSS_SERVICE_MODULES[@]}"; do
    svc_file="${SCRIPT_DIR}/services/${module}.service"
    if [[ ! -f "$svc_file" ]]; then
      continue
    fi

    expected_rw=$(get_module_readwrite_paths "$module")
    current_rw=$(grep -m1 '^ReadWritePaths=' "$svc_file" 2>/dev/null | cut -d'=' -f2- || true)

    if [[ "$current_rw" != "$expected_rw" ]]; then
      if service_file_set_directive "$svc_file" "ReadWritePaths" "$expected_rw"; then
        needs_reload=1
        log_cdss_event "service policy: fixed ReadWritePaths in ${module}.service"
      else
        failed=1
      fi
    fi

    if [[ "$module" != "x100" ]] && ! grep -q '^WorkingDirectory=' "$svc_file"; then
      if service_file_set_directive "$svc_file" "WorkingDirectory" "${SCRIPT_DIR}"; then
        needs_reload=1
        log_cdss_event "service policy: added WorkingDirectory to ${module}.service"
      else
        failed=1
      fi
    fi
  done

  if [[ "$failed" == 1 ]]; then
    return 2
  fi

  if [[ "$needs_reload" == 1 ]]; then
    return 0
  fi
  return 1
}

ensure_runtime_service_reload() {
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    service_daemon_reload
  fi
  return 0
}

ensure_runtime_update_environment() {
  ensure_module_runtime_permissions
  local policy_status=1
  ensure_module_service_policy || policy_status=$?
  if [[ "$policy_status" == 0 ]]; then
    ensure_runtime_service_reload
  fi
  return 0
}

regenerate_module_service_files() {
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" != "systemd" ]]; then
    return 0
  fi

  if [[ -f "${SCRIPT_DIR}/bin/mhddos_proxy_linux" ]] && command -v regenerate_mhddos_service_file >/dev/null 2>&1; then
    regenerate_mhddos_service_file || true
  fi
  if [[ -f "${SCRIPT_DIR}/bin/distress" ]] && command -v regenerate_distress_service_file >/dev/null 2>&1; then
    regenerate_distress_service_file || true
  fi
  if [[ -d "${SCRIPT_DIR}/x100-for-docker" ]] && command -v regenerate_x100_service_file >/dev/null 2>&1; then
    regenerate_x100_service_file || true
  fi
  return 0
}

install_module_symlink() {
  local module="$1"
  local source_file="${SCRIPT_DIR}/services/${module}.service"
  local target_file="/etc/systemd/system/${module}.service"

  if [[ ! -f "$source_file" ]]; then
    return 1
  fi

  if ! validate_service_file "$source_file" "$module"; then
    log_cdss_event "repair-runtime: invalid service file for ${module}.service, symlink skipped"
    return 1
  fi

  local previous_target=""
  if [[ -L "$target_file" ]]; then
    previous_target=$(readlink "$target_file" 2>/dev/null || true)
  fi

  if [[ -L "$target_file" && "$(readlink "$target_file" 2>/dev/null)" == "$source_file" ]]; then
    return 0
  fi

  sudo_or_root rm -f "$target_file"
  if ! sudo_or_root ln -sf "$source_file" "$target_file"; then
    if [[ -n "$previous_target" ]]; then
      sudo_or_root ln -sf "$previous_target" "$target_file" 2>/dev/null || true
    fi
    return 1
  fi

  if [[ ! -e "$target_file" ]]; then
    if [[ -n "$previous_target" ]]; then
      sudo_or_root ln -sf "$previous_target" "$target_file" 2>/dev/null || true
    fi
    return 1
  fi

  return 0
}

repair_runtime() {
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" != "systemd" ]]; then
    echo -e "${ORANGE}$(transf "--repair-runtime підтримується тільки на systemd. Поточна init-система: %s" "$init_system")${NC}"
    return 0
  fi

  echo -e "${GREEN}$(trans "Ремонт runtime-середовища CDSS")${NC}"

  local -A service_state=()
  local module
  for module in "${CDSS_SERVICE_MODULES[@]}"; do
    if service_is_active "$module"; then
      service_state["$module"]="active"
    else
      service_state["$module"]="inactive"
    fi
  done

  ensure_runtime_update_environment
  regenerate_module_service_files || true

  local failed=0
  for module in "${CDSS_SERVICE_MODULES[@]}"; do
    local has_runtime=0
    case "$module" in
      mhddos)
        [[ -f "${SCRIPT_DIR}/bin/mhddos_proxy_linux" ]] && has_runtime=1
        ;;
      distress)
        [[ -f "${SCRIPT_DIR}/bin/distress" ]] && has_runtime=1
        ;;
      x100)
        [[ -d "${SCRIPT_DIR}/x100-for-docker" ]] && has_runtime=1
        ;;
    esac

    if [[ "$has_runtime" == 1 ]]; then
      if ! install_module_symlink "$module"; then
        echo -e "${RED}$(transf "Не вдалося оновити symlink для %s.service" "$module")${NC}"
        failed=1
      fi
    fi
  done

  ensure_runtime_service_reload

  for module in "${CDSS_SERVICE_MODULES[@]}"; do
    if [[ "${service_state[$module]:-inactive}" == "active" ]]; then
      service_restart "$module" || failed=1
    fi
  done

  if [[ "$failed" == 1 ]]; then
    echo -e "${ORANGE}$(trans "Ремонт runtime-середовища завершено з помилками")${NC}"
    return 1
  fi

  echo -e "${GREEN}$(trans "Ремонт runtime-середовища завершено успішно")${NC}"
  return 0
}
