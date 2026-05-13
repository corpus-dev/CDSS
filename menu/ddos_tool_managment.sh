show_log_tail() {
  local log_file="$1"

  if [[ -z "$log_file" ]]; then
    cdss_dialog "$(trans "Шлях до лог-файлу не вказано")"
    return 1
  fi

  if [[ ! -f "$log_file" ]]; then
    cdss_dialog "$(trans "Лог-файл не знайдено: $log_file")"
    return 1
  fi

  if [[ ! -r "$log_file" ]]; then
    cdss_dialog "$(trans "Лог-файл недоступний для читання: $log_file")"
    return 1
  fi

  tail --lines=20 "$log_file"
}

check_enabled() {
  local init_system
  init_system=$(get_init_system)
  local services=("mhddos" "distress" "x100")
  local stop_service=0
  local service

  for service in "${services[@]}"; do
    if service_is_active "$service"; then
      stop_service=1
      break
    fi
  done

  return "$stop_service"
}

create_symlink() {
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" != "systemd" ]]; then
    cdss_dialog "$(trans "Створення symlink працює тільки для systemd. Поточна init-система: $init_system")"
    return 1
  fi

  local service_files=("mhddos" "distress" "x100")
  local svc

  for svc in "${service_files[@]}"; do
    local service_path="$SCRIPT_DIR/services/${svc}.service"
    if [[ ! -f "$service_path" ]]; then
      cdss_dialog "$(trans "Сервісний файл відсутній: $service_path")"
      return 1
    fi
  done

sudo_or_root rm -f /etc/systemd/system/mhddos.service
sudo_or_root rm -f /etc/systemd/system/distress.service
sudo_or_root rm -f /etc/systemd/system/x100.service

sudo_or_root ln -sf "$SCRIPT_DIR"/services/mhddos.service /etc/systemd/system/mhddos.service >/dev/null 2>&1
sudo_or_root ln -sf "$SCRIPT_DIR"/services/distress.service /etc/systemd/system/distress.service >/dev/null 2>&1
sudo_or_root ln -sf "$SCRIPT_DIR"/services/x100.service /etc/systemd/system/x100.service >/dev/null 2>&1
}

stop_services() {
  local services=("mhddos" "distress" "x100")
  local service
  local stopped=0
  local failed=0

  cdss_dialog "$(trans "Зупиняємо атаку")"

  for service in "${services[@]}"; do
    if service_is_active "$service"; then
      if service_stop "$service"; then
        stopped=1
      else
        failed=1
      fi
    fi
  done

  if [[ "$failed" == 1 ]]; then
    cdss_dialog "$(trans "Деякі сервіси не вдалося зупинити")"
  else
    confirm_dialog "$(trans "Атака зупинена")"
  fi

  ddos_tool_managment
}

get_ddoss_status() {
  local init_system
  init_system=$(get_init_system)
  local services=("mhddos" "distress" "x100")
  local service=""
  local element

  for element in "${services[@]}"; do
    if service_is_active "$element"; then
      service="$element"
      break
    fi
  done

  if [[ -n "$service" ]]; then
    while true; do
      clear
      echo -e "${GREEN}$(trans "Запущено $service")${NC}"

      if [[ -f /etc/os-release ]]; then
        local lsb_version
        local lsb_id
        lsb_version="$(. /etc/os-release && echo "$VERSION_ID")"
        lsb_id="$(. /etc/os-release && echo "$ID")"

        if [[ "$lsb_id" == "ubuntu" ]] && [[ "$lsb_version" < 19* ]]; then
          if command -v journalctl >/dev/null 2>&1; then
            journalctl -n 20 -u "$service.service" --no-pager
          else
            cdss_dialog "$(trans "journalctl недоступний")"
          fi
        else
          if [[ $service == "x100" ]]; then
            show_log_tail "$SCRIPT_DIR/x100-for-docker/put-your-ovpn-files-here/x100-log-short.txt"
          else
            show_log_tail /var/log/cdss.log
          fi
        fi
      else
        if [[ $service == "x100" ]]; then
          show_log_tail "$SCRIPT_DIR/x100-for-docker/put-your-ovpn-files-here/x100-log-short.txt"
        else
          show_log_tail /var/log/cdss.log
        fi
      fi

      echo -e "${ORANGE}$(trans "Нажміть будь яку клавішу щоб продовжити")${NC}"
      sleep 3
      if read -rsn1 -t 0.1; then
        break
      fi
    done
  else
    confirm_dialog "$(trans "Немає запущених процесів")"
  fi
}

ddos_tool_managment() {
  local menu_items=("$(trans "Статус атаки")")
  check_enabled
  local enabled_tool=$?
  if [[ "$enabled_tool" == 1 ]]; then
    menu_items+=("$(trans "Зупинити атаку")")
  fi
  menu_items+=("$(trans "Налаштування автозапуску")")
  is_not_arm_arch
  if [[ $? == 1 ]]; then
    menu_items+=("MHDDOS")
  fi
  menu_items+=("DISTRESS" "X100" "$(trans "Повернутись назад")")
  local res
  res=$(display_menu "$(trans "Управління ддос інструментами")" "${menu_items[@]}")

  while true; do
    case "$res" in
    "$(trans "Статус атаки")")
      get_ddoss_status
      ;;
    "$(trans "Зупинити атаку")")
      stop_services
      ;;
    "$(trans "Налаштування автозапуску")")
      autoload_configuration
      ;;
    "MHDDOS")
      initiate_mhddos
      ;;
    "DISTRESS")
      initiate_distress
      ;;
    "X100")
      initiate_x100
      ;;
    "$(trans "Повернутись назад")")
      return 0
      ;;
    esac
    res=$(display_menu "$(trans "Управління ддос інструментами")" "${menu_items[@]}")
  done
}
