install_mhddos() {
    local dist_family
    dist_family=$(get_distribution_family)
    local arch
    arch=$(get_normalized_arch)
    local init_system
    init_system=$(get_init_system)

    if ! tool_supports_platform "mhddos" "$dist_family" "$arch" "$init_system"; then
      cdss_dialog "$(trans "MHDDOS не підтримується на цій платформі. Потрібно: amd64/arm64 (openrc — partial support).")${NC}"
      return 1
    fi

    cdss_dialog "$(trans "Встановлюємо MHDDOS")"
    install() {
        cd "$TOOL_DIR" || return 1
        case "$OSARCH" in
          aarch64*)
            package=https://github.com/corpus-dev/mhddos_proxy/releases/latest/download/mhddos_proxy_linux_arm64
          ;;

          x86_64*)
            package=https://github.com/corpus-dev/mhddos_proxy/releases/latest/download/mhddos_proxy_linux
          ;;

          armv6* | armv7* | armv8*)
            confirm_dialog "$(trans "MHDDOS_PROXY не підтримує ARM32")"
            ddos_tool_managment
            return 1
          ;;

          i386* | i686*)
            confirm_dialog "$(trans "MHDDOS_PROXY не підтримує x86 (i386/i686)")"
            ddos_tool_managment
            return 1
          ;;

          *)
            confirm_dialog "$(trans "Неможливо визначити розрядность операційної системи")"
            ddos_tool_managment
            return 1
          ;;
        esac

        sudo_or_root curl -Lo mhddos_proxy_linux "$package"
        sudo_or_root chmod +x mhddos_proxy_linux
        regenerate_mhddos_service_file
        create_symlink
    }
    install > /dev/null 2>&1
    if [[ $? -ne 0 ]];then
      confirm_dialog "$(trans "MHDDOS_PROXY не підтримує ARM32 та x86 (i386/i686)")"
    else
      confirm_dialog "$(trans "MHDDOS успішно встановлено")"
    fi
}

configure_mhddos() {
    clear
    declare -A params
echo -e "${ORANGE}$(trans "Залишіть пустим якщо бажаєте видалити параметри")${NC}"
    echo -ne "\n"
    echo -ne "${GREEN}$(trans "В процесі відновлення")${NC}""\n"
    echo -ne "${GREEN}$(trans "Надається Telegram ботом")${NC} ${ORANGE}@itarmy_stats_bot${NC}""\n"
    echo -ne "\n"
    read -e -p "$(trans "Юзер ІД: ")" -i "$(get_mhddos_variable 'user-id')" user_id
    if [[ -n "$user_id" ]];then
      while [[ ! $user_id =~ ^[0-9]+$ ]]
      do
        echo "$(trans "Будь ласка введіть правильні значення")"
        read -e -p "$(trans "Юзер ІД: ")" -i "$(get_mhddos_variable 'user-id')" user_id
      done
    fi

    params["user-id"]="$user_id"

    read -e -p "$(trans "Мова (ua | en | es | de | pl | it): ")" -i "$(get_mhddos_variable 'lang')" lang

    languages=("ua" "en" "es" "de" "pl" "it")
    if [[ -n "$lang" ]];then
      while [[ ! "${languages[*]}" =~ "$lang" ]]
      do
        echo "$(trans "Будь ласка введіть правильні значення")"
        read -e -p "$(trans "Мова (ua | en | es | de | pl | it): ")" -i "$(get_mhddos_variable 'lang')" lang
      done
    fi

    params["lang"]="$lang"

    read -e -p "$(trans "Кількість копій (auto | X): ")" -i "$(get_mhddos_variable 'copies')" copies
    if [[ -n "$copies" ]];then
      while  [[ ! $copies =~ ^[0-9]+$ && "$copies" != "auto" ]]
      do
        echo "$(trans "Будь ласка введіть правильні значення")"
        read -e -p "$(trans "Кількість копій (auto | X): ")" -i "$(get_mhddos_variable 'copies')" copies
      done
    fi

    params["copies"]="$copies"

    read -e -p "$(trans "Відсоткове співвідношення використання власної IP адреси (0-100): ")" -i "$(get_mhddos_variable 'use-my-ip')" use_my_ip
    if [[ -n "$use_my_ip" ]];then
      while [[ $use_my_ip -lt 0 || $use_my_ip -gt 100 ]]
      do
        echo "$(trans "Будь ласка введіть правильні значення")"
        read -e -p "$(trans "Відсоткове співвідношення використання власної IP адреси (0-100): ")" -i "$(get_mhddos_variable 'use-my-ip')" use_my_ip
      done
    fi

    params["use-my-ip"]="$use_my_ip"

read -e -p "$(trans "Threads: ")" -i "$(get_mhddos_variable "threads")" threads
    if [[ -n "$threads" ]];then
      while [[ ! $threads =~ ^[0-9]+$ ]]
      do
        echo "$(trans "Будь ласка введіть правильні значення")"
        read -e -p "Threads: " -i "$(get_mhddos_variable 'threads')" threads
      done
    fi

    params["threads"]="$threads"

    read -e -p "$(trans "Проксі (шлях до файлу або веб-ресурсу): ")" -i "$(get_mhddos_variable 'proxies')" proxies

    params["proxies"]="$proxies"

    echo -ne "\n"
    echo -e "${ORANGE}$(trans "Мережеві інтерфейси (через пробіл: eth0 eth1 тощо.)")${NC}"
    read -e -p "$(trans "Інтерфейси: ")"  -i "$(get_mhddos_variable 'ifaces')" interface
    if [[ -n "$interface" ]];then
      params[ifaces="$interface"]
    else
      params[ifaces]=" "
    fi

    for i in "${!params[@]}"; do
    	  value="${params[$i]}"
    	  write_mhddos_variable "$i" "$value"
    done
    regenerate_mhddos_service_file
    local init_system
    init_system=$(get_init_system)
    if [[ "$init_system" == "systemd" ]] && service_is_active mhddos; then
        safe_remove_path "/tmp/_MEI*" || true
        service_restart mhddos
    elif [[ "$init_system" == "openrc" ]] && service_is_active mhddos; then
        safe_remove_path "/tmp/_MEI*" || true
        service_restart mhddos
    fi
    confirm_dialog "$(trans "Успішно виконано")"
}

get_mhddos_variable() {
  get_config_value "${SCRIPT_DIR}/services/EnvironmentFile" "mhddos" "$1"
}

write_mhddos_variable() {
  ensure_config_section "${SCRIPT_DIR}/services/EnvironmentFile" "mhddos"
  set_config_value "${SCRIPT_DIR}/services/EnvironmentFile" "mhddos" "$1" "$2"
}

regenerate_mhddos_service_file() {
  local config_file="${SCRIPT_DIR}/services/EnvironmentFile"
  local init_system
  init_system=$(get_init_system)

  local start="ExecStart=${SCRIPT_DIR}/bin/mhddos_proxy_linux"

  local in_section=0
  while IFS= read -r line; do
    local key value
    if [[ "$line" == "[mhddos]" ]]; then
      in_section=1
      continue
    fi
    if [[ "$line" == "[/mhddos]" ]]; then
      in_section=0
      continue
    fi
    if [[ "$in_section" == 0 ]]; then
      continue
    fi
    if [[ "$line" == "use-my-ip="* ]]; then
      value="${line#use-my-ip=}"
      if [[ "$value" == "0" ]]; then
        continue
      fi
    fi
    if [[ "$line" == "cron-to-run="* ]] || [[ "$line" == "cron-to-stop="* ]]; then
      continue
    fi
    if [[ "$line" == *"="* ]]; then
      key="${line%%=*}"
      value="${line#*=}"
      if [[ -n "$value" ]]; then
        local escaped_value
        escaped_value=$(escape_for_execstart "$value")
        start="$start --$key $escaped_value"
      fi
    fi
  done < "$config_file"

  if [[ "$init_system" == "systemd" ]]; then
    local tmp_svc
    tmp_svc=$(mktemp)
    while IFS= read -r line; do
      if [[ "$line" == ExecStart=* ]]; then
        echo "ExecStart=$start" >> "$tmp_svc"
      else
        echo "$line" >> "$tmp_svc"
      fi
    done < "${SCRIPT_DIR}/services/mhddos.service"
    mv -f "$tmp_svc" "${SCRIPT_DIR}/services/mhddos.service"
    service_daemon_reload
  fi
}

mhddos_run() {
  safe_remove_path "/tmp/_MEI*" || true

  service_stop distress
  service_stop x100
  service_start mhddos
}

mhddos_auto_enable() {
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    service_disable distress
    service_disable x100
    service_enable mhddos
  elif [[ "$init_system" == "openrc" ]]; then
    service_disable distress
    service_disable x100
    service_enable mhddos
  else
    cdss_dialog "$(trans "Автозавантаження підтримується тільки на systemd та openrc.")"
    return 1
  fi
  create_symlink
  confirm_dialog "$(trans "MHDDOS додано до автозавантаження")"
}

mhddos_auto_disable() {
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    service_disable mhddos
  elif [[ "$init_system" == "openrc" ]]; then
    service_disable mhddos
  else
    cdss_dialog "$(trans "Автозавантаження підтримується тільки на systemd та openrc.")"
    return 1
  fi
  create_symlink
  confirm_dialog "$(trans "MHDDOS видалено з автозавантаження")"
}

mhddos_enabled() {
  service_is_enabled mhddos
}

mhddos_stop() {
  service_stop mhddos
}

mhddos_get_status() {
  while true; do
    clear
    local init_system
    init_system=$(get_init_system)

    service_status mhddos

    echo -e "${ORANGE}$(trans "Нажміть будь яку клавішу щоб продовжити")${NC}"
    sleep 3
    if read -rsn1 -t 0.1; then
      break
    fi
  done
  return 0
}

mhddos_installed() {
  if [[ ! -f "$TOOL_DIR/mhddos_proxy_linux" ]]; then
      return 1
  else
      return 0
  fi
}

is_not_arm_arch() {
  if [[ "$OSARCH" != armv6* && "$OSARCH" != armv7* && $OSARCH != armv8* ]]; then
    return 1
  else
    return 0
  fi
}

mhddos_configure_scheduler() {
  clear
  echo -ne "${GREEN}  .---------------- $(trans "хвилина") (0 - 59)
  |  .------------- $(trans "година") (0 - 23)
  |  |  .---------- $(trans "день місяця") (1 - 31)
  |  |  |  .------- $(trans "місяць") (1 - 12)
  |  |  |  |  .---- $(trans "день тижня") (0 - 6)
  |  |  |  |  |
  *  *  *  *  *${NC}"

  echo -ne "\n\n"
  echo -ne "${GREEN}$(trans "Або згенеруйте його за посиланням") ${NC}${RED}https://crontab.guru/${NC}"
  echo -ne "\n\n"
  echo -ne "$(trans "Зверніть увагу на ваш час командою") ${GREEN}date${NC}"
  echo -ne "\n\n"
  echo -ne "$(trans "Наприклад:")"
  echo -ne "\n"
  echo -ne "  ${GREEN}$(trans "Запуск MHDDOS о 20:00 щодня") -${NC} ${RED}0 20 * * *${NC}"
  echo -ne "\n"
  echo -ne "  ${GREEN}$(trans "Зупинка MHDDOS о 08:00 щодня") -${NC} ${RED}0 8 * * *${NC}"
  echo -ne "\n\n"
  read -e -p "$(trans "Введіть cron-час для ЗАПУСКУ (формат: * * * * *): ")" -i "$(get_mhddos_variable 'cron-to-run')" cron_time_to_run
  echo -ne "\n"
  read -e -p "$(trans "Введіть cron-час для ЗУПИНКИ (формат: * * * * *): ")"  -i "$(get_mhddos_variable 'cron-to-stop')" cron_time_to_stop

  if [[ -n "$cron_time_to_run" ]]; then
    write_mhddos_variable "cron-to-run" "$cron_time_to_run"
  elif [[ "$cron_time_to_run" == "" ]]; then
    cron_remove_job "mhddos_run" || true
    write_mhddos_variable "cron-to-run" ""
  fi

  if [[ -n "$cron_time_to_stop" ]]; then
    write_mhddos_variable "cron-to-stop" "$cron_time_to_stop"
  elif [[ "$cron_time_to_stop" == "" ]]; then
    cron_remove_job "mhddos_stop" || true
    write_mhddos_variable "cron-to-stop" ""
  fi

  if [[ "$cron_time_to_run" == "" ]] && [[ "$cron_time_to_stop" == "" ]]; then
      confirm_dialog "$(trans "Запуск MHDDOS за розкладом припинено")"
      autoload_configuration
  elif [[ -n "$cron_time_to_run" ]] || [[ -n "$cron_time_to_stop" ]]; then
    to_start_mhddos_schedule_running
  else
    autoload_configuration
  fi
}

check_if_mhddos_running_on_schedule() {
  local crontab_content
  crontab_content=$(sudo_or_root crontab -l 2>/dev/null || true)
  if echo "$crontab_content" | grep -q '# CDSS:mhddos_run' || echo "$crontab_content" | grep -q '# CDSS:mhddos_stop'; then
    return 0
  fi
  return 1
}

to_start_mhddos_schedule_running() {
    local menu_items=("$(trans "Так")" "$(trans "Ні")")
    local res=$(display_menu "$(trans "Запустити MHDDOS за розкладом?")" "${menu_items[@]}")
    case "$res" in
    "$(trans "Так")")
      run_mhddos_on_schedule
      confirm_dialog "$(trans "MHDDOS буде ЗАПУЩЕНО за розкладом")"
      autoload_configuration
    ;;
    "$(trans "Ні")")
      autoload_configuration
    ;;
    esac
}

run_mhddos_on_schedule() {
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

  chmod +x "$SCRIPT_DIR/utils/mhddos.sh"
  local cron_time_to_run=$(get_mhddos_variable 'cron-to-run')
  local cron_time_to_stop=$(get_mhddos_variable 'cron-to-stop')
  cron_remove_job "mhddos_run" || true
  cron_remove_job "mhddos_stop" || true
  cron_remove_job "distress_run" || true
  cron_remove_job "distress_stop" || true
  cron_remove_job "x100_run" || true
  cron_remove_job "x100_stop" || true
  if [[ -n "$cron_time_to_run" ]]; then
    cron_install_job "mhddos_run" "$cron_time_to_run" ". $(shell_single_quote "${SCRIPT_DIR}/utils/mhddos.sh") && mhddos_run"
  fi

  if [[ -n "$cron_time_to_stop" ]]; then
    cron_install_job "mhddos_stop" "$cron_time_to_stop" ". $(shell_single_quote "${SCRIPT_DIR}/utils/mhddos.sh") && mhddos_stop"
  fi
}

stop_mhddos_on_schedule() {
  cron_remove_job "mhddos_run" || true
  cron_remove_job "mhddos_stop" || true
  write_mhddos_variable "cron-to-run" ""
  write_mhddos_variable "cron-to-stop" ""
}

initiate_mhddos() {
  mhddos_installed
  if [[ $? == 1 ]]; then
    confirm_dialog "$(trans "MHDDOS не встановлений, будь ласка встановіть і спробуйте знову")"
    ddos_tool_managment
  else
      if service_is_active mhddos; then
        local active_disactive="$(trans "Зупинка MHDDOS")"
      else
        local active_disactive="$(trans "Запуск MHDDOS")"
      fi
      local menu_items=("$active_disactive" "$(trans "Налаштування MHDDOS")" "$(trans "Статус MHDDOS")" "$(trans "Повернутись назад")")
      local res=$(display_menu "MHDDOS" "${menu_items[@]}")

      case "$res" in
        "$(trans "Зупинка MHDDOS")")
          mhddos_stop
          mhddos_get_status
        ;;
        "$(trans "Запуск MHDDOS")")
          mhddos_run
          mhddos_get_status
        ;;
        "$(trans "Налаштування MHDDOS")")
           configure_mhddos
           return 0
         ;;
        "$(trans "Статус MHDDOS")")
          mhddos_get_status
        ;;
        "$(trans "Повернутись назад")")
          ddos_tool_managment
        ;;
      esac
  fi
}
