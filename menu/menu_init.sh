set -uo pipefail

display_menu() {
  local title="$1"
  shift
  local options=("$@")

  if command -v dialog >/dev/null 2>&1; then
    local dialog_args=()
    local index
    for index in "${!options[@]}"; do
      dialog_args+=("${options[index]}" "")
    done
    local selection
    selection=$(dialog --ascii-lines --clear --stdout --cancel-label "$(trans "Вихід")" --title "$title" \
      --menu "$(trans "Оберіть опцію:")" 0 0 0 "${dialog_args[@]}")


    if [[ -z "$selection" ]]; then
      reset
      clear
      exit 0
    fi
    echo "$selection"
  else
    local choice
    local idx
    local i

    while true; do
      echo -e "\n${title}\n"
      i=1
      for opt in "${options[@]}"; do
        echo -e "  $i) $opt"
        ((i++))
      done
      echo -e "  0) $(trans "Вихід")"
      echo -ne "\nОберіть опцію: "
      read -r choice

      if [[ "$choice" =~ ^[0-9]+$ ]]; then
        if [[ "$choice" -eq 0 ]]; then
          exit 0
        fi
        idx=$((choice - 1))
        if [[ $idx -ge 0 && $idx -lt ${#options[@]} ]]; then
          echo "${options[$idx]}"
          return 0
        fi
      fi

      echo "$(trans "Неправильний вхідний параметр!")"
    done
  fi
}
