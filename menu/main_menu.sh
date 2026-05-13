set -uo pipefail

log_cancel_event() {
  local event="$1"
  local details="${2:-}"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$timestamp [CDSS-CANCEL-DEBUG] $event $details" >> "/var/log/cdss_cancel_debug.log" 2>/dev/null || true
}

main_menu() {
  local menu_items=("$(trans "Статус атаки")" "$(trans "Розширення портів")" "DDOS" "$(trans "Налаштування безпеки")")
  local res
  res=$(display_menu "$(trans "Головне меню")" "${menu_items[@]}")

  while true; do
    case "$res" in
    "$(trans "Статус атаки")")
      get_ddoss_status
      ;;
    "$(trans "Розширення портів")")
      extend_ports
      ;;
    "DDOS")
      ddos
      ;;
    "$(trans "Налаштування безпеки")")
      security_settings
      ;;
    "")
      log_cancel_event "MAIN MENU CANCEL" "exit"
      stty sane
      clear
      exit 0
      ;;
    esac
    res=$(display_menu "$(trans "Головне меню")" "${menu_items[@]}")
  done
}
