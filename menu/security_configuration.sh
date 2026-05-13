security_configuration() {
  local menu_items=()
  local uufw=""
  local fail2ban=""
  local res

  uufw_installed
  if [[ $? == 1 ]]; then
    uufw=1
    uufw_is_active
    if [[ $? == 1 ]]; then
      menu_items+=("$(trans "Вимкнути фаервол")")
    else
      menu_items+=("$(trans "Увімкнути фаервол")")
    fi
  fi

  fail2ban_installed
  if [[ $? == 1 ]]; then
    fail2ban=1
    fail2ban_is_active
    if [[ $? == 1 ]]; then
      menu_items+=("$(trans "Вимкнути захист від брутфорсу")")
    else
      menu_items+=("$(trans "Увімкнути захит від брутфорсу")")
    fi
  fi

  menu_items+=("$(trans "Налаштування фаєрвола")" "$(trans "Налаштування захисту від брутфорса")" "$(trans "Повернутись назад")")
  res=$(display_menu "$(trans "Налаштування захисту")" "${menu_items[@]}")

  while true; do
    case "$res" in
    "$(trans "Вимкнути фаервол")")
      disable_ufw
      ;;
    "$(trans "Увімкнути фаервол")")
      enable_ufw
      ;;
    "$(trans "Вимкнути захист від брутфорсу")")
      disable_fail2ban
      ;;
    "$(trans "Увімкнути захист від брутфорсу")")
      enable_fail2ban
      ;;
    "$(trans "Налаштування фаєрвола")")
      configure_ufw
      ;;
    "$(trans "Налаштування захисту від брутфорса")")
      configure_fail2ban
      ;;
    "$(trans "Повернутись назад")")
      return 0
      ;;
    esac
    res=$(display_menu "$(trans "Налаштування захисту")" "${menu_items[@]}")
  done
}
