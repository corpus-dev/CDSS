set -uo pipefail

security_configuration() {
  local menu_items=()
  local firewall_name
  firewall_name=$(get_firewall_display_name)
  local res

  if firewall_installed; then
    if firewall_is_active; then
      menu_items+=("$(trans "Вимкнути фаєрвол")")
    else
      menu_items+=("$(trans "Увімкнути фаєрвол")")
    fi
  else
    menu_items+=("$(trans "Встановити фаєрвол")")
  fi

  if fail2ban_installed; then
    if fail2ban_is_active; then
      menu_items+=("$(trans "Вимкнути захист від брутфорсу")")
    else
      menu_items+=("$(trans "Увімкнути захист від брутфорсу")")
    fi
  else
    menu_items+=("$(trans "Встановити Fail2ban")")
  fi

  menu_items+=("$(trans "Налаштувати фаєрвол")" "$(trans "Налаштувати Fail2ban")" "$(trans "Повернутись назад")")

  while true; do
    display_menu "$(trans "Налаштування захисту") ($firewall_name + Fail2ban)" "${menu_items[@]}"
    res="$CDSS_SELECTION"

    case "$res" in
    "$(trans "Встановити фаєрвол")")
      install_ufw
      return 0
      ;;
    "$(trans "Вимкнути фаєрвол")")
      disable_ufw
      return 0
      ;;
    "$(trans "Увімкнути фаєрвол")")
      enable_ufw
      return 0
      ;;
    "$(trans "Встановити Fail2ban")")
      install_fail2ban
      return 0
      ;;
    "$(trans "Вимкнути захист від брутфорсу")")
      disable_fail2ban
      return 0
      ;;
    "$(trans "Увімкнути захист від брутфорсу")")
      enable_fail2ban
      return 0
      ;;
    "$(trans "Налаштувати фаєрвол")")
      configure_ufw
      return 0
      ;;
    "$(trans "Налаштувати Fail2ban")")
      configure_fail2ban
      return 0
      ;;
    "$(trans "Повернутись назад")")
      return 0
      ;;
    esac
  done
}
