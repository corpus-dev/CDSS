set -uo pipefail

update_env_user_id() {
  local new_user_id="$1"
  local environment_file="$2"

  if [[ -z "$environment_file" ]]; then
    cdss_dialog "$(trans "Шлях до EnvironmentFile не вказано")"
    return 1
  fi

  if [[ ! -f "$environment_file" ]]; then
    cdss_dialog "$(trans "Файл EnvironmentFile не знайдено: $environment_file")"
    return 1
  fi

  if [[ -z "$new_user_id" ]]; then
    return 0
  fi

  if [[ ! "$new_user_id" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    cdss_dialog "$(trans "Corpus ID має містити лише літери, цифри, крапки, тире та підкреслення")"
    return 1
  fi

  if set_config_value "$environment_file" "mhddos" "user-id" "$new_user_id" &&
     set_config_value "$environment_file" "distress" "user-id" "$new_user_id"; then
    cdss_dialog "$(trans "Corpus ID оновлено успішно")"
    return 0
  else
    cdss_dialog "$(trans "Помилка запису: не вдалося оновити файл")"
    return 1
  fi
}

ddos() {
  local menu_items=("$(trans "Встановити DDOS інструменти")" "$(trans "Керування DDOS інструментами")" "$(trans "Повернутися")")

  while true; do
    display_menu "$(trans "DDOS центр")" "${menu_items[@]}"
    res="$CDSS_SELECTION"

    case "$res" in
    "$(trans "Встановити DDOS інструменти")")
      clear
      echo -ne "\n"
      echo -ne "${GREEN}$(trans "В процесі відновлення")${NC}\n"
      echo -ne "${GREEN}$(trans "Corpus ID: https://t.me/corps_statistics_bot")${NC}\n"
      echo -ne "\n"
      echo -ne "${GREEN}$(trans "Щоб пропустити, натисніть Enter")${NC}\n\n"
      echo -ne "$(trans "Corpus ID: ")"

      if [[ -n "$SCRIPT_DIR" ]]; then
        local environment_file="$SCRIPT_DIR/services/EnvironmentFile"
        update_env_user_id "$user_id" "$environment_file"
      else
        cdss_dialog "$(trans "SCRIPT_DIR не визначено, пропуск оновлення user_id")"
      fi

      if is_not_arm_arch; then
        install_mhddos
      fi

      install_distress
      ;;
    "$(trans "Керування DDOS інструментами")")
      ddos_tool_managment
      ;;
    "$(trans "Повернутися")")
      return 0
      ;;
    esac
  done
}
