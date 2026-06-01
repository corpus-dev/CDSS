set -uo pipefail

x100_run() {
  if service_stop distress; then
    cdss_dialog "$(trans "DISTRESS зупинено")"
  else
    cdss_dialog "$(trans "Не вдалося зупинити DISTRESS")"
  fi
  if service_stop mhddos; then
    cdss_dialog "$(trans "MHDDOS зупинено")"
  else
    cdss_dialog "$(trans "Не вдалося зупинити MHDDOS")"
  fi
  service_start x100
}

x100_auto_enable() {
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    service_disable mhddos
    service_disable distress
    service_enable x100
  elif [[ "$init_system" == "openrc" ]]; then
    service_disable mhddos
    service_disable distress
    service_enable x100
  else
    cdss_dialog "$(trans "Автозавантаження підтримується тільки на systemd та openrc.")"
    return 1
  fi
  create_symlink
  confirm_dialog "$(trans "X100 додано до автозавантаження")"
}

x100_auto_disable() {
  local init_system
  init_system=$(get_init_system)

  if [[ "$init_system" == "systemd" ]]; then
    service_disable x100
  elif [[ "$init_system" == "openrc" ]]; then
    service_disable x100
  else
    cdss_dialog "$(trans "Автозавантаження підтримується тільки на systemd та openrc.")"
    return 1
  fi
  create_symlink
  confirm_dialog "$(trans "X100 видалено з автозавантаження")"
}

x100_enabled() {
  service_is_enabled x100
}

x100_stop() {
  service_stop x100
}

x100_get_status() {
  while true; do
    clear
    local init_system
    init_system=$(get_init_system)

    service_status x100

    echo -e "${ORANGE}$(trans "Нажміть будь яку клавішу щоб продовжити")${NC}"
    sleep 3
    if read -rsn1 -t 0.1; then
      break
    fi
  done
  return 0
}

docker_installed() {
   docker container ls >/dev/null 2>&1
}

add_user_to_docker_group() {
  if ! grep -q docker /etc/group; then
    sudo_or_root groupadd docker
  fi

  local real_user
  real_user=$(get_real_user)

  if ! id -nG "$real_user" | grep -qw "docker"; then
      sudo_or_root usermod -aG docker "$real_user"
      clear
      echo -e "\n"
      echo -e "${ORANGE}Docker-групу оновлено. Перезапустіть сесію користувача '${real_user}' і запустіть ${NC}${GREEN}\e[4mcdss\e[0m${NC}${ORANGE} знову.${NC}"
  fi
}

install_docker() {
  local pkg_manager
  pkg_manager=$(get_package_manager)

  if [ -r /etc/os-release ]; then
    clear
    case "$pkg_manager" in
      apt-get)
        sudo_or_root apt-get install -y docker.io
        service_start docker || true
        service_enable docker || true
        ;;
      dnf|yum)
        sudo_or_root $pkg_manager install -y docker
        service_enable docker || true
        service_start docker || true
        ;;
      pacman)
        sudo_or_root pacman -Sy docker --noconfirm
        service_enable docker || true
        service_start docker || true
        ;;
      xbps-install)
        sudo_or_root xbps-install -Su docker
        service_enable docker || true
        service_start docker || true
        ;;
      emerge)
        sudo_or_root emerge -n app-containers/docker
        service_enable docker || true
        service_start docker || true
        ;;
      *)
        echo -e "${RED}Неможливо визначити операційну систему/Unable to determine operating system${NC}"
        ;;
    esac
  else
    echo -e "${RED}Неможливо визначити операційну систему/Unable to determine operating system${NC}"
  fi
}

initiate_x100() {
   x100_installed
   if [[ $? == 1 ]]; then
      menu_items=("$(trans "Так")" "$(trans "Ні")")
       local res
        display_menu "$(trans "X100 не встановлений, встановити?")" "${menu_items[@]}"
        res="$CDSS_SELECTION"
       case "$res" in
         "$(trans "Так")" )
           confirm_dialog "$(trans "Встановлюємо Х100")"
           install_x100
           confirm_dialog "$(trans "Х100 успішно встановлено")"
         ;;
         "$(trans "Ні")" )
            ddos_tool_managment
            return
          ;;
       esac
   fi
   docker_installed
   if [[ $? == 1 ]]; then
      confirm_dialog "$(trans "Встановлюємо докер")"
      install_docker
      confirm_dialog "$(trans "Докер успішно встановлено")"
      add_user_to_docker_group
   fi
    while true; do
       if service_is_active x100; then
         local active_disactive="$(trans "Зупинка X100")"
       else
         local active_disactive="$(trans "Запуск X100")"
       fi
        local menu_items=("$active_disactive" "$(trans "Налаштування X100")"  "$(trans "Статус X100")" "$(trans "Повернутись назад")")
        local res
         display_menu "X100" "${menu_items[@]}"
         res="$CDSS_SELECTION"

       case "$res" in
        "$(trans "Запуск X100")" )
           x100_run
           x100_get_status
         ;;
        "$(trans "Зупинка X100")" )
           x100_stop
           x100_get_status
         ;;
             "$(trans "Налаштування X100")" )
            configure_x100
            continue
          ;;
        "$(trans "Статус X100")" )
           x100_get_status
         ;;
        "$(trans "Повернутись назад")" )
           return 0
         ;;
        esac
    done
 }

configure_x100() {
    clear
    echo -ne "${GREEN}$(trans "Налаштування X100")${NC}\n"
    echo -ne "\n"
    local user_id
    read -e -p "$(trans "Corpus ID: ")" -i "$(get_x100_variable "itArmyUserId")"  user_id

    local configPath="$SCRIPT_DIR/x100-for-docker/put-your-ovpn-files-here/x100-config.txt"
    if [[ ! -f "$configPath" ]]; then
        confirm_dialog "$(trans "Файл конфігурації x100 не знайдено")"
        return 1
    fi

    set_config_value "$configPath" "x100config" "itArmyUserId" "$user_id"

    local scale
    read -e -p "$(trans "Initial Distress Scale (10-40960): ")" -i "$(get_x100_variable "initialDistressScale")"  scale
    if [[ -n "$scale" ]];then
      while [[ $scale -lt 10 || $scale -gt 40960 ]]
      do
        echo "$(trans "Будь ласка введіть правильні значення")"
        read -e -p "$(trans "Initial Distress Scale (10-40960): ")" -i "$(get_x100_variable "initialDistressScale")" scale
      done
    fi
    set_config_value "$configPath" "x100config" "initialDistressScale" "$scale"

    if [[ -n "$(get_x100_variable "ignoreBundledFreeVpn")" ]];then
      local ignoreBundledFreeVpn
      read -e -p "$(trans "Ignore Bundled Free Vpn (0-1): ")" -i "$(get_x100_variable "ignoreBundledFreeVpn")"  ignoreBundledFreeVpn
      while [[ $ignoreBundledFreeVpn -lt 0 || $ignoreBundledFreeVpn -gt 1 ]]
      do
        echo "$(trans "Будь ласка введіть правильні значення")"
        read -e -p "$(trans "Ignore Bundled Free Vpn (0-1): ")" -i "$(get_x100_variable "ignoreBundledFreeVpn")" ignoreBundledFreeVpn
      done

      set_config_value "$configPath" "x100config" "ignoreBundledFreeVpn" "$ignoreBundledFreeVpn"
    fi

    local init_system
    init_system=$(get_init_system)
    if [[ "$init_system" == "systemd" ]] && service_is_active x100; then
        service_restart x100
    elif [[ "$init_system" == "openrc" ]] && service_is_active x100; then
        service_restart x100
    fi
    confirm_dialog "$(trans "Успішно виконано")"
}

get_x100_variable() {
  local configPath="$SCRIPT_DIR/x100-for-docker/put-your-ovpn-files-here/x100-config.txt"
  if [[ ! -f "$configPath" ]]; then
    echo ""
    return 1
  fi
  get_config_value "$configPath" "x100config" "$1"
}

get_x100_cdss_variable() {
  get_config_value "${SCRIPT_DIR}/services/EnvironmentFile" "x100" "$1"
}

write_x100_cdss_variable() {
  ensure_config_section "${SCRIPT_DIR}/services/EnvironmentFile" "x100"
  set_config_value "${SCRIPT_DIR}/services/EnvironmentFile" "x100" "$1" "$2"
}

x100_installed() {
  if [[ ! -d "$SCRIPT_DIR/x100-for-docker" ]]; then
      return 1
  else
      return 0
  fi
}

install_x100() {
    local arch
    arch=$(get_normalized_arch)
    local init_system
    init_system=$(get_init_system)
    local dist_family
    dist_family=$(get_distribution_family)

    if ! tool_supports_platform "x100" "$dist_family" "$arch" "$init_system"; then
      cdss_dialog "$(trans "X100 не підтримується на цій платформі. Потрібно: Docker + systemd + amd64/arm64.")${NC}"
      return 1
    fi

    if ! command -v docker >/dev/null 2>&1; then
      cdss_dialog "$(trans "Docker не встановлено. X100 вимагає Docker.")${NC}"
      return 1
    fi

    if ! service_is_active docker; then
      cdss_dialog "$(trans "Docker не запущено. Запустіть sudo systemctl start docker або sudo service docker start.")${NC}"
      return 1
    fi

    clear
    local user_id configPath scriptBeforeRunPath

    cd "$SCRIPT_DIR" || return 1

    if ! command -v tar >/dev/null 2>&1; then
      cdss_dialog "$(trans "tar не встановлено. Встановіть tar і повторіть спробу.")"
      return 1
    fi

    local archive="./x100-for-docker.tar.gz"
    if ! curl -L --fail --show-error --connect-timeout 10 --max-time 30 "https://github.com/corpus-dev/x100_releases/raw/refs/heads/main/docker/x100-for-docker.tar.gz" -o "$archive"; then
      cdss_dialog "$(trans "Помилка завантаження x100-for-docker.tar.gz")"
      return 1
    fi

    if [[ ! -s "$archive" ]]; then
      cdss_dialog "$(trans "Завантажений файл x100-for-docker.tar.gz порожній")"
      rm -f "$archive"
      return 1
    fi

    if ! tar tzf "$archive" >/dev/null 2>&1; then
      cdss_dialog "$(trans "x100-for-docker.tar.gz не пройшов перевірку цілісності")"
      rm -f "$archive"
      return 1
    fi

    if ! tar xzf "$archive"; then
      cdss_dialog "$(trans "tar xzf x100-for-docker.tar.gz завершився з помилкою")"
      rm -f "$archive"
      return 1
    fi

    rm -f "$archive"

    if [[ ! -d "$SCRIPT_DIR/x100-for-docker" ]]; then
      cdss_dialog "$(trans "Директорія x100-for-docker не знайдена після unzip")"
      return 1
    fi

    if [[ ! -f "$SCRIPT_DIR/x100-for-docker/put-your-ovpn-files-here/x100-config.txt" ]]; then
      cdss_dialog "$(trans "x100-config.txt не знайдено в архіві")"
      return 1
    fi

    cd "$SCRIPT_DIR/x100-for-docker" || return 1

    if [[ ! -d "$SCRIPT_DIR/x100-for-docker/for-macOS-and-Linux-hosts" ]]; then
      cdss_dialog "$(trans "for-macOS-and-Linux-hosts не знайдено в архіві")"
      return 1
    fi

    if ! sudo_or_root chmod -R ug+x "./for-macOS-and-Linux-hosts"; then
      cdss_dialog "$(trans "Не вдалося встановити права для for-macOS-and-Linux-hosts")"
      return 1
    fi

    echo -ne "${GREEN}$(trans "Налаштування X100")${NC}\n"
    echo -ne "\n"
    read -e -p "$(trans "Corpus ID: ")"  user_id

    if [[ -z "$user_id" ]]; then
      cdss_dialog "$(trans "Corpus ID порожній. Встановлення перервано.")"
      return 1
    fi

    if [[ ! "$user_id" =~ ^[a-zA-Z0-9_]+$ ]]; then
      cdss_dialog "$(trans "Corpus ID має містити лише літери, цифри та підкреслення")"
      return 1
    fi

    configPath=./put-your-ovpn-files-here/x100-config.txt

    if ! set_config_value "$configPath" "x100config" "itArmyUserId" "$user_id"; then
      cdss_dialog "$(trans "Не вдалося записати itArmyUserId у x100-config.txt")"
      return 1
    fi

    if ! set_config_value "$configPath" "x100config" "dockerInteractiveConfiguration" "0"; then
      cdss_dialog "$(trans "Не вдалося записати dockerInteractiveConfiguration у x100-config.txt")"
      return 1
    fi

    scriptBeforeRunPath=./for-macOS-and-Linux-hosts/custom-script-before-run.bash

    if ! touch "$scriptBeforeRunPath"; then
      cdss_dialog "$(trans "Не вдалося створити custom-script-before-run.bash")"
      return 1
    fi

    {
      echo " "
      echo " "
      echo "cd ./put-your-ovpn-files-here/FreeAndSlowVpn"
      echo "./generate-vpngate.bash"
    } >> "$scriptBeforeRunPath" || {
      cdss_dialog "$(trans "Не вдалося записати дані у custom-script-before-run.bash")"
      return 1
    }

    if ! sudo_or_root chmod ug+x "./put-your-ovpn-files-here/FreeAndSlowVpn/generate-vpngate.bash"; then
      cdss_dialog "$(trans "Не вдалося встановити права для generate-vpngate.bash")"
      return 1
    fi

    sudo_or_root chown -R cdss:cdss "$SCRIPT_DIR/x100-for-docker" 2>/dev/null || true

    if ! create_symlink; then
      cdss_dialog "$(trans "Не вдалося створити symlink")"
      return 1
    fi
     echo -ne "${GREEN}$(trans "Це встановлення X100 використовує безкоштовний і повільний VPN-провайдер VPNGate.")${NC}\n"
     echo -ne "${GREEN}${ORANGE}http://www.vpngate.net${NC}\n"
     echo -ne "${GREEN}$(trans "Для досягнення максимальної швидкості атаки (1 Гбіт/с або більше) вам знадобиться комерційний VPN-акаунт.")${NC}\n"
     echo -ne "${GREEN}$(trans "Посилання на безкоштовний повнофункціональний VPN: https://www.vpnunlimited.com/ua/palianytsia")${NC}\n"
     echo -ne "${GREEN}$(trans "Також зверніть увагу, що X100 поступово збільшує використання ресурсів.")${NC}\n"
     echo -ne "${GREEN}$(trans "X100 досягне пікової продуктивності приблизно через 3 години після запуску.")${NC}\n"
     echo -ne "${GREEN}$(trans "Логи зберігаються в папці") ${ORANGE}$SCRIPT_DIR/x100-for-docker/put-your-ovpn-files-here${NC}${NC}\n"
     echo -ne "${GREEN}$(trans "Corpus ID: https://t.me/corps_statistics_bot")${NC}\n"
     echo -ne "${GREEN}$(trans "Також документація на офіційному сайті") ${ORANGE}https://x100.vn.ua/${NC}${NC}\n"
     echo -ne "${GREEN}$(trans "З повагою, X100 Кіберкорпус TEAM! Слава УКРАЇНІ!")${NC}\n"

    echo -e "${ORANGE}$(trans "Нажміть будь яку клавішу щоб продовжити")${NC}"
    read -s -n 1 key
}

x100_configure_scheduler() {
  clear
  local trans_minute=$(trans "хвилина")
  local trans_hour=$(trans "година")
  local trans_day=$(trans "день місяця")
  local trans_month=$(trans "місяць")
  local trans_weekday=$(trans "день тижня")
  echo -ne "${GREEN}  .---------------- ${trans_minute} 0-59${NC}\n"
  echo -ne "${GREEN}  +  .------------- ${trans_hour} 0-23${NC}\n"
  echo -ne "${GREEN}  +  +  .---------- ${trans_day} 1-31${NC}\n"
  echo -ne "${GREEN}  +  +  +  .------- ${trans_month} 1-12${NC}\n"
  echo -ne "${GREEN}  +  +  +  +  .---- ${trans_weekday} 0-6${NC}\n"
  echo -ne "${GREEN}  +  +  +  +  +${NC}\n"
  echo -ne "${GREEN}  *  *  *  *  *${NC}\n"

  echo -ne "\n\n"
  echo -ne "${GREEN}$(trans "Або згенеруйте його за посиланням") ${NC}${RED}https://crontab.guru/${NC}"
  echo -ne "\n\n"
  echo -ne "$(trans "Зверніть увагу на ваш час командою") ${GREEN}date${NC}"
  echo -ne "\n\n"
  echo -ne "Наприклад:"
  echo -ne "\n"
  echo -ne "  ${GREEN}$(trans "Запуск X100 о 20:00 щодня") -${NC} ${RED}0 20 * * *${NC}"
  echo -ne "\n"
  echo -ne "  ${GREEN}$(trans "Зупинка X100 о 08:00 щодня") -${NC} ${RED}0 8 * * *${NC}"
  echo -ne "\n\n"
  read -e -p "$(trans "Введіть cron-час для ЗАПУСКУ (формат: * * * * *): ")" -i "$(get_x100_cdss_variable "cron-to-run")" cron_time_to_run
  echo -ne "\n"
  read -e -p "$(trans "Введіть cron-час для ЗУПИНКИ (формат: * * * * *): ")"  -i "$(get_x100_cdss_variable "cron-to-stop")" cron_time_to_stop

  if [[ -n "$cron_time_to_run" ]]; then
    write_x100_cdss_variable "cron-to-run" "$cron_time_to_run"
  elif [[ "$cron_time_to_run" == "" ]]; then
    cron_remove_job "x100_run" || true
    write_x100_cdss_variable "cron-to-run" ""
  fi

  if [[ -n "$cron_time_to_stop" ]]; then
    write_x100_cdss_variable "cron-to-stop" "$cron_time_to_stop"
  elif [[ "$cron_time_to_stop" == "" ]]; then
    cron_remove_job "x100_stop" || true
    write_x100_cdss_variable "cron-to-stop" ""
  fi

  if [[ "$cron_time_to_run" == "" ]] && [[ "$cron_time_to_stop" == "" ]]; then
      confirm_dialog "$(trans "Запуск X100 за розкладом припинено")"
      autoload_configuration
  elif [[ -n "$cron_time_to_run" ]] || [[ -n "$cron_time_to_stop" ]]; then
    to_start_x100_schedule_running
  else
    autoload_configuration
  fi
}

to_start_x100_schedule_running() {
    local menu_items=("$(trans "Так")" "$(trans "Ні")")
    display_menu "$(trans "Запустити X100 за розкладом?")" "${menu_items[@]}"
    res="$CDSS_SELECTION"
     case "$res" in
     "$(trans "Так")" )
       run_x100_on_schedule
       confirm_dialog "$(trans "X100 буде ЗАПУЩЕНО за розкладом")"
       autoload_configuration
     ;;
     "$(trans "Ні")" )
       autoload_configuration
     ;;
     esac
}

run_x100_on_schedule() {
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

  sudo_or_root chmod +x "$SCRIPT_DIR/utils/x100.sh"
  local cron_time_to_run=$(get_x100_cdss_variable "cron-to-run")
  local cron_time_to_stop=$(get_x100_cdss_variable "cron-to-stop")
  cron_remove_job "mhddos_run" || true
  cron_remove_job "mhddos_stop" || true
  cron_remove_job "distress_run" || true
  cron_remove_job "distress_stop" || true
  cron_remove_job "x100_run" || true
  cron_remove_job "x100_stop" || true
  if [[ -n "$cron_time_to_run" ]]; then
    cron_install_job "x100_run" "$cron_time_to_run" ". $(shell_single_quote "${SCRIPT_DIR}/utils/x100.sh") && x100_run"
  fi

  if [[ -n "$cron_time_to_stop" ]]; then
    cron_install_job "x100_stop" "$cron_time_to_stop" ". $(shell_single_quote "${SCRIPT_DIR}/utils/x100.sh") && x100_stop"
  fi
}

regenerate_x100_service_file() {
  local service_file="${SCRIPT_DIR}/services/x100.service"
  local run_path="${SCRIPT_DIR}/x100-for-docker/for-macOS-and-Linux-hosts/run-and-auto-update.bash"
  local stop_path="${SCRIPT_DIR}/x100-for-docker/for-macOS-and-Linux-hosts/stop.bash"
  local work_dir="${SCRIPT_DIR}/x100-for-docker/for-macOS-and-Linux-hosts/"
  local log_file="${SCRIPT_DIR}/x100-for-docker/put-your-ovpn-files-here/x100-log-short.txt"
  local tmp_svc
  tmp_svc=$(mktemp)

  while IFS= read -r line; do
    case "$line" in
      ExecStart=*) echo "ExecStart=$run_path" >> "$tmp_svc" ;;
      ExecStop=*) echo "ExecStop=$stop_path" >> "$tmp_svc" ;;
      WorkingDirectory=*) echo "WorkingDirectory=$work_dir" >> "$tmp_svc" ;;
      ReadWritePaths=*) echo "ReadWritePaths=${SCRIPT_DIR}/x100-for-docker /var/log /tmp" >> "$tmp_svc" ;;
      StandardOutput=*) echo "StandardOutput=append:$log_file" >> "$tmp_svc" ;;
      StandardError=*) echo "StandardError=append:$log_file" >> "$tmp_svc" ;;
      *) echo "$line" >> "$tmp_svc" ;;
    esac
  done < "$service_file"

  sudo_or_root mv -f "$tmp_svc" "$service_file"
}

check_if_x100_running_on_schedule() {
  local crontab_content
  crontab_content=$(sudo_or_root crontab -l 2>/dev/null || true)
  local x100_run_marker="# CDSS:x100_run"
  local x100_stop_marker="# CDSS:x100_stop"
  if echo "$crontab_content" | grep -q "$x100_run_marker" || echo "$crontab_content" | grep -q "$x100_stop_marker"; then
    return 0
  fi
  return 1
}
