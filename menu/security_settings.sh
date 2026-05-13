set -uo pipefail

log_cancel_event() {
  local event="$1"
  local details="${2:-}"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$timestamp [CDSS-CANCEL-DEBUG] $event $details" >> "/var/log/cdss_cancel_debug.log" 2>/dev/null || true
}

security_settings() {
  local menu_items=("$(trans "Встановлення захисту")" "$(trans "Налаштування захисту")" "$(trans "Повернутись назад")")
  local res
  res=$(display_menu "$(trans "Налаштування безпеки")" "${menu_items[@]}")

  while true; do
    case "$res" in
    "$(trans "Встановлення захисту")")
      install_ufw
      install_fail2ban
      ;;
    "$(trans "Налаштування захисту")")
      security_configuration
      ;;
    "$(trans "Повернутись назад")")
      return 0
      ;;
    esac
    res=$(display_menu "$(trans "Налаштування безпеки")" "${menu_items[@]}")
  done
}
