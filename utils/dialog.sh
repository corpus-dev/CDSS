set -uo pipefail

cdss_dialog() {
  if [[ -t 2 ]]; then
    dialog --ascii-lines --title "Execution Message" --infobox "$1" 10 40
  else
    echo -e "$1"
  fi
}

confirm_dialog() {
  if [[ -t 2 ]]; then
    dialog --ascii-lines --title "Execution Message" --infobox "$1" 10 40
    sleep 2
  else
    echo -e "$1"
  fi
}
