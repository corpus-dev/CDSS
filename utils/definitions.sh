set -uo pipefail

get_service_command() {
  local init_system
  init_system=$(get_init_system)

  case "$init_system" in
    openrc)
      echo "rc-service"
      ;;
    runit)
      echo "sv"
      ;;
    systemd)
      echo "systemctl"
      ;;
  esac
}

get_service_enable_command() {
  local init_system
  init_system=$(get_init_system)

  case "$init_system" in
    openrc)
      echo "rc-update add"
      ;;
    runit)
      echo ""
      ;;
    systemd)
      echo "systemctl enable"
      ;;
  esac
}

get_service_disable_command() {
  local init_system
  init_system=$(get_init_system)

  case "$init_system" in
    openrc)
      echo "rc-update del"
      ;;
    runit)
      echo ""
      ;;
    systemd)
      echo "systemctl disable"
      ;;
  esac
}

get_service_stop_command() {
  local init_system
  init_system=$(get_init_system)

  case "$init_system" in
    openrc)
      echo "rc-service"
      ;;
    runit)
      echo "sv stop"
      ;;
    systemd)
      echo "systemctl stop"
      ;;
  esac
}

get_service_start_command() {
  local init_system
  init_system=$(get_init_system)

  case "$init_system" in
    openrc)
      echo "rc-service"
      ;;
    runit)
      echo "sv start"
      ;;
    systemd)
      echo "systemctl start"
      ;;
  esac
}

get_service_is_active_command() {
  local init_system
  init_system=$(get_init_system)

  case "$init_system" in
    openrc)
      echo "rc-service is-active"
      ;;
    runit)
      echo "sv status"
      ;;
    systemd)
      echo "systemctl is-active --quiet"
      ;;
  esac
}

get_service_is_enabled_command() {
  local init_system
  init_system=$(get_init_system)

  case "$init_system" in
    openrc)
      echo "rc-update is-active"
      ;;
    runit)
      echo "sv status"
      ;;
    systemd)
      echo "systemctl is-enabled"
      ;;
  esac
}

get_service_restart_command() {
  local init_system
  init_system=$(get_init_system)

  case "$init_system" in
    openrc)
      echo "rc-service"
      ;;
    runit)
      echo "sv restart"
      ;;
    systemd)
      echo "systemctl restart"
      ;;
  esac
}

get_service_daemon_reload_command() {
  local init_system
  init_system=$(get_init_system)

  case "$init_system" in
    systemd)
      echo "systemctl daemon-reload"
      ;;
    *)
      echo ""
      ;;
  esac
}

assert_safe_script_dir() {
  local check_dir="${1:-$SCRIPT_DIR}"

  if [[ -z "$check_dir" ]]; then
    cdss_dialog "$(trans "SCRIPT_DIR порожній! Безпечне видалення відкладено.")"
    return 1
  fi

  case "$check_dir" in
    /|/opt|/tmp|/root|/home|"$HOME")
      cdss_dialog "$(trans "SCRIPT_DIR дорівнює '$check_dir'. Це занадто широко. Безпечне видалення відкладено.")"
      return 1
      ;;
  esac

  if [[ ! -d "$check_dir" ]]; then
    cdss_dialog "$(trans "Директорія '$check_dir' не існує. Безпечне видалення відкладено.")"
    return 1
  fi

  local required_files=("bin/cdss" "services/EnvironmentFile")
  local required_dirs=("utils" "menu" "services")
  local missing=0

  for req_file in "${required_files[@]}"; do
    if [[ ! -f "$check_dir/$req_file" ]]; then
      cdss_dialog "$(trans "Очікуваний файл '$check_dir/$req_file' відсутній. SCRIPT_DIR може бути неправильним.")"
      missing=1
    fi
  done

  for req_dir in "${required_dirs[@]}"; do
    if [[ ! -d "$check_dir/$req_dir" ]]; then
      cdss_dialog "$(trans "Очікувана директорія '$check_dir/$req_dir' відсутня. SCRIPT_DIR може бути неправильним.")"
      missing=1
    fi
  done

  if [[ "$missing" == 1 ]]; then
    return 1
  fi

  return 0
}

safe_remove_path() {
  local target_path="$1"

  if [[ -z "$target_path" ]]; then
    cdss_dialog "$(trans "Шлях для видалення не вказано.")"
    return 1
  fi

  case "$target_path" in
    /tmp/_MEI*)
      safe_remove_tmp_mei_dirs
      return $?
      ;;
    /tmp/distress)
      if [[ -d "$target_path" ]] || [[ -f "$target_path" ]]; then
        sudo_or_root rm -rf "$target_path" 2>/dev/null
        return 0
      fi
      return 1
      ;;
    *)
      cdss_dialog "$(trans "Шлях '$target_path' не в списку дозволених для видалення.")"
      return 1
      ;;
  esac
}

safe_remove_tmp_mei_dirs() {
  local mei_dir
  set -f
  for mei_dir in /tmp/_MEI*; do
    if [[ -d "$mei_dir" ]] && [[ "$mei_dir" == /tmp/_MEI* ]]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') [CDSS] Removing PyInstaller temp dir: $mei_dir" >> /var/log/cdss.log 2>/dev/null || true
      sudo_or_root rm -rf "$mei_dir"
    fi
  done
  set +f
  return 0
}

safe_remove_cdss_dir() {
  local dir_to_remove="$1"

  if [[ -z "$dir_to_remove" ]]; then
    cdss_dialog "$(trans "Директорія для видалення не вказана.")"
    return 1
  fi

  if ! assert_safe_script_dir "$dir_to_remove"; then
    cdss_dialog "$(trans "Директорія '$dir_to_remove' не пройшла перевірку безпеки. Видалення відкладено.")"
    return 1
  fi

  local resolved_dir
  resolved_dir=$(realpath "$dir_to_remove" 2>/dev/null || echo "$dir_to_remove")

  case "$resolved_dir" in
    /|/opt|/tmp|/root|/home|"$HOME")
      cdss_dialog "$(trans "Resolved директорія '$resolved_dir' занадто широка. Видалення відкладено.")"
      return 1
      ;;
  esac

  if [[ ! -f "$resolved_dir/bin/cdss" ]]; then
    cdss_dialog "$(trans "Файл '$resolved_dir/bin/cdss' не знайдено. Перевірте шлях.")"
    return 1
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') [CDSS] Removing CDSS directory: $resolved_dir" >> /var/log/cdss.log 2>/dev/null || true
  sudo_or_root rm -rfv "$resolved_dir"

  if [[ -e "$resolved_dir" ]]; then
    cdss_dialog "$(trans "Видалення '$resolved_dir' не вдалося. Директорія все ще існує.")"
    return 1
  fi

  return 0
}

get_config_value() {
  local config_file="$1"
  local section="$2"
  local key="$3"

  if [[ -z "$config_file" ]] || [[ ! -f "$config_file" ]]; then
    echo ""
    return 1
  fi

  local in_section=0
  local value=""

  while IFS= read -r line; do
    if [[ "$line" == "[$section]" ]]; then
      in_section=1
      continue
    fi
    if [[ "$line" == "[/$section]" ]]; then
      in_section=0
      continue
    fi
    if [[ "$in_section" == 1 ]] && [[ "$line" == "$key="* ]]; then
      value="${line#$key=}"
      break
    fi
  done < "$config_file"

  echo "$value"
}

get_config_lockfile() {
  local config_file="$1"
  local safe_name
  safe_name=$(printf '%s' "$config_file" | tr '/[:space:]' '___' | tr -cd '[:alnum:]_.-')
  echo "/tmp/cdss-${safe_name}.lock"
}

set_config_value() {
  local config_file="$1"
  local section="$2"
  local key="$3"
  local value="$4"

  if [[ -z "$config_file" ]] || [[ ! -f "$config_file" ]]; then
    cdss_dialog "$(trans "Файл конфігурації '$config_file' не знайдено.")"
    return 1
  fi

  if [[ -z "$section" ]] || [[ -z "$key" ]]; then
    cdss_dialog "$(trans "Section або key порожні.")"
    return 1
  fi

  if ! grep -q "^\[$section\]$" "$config_file"; then
    ensure_config_section "$config_file" "$section"
  fi

  local tmp_file
  tmp_file=$(mktemp)
  local found=0
  local in_section=0
  local file_owner=""
  local file_mode=""

  file_owner=$(stat -c '%u:%g' "$config_file" 2>/dev/null || echo "")
  file_mode=$(stat -c '%a' "$config_file" 2>/dev/null || echo "")

  while IFS= read -r line; do
    if [[ "$line" == "[$section]" ]]; then
      in_section=1
      echo "$line" >> "$tmp_file"
      continue
    fi
    if [[ "$line" == "[/$section]" ]]; then
      if [[ "$found" == 0 ]]; then
        echo "$key=$value" >> "$tmp_file"
        found=1
      fi
      in_section=0
      echo "$line" >> "$tmp_file"
      continue
    fi
    if [[ "$in_section" == 1 ]] && [[ "$line" == "$key="* ]]; then
      echo "$key=$value" >> "$tmp_file"
      found=1
      continue
    fi
    echo "$line" >> "$tmp_file"
  done < "$config_file"

  if [[ "$found" == 0 ]]; then
    echo "$key=$value" >> "$tmp_file"
  fi

  if cmp -s "$config_file" "$tmp_file"; then
    rm -f "$tmp_file"
    return 0
  fi

  local lockfile
  lockfile=$(get_config_lockfile "$config_file")
  sudo_or_root touch "$lockfile"
  sudo_or_root chmod 666 "$lockfile" 2>/dev/null || true
  exec 200>"$lockfile"
  flock -x 200
  sudo_or_root mv -f "$tmp_file" "$config_file"
  if [[ -n "$file_owner" ]]; then
    sudo_or_root chown "$file_owner" "$config_file" 2>/dev/null || true
  fi
  if [[ -n "$file_mode" ]]; then
    sudo_or_root chmod "$file_mode" "$config_file" 2>/dev/null || true
  fi
  if [[ "$config_file" == *"EnvironmentFile"* ]]; then
    sudo_or_root chmod 600 "$config_file" 2>/dev/null || true
  fi
  flock -u 200
  exec 200>&-
  return 0
}

ensure_config_section() {
  local config_file="$1"
  local section="$2"

  if [[ -z "$config_file" ]] || [[ ! -f "$config_file" ]]; then
    return 1
  fi

  if grep -q "^\[$section\]$" "$config_file"; then
    return 0
  fi

  local tmp_file
  tmp_file=$(mktemp)
  cat "$config_file" > "$tmp_file"
  printf "\n[%s]\n[/%s]\n" "$section" "$section" >> "$tmp_file"
  sudo_or_root mv -f "$tmp_file" "$config_file"
  return $?
}

ensure_config_key() {
  local config_file="$1"
  local section="$2"
  local key="$3"
  local default_value="$4"

  local current_value
  current_value=$(get_config_value "$config_file" "$section" "$key")

  if [[ -z "$current_value" ]]; then
    set_config_value "$config_file" "$section" "$key" "$default_value"
    return $?
  fi
  return 0
}

escape_for_execstart() {
  local arg="$1"
  if [[ -z "$arg" ]]; then
    echo ""
    return 1
  fi

  local escaped=""
  local i
  for ((i = 0; i < ${#arg}; i++)); do
    local char="${arg:$i:1}"
    case "$char" in
      '\'|'"'|'$'|'`'|'!')
        escaped="${escaped}\\${char}"
        ;;
      *)
        escaped="${escaped}${char}"
        ;;
    esac
  done

  echo "$escaped"
}

shell_single_quote() {
  local arg="$1"
  if [[ -z "$arg" ]]; then
    echo ""
    return 1
  fi

  local escaped
  escaped="${arg//\'/\'\\\'\'}"
  printf "'%s'" "$escaped"
}

service_is_active() {
  local service_name="$1"
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
      sudo_or_root systemctl is-active "$service_name" >/dev/null 2>&1
      return $?
    fi
  elif [[ "$init_system" == "openrc" ]]; then
    if command -v rc-service >/dev/null 2>&1; then
      sudo_or_root rc-service "$service_name" is-active >/dev/null 2>&1
      return $?
    fi
  elif [[ "$init_system" == "runit" ]]; then
    if command -v sv >/dev/null 2>&1; then
      sudo_or_root sv status "$service_name" >/dev/null 2>&1
      return $?
    fi
  else
    cdss_dialog "$(trans "Невідома init-система: $init_system. Не вдалося перевірити статус.")"
    return 1
  fi

  cdss_dialog "$(trans "Команда недоступна: $(command -v "$init_system" 2>/dev/null || echo "$init_system")")"
  return 1
}

service_start() {
  local service_name="$1"
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
      sudo_or_root systemctl start "$service_name" >/dev/null 2>&1
      return $?
    fi
  elif [[ "$init_system" == "openrc" ]]; then
    if command -v rc-service >/dev/null 2>&1; then
      sudo_or_root rc-service "$service_name" start >/dev/null 2>&1
      return $?
    fi
  elif [[ "$init_system" == "runit" ]]; then
    if command -v sv >/dev/null 2>&1; then
      sudo_or_root sv start "$service_name" >/dev/null 2>&1
      return $?
    fi
  else
    cdss_dialog "$(trans "Невідома init-система: $init_system. Не вдалося запустити сервіс.")"
    return 1
  fi

  cdss_dialog "$(trans "Команда недоступна для запуску сервісу")"
  return 1
}

service_stop() {
  local service_name="$1"
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
      sudo_or_root systemctl stop "$service_name"
      return $?
    fi
  elif [[ "$init_system" == "openrc" ]]; then
    if command -v rc-service >/dev/null 2>&1; then
      sudo_or_root rc-service "$service_name" stop
      return $?
    fi
  elif [[ "$init_system" == "runit" ]]; then
    if command -v sv >/dev/null 2>&1; then
      sudo_or_root sv down "$service_name"
      return $?
    fi
  else
    cdss_dialog "$(trans "Невідома init-система: $init_system. Не вдалося зупинити сервіс.")"
    return 1
  fi

  cdss_dialog "$(trans "Команда недоступна для зупинки сервісу")"
  return 1
}

service_restart() {
  local service_name="$1"
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
      sudo_or_root systemctl restart "$service_name" >/dev/null 2>&1
      return $?
    fi
  elif [[ "$init_system" == "openrc" ]]; then
    if command -v rc-service >/dev/null 2>&1; then
      sudo_or_root rc-service "$service_name" restart >/dev/null 2>&1
      return $?
    fi
  elif [[ "$init_system" == "runit" ]]; then
    if command -v sv >/dev/null 2>&1; then
      sudo_or_root sv restart "$service_name" >/dev/null 2>&1
      return $?
    fi
  else
    cdss_dialog "$(trans "Невідома init-система: $init_system. Не вдалося перезапустити сервіс.")"
    return 1
  fi

  cdss_dialog "$(trans "Команда недоступна для перезапуску сервісу")"
  return 1
}

service_enable() {
  local service_name="$1"
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
      sudo_or_root systemctl enable "$service_name" >/dev/null 2>&1
      return $?
    fi
  elif [[ "$init_system" == "openrc" ]]; then
    if command -v rc-update >/dev/null 2>&1; then
      sudo_or_root rc-update add "$service_name" >/dev/null 2>&1
      return $?
    fi
  elif [[ "$init_system" == "runit" ]]; then
    cdss_dialog "$(trans "runit не підтримує enable. Потрібно додати сервіс в потрібний runlevel вручну.")"
    return 1
  else
    cdss_dialog "$(trans "Автозавантаження не підтримується на $init_system.")"
    return 1
  fi

  cdss_dialog "$(trans "Команда недоступна для увімкнення сервісу")"
  return 1
}

service_disable() {
  local service_name="$1"
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
      sudo_or_root systemctl disable "$service_name" >/dev/null 2>&1
      return $?
    fi
  elif [[ "$init_system" == "openrc" ]]; then
    if command -v rc-update >/dev/null 2>&1; then
      sudo_or_root rc-update del "$service_name" >/dev/null 2>&1
      return $?
    fi
  elif [[ "$init_system" == "runit" ]]; then
    cdss_dialog "$(trans "runit не підтримує disable. Потрібно видалити сервіс з runlevel вручну.")"
    return 1
  else
    cdss_dialog "$(trans "Автозавантаження не підтримується на $init_system.")"
    return 1
  fi

  cdss_dialog "$(trans "Команда недоступна для вимкнення сервісу")"
  return 1
}

service_daemon_reload() {
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
      sudo_or_root systemctl daemon-reload >/dev/null 2>&1
      return $?
    fi
  fi

  return 1
}

service_is_enabled() {
  local service_name="$1"
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
      sudo_or_root systemctl is-enabled "$service_name" >/dev/null 2>&1
      return $?
    fi
  elif [[ "$init_system" == "openrc" ]]; then
    if command -v rc-update >/dev/null 2>&1; then
      sudo_or_root rc-update is-active "$service_name" >/dev/null 2>&1
      return $?
    fi
  elif [[ "$init_system" == "runit" ]]; then
    cdss_dialog "$(trans "runit не підтримує is-enabled. Потрібно перевірити runlevel вручну.")"
    return 1
  else
    cdss_dialog "$(trans "Автозавантаження не підтримується на $init_system.")"
    return 1
  fi

  cdss_dialog "$(trans "Команда недоступна для перевірки автозавантаження")"
  return 1
}

service_status() {
  local service_name="$1"
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
      sudo_or_root systemctl status "$service_name" 2>&1
      return $?
    fi
  elif [[ "$init_system" == "openrc" ]]; then
    if command -v rc-service >/dev/null 2>&1; then
      sudo_or_root rc-service "$service_name" status 2>&1
      return $?
    fi
  elif [[ "$init_system" == "runit" ]]; then
    if command -v sv >/dev/null 2>&1; then
      sudo_or_root sv status "$service_name" 2>&1
      return $?
    fi
  else
    cdss_dialog "$(trans "Невідома init-система: $init_system. Не вдалося отримати статус.")"
    return 1
  fi

  cdss_dialog "$(trans "Команда недоступна для отримання статусу сервісу")"
  return 1
}
