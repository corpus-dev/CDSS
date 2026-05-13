set -uo pipefail

main_menu() {
  local menu_items=("$(trans "Статус атаки")" "$(trans "Розширення портів")" "DDOS" "$(trans "Налаштування безпеки")" "$(trans "Вихід")")
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
    "$(trans "Вихід")")
      echo "$(trans "До побачення!")"
      exit 0
      ;;
    esac
    res=$(display_menu "$(trans "Головне меню")" "${menu_items[@]}")
  done
}
