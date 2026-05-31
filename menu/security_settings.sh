set -uo pipefail

security_settings() {
  local menu_items=("$(trans "Встановлення захисту")" "$(trans "Налаштування захисту")" "$(trans "Повернутись назад")")

  while true; do
    display_menu "$(trans "Налаштування безпеки")" "${menu_items[@]}"
    res="$CDSS_SELECTION"

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
  done
}
