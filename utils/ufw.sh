set -uo pipefail

install_ufw() {
  cdss_dialog "$(trans "Встановлюємо фаєрвол")"

  if ! install_firewall_backend; then
    cdss_dialog "$(trans "Не вдалося встановити фаєрвол backend. Спробуйте вручну.")${NC}"
    return 1
  fi

  confirm_dialog "$(trans "Faєrвол встановлено")"
}

ufw_is_active() {
  local svc_cmd
  svc_cmd=$(get_service_is_active_command)
  if $svc_cmd ufw >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

enable_ufw() {
  service_enable ufw
  service_start ufw
  confirm_dialog "$(trans "UFW успішно увімкнено")"
}

disable_ufw() {
  service_disable ufw
  service_stop ufw
  confirm_dialog "$(trans "UFW успішно вимкнено")"
}

ufw_installed() {
  if [[ -n "$(sudo_or_root ufw status 2>/dev/null)" ]]; then
    return 0
  else
    return 1
  fi
}

configure_ufw() {
  ufw_installed
  if [[ $? == 1 ]]; then
    confirm_dialog "$(trans "UFW не встановлений, будь ласка встановіть і спробуйте знову")"
  else
    cdss_dialog "$(trans "Налаштовуємо UFW фаєрвол")"
    sudo_or_root ufw default deny incoming
    sudo_or_root ufw default allow outgoing
    sudo_or_root ufw allow 22
    sudo_or_root ufw --force enable
    confirm_dialog "$(trans "Faєrвол UFW налаштовано і активовано")"
  fi
}
