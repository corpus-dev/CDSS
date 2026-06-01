set -uo pipefail

get_firewall_display_name() {
  local backend
  backend=$(get_firewall_backend 2>/dev/null || echo "unknown")
  case "$backend" in
    ufw) echo "UFW" ;;
    firewalld) echo "firewalld" ;;
    *) echo "$(trans "невідомий фаєрвол")" ;;
  esac
}

firewall_installed() {
  local backend
  backend=$(get_firewall_backend 2>/dev/null || echo "unknown")
  case "$backend" in
    ufw)
      command -v ufw >/dev/null 2>&1
      ;;
    firewalld)
      command -v firewall-cmd >/dev/null 2>&1 || command -v firewalld >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

firewall_is_active() {
  local backend
  backend=$(get_firewall_backend 2>/dev/null || echo "unknown")
  case "$backend" in
    ufw)
      sudo_or_root ufw status 2>/dev/null | grep -qi "Status: active"
      ;;
    firewalld)
      service_is_active firewalld
      ;;
    *)
      return 1
      ;;
  esac
}

install_ufw() {
  local firewall_name
  firewall_name=$(get_firewall_display_name)
  cdss_dialog "$(trans "Буде встановлено фаєрвол $firewall_name. Він потрібен, щоб закрити вхідні підключення за замовчуванням і залишити дозволеним SSH-доступ.")"

  if ! install_firewall_backend; then
    cdss_dialog "$(trans "Не вдалося встановити фаєрвол backend. Спробуйте вручну.")${NC}"
    return 1
  fi

  confirm_dialog "$(trans "Фаєрвол $firewall_name встановлено")"
}

ufw_is_active() {
  firewall_is_active
}

enable_ufw() {
  local backend firewall_name
  backend=$(get_firewall_backend 2>/dev/null || echo "unknown")
  firewall_name=$(get_firewall_display_name)
  cdss_dialog "$(trans "Увімкнення фаєрвола $firewall_name активує захист на старті системи.")"
  case "$backend" in
    ufw)
      sudo_or_root ufw --force enable
      ;;
    firewalld)
      service_enable firewalld
      service_start firewalld
      ;;
    *)
      cdss_dialog "$(trans "Не вдалося визначити фаєрвол backend.")"
      return 1
      ;;
  esac
  confirm_dialog "$(trans "Фаєрвол $firewall_name успішно увімкнено")"
}

disable_ufw() {
  local backend firewall_name
  backend=$(get_firewall_backend 2>/dev/null || echo "unknown")
  firewall_name=$(get_firewall_display_name)
  cdss_dialog "$(trans "Вимкнення фаєрвола $firewall_name прибере активний мережевий захист. SSH-сесія не повинна обірватися, але сервер стане відкритішим.")"
  case "$backend" in
    ufw)
      sudo_or_root ufw --force disable
      ;;
    firewalld)
      service_disable firewalld
      service_stop firewalld
      ;;
    *)
      cdss_dialog "$(trans "Не вдалося визначити фаєрвол backend.")"
      return 1
      ;;
  esac
  confirm_dialog "$(trans "Фаєрвол $firewall_name успішно вимкнено")"
}

ufw_installed() {
  firewall_installed
}

configure_ufw() {
  local firewall_name
  firewall_name=$(get_firewall_display_name)
  if ! firewall_installed; then
    confirm_dialog "$(trans "Фаєрвол $firewall_name не встановлений, будь ласка встановіть і спробуйте знову")"
  else
    cdss_dialog "$(trans "Буде налаштовано фаєрвол $firewall_name: deny incoming, allow outgoing, дозволити SSH порт 22 і активувати правила.")"
    if ! configure_firewall_backend; then
      confirm_dialog "$(trans "Не вдалося налаштувати фаєрвол $firewall_name")"
      return 1
    fi
    confirm_dialog "$(trans "Фаєрвол $firewall_name налаштовано і активовано")"
  fi
}
