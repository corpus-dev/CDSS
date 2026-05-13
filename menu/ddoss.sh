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

  if [[ ! -w "$environment_file" ]]; then
    cdss_dialog "$(trans "Файл EnvironmentFile недоступний для запису: $environment_file")"
    return 1
  fi

  if [[ -z "$new_user_id" ]]; then
    return 0
  fi

  if [[ ! "$new_user_id" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    cdss_dialog "$(trans "Юзер ІД має містити лише літери, цифри, крапки, тире та підкреслення")"
    return 1
  fi

  if grep -q '^user-id=' "$environment_file" 2>/dev/null; then
    local tmpfile
    tmpfile=$(mktemp)
    sed 's/^user-id=.*/user-id='"$new_user_id"'/' "$environment_file" > "$tmpfile"
    if mv "$tmpfile" "$environment_file"; then
      cdss_dialog "$(trans "Юзер ІД оновлено успішно")"
      return 0
    else
      rm -f "$tmpfile"
      cdss_dialog "$(trans "Помилка запису: не вдалося оновити файл")"
      return 1
    fi
  else
    if echo "user-id=$new_user_id" >> "$environment_file"; then
      cdss_dialog "$(trans "Юзер ІД додано в кінець файлу")"
      return 0
    else
      cdss_dialog "$(trans "Помилка запису: не вдалося додати файл")"
      return 1
    fi
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
      echo -ne "${GREEN}$(trans "Надається Telegram ботом")${NC} ${ORANGE}$(trans "В статусі відновлення, очікуйте на оновлення")${NC}\n"
      echo -ne "\n"
      echo -ne "${GREEN}$(trans "Щоб пропустити, натисніть Enter")${NC}\n\n"
      echo -ne "$(trans "Юзер ІД: ")"
      read -r user_id

      if [[ -n "$SCRIPT_DIR" ]]; then
        local environment_file="$SCRIPT_DIR/services/EnvironmentFile"
        update_env_user_id "$user_id" "$environment_file"
      else
        cdss_dialog "$(trans "SCRIPT_DIR не визначено, пропуск оновлення user_id")"
      fi

      is_not_arm_arch
      if [[ $? == 1 ]]; then
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
