validate_cron_schedule() {
  local schedule="$1"

  if [[ -z "$schedule" ]]; then
    return 0
  fi

  local field_count
  field_count=$(echo "$schedule" | awk '{print NF}')

  if [[ "$field_count" -ne 5 ]]; then
    return 1
  fi

  local minute hour day month weekday
  read -r minute hour day month weekday <<< "$schedule"

  for field in "$minute" "$hour" "$day" "$month" "$weekday"; do
    if [[ ! "$field" =~ ^([0-9]+|\*|[0-9]+-[0-9]+|[0-9]+\/[0-9]+|([0-9]+,)+[0-9]+)$ ]]; then
      return 1
    fi
  done

  return 0
}

cron_list() {
  sudo_or_root crontab -l 2>/dev/null || true
}

cleanup_legacy_cron_lines() {
  local tmp_file
  tmp_file=$(mktemp)

  local crontab_content
  crontab_content=$(sudo_or_root crontab -l 2>/dev/null || true)

  local legacy_patterns=("mhddos_run" "mhddos_stop" "distress_run" "distress_stop" "x100_run" "x100_stop")

  while IFS= read -r line; do
    local is_legacy=0
    if [[ "$line" == "# CDSS:"* ]]; then
      continue
    fi
    for pattern in "${legacy_patterns[@]}"; do
      if [[ "$line" == *"$pattern"* ]] && [[ "$line" != "# CDSS:"* ]]; then
        is_legacy=1
        break
      fi
    done
    if [[ $is_legacy -eq 0 ]]; then
      echo "$line" >> "$tmp_file"
    fi
  done <<< "$crontab_content"

  if [[ -s "$tmp_file" ]]; then
    sudo_or_root crontab "$tmp_file" 2>/dev/null
  else
    : > "$tmp_file"
    sudo_or_root crontab "$tmp_file" 2>/dev/null
  fi
  rm -f "$tmp_file"
}

cron_has_job() {
  local job_id="$1"
  local crontab_content
  crontab_content=$(sudo_or_root crontab -l 2>/dev/null || true)

  if echo "$crontab_content" | grep -q "# CDSS:${job_id}"; then
    return 0
  fi

  return 1
}

cron_remove_job() {
  local job_id="$1"
  local tmp_file
  tmp_file=$(mktemp)

  local crontab_content
  crontab_content=$(sudo_or_root crontab -l 2>/dev/null || true)

  local found=0
  while IFS= read -r line; do
    if [[ "$line" == "# CDSS:${job_id}"* ]]; then
      found=1
      continue
    fi
    if [[ "$found" == 1 ]] && [[ -n "$line" ]] && [[ ! "$line" == "# CDSS:"* ]]; then
      found=0
      echo "$line" >> "$tmp_file"
      continue
    fi
    if [[ "$found" == 0 ]]; then
      echo "$line" >> "$tmp_file"
    fi
  done <<< "$crontab_content"

  if [[ "$found" == 1 ]]; then
    if [[ -s "$tmp_file" ]]; then
      sudo_or_root crontab "$tmp_file" 2>/dev/null
    else
      : > "$tmp_file"
      sudo_or_root crontab "$tmp_file" 2>/dev/null
    fi
    rm -f "$tmp_file"
    return 0
  fi

  rm -f "$tmp_file"
  return 1
}

cron_install_job() {
  local job_id="$1"
  local schedule="$2"
  local command="$3"

  if ! validate_cron_schedule "$schedule"; then
    cdss_dialog "$(trans "Некоректний cron-вираз: $schedule")"
    return 1
  fi

  cleanup_legacy_cron_lines
  cron_remove_job "$job_id" || true

  local tmp_file
  tmp_file=$(mktemp)

  local crontab_content
  crontab_content=$(sudo_or_root crontab -l 2>/dev/null || true)

  while IFS= read -r line; do
    echo "$line" >> "$tmp_file"
  done <<< "$crontab_content"

  echo "# CDSS:${job_id}" >> "$tmp_file"
  echo "${schedule} ${command}" >> "$tmp_file"

  if [[ -s "$tmp_file" ]]; then
    sudo_or_root crontab "$tmp_file" 2>/dev/null
    rm -f "$tmp_file"
    return 0
  fi

  rm -f "$tmp_file"
  return 1
}
