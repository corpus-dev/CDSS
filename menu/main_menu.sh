set -uo pipefail

main_menu() {
  local menu_items=("$(trans "Статус атаки")" "$(trans "Розширення портів")" "DDOS" "$(trans "Налаштування безпеки")")
  local res

  while true; do
    display_menu "$(trans "Головне меню")" "${menu_items[@]}"
    res="$CDSS_SELECTION"

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
  done
}
