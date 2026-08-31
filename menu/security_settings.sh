# shellcheck shell=bash
set -uo pipefail

security_settings() {
  local firewall_name
  firewall_name=$(get_firewall_display_name)
  local menu_items=("$(trans "Встановлення захисту")" "$(trans "Налаштування захисту")" "$(trans "Повернутись назад")")

  while true; do
    display_menu "$(trans "Налаштування безпеки")" "${menu_items[@]}"
    res="$CDSS_SELECTION"

    case "$res" in
    "$(trans "Встановлення захисту")")
      cdss_dialog "$(transf "CDSS встановить рекомендований фаєрвол для цієї системи (%s) та Fail2ban для SSH brute-force захисту." "$firewall_name")"
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
