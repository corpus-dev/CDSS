set -uo pipefail

LOGFILE="/var/log/cdss_cancel_debug.log"

log_cancel_event() {
  local event="$1"
  local details="${2:-}"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$timestamp [CDSS-CANCEL-DEBUG] $event $details" >> "$LOGFILE" 2>/dev/null || true
}

display_menu() {
  local title="$1"
  shift
  local options=("$@")

  log_cancel_event "display_menu CALLED" "title='$title' options_count=${#options[@]}"

  if command -v dialog >/dev/null 2>&1; then
    local dialog_args=()
    local index
    for index in "${!options[@]}"; do
      dialog_args+=("${options[index]}" "")
    done
    local selection
    local tmp_output
    tmp_output=$(mktemp)

    log_cancel_event "dialog LAUNCHING" "title='$title' args_count=${#dialog_args[@]}"

    dialog --ascii-lines --clear --stdout --cancel-label "$(trans "Вихід")" --title "$title" \
      --menu "$(trans "Оберіть опцію:")" 0 0 0 "${dialog_args[@]}" > "$tmp_output" 2>&1
    local dialog_exit=$?

    log_cancel_event "dialog EXIT CODE" "exit_code=$dialog_exit"

    selection=$(cat "$tmp_output" 2>/dev/null || true)
    rm -f "$tmp_output"

    log_cancel_event "selection VALUE" "selection='$selection' length=${#selection}"

    if [[ $dialog_exit -ne 0 ]]; then
      log_cancel_event "CANCEL DETECTED" "dialog_exit=$dialog_exit exit"
      stty sane
      reset
      exit 0
    fi

    if [[ -z "$selection" ]]; then
      log_cancel_event "EMPTY SELECTION" "return empty"
      stty sane
      reset
      exit 0
    fi

    log_cancel_event "VALID SELECTION" "selection='$selection'"
    CDSS_SELECTION="$selection"
    return 0
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
          log_cancel_event "TEXT MODE CHOICE 0" "exit"
          clear
          exit 0
        fi
        idx=$((choice - 1))
        if [[ $idx -ge 0 && $idx -lt ${#options[@]} ]]; then
          log_cancel_event "TEXT MODE VALID CHOICE" "choice=$choice idx=$idx option='${options[$idx]}'"
          CDSS_SELECTION="${options[$idx]}"
          return 0
        fi
      fi

      echo "$(trans "Неправильний вхідний параметр!")"
    done
  fi
}
